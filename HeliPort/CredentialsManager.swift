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

    func save(_ network: NetworkInfo) {
        guard let networkAuthJson = try? String(data: JSONEncoder().encode(network.auth), encoding: .utf8) else {
            return
        }
        network.auth = NetworkAuth()
        guard let networkInfoJson = try? String(data: JSONEncoder().encode(network), encoding: .utf8) else {
            return
        }

        Log.debug("Saving password for network \(network.ssid)")
        try? keychain.comment(networkInfoJson).set(networkAuthJson, key: network.keychainKey)
    }

    func get(_ network: NetworkInfo) -> NetworkAuth? {
        guard let password = keychain[string: network.keychainKey],
            let jsonData = password.data(using: .utf8) else {
            Log.debug("No stored password for network \(network.ssid)")
            return nil
        }

        Log.debug("Loading password for network \(network.ssid)")
        return try? JSONDecoder().decode(NetworkAuth.self, from: jsonData)
    }

    func getSavedNetworks() -> [NetworkInfo?] {
        return keychain.allKeys().map { ssid in
            guard let attributes = try? keychain.get(ssid, handler: {$0}),
                let json = attributes.comment,
                let jsonData = json.data(using: .utf8) else {
                return nil
            }
            return try? JSONDecoder().decode(NetworkInfo.self, from: jsonData)
        }
    }
}

fileprivate extension NetworkInfo {
    var keychainKey: String {
        return ssid
    }
}
