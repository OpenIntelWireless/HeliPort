//
//  CertificatePinStore.swift
//  HeliPort
//
//  Copyright © 2026 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation
import KeychainAccess

/// Trust-on-first-use storage for the RADIUS server certificate presented
/// during PEAP, keyed by SSID (not BSSID: one RADIUS server backs an entire
/// ESS, and pinning per-BSSID would both break roaming between APs of the
/// same network and add no real security). Deliberately a separate Keychain
/// service from CredentialsManager's -- certificate pins and network
/// passwords are different concerns and shouldn't share a namespace.
final class CertificatePinStore {
    static let shared = CertificatePinStore()

    private let keychain: Keychain

    private init() {
        let base = Bundle.main.bundleIdentifier ?? "org.openintelwireless.HeliPort"
        keychain = Keychain(service: base + ".certpin")
    }

    struct Pin: Codable {
        let sha256Hex: String
        let subject: String
    }

    func pin(forSSID ssid: String) -> Pin? {
        guard let json = keychain[string: ssid], let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(Pin.self, from: data)
    }

    func setPin(_ pin: Pin, forSSID ssid: String) {
        guard let data = try? JSONEncoder().encode(pin), let json = String(bytes: data, encoding: .utf8) else {
            return
        }
        try? keychain.set(json, key: ssid)
    }

    func removePin(forSSID ssid: String) {
        try? keychain.remove(ssid)
    }
}
