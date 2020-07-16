//
//  CredentialsManager.swift
//  HeliPort
//
//  Created by Igor Kulman on 22/06/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

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
        let entity = NetworkInfoStorageEntity(network)
        guard let entityJson = try? String(data: JSONEncoder().encode(entity), encoding: .utf8) else {
            return
        }

        Log.debug("Saving password for network \(network.ssid)")
        try? keychain.comment(entityJson).set(networkAuthJson, key: network.keychainKey)
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

    func getSavedNetworks() -> [NetworkInfo] {
        return (keychain.allKeys().compactMap { ssid in
            guard let attributes = try? keychain.get(ssid, handler: {$0}),
                let json = attributes.comment,
                let jsonData = json.data(using: .utf8) else {
                return nil
            }
            return try? JSONDecoder().decode(NetworkInfoStorageEntity.self, from: jsonData)
        } as [NetworkInfoStorageEntity]).filter { entity in
            entity.autoJoin && entity.version == NetworkInfoStorageEntity.CURRENT_VERSION
        }.sorted {
            $0.order < $1.order
        }.map { entity in
            entity.network
        }
    }
}

fileprivate extension NetworkInfo {
    var keychainKey: String {
        return ssid
    }
}
