//
//  NetworkManager.swift
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
import SystemConfiguration

final class NetworkManager {
    static let supportedSecurityMode = [
        ITL80211_SECURITY_NONE,
        ITL80211_SECURITY_WEP,
        ITL80211_SECURITY_WPA_PERSONAL,
        ITL80211_SECURITY_WPA_PERSONAL_MIXED,
        ITL80211_SECURITY_WPA2_PERSONAL,
        ITL80211_SECURITY_PERSONAL,
        ITL80211_SECURITY_WPA_ENTERPRISE_MIXED,
        ITL80211_SECURITY_WPA2_ENTERPRISE
    ]

    private static let enterpriseSecurityModes = [
        ITL80211_SECURITY_WPA_ENTERPRISE_MIXED,
        ITL80211_SECURITY_WPA2_ENTERPRISE
    ]

    static func connect(networkInfo: NetworkInfo, saveNetwork: Bool = false,
                        _ callback: ((_ result: Bool) -> Void)? = nil) {

        guard supportedSecurityMode.contains(networkInfo.auth.security) else {
            let alert = Alert(text: NSLocalizedString("Network security not supported: ")
                              + networkInfo.auth.security.description)
            alert.show()
            return
        }

        let getAuthInfoCallback: (_ auth: NetworkAuth, _ savePassword: Bool) -> Void = { auth, savePassword in
            DispatchQueue.global(qos: .background).async {
                StatusBarIcon.shared().connecting()
                EAPSupplicantManager.shared.endSession(reason: "connecting to \(networkInfo.ssid)")

                if enterpriseSecurityModes.contains(auth.security) {
                    connectEnterprise(networkInfo: networkInfo, auth: auth, savePassword: savePassword, callback)
                    return
                }

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

    // Enterprise networks can't hand a plaintext password straight to
    // connect_network(): the PSK-style ioctl expects a passphrase it derives
    // a PMK from locally, but 802.1X requires an actual multi-round-trip EAP
    // handshake with the RADIUS server (relayed through itlwm) before a PMK
    // exists at all. EAPSupplicantManager owns that handshake and is the
    // only thing that may hand a derived PMK down to itlwm.
    private static func connectEnterprise(networkInfo: NetworkInfo,
                                          auth: NetworkAuth,
                                          savePassword: Bool,
                                          _ callback: ((_ result: Bool) -> Void)?) {
        guard KextEAPOLTransport.isSupported else {
            Log.error("connectEnterprise: installed itlwm has no 802.1X support")
            DispatchQueue.main.async {
                Alert(text: NSLocalizedString("This version of itlwm doesn't support WPA2-Enterprise networks. " +
                                              "Please update itlwm.")).show()
            }
            callback?(false)
            return
        }
        EAPSupplicantManager.shared.useKextTransport()
        beginEnterpriseAssociation(networkInfo: networkInfo, auth: auth,
                                   savePassword: savePassword, callback)
    }

    private static func beginEnterpriseAssociation(networkInfo: NetworkInfo,
                                                   auth: NetworkAuth,
                                                   savePassword: Bool,
                                                   _ callback: ((_ result: Bool) -> Void)?) {
        // Must happen before the EAP handshake starts: this locks itlwm's
        // ic_des_essid onto this SSID and kicks off 802.11 scan/auth/assoc
        // with RSN AKM=8021X (no PSK). Skipping this is exactly the SSID
        // race — a PMK delivered later via set_eap_pmk() would be rejected
        // kernel-side because ic_des_essid would still be whatever the
        // driver was last pointed at (or empty).
        Log.debug("connectEnterprise: associating to \(networkInfo.ssid) " +
                  "(usernameLength=\(auth.username.count), passwordLength=\(auth.password.count))")
        let assocResult = associate_ssid_enterprise(networkInfo.ssid)
        guard assocResult == KERN_SUCCESS else {
            Log.error("connectEnterprise: associate_ssid_enterprise(\(networkInfo.ssid)) failed: \(assocResult)")
            callback?(false)
            return
        }

        // Start the EAP engine right away: the AP sends its EAP-Request/
        // Identity within milliseconds of associating, and itlwm briefly
        // reports the new BSS as RUN before it has actually left the old
        // one, so polling for "associated" first is both too slow and
        // unreliable. The watcher below only nudges (EAPOL-Start) and
        // enforces a timeout.
        startEnterpriseAuthentication(networkInfo: networkInfo, auth: auth,
                                      savePassword: savePassword, callback)
        watchEnterpriseAssociation(ssid: networkInfo.ssid)
    }

    private static let enterpriseAssociationTimeout: TimeInterval = 20

    private static func watchEnterpriseAssociation(ssid: String) {
        let queue = DispatchQueue(label: "org.openintelwireless.HeliPort.enterprise-assoc")
        let start = Date()
        var lastDescription = ""
        var wasRunning = false

        func poll() {
            let elapsed = Date().timeIntervalSince(start)
            let progress = EAPSupplicantManager.shared.progress()
            // authenticate() starts the attempt asynchronously; give it a
            // moment before treating "no active attempt" as "attempt over".
            if !progress.active && elapsed > 2 {
                Log.debug(String(format: "connectEnterprise: +%.2fs attempt for %@ ended, stop watching",
                                 elapsed, ssid))
                return
            }
            if progress.framesIn > 0 {
                Log.debug(String(format: "connectEnterprise: +%.2fs EAP traffic from %@ is flowing, stop watching",
                                 elapsed, ssid))
                return
            }

            var state: UInt32 = 0
            let gotState = get_80211_state(&state)
            var ssidBuf = [CChar](repeating: 0, count: Int(MAX_SSID_LENGTH) + 1)
            let gotSSID = get_network_ssid(&ssidBuf)
            let currentSSID = gotSSID ? String(cString: ssidBuf) : ""
            var bssidBuf = [CChar](repeating: 0, count: 6)
            let gotBSSID = get_network_bssid(&bssidBuf)
            let bssid = bssidBuf.map { String(format: "%02x", UInt8(bitPattern: $0)) }.joined(separator: ":")

            let description = "state=\(gotState ? String(state) : "?") ssid=\(currentSSID) " +
                "bssid=\(gotBSSID ? bssid : "?")"
            if description != lastDescription {
                Log.debug(String(format: "connectEnterprise: +%.2fs %@: %@", elapsed, ssid, description))
                lastDescription = description
            }

            let running = gotState && state == ITL80211_S_RUN.rawValue && currentSSID == ssid &&
                gotBSSID && bssid != "00:00:00:00:00:00"
            if running && !wasRunning {
                EAPSupplicantManager.shared.associationEstablished(bssid: bssid)
            }
            wasRunning = running

            if elapsed >= enterpriseAssociationTimeout {
                EAPSupplicantManager.shared.abortIfNoProgress(
                    reason: "no EAP traffic within \(Int(enterpriseAssociationTimeout))s (last: \(description))")
                return
            }
            queue.asyncAfter(deadline: .now() + 0.1, execute: poll)
        }
        queue.async(execute: poll)
    }

    private static func startEnterpriseAuthentication(networkInfo: NetworkInfo,
                                                      auth: NetworkAuth,
                                                      savePassword: Bool,
                                                      _ callback: ((_ result: Bool) -> Void)?) {
        EAPSupplicantManager.shared.authenticate(ssid: networkInfo.ssid, auth: auth) { result in
            if case .failure = result {
                abandonEnterpriseNetwork(networkInfo.ssid, reason: "EAP failed")
            }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    Log.debug("connectEnterprise: EAP succeeded for \(networkInfo.ssid); PMK handed to itlwm, " +
                              "4-way handshake is up to the driver now")
                    if savePassword {
                        CredentialsManager.instance.save(networkInfo)
                    }
                    callback?(true)
                case .failure(let error):
                    Log.error("EAP authentication failed for \(networkInfo.ssid): \(error)")
                    callback?(false)
                }
            }
        }
    }

    // Without this the driver keeps ic_des_essid pinned to the enterprise
    // SSID after a failure and silently re-associates to it (no keys, no
    // traffic) instead of going back to scanning/auto-join.
    static func abandonEnterpriseNetwork(_ ssid: String, reason: String) {
        // itlwm's disassociate deauths whatever BSS it is on, regardless of
        // the SSID passed. A late failure (e.g. a timeout after the user
        // already switched networks) must not kick them off the new one.
        var ssidBuf = [CChar](repeating: 0, count: Int(MAX_SSID_LENGTH) + 1)
        let current = get_network_ssid(&ssidBuf) ? String(cString: ssidBuf) : ""
        guard current == ssid else {
            Log.debug("connectEnterprise: not releasing \(ssid) (\(reason)); driver has moved on to '\(current)'")
            return
        }
        let result = dis_associate_ssid(ssid)
        if result == KERN_SUCCESS {
            Log.debug("connectEnterprise: released \(ssid) in itlwm (\(reason))")
        } else {
            Log.error("connectEnterprise: dis_associate_ssid(\(ssid)) failed: \(result) (\(reason))")
        }
    }

    static func scanNetwork(sortBy areInIncreasingOrder: @escaping (NetworkInfo, NetworkInfo) -> Bool
                                = { $0.ssid < $1.ssid },
                            callback: @escaping (_ sortedNetworkInfoList: [NetworkInfo]) -> Void) {
        scanNetwork { result in
            callback(result.sorted(by: areInIncreasingOrder))
        }
    }

    static func scanNetwork(sortBy areInIncreasingOrder: @escaping (NetworkInfo, NetworkInfo) -> Bool
                                = { $0.ssid < $1.ssid },
                            callback: @escaping (_ knownNetworks: [NetworkInfo],
                                                 _ otherNetworks: [NetworkInfo]) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let savedSSIDs = CredentialsManager.instance.getSavedNetworkSSIDs()
            scanNetwork { result in
                let known = result.filter { savedSSIDs.contains($0.ssid) }
                let other = result.subtracting(known)

                DispatchQueue.main.async {
                    callback(known.sorted(by: areInIncreasingOrder),
                             other.sorted(by: areInIncreasingOrder))
                }
            }
        }
    }

