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
    var signal: Int = 0
    private var password: String = ""

    init (ssid: String, connected: Bool, encrypted: Bool, signal: Int) {
        self.ssid = ssid
        self.isConnected = connected
        self.isEncrypted = encrypted
        self.signal = signal
    }

    @objc func setPassword(password: String) {
        self.password = password
    }

    @objc func connect() {
        print("connect ", ssid, password)
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
            let networkInfo = NetworkInfo(ssid: String(cString: &network!.SSID.0), connected: network!.is_connected, encrypted: network!.is_encrypted, signal: Int(network!.RSSI))
            networkInfoList.append(networkInfo)
        }
        return networkInfoList
    }

    class func count() {

    }
}
