//
//  NetworkManager+Data.swift
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

final class NetworkInfo {
    let ssid: String
    let isConnected: Bool
    var rssi: Int

    var auth = NetworkAuth()

    init (ssid: String, connected: Bool, rssi: Int) {
        self.ssid = ssid
        self.isConnected = connected
        self.rssi = rssi
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

final class NetworkAuth {
    var security: itl80211_security = ITL80211_SECURITY_NONE
    var option: UInt64 = 0
    var identity = [UInt8]()
    var username: String = ""
    var password: String = ""
}
