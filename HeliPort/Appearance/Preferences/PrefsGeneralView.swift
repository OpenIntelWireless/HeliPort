//
//  PrefsGeneralView.swift
//  HeliPort
//
//  Created by Erik Bautista on 8/3/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa
import Sparkle.SPUStandardUpdaterController

class PrefsGeneralView: NSView {

    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    var updater: SPUUpdater {
        return updaterController.updater
    }

    let updatesLabel: NSTextField = {
        let view = NSTextField(labelWithString: .startup)
        return view
    }()

    let autoUpdateCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: .autoCheckUpdate,
                                target: NSButton.self,
                                action: #selector(checkboxChanged(_:)))
        checkbox.identifier = .autoUpdateId
        return checkbox
    }()

    let autoDownloadCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: .autoDownload,
                                target: NSButton.self,
                                action: #selector(checkboxChanged(_:)))
        checkbox.identifier = .autoDownloadId
        return checkbox
    }()

    let gridView: NSGridView = {
        let view = NSGridView()
        view.setContentHuggingPriority(.init(rawValue: 600), for: .horizontal)
        return view
    }()

    convenience init() {
        self.init(frame: NSRect.zero)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        autoUpdateCheckbox.target = self
        autoDownloadCheckbox.target = self
        gridView.addRow(with: [updatesLabel])
        gridView.addColumn(with: [autoUpdateCheckbox, autoDownloadCheckbox])

        let isAutoUpdate = updater.automaticallyChecksForUpdates
        if isAutoUpdate {
            autoUpdateCheckbox.state = isAutoUpdate ? .on : .off
        } else {
            Log.debug("Cannot get auto update state")
        }

        let isAutoDownload = updater.automaticallyDownloadsUpdates
        if isAutoUpdate {
            autoDownloadCheckbox.state = isAutoDownload ? .on : .off
        } else {
            Log.debug("Cannot get auto update state")
        }

        addSubview(gridView)
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupConstraints() {
        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let inset: CGFloat = 20
        gridView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset).isActive = true
        gridView.topAnchor.constraint(equalTo: topAnchor, constant: inset).isActive = true
        gridView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset).isActive = true
        gridView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset).isActive = true
    }
}

extension PrefsGeneralView {
    @objc private func checkboxChanged(_ sender: NSButton) {
        guard let identifier = sender.identifier else { return }
        Log.debug("State changed for \(identifier)")

        switch identifier {
        case .autoUpdateId:
            updater.automaticallyChecksForUpdates = sender.state == .on
        case .autoDownloadId:
            updater.automaticallyDownloadsUpdates = sender.state == .on
        default:
            break
        }
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let autoUpdateId = NSUserInterfaceItemIdentifier(rawValue: "AutoUpdateCheckbox")
    static let autoDownloadId = NSUserInterfaceItemIdentifier(rawValue: "AutoDownloadCheckbox")
}

private extension String {
    static let startup = NSLocalizedString("Updates:")
    static let autoCheckUpdate = NSLocalizedString("Automatically check for updates.")
    static let autoDownload = NSLocalizedString("Automatically download new updates.")
}
