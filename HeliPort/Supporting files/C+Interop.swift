//
//  C+Interop.swift
//  HeliPort
//
//  Created by Igor Kulman on 30/06/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

import Foundation

func cTupleToString<T>(tuple: T) -> String {
    var result: [CChar] = []
    let mirror = Mirror(reflecting: tuple)
    for child in mirror.children {
        if let value = child.value as? CChar {
            result.append(value)
        }
    }
    result.append(CChar(0))  // Null terminate

    return String(cString: result)
}
