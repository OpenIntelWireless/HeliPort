//
//  itl_phy_mode+Description.swift
//  HeliPort
//
//  Created by Igor Kulman on 07/07/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation

extension itl_phy_mode: CustomStringConvertible {
    public var description: String {
        switch self {
        case ITL80211_MODE_11A:
            return "802.11a"
        case ITL80211_MODE_11B:
            return "802.11b"
        case ITL80211_MODE_11G:
            return "802.11g"
        case ITL80211_MODE_11N:
            return "802.11n"
        case ITL80211_MODE_11AC:
            return "802.11ac"
        case ITL80211_MODE_11AX:
            return "802.11ax"
        default:
            return "Unknown"
        }
    }
}
