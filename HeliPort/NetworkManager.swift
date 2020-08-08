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

        guard supportedSecurityMode.contains(networkInfo.auth.security) else {
            let alert = Alert(text: NSLocalizedString("Network security not supported: ")
                + networkInfo.auth.security.description)
            alert.show()
            return
        }

        let getAuthInfoCallback: (_ auth: NetworkAuth, _ savePassword: Bool) -> Void = { auth, savePassword in
            DispatchQueue.global(qos: .background).async {
                StatusBarIcon.connecting()
                let result = connect_network(networkInfo.ssid, auth.password)
                DispatchQueue.main.async {
                    if result {
                        if savePassword {
                            CredentialsManager.instance.save(networkInfo)
                        }
                    } else {
                        Log.error("Failed to connect to: \(networkInfo.ssid)")
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
                WiFiConfigWindow(windowState: .connectWiFi,
                                 networkInfo: networkInfo,
                                 getAuthInfoCallback: getAuthInfoCallback).show()
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
                guard var network = element as? ioctl_network_info else {
                    continue
                }
                let ssid = String(cString: &network.ssid.0)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "[\n,\r]*", with: "", options: .regularExpression)
                guard !ssid.isEmpty else {
                    continue
                }

                let networkInfo = NetworkInfo(
                    ssid: ssid,
                    rssi: Int(network.rssi)
                )
                networkInfo.auth.security = getSecurityType(network)
                result.insert(networkInfo)
            }

            DispatchQueue.main.async {
                callback(Array(result).sorted { $0.ssid < $1.ssid })
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
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, "captive.apple.com") else {
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
        // from Goshin
        let ipAddressRegex = #"\s([a-fA-F0-9\.:]+)(\s|%)"# // for ipv4 and ipv6

        let routerCommand = ["-c", "netstat -rn", "|", "egrep -o", "default.*\(bsd)"]
        guard let routerOutput = Commands.execute(executablePath: .shell, args: routerCommand).0 else {
            return nil
        }

        let regex = try? NSRegularExpression.init(pattern: ipAddressRegex, options: [])
        let firstMatch = regex?.firstMatch(in: routerOutput,
                                        options: [],
                                        range: NSRange(location: 0, length: routerOutput.count))
        if let range = firstMatch?.range(at: 1) {
            if let swiftRange = Range(range, in: routerOutput) {
                let ipAddr = String(routerOutput[swiftRange])
                return ipAddr
            }
        } else {
            Log.debug("Could not find router ip address")
        }

        return nil
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

    class func getSecurityType(_ info: ioctl_network_info) -> itl80211_security {
        if info.supported_rsnprotos & ITL80211_PROTO_RSN.rawValue != 0 {
            //wpa2
            if info.rsn_akms & ITL80211_AKM_8021X.rawValue != 0 {
                if info.supported_rsnprotos & ITL80211_PROTO_WPA.rawValue != 0 {
                    return ITL80211_SECURITY_WPA_ENTERPRISE_MIXED
                }
                return ITL80211_SECURITY_WPA2_ENTERPRISE
            } else if info.rsn_akms & ITL80211_AKM_PSK.rawValue != 0 {
                if info.supported_rsnprotos & ITL80211_PROTO_WPA.rawValue != 0 {
                    return ITL80211_SECURITY_WPA_PERSONAL_MIXED
                }
                return ITL80211_SECURITY_WPA2_PERSONAL
            } else if info.rsn_akms & ITL80211_AKM_SHA256_8021X.rawValue != 0 {
                return ITL80211_SECURITY_WPA2_ENTERPRISE
            } else if info.rsn_akms & ITL80211_AKM_SHA256_PSK.rawValue != 0 {
                return ITL80211_SECURITY_PERSONAL
            }
        } else if info.supported_rsnprotos & ITL80211_PROTO_WPA.rawValue != 0 {
            //wpa
            if info.rsn_akms & ITL80211_AKM_8021X.rawValue != 0 {
                return ITL80211_SECURITY_WPA_ENTERPRISE
            } else if info.rsn_akms & ITL80211_AKM_PSK.rawValue != 0 {
                return ITL80211_SECURITY_WPA_PERSONAL
            } else if info.rsn_akms & ITL80211_AKM_SHA256_8021X.rawValue != 0 {
                return ITL80211_SECURITY_WPA_ENTERPRISE
            } else if info.rsn_akms & ITL80211_AKM_SHA256_PSK.rawValue != 0 {
                return ITL80211_SECURITY_ENTERPRISE
            }
        } else if info.supported_rsnprotos == 0 {
            return ITL80211_SECURITY_NONE
        }
        //TODO wpa3
        return ITL80211_SECURITY_UNKNOWN
    }
}
