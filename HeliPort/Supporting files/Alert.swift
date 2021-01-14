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

final class CriticalAlert: NSObject {
    private let message: String
    private let informativeText: String
    private let options: [String]
    private var helpAnchor: String?
    private var errorText: String?

    init(message: String,
         informativeText: String = "",
         options: [String],
         helpAnchor: String? = nil,
         errorText: String? = nil) {
        self.message = message
        self.informativeText = informativeText
        self.options = options
        self.helpAnchor = helpAnchor
        self.errorText = errorText
    }

    @discardableResult
    func show() -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = message
        alert.informativeText = informativeText
        if let helpAnchor = helpAnchor {
            alert.delegate = self
            alert.showsHelp = true
            alert.helpAnchor = helpAnchor
        }

        if let errorText = errorText {
            let errorTextField = NSTextField(labelWithString: "Error code: \(errorText)")
            errorTextField.font = NSFont.labelFont(ofSize: 10)
            alert.accessoryView = errorTextField
        }

        options.forEach {
            alert.addButton(withTitle: $0)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        return alert.runModal()
    }
}

extension CriticalAlert: NSAlertDelegate {
    func alertShowHelp(_ alert: NSAlert) -> Bool {
        if let helpAnchor = helpAnchor, let url = URL(string: helpAnchor) {
            NSWorkspace().open(url)
            return true
        }
        return false
    }
}
