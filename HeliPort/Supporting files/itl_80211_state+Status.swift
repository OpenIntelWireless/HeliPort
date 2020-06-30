//
//  itl_80211_state+Status.swift
//  HeliPort
//
//  Created by Igor Kulman on 30/06/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

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
            return "Wi-Fi: Off"
        }
    }
}
