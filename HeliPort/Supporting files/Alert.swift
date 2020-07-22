//
//  CriticalAlert.swift
//  HeliPort
//
//  Created by Igor Kulman on 22/07/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

import AppKit
import Foundation

final class Alert {
    private let text: String

    init(text: String) {
        self.text = text
    }

    func show() {
        let alert = NSAlert()
        alert.messageText = text
        alert.alertStyle = .critical

        if Thread.isMainThread {
            alert.runModal()
        } else {
            DispatchQueue.main.async {
                alert.runModal()
            }
        }
    }
}
