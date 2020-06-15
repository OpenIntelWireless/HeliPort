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
        if networkInfo.isConnected {
            return
        }
        if !supportedSecurityMode.contains(networkInfo.auth.security) {
            let alert = NSAlert()
            let labelName = String(describing: NetworkInfo.AuthSecurity.init(rawValue: networkInfo.auth.security) ?? NetworkInfo.AuthSecurity.NONE)
            alert.messageText = NSLocalizedString("Network security not supported: ", comment: "")
                + labelName
            alert.alertStyle = NSAlert.Style.critical
            DispatchQueue.main.async {
                alert.runModal()
            }
            return
        }

        let getAuthInfoCallback: (_ auth: NetworkAuth) -> Void = { auth in
            var networkInfoStruct = network_info_t()
            strncpy(&networkInfoStruct.SSID.0, networkInfo.ssid, Int(MAX_SSID_LENGTH))
            networkInfoStruct.is_connected = false
            networkInfoStruct.RSSI = Int32(networkInfo.rssi)

            networkInfoStruct.auth.security = auth.security
            networkInfoStruct.auth.option = auth.option
            networkInfoStruct.auth.identity = UnsafeMutablePointer<UInt8>.allocate(capacity: auth.identity.count)
            networkInfoStruct.auth.identity.initialize(from: &auth.identity, count: auth.identity.count)
            networkInfoStruct.auth.identity_length = UInt32(auth.identity.count)
            networkInfoStruct.auth.username = UnsafeMutablePointer<Int8>(mutating: (auth.username as NSString).utf8String)
            networkInfoStruct.auth.password = UnsafeMutablePointer<Int8>(mutating: (auth.password as NSString).utf8String)

            StatusBarIcon.connecting()
            DispatchQueue.global(qos: .background).async {
                let result = connect_network(&networkInfoStruct)
                DispatchQueue.main.async {
                    if result {
                        StatusBarIcon.connected()
                    } else {
                        StatusBarIcon.disconnected()
                    }
                }
            }
        }

        if networkInfo.auth.security == NetworkInfo.AuthSecurity.NONE.rawValue {
            networkInfo.auth.password = ""
            getAuthInfoCallback(networkInfo.auth)
        } else {
            let popWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 450, height: 247), styleMask: .titled, backing: .buffered, defer: false)
            let wifiPopView: WiFiPopoverSubview = WiFiPopoverSubview(popWindow: popWindow, networkInfo: networkInfo, getAuthInfoCallback: getAuthInfoCallback)
            popWindow.contentView = wifiPopView
            popWindow.isReleasedWhenClosed = false
            popWindow.level = .floating
            popWindow.makeKeyAndOrderFront(self)
            popWindow.center()
        }
    }

    class func scanNetwork(callback: @escaping (_ networkInfoList: [NetworkInfo]) -> Void) {
        DispatchQueue.global(qos: .background).async {
            var list = network_info_list_t()
            get_network_list(&list)
            networkInfoList.removeAll()
            let networks = Mirror(reflecting: list.networks).children.map({ $0.value })
            var idx = 1
            for element in networks {
                if idx > list.count {
                    break
                }
                idx += 1
                var network = element as? network_info_t
                let networkInfo = NetworkInfo(ssid: String(cString: &network!.SSID.0), connected: network!.is_connected, rssi: Int(network!.RSSI))
//                networkInfo.auth.security = network?.auth.security ?? 0
                //TODO hard coded
                networkInfo.auth.security = NetworkInfo.AuthSecurity.CCMP.rawValue
                networkInfo.auth.option = network?.auth.option ?? 0
                networkInfoList.append(networkInfo)
            }
            var ssidSet = Set<String>()
            networkInfoList = networkInfoList.sorted { $0.rssi > $1.rssi }.sorted { $0.isConnected && !$1.isConnected }
                .filter { $0.ssid != "" && ssidSet.insert($0.ssid).0 }
            callback(networkInfoList)
        }
    }
}
