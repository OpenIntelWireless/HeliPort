//
//  itl_80211_state+Status.swift
//  HeliPort
//
//  Created by Igor Kulman on 30/06/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation

extension itl_80211_state: CustomStringConvertible {
    public var description: String {
        switch self {
        case ITL80211_S_INIT:
            return "Wi-Fi: On"
        case ITL80211_S_SCAN:
            return "Wi-Fi: Looking for Networks..."
        case ITL80211_S_AUTH, ITL80211_S_ASSOC:
            return "Wi-Fi: Connecting"
        case ITL80211_S_RUN:
            return "Wi-Fi: Connected"
        default:
            return "Wi-Fi: Status unavailable"
        }
    }
}
