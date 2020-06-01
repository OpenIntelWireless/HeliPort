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

class NetworkInfo {
    static var networkInfoList = [NetworkInfo]()

    var ssid: String = ""
    var isConnected: Bool = false
    var isEncrypted: Bool = false
    var rssi: Int = 0

    init (ssid: String, connected: Bool, encrypted: Bool, rssi: Int) {
        self.ssid = ssid
        self.isConnected = connected
        self.isEncrypted = encrypted
        self.rssi = rssi
    }

    func connect(auth: NetworkAuth) -> Bool {
        StatusBarIcon.connecting()
        var networkInfoStruct = network_info_t()
        strncpy(&networkInfoStruct.SSID.0, ssid, Int(MAX_SSID_LENGTH))
        networkInfoStruct.is_connected = false
        networkInfoStruct.is_encrypted = isEncrypted
        networkInfoStruct.RSSI = Int32(rssi)

        networkInfoStruct.auth.security = auth.security
        networkInfoStruct.auth.option = auth.option
        networkInfoStruct.auth.identity = UnsafeMutablePointer<UInt8>.allocate(capacity: auth.identity.count)
        networkInfoStruct.auth.identity.initialize(from: &auth.identity, count: auth.identity.count)
        networkInfoStruct.auth.identity_length = UInt32(auth.identity.count)
        networkInfoStruct.auth.username = UnsafeMutablePointer<Int8>(mutating: (auth.username as NSString).utf8String)
        networkInfoStruct.auth.password = UnsafeMutablePointer<Int8>(mutating: (auth.passward as NSString).utf8String)

        return connect_network(&networkInfoStruct)
    }

    class func scanNetwork() -> [NetworkInfo] {
        var list = network_info_list_t()
        get_network_list(&list)
        networkInfoList.removeAll()
        let networks = Mirror(reflecting: list.networks).children.map({ $0.value })
        var idx = 1
        for element in networks {
            if idx > list.count {
                break;
            }
            idx += 1
            var network = element as? network_info_t
            let networkInfo = NetworkInfo(ssid: String(cString: &network!.SSID.0), connected: network!.is_connected, encrypted: network!.is_encrypted, rssi: Int(network!.RSSI))
            networkInfoList.append(networkInfo)
        }
        return networkInfoList.sorted { $0.rssi > $1.rssi }.sorted { $0.isConnected && !$1.isConnected }
    }

    class func count() {

    }
}

class NetworkAuth {
    var security: UInt8 = 0
    var option: UInt64 = 0
    var identity = [UInt8]()
    var username: String = ""
    var passward: String = ""
}
