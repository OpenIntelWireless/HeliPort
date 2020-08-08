//
//  PrefsWindow.swift
//  HeliPort
//
//  Created by Erik Bautista on 8/1/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

class PrefsWindow: NSWindow {

    // MARK: Properties

    var previousIdentifier: NSToolbarItem.Identifier = .none

    convenience init() {
        self.init(contentRect: NSRect.zero,
                  styleMask: [.titled, .closable],
                  backing: .buffered,
                  defer: false)
    }

    override init(contentRect: NSRect,
                  styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType,
                  defer flag: Bool) {

        super.init(contentRect: contentRect,
                   styleMask: style,
                   backing: backingStoreType,
                   defer: flag)

        isReleasedWhenClosed = false

        title = .networkPrefs

        toolbar = NSToolbar(identifier: "NetworkPrefWindowToolbar")
        toolbar!.delegate = self
        toolbar!.displayMode = .iconAndLabel
        toolbar!.insertItem(withItemIdentifier: .general, at: 0)
        toolbar!.insertItem(withItemIdentifier: .networks, at: 1)
        toolbar!.selectedItemIdentifier = .general

        // Set selected item
        clickToolbarItem(NSToolbarItem(itemIdentifier: toolbar!.selectedItemIdentifier!))
    }

    func show() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        center()
    }

    override func close() {
        super.close()
        self.orderOut(NSApp)
    }

    @objc private func clickToolbarItem(_ sender: NSToolbarItem) {
        guard let identifier = toolbar?.selectedItemIdentifier else { return }
        guard previousIdentifier != identifier else {
            Log.debug("Toolbar Item already showing \(identifier)")
            return
        }

        Log.debug("Toolbar Item clicked: \(identifier)")

        var newView: NSView?
        var origin = frame.origin
        var size = frame.size
        switch identifier {
        case .networks:
            newView = PrefsSavedNetworksView()
            size = NSSize(width: 620, height: 420)
        case .general:
            newView = PrefsGeneralView()
            size = newView!.fittingSize
        default:
            Log.error("Toolbar Item not implemented: \(identifier)")
        }

        guard let view = newView else { return }

        origin.y -= size.height - frame.size.height
        contentView = view
        setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
        previousIdentifier = identifier
    }
}

// MARK: NSToolbarItemDelegate

extension PrefsWindow: NSToolbarDelegate {

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general, .networks]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general, .networks]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general, .networks]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.target = self
        toolbarItem.action = #selector(clickToolbarItem(_:))

        switch itemIdentifier {
        case .networks:
            toolbarItem.label = .networks
            toolbarItem.paletteLabel = .networks
            toolbarItem.image = #imageLiteral(resourceName: "WiFi")
            toolbarItem.isEnabled = true
            return toolbarItem
        case .general:
            toolbarItem.label = .general
            toolbarItem.paletteLabel = .general
            toolbarItem.image = NSImage(named: NSImage.preferencesGeneralName)
            toolbarItem.isEnabled = true
            return toolbarItem
        default:
            return nil
        }
    }
}

// MARK: Toolbar Item Identifiers

private extension NSToolbarItem.Identifier {
    static let networks = NSToolbarItem.Identifier("WiFiNetworks")
    static let general = NSToolbarItem.Identifier("General")
    static let none = NSToolbarItem.Identifier("none")
}

// MARK: Localized Strings

private extension String {
    static let networkPrefs = NSLocalizedString("Network Preferences")
    static let networks = NSLocalizedString("Networks")
    static let general = NSLocalizedString("General")
}
