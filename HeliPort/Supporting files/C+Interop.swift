//
//  C+Interop.swift
//  HeliPort
//
//  Created by Igor Kulman on 30/06/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//
// swiftlint:disable large_tuple line_length

import Foundation

func char32ToString(tuple: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar)) -> String {
    let arr: [unichar] = [unichar(tuple.0), unichar(tuple.1), unichar(tuple.2), unichar(tuple.3),
                        unichar(tuple.4), unichar(tuple.5), unichar(tuple.6), unichar(tuple.7), unichar(tuple.8), unichar(tuple.9), unichar(tuple.10), unichar(tuple.11),
                        unichar(tuple.12), unichar(tuple.13), unichar(tuple.14), unichar(tuple.15), unichar(tuple.16), unichar(tuple.17), unichar(tuple.18), unichar(tuple.19),
                        unichar(tuple.20), unichar(tuple.21), unichar(tuple.22), unichar(tuple.23), unichar(tuple.24), unichar(tuple.25), unichar(tuple.26), unichar(tuple.27),
                        unichar(tuple.28), unichar(tuple.29), unichar(tuple.30), unichar(tuple.31)]
    let len = arr.firstIndex(of: 0) ?? 0
    return NSString(characters: arr, length: len) as String
}
