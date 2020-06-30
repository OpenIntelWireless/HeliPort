//
//  NetworkInfo.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/3/23.
//  Copyright © 2020 lhy. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation
import Cocoa

class NetworkInfo {
    var ssid: String = ""
    var isConnected: Bool = false
    var rssi: Int = 0

    var auth = NetworkAuth()

    enum AuthSecurity: UInt32 {
        case NONE        = 0x00000000
        case USEGROUP    = 0x00000001
        case WEP40       = 0x00000002
        case TKIP        = 0x00000004
        case CCMP        = 0x00000008
        case WEP104      = 0x00000010
        case BIP         = 0x00000020    /* 11w */
    }

    init (ssid: String, connected: Bool, rssi: Int) {
        self.ssid = ssid
        self.isConnected = connected
        self.rssi = rssi
    }
}

class NetworkAuth {
    var security: UInt32 = 0
    var option: UInt64 = 0
    var identity = [UInt8]()
    var username: String = ""
    var password: String = ""
}

class NetworkManager {
    static var networkInfoList = [NetworkInfo]()

    static let supportedSecurityMode = [
        NetworkInfo.AuthSecurity.NONE.rawValue,
        NetworkInfo.AuthSecurity.TKIP.rawValue,
        NetworkInfo.AuthSecurity.CCMP.rawValue
    ]

    class func connect(networkInfo: NetworkInfo) {
        guard !networkInfo.isConnected else {
            return
        }

        guard supportedSecurityMode.contains(networkInfo.auth.security) else {
            let alert = NSAlert()
            let labelName = String(
                describing: NetworkInfo.AuthSecurity.init(rawValue: networkInfo.auth.security) ??
                NetworkInfo.AuthSecurity.NONE
            )
            alert.messageText = NSLocalizedString("Network security not supported: ", comment: "")
                + labelName
            alert.alertStyle = NSAlert.Style.critical
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

            networkInfoStruct.auth.security = auth.security
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
                        if savePassword, !auth.password.isEmpty {
                            CredentialsManager.instance.save(networkInfo, password: auth.password)
                        }
                    }
                }
            }
        }

        guard networkInfo.auth.security != NetworkInfo.AuthSecurity.NONE.rawValue else {
            networkInfo.auth.password = ""
            getAuthInfoCallback(networkInfo.auth, false)
            return
        }

        guard let savedPassword = CredentialsManager.instance.get(networkInfo) else {
            let popup = WifiPopupWindow(networkInfo: networkInfo, getAuthInfoCallback: getAuthInfoCallback)
            popup.show()
            return
        }

        networkInfo.auth.password = savedPassword
        Log.debug("Connecting to network \(networkInfo.ssid) with saved password")
        getAuthInfoCallback(networkInfo.auth, false)
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
                networkInfo.auth.security = network?.auth.security ?? 0
                networkInfo.auth.option = network?.auth.option ?? 0
                result.insert(networkInfo)
            }

            DispatchQueue.main.async {
                callback(Array(result).sorted { $0.rssi > $1.rssi }.sorted { $0.isConnected && !$1.isConnected })
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
            print("Error: could not find index for bsd name \(bsd)")
            return nil
        }
        let bsdData = Data(bsd.utf8)
        var managementInfoBase = [CTL_NET, AF_ROUTE, 0, AF_LINK, NET_RT_IFLIST, bsdIndex]

        if sysctl(&managementInfoBase, 6, nil, &length, nil, 0) < 0 {
            print("Error: could not determine length of info data structure")
            return nil
        }

        buffer = [CChar](unsafeUninitializedCapacity: length, initializingWith: {buffer, initializedCount in
            for idx in 0..<length { buffer[idx] = 0 }
            initializedCount = length
        })

        if sysctl(&managementInfoBase, 6, &buffer, &length, nil, 0) < 0 {
            print("Error: could not read info data structure")
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
}

extension NetworkInfo: Hashable {
    static func == (lhs: NetworkInfo, rhs: NetworkInfo) -> Bool {
        return lhs.ssid == rhs.ssid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ssid)
    }
}
