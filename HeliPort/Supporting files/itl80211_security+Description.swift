//
//  itl80211_security+Description.swift
//  HeliPort
//
//  Created by Igor Kulman on 09/07/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation

extension itl80211_security: CustomStringConvertible {
    public var description: String {
        switch self {
        case ITL80211_SECURITY_NONE:
            return "None"
        case ITL80211_SECURITY_WEP:
            return "WEP"
        case ITL80211_SECURITY_WPA_PERSONAL:
            return "WPA Personal"
        case ITL80211_SECURITY_WPA_PERSONAL_MIXED:
            return "WPA/WPA2 Personal"
        case ITL80211_SECURITY_WPA2_PERSONAL:
            return "WPA2 Personal"
        case ITL80211_SECURITY_PERSONAL:
            return "Personal"
        case ITL80211_SECURITY_DYNAMIC_WEP:
            return "Dynamic WEP"
        case ITL80211_SECURITY_WPA_ENTERPRISE:
            return "WPA Enterprise"
        case ITL80211_SECURITY_WPA_ENTERPRISE_MIXED:
            return "WPA/WPA2 Enterprise"
        case ITL80211_SECURITY_WPA2_ENTERPRISE:
            return "WPA2 Enterprise"
        case ITL80211_SECURITY_ENTERPRISE:
            return "Enterprise"
        case ITL80211_SECURITY_WPA3_PERSONAL:
            return "WPA3 Personal"
        case ITL80211_SECURITY_WPA3_ENTERPRISE:
            return "WPA3 Enterprise"
        case ITL80211_SECURITY_WPA3_TRANSITION:
            return "WPA3 Transition"
        default:
            return "Unknown"
        }
    }
}

extension itl80211_security: Codable { }
