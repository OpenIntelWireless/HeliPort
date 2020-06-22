//
//  CredentialsManager.swift
//  HeliPort
//
//  Created by Igor Kulman on 22/06/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

import Foundation
import KeychainAccess

final class CredentialsManager {
    static let instance: CredentialsManager = CredentialsManager()

    private let keychain: Keychain

    init() {
        keychain = Keychain(service: Bundle.main.bundleIdentifier!)
    }

    func save(_ network: NetworkInfo, password: String) {
        Log.debug("Saving password for network \(network.ssid)")
        keychain[string: network.keychainKey] = password
    }

    func get(_ network: NetworkInfo) -> String? {
        guard let password = keychain[string: network.keychainKey], !password.isEmpty else {
            Log.debug("No stored password for network \(network.ssid)")
            return nil
        }

        Log.debug("Loading password for network \(network.ssid)")
        return password
    }
}

fileprivate extension NetworkInfo {
    var keychainKey: String {
        return ssid
    }
}
