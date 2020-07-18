//
//  NetworkInfo.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/3/23.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation
import Cocoa
import SystemConfiguration

final class NetworkManager {
    static let supportedSecurityMode = [
        ITL80211_SECURITY_NONE,
        ITL80211_SECURITY_WEP,
        ITL80211_SECURITY_WPA_PERSONAL,
        ITL80211_SECURITY_WPA_PERSONAL_MIXED,
        ITL80211_SECURITY_WPA2_PERSONAL,
        ITL80211_SECURITY_PERSONAL
    ]

    class func connect(networkInfo: NetworkInfo, saveNetwork: Bool = false,
                       _ callback: ((_ result: Bool) -> Void)? = nil) {
        guard !networkInfo.isConnected else {
            return
        }

        guard supportedSecurityMode.contains(networkInfo.auth.security) else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Network security not supported: ", comment: "")
                + networkInfo.auth.security.description
            alert.alertStyle = .critical
            DispatchQueue.main.async {
                alert.runModal()
            }
            return
        }

        let getAuthInfoCallback: (_ auth: NetworkAuth, _ savePassword: Bool) -> Void = { auth, savePassword in
            var networkInfoStruct = network_info_t()
            strncpy(
                &networkInfoStruct.SSID.0,
                networkInfo.ssid,
                Int(MAX_SSID_LENGTH)
            )
            networkInfoStruct.is_connected = false
            networkInfoStruct.RSSI = Int32(networkInfo.rssi)

            networkInfoStruct.auth.security = auth.security.rawValue
            networkInfoStruct.auth.option = auth.option
            networkInfoStruct.auth.identity = UnsafeMutablePointer<UInt8>.allocate(capacity: auth.identity.count)
            networkInfoStruct.auth.identity.initialize(
                from: &auth.identity,
                count: auth.identity.count
            )
            networkInfoStruct.auth.identity_length = UInt32(auth.identity.count)
            networkInfoStruct.auth.username = UnsafeMutablePointer<Int8>(
                mutating: (auth.username as NSString).utf8String
            )
            networkInfoStruct.auth.password = UnsafeMutablePointer<Int8>(
                mutating: (auth.password as NSString).utf8String
            )

            DispatchQueue.global(qos: .background).async {
                StatusBarIcon.connecting()
                let result = connect_network(&networkInfoStruct)
                DispatchQueue.main.async {
                    if result {
                        if savePassword {
                            CredentialsManager.instance.save(networkInfo)
                        }
                    }
                    callback?(result)
                }
            }
        }

