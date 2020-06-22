//
//  CredentialsManager.swift
//  HeliPort
//
//  Created by Igor Kulman on 22/06/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

import Foundation

final class CredentialsManager {
    static let instance: CredentialsManager = CredentialsManager()

    func save(_ network: NetworkInfo, password: String) {
        Log.debug("Saving password for network \(network.ssid)")
        KeychainManager.keyChainSaveData(data: password.data(using: .utf8)!, withIdentifier: network.ssid)
    }

    func get(_ network: NetworkInfo) -> String? {
        guard let savedData = KeychainManager.keyChainReadData(identifier: network.ssid) as? Data, let password = String(data: savedData, encoding: .utf8), !password.isEmpty else {
            Log.debug("No stored password for network \(network.ssid)")
            return nil
        }

        Log.debug("Loading password for network \(network.ssid)")
        return password
    }
}
