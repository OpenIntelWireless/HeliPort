//
//  KextInfo.swift
//  HeliPort
//
//  Created by Bat.bat on 8/7/21.
//  Copyright © 2021 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation
import IOKit.kext

public class KextInfo {

    private let bundleID: String
    private let kextInfo: NSDictionary

    public init(_ bundleID: String) {
        self.bundleID = bundleID
        self.kextInfo = KextManagerCopyLoadedKextInfo([bundleID] as CFArray, nil).takeRetainedValue() as NSDictionary
    }

    public func kextDidLoad() -> Bool {
        // Kext not loaded will have an empty NSDictionary
        return kextInfo.count > 0
    }

    public func getKextVersion() -> String? {
        return (kextInfo[bundleID] as? NSDictionary)?["CFBundleVersion"] as? String
    }
}