        // Getting keychain access blocks UI Thread and makes everything freeze unless made async
        DispatchQueue.global().async {
            if let savedNetworkAuth = CredentialsManager.instance.get(networkInfo) {
                networkInfo.auth = savedNetworkAuth
                Log.debug("Connecting to network \(networkInfo.ssid) with saved password")
                CredentialsManager.instance.setAutoJoin(networkInfo.ssid, true)
                getAuthInfoCallback(networkInfo.auth, false)
                return
            }

            guard networkInfo.auth.security != ITL80211_SECURITY_NONE,
                networkInfo.auth.password.isEmpty else {
                getAuthInfoCallback(networkInfo.auth, saveNetwork)
                return
            }

            DispatchQueue.main.async {
                WifiPopupWindow(networkInfo: networkInfo, getAuthInfoCallback: getAuthInfoCallback).show()
            }
        }
    }

    class func scanNetwork(callback: @escaping (_ networkInfoList: [NetworkInfo]) -> Void) {
        DispatchQueue.global(qos: .background).async {
            var list = network_info_list_t()
            get_network_list(&list)

            var result = Set<NetworkInfo>()
            let networks = Mirror(reflecting: list.networks).children.map({ $0.value }).prefix(Int(list.count))

            for element in networks {
                var network = element as? network_info_t
                let ssid = String(cString: &network!.SSID.0)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "[\n,\r]*", with: "", options: .regularExpression)
                guard !ssid.isEmpty else {
                    continue
                }

                let networkInfo = NetworkInfo(
                    ssid: ssid,
                    connected: network!.is_connected,
                    rssi: Int(network!.RSSI)
                )
                networkInfo.auth.security = itl80211_security(rawValue: network?.auth.security ?? 0)
                networkInfo.auth.option = network?.auth.option ?? 0
                result.insert(networkInfo)
            }

            DispatchQueue.main.async {
                callback(Array(result).sorted { $0.ssid < $1.ssid }.sorted { $0.isConnected && !$1.isConnected })
            }
        }
    }

    class func connectSavedNetworks() {
        DispatchQueue.global(qos: .background).async {
            let dispatchSemaphore = DispatchSemaphore(value: 0)
            var connected = false
            for network in CredentialsManager.instance.getSavedNetworks() where !connected {
                connect(networkInfo: network) { (result: Bool) -> Void in
                    connected = result
                    dispatchSemaphore.signal()
                }
                dispatchSemaphore.wait()
            }
        }
    }

    // Credit: vadian
    // https://stackoverflow.com/a/31838376/13164334
    class func getMACAddressFromBSD(bsd: String) -> String? {
        let MAC_ADDRESS_LENGTH = 6
        let separator = ":"

        var length: size_t = 0
        var buffer: [CChar]

        let bsdIndex = Int32(if_nametoindex(bsd))
        if bsdIndex == 0 {
            Log.error("Could not find index for bsd name \(bsd)")
            return nil
        }
        let bsdData = Data(bsd.utf8)
        var managementInfoBase = [CTL_NET, AF_ROUTE, 0, AF_LINK, NET_RT_IFLIST, bsdIndex]

        if sysctl(&managementInfoBase, 6, nil, &length, nil, 0) < 0 {
            Log.error("Could not determine length of info data structure")
            return nil
        }

        buffer = [CChar](unsafeUninitializedCapacity: length, initializingWith: {buffer, initializedCount in
            for idx in 0..<length { buffer[idx] = 0 }
            initializedCount = length
        })

        if sysctl(&managementInfoBase, 6, &buffer, &length, nil, 0) < 0 {
            Log.error("Could not read info data structure")
            return nil
        }

        let infoData = Data(bytes: buffer, count: length)
        let indexAfterMsghdr = MemoryLayout<if_msghdr>.stride + 1
        let rangeOfToken = infoData[indexAfterMsghdr...].range(of: bsdData)!
        let lower = rangeOfToken.upperBound
        let upper = lower + MAC_ADDRESS_LENGTH
        let macAddressData = infoData[lower..<upper]
        let addressBytes = macAddressData.map { String(format: "%02x", $0) }
        return addressBytes.joined(separator: separator)
    }

    class func isReachable() -> Bool {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com") else {
            return false
        }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)

        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability, &flags)

        let isReachable: Bool = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let canConnectAutomatically = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
        let canConnectWithoutUserInteraction = canConnectAutomatically && !flags.contains(.interventionRequired)
        return isReachable && (!needsConnection || canConnectWithoutUserInteraction)
    }

    class func getRouterAddress(bsd: String) -> String? {
        let dynamicCreate = SCDynamicStoreCreate(kCFAllocatorDefault, "router-ip" as CFString, nil, nil)
        let keyIPv4 = "State:/Network/Global/IPv4" as CFString
        let keyIPv6 = "State:/Network/Global/IPv6" as CFString
        let dictionary = SCDynamicStoreCopyValue(dynamicCreate, keyIPv4)
            ?? SCDynamicStoreCopyValue(dynamicCreate, keyIPv6)

        guard let interface = dictionary?[kSCDynamicStorePropNetPrimaryInterface] as? String, interface == bsd else {
            Log.error("Could not find interface")
            return nil
        }

        guard let ipRouterAddr = dictionary?["Router"] as? String else {
            Log.error("Could not find router ip")
            return nil
        }

        return ipRouterAddr
    }

    // from https://stackoverflow.com/questions/30748480/swift-get-devices-wifi-ip-address/30754194#30754194
    class func getLocalAddress(bsd: String) -> String? {
        // Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        var ipV4: String?
        var ipV6: String?

        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            guard addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) else {
                continue
            }

            // Check interface name:
            let name = String(cString: interface.ifa_name)
            guard name == bsd else {
                continue
            }

            // Convert interface address to a human readable string:
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, socklen_t(0), NI_NUMERICHOST)

            if addrFamily == UInt8(AF_INET) {
                ipV4 = String(cString: hostname)
            } else if addrFamily == UInt8(AF_INET6) {
                ipV6 = String(cString: hostname)
            }
        }

        freeifaddrs(ifaddr)

        // ipV4 has priority
        return ipV4 ?? ipV6
    }
}
