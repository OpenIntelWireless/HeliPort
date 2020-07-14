//
//  PlistManager.swift
//  
//
//  Created by Bat.bat on 6/16/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//
//  Credit mansi-cherry
//  https://github.com/mansi-cherry/iOSHowTo-s/blob/master/MyPlistPlayground.playground/Contents.swift
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation
import Cocoa

public extension FileManager {
    static var appSupportDirURL: URL {
        // Application Support folder is always present
        // swiftlint:disable force_try
        return try! FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        // swiftlint:enable force_try
    }
}

class WifiPlistManager: NSObject {

    enum FileSysError: Error {
        case notAFile
        case notADir
    }

    enum WifiAuthType: String, Codable {
        case NONE
        case WPA1P
        case WPA2P
        case WPA3P
        case WPA1E
        case WPA2E
        case WPA3E
        case WPA12P
        case WPA23P
        case WPA12E
        case WPA23E
    }

    struct WifiPlistEntry: Codable, Hashable {
        init(
            ssid: String,
            authType: WifiAuthType,
            macAddr: String,
            isHidden: Bool,
            userName: String? = nil
        ) {
            self.SSID = ssid
            self.AUTHType = authType
            self.MACAddr = macAddr
            self.ISHidden = isHidden
            self.USERName = userName
        }
        let SSID: String
        let AUTHType: WifiAuthType
        let MACAddr: String
        let ISHidden: Bool
        let USERName: String?
    }

    // CFBundleName is always present in the app's into.plist
    // swiftlint:disable force_cast
    static var appDirName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    // swiftlint:enable force_cast

    static let plistURL = URL(
        fileURLWithPath: Bundle.main.bundleIdentifier! + ".UserData",
        relativeTo: FileManager.appSupportDirURL.appendingPathComponent(appDirName)
    ).appendingPathExtension("plist")

    class func createSupportDir() throws {
        var isDir: ObjCBool = false
        let appSupportSubdirURL = URL(
            fileURLWithPath: appDirName,
            relativeTo: FileManager.appSupportDirURL
        )

        if FileManager.default.fileExists(atPath: appSupportSubdirURL.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                throw FileSysError.notADir
            }
        } else {
            try FileManager.default.createDirectory(
                at: appSupportSubdirURL,
                withIntermediateDirectories: false
            )
        }
    }

    class func writePlist(value: [WifiPlistEntry]) throws {
        let plistDecoder = PropertyListDecoder()
        let plistEncoder = PropertyListEncoder()
        plistEncoder.outputFormat = .xml
        var isDir: ObjCBool = false
        var plistValue: [WifiPlistEntry] = value

        if FileManager.default.fileExists(atPath: plistURL.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                let existingData = try Data.init(contentsOf: plistURL)
                let existingValue = try plistDecoder.decode(
                    [WifiPlistEntry].self,
                    from: existingData
                )
                // Append unique items only
                plistValue = Array(Set(plistValue + existingValue))
            } else {
                throw FileSysError.notAFile
            }
        }
        let plistData = try plistEncoder.encode(plistValue)
        try plistData.write(to: plistURL)
    }

    class func readPlist() throws -> [WifiPlistEntry] {
        let plistDecoder = PropertyListDecoder()
        let data = try Data.init(contentsOf: plistURL)
        let value = try plistDecoder.decode(
            [WifiPlistEntry].self,
            from: data
        )
        return value
    }
}
