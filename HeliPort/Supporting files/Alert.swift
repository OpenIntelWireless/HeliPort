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

final class CriticalAlert {
    private let message: String
    private let informativeText: String
    private let options: [String]

    init(message: String, informativeText: String = "", options: [String]) {
        self.message = message
        self.informativeText = informativeText
        self.options = options
    }

    @discardableResult
    func show() -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = message
        alert.informativeText = informativeText

        options.forEach {
            alert.addButton(withTitle: $0)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        return alert.runModal()
    }
}
