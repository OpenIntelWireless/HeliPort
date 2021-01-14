//
//  String+NonNullTerminated.swift
//  HeliPort
//
//  Created by Erik Bautista on 11/21/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation

public extension String {
    static func getSSIDFromCString(cString: UnsafePointer<UInt8>) -> String {
        var string = String(cString: cString).trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[\n,\r]*", with: "", options: .regularExpression)
        if string.count > NWID_LEN {
            let pointer = UnsafeRawPointer(cString)
            let nsString = NSString(bytes: pointer, length: Int(NWID_LEN), encoding: Encoding.utf8.rawValue)
            if let nsString = nsString {
                string = nsString as String
            } else {
                string = "\(string.prefix(Int(NWID_LEN)))"
            }
        }
        return string
    }
}
