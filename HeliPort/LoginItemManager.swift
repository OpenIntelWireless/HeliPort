//
//  LoginItemManager.swift
//  HeliPort
//
//  Created by Bat.bat on 7/14/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation
import ServiceManagement

class LoginItemManager {

    private static let launcherId = Bundle.main.bundleIdentifier! + "-Launcher"

    public class func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            guard let jobs =
                (LoginItemManager.self as DeprecationWarningWorkaround.Type).jobsDict
            else {
                return false
            }

            let job = jobs.first { $0["Label"] as? String? == launcherId }

            return job?["OnDemand"] as? Bool ?? false
        }
    }

    public class func setStatus(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status == .enabled {
                        try? SMAppService.mainApp.unregister()
                    }
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Log.error("Failed to \(enabled ? "enable" : "disable") login item: \(error.localizedDescription)")
            }
        } else {
            SMLoginItemSetEnabled(launcherId as CFString, enabled)
        }
    }
}

private protocol DeprecationWarningWorkaround {
    static var jobsDict: [[String: AnyObject]]? { get }
}

extension LoginItemManager: DeprecationWarningWorkaround {
    // Workaround to silence "'SMCopyAllJobDictionaries' was deprecated in OS X 10.10" warning
    @available(*, deprecated)
    static var jobsDict: [[String: AnyObject]]? {
        SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: AnyObject]]
    }
}