//
//  String+NonNullTerminated.swift
//  HeliPort
//
//  Created by Erik Bautista on 11/21/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

import Foundation

public extension String {
    static func getSSIDFromCString(cString: UnsafePointer<UInt8>) -> String {
        var string = String(cString: cString)
        if string.count > NWID_LEN {
            let pointer = UnsafeRawPointer(cString)
            let nsString = NSString(bytes: pointer, length: Int(NWID_LEN), encoding: Encoding.utf8.rawValue)
            if let nsString = nsString {
                string = nsString as String
            } else {
                string = "\(string.prefix(Int(NWID_LEN)))"
            }
        }
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[\n,\r]*", with: "", options: .regularExpression)

    }
}