    private static func scanNetwork(callback: @escaping (_ networkInfoList: Set<NetworkInfo>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            var list = network_info_list_t()
            get_network_list(&list)

            var result = Set<NetworkInfo>()
            let networks = Mirror(reflecting: list.networks).children.map({ $0.value }).prefix(Int(list.count))

            for element in networks {
                guard let network = element as? ioctl_network_info else {
                    continue
                }
                let ssid = String(ssid: network.ssid)
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
                callback(result)
            }
        }
    }

    static func scanSavedNetworks() {
        DispatchQueue.global(qos: .background).async {
            let savedNetworks: [NetworkInfo] = CredentialsManager.instance.getSavedNetworks()
            guard savedNetworks.count > 0 else {
                Log.debug("No network saved for auto join")
                return
            }
            let scanTimer: Timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
                NetworkManager.scanNetwork { networkList in
                    let targetNetworks = savedNetworks.filter { networkList.contains($0) }
                    if targetNetworks.count > 0 {
                        // This will stop the timer completely
                        timer.invalidate()
                        Log.debug("Auto join timer stopped")
                        connectSavedNetworks(networks: targetNetworks)
                    }
                }
            }
            // Start executing code inside the timer immediately
            scanTimer.fire()
            let currentRunLoop = RunLoop.current
            currentRunLoop.add(scanTimer, forMode: .common)
            currentRunLoop.run()
        }
    }

    private static func connectSavedNetworks(networks: [NetworkInfo]) {
        DispatchQueue.global(qos: .background).async {
            let dispatchSemaphore = DispatchSemaphore(value: 0)
            var connected = false
            for network in networks where !connected {
                connect(networkInfo: network) { (result: Bool) in
                    connected = result
                    dispatchSemaphore.signal()
                }
                dispatchSemaphore.wait()
            }
        }
    }

    // Credit: vadian
    // https://stackoverflow.com/a/31838376/13164334
    static func getMACAddressFromBSD(bsd: String) -> String? {
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
        var managementInfoBase = [CTL_NET,
                                  AF_ROUTE,
                                  0,
                                  AF_LINK,
                                  NET_RT_IFLIST,
                                  bsdIndex]

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

    static func isReachable() -> Bool {
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

    static func getRouterAddress(bsd: String) -> String? {
        return getRouterAddressFromSysctl(bsd) ?? getRouterAddressFromNetstat(bsd)
    }

    // from https://stackoverflow.com/questions/30748480/swift-get-devices-wifi-ip-address/30754194#30754194
    static func getLocalAddress(bsd: String) -> String? {
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

    static func getSecurityType(_ info: ioctl_network_info) -> itl80211_security {
        if info.supported_rsnprotos & ITL80211_PROTO_RSN.rawValue != 0 {
            // WPA2
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
            // WPA
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
        return ITL80211_SECURITY_UNKNOWN
    }

    private static func getRouterAddressFromNetstat(_ bsd: String) -> String? {
        var ipAddr: String?

        autoreleasepool {
            // from Goshin
            let ipAddressRegex = #"\s([a-fA-F0-9\.:]+)(\s|%)"# // for ipv4 and ipv6

            let routerCommand = ["-c", "netstat -rn", "|", "egrep -o", "default.*\(bsd)"]
            guard let routerOutput = Commands.execute(executablePath: .shell, args: routerCommand).0 else { return }
            let regex = try? NSRegularExpression.init(pattern: ipAddressRegex, options: [])
            let firstMatch = regex?.firstMatch(in: routerOutput,
                                               options: [],
                                               range: NSRange(location: 0, length: routerOutput.count))
            if let range = firstMatch?.range(at: 1) {
                if let swiftRange = Range(range, in: routerOutput) {
                    ipAddr = String(routerOutput[swiftRange])
                }
            } else {
                Log.debug("Could not find router ip address")
            }
        }

        return ipAddr
    }

    // Modified from https://stackoverflow.com/a/67780630 to support ipv6 and bsd filtering
    // See https://opensource.apple.com/source/network_cmds/network_cmds-606.40.2/netstat.tproj/route.c
    private static func getRouterAddressFromSysctl(_ bsd: String) -> String? {
        var mib: [Int32] = [CTL_NET,
                            PF_ROUTE,
                            0,
                            0,
                            NET_RT_DUMP2,
                            0]
        let mibSize = u_int(mib.count)

        var bufSize = 0
        sysctl(&mib, mibSize, nil, &bufSize, nil, 0)

        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buf.deallocate() }
        buf.initialize(repeating: 0, count: bufSize)

        guard sysctl(&mib, mibSize, buf, &bufSize, nil, 0) == 0 else { return nil }

        // Routes
        var next = buf
        let lim = next.advanced(by: bufSize)
        while next < lim {
            let rtm = next.withMemoryRebound(to: rt_msghdr2.self, capacity: 1) { $0.pointee }
            var ifname = [CChar](repeating: 0, count: Int(IFNAMSIZ + 1))
            if_indextoname(UInt32(rtm.rtm_index), &ifname)

            if String(cString: ifname) == bsd, let addr = getRouterAddressFromRTM(rtm, next) {
                return addr
            }

            next = next.advanced(by: Int(rtm.rtm_msglen))
        }

        return nil
    }

    private static func getRouterAddressFromRTM(_ rtm: rt_msghdr2,
                                                _ ptr: UnsafeMutablePointer<UInt8>) -> String? {
        var rawAddr = ptr.advanced(by: MemoryLayout<rt_msghdr2>.stride)

        for idx in 0..<RTAX_MAX {
            let sockAddr = rawAddr.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0.pointee }

            if (rtm.rtm_addrs & (1 << idx)) != 0 && idx == RTAX_GATEWAY {
                switch Int32(sockAddr.sa_family) {
                case AF_INET:
                    let sAddr = rawAddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }.sin_addr
                    // Take the first match, assuming its destination is "default"
                    return String(cString: inet_ntoa(sAddr), encoding: .ascii)
                case AF_INET6: // Not tested, maybe a garbage address from ipv4 will come first?
                    var sAddr6 = rawAddr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }.sin6_addr
                    var addrV6 = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    inet_ntop(AF_INET6, &sAddr6, &addrV6, socklen_t(INET6_ADDRSTRLEN))
                    return String(cString: addrV6, encoding: .ascii)
                default: break
                }
            }

            rawAddr = rawAddr.advanced(by: Int(sockAddr.sa_len))
        }

        return nil
    }
}
