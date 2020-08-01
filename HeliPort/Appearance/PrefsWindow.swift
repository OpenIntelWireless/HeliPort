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

    var oldView: NSView = NSView()

    convenience init() {
        self.init(
            contentRect: NSRect(
            x: 0,
            y: 0,
            width: 520,
            height: 320
        ),
            styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false)
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )
        isReleasedWhenClosed = false

        title = NSLocalizedString("Network Preferences", comment: "")

        toolbar = NSToolbar(identifier: "NetworkPrefWindowToolbar")
        toolbar!.delegate = self
        toolbar!.displayMode = .iconAndLabel
        toolbar!.insertItem(withItemIdentifier: .general, at: 0)
        toolbar!.insertItem(withItemIdentifier: .networks, at: 1)
        toolbar!.selectedItemIdentifier = .networks

        contentView?.addSubview(oldView)

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
        let identifier = sender.itemIdentifier

        Log.debug("Toolbar Item clicked: \(identifier)")

        var newView: NSView?

        switch identifier {
        case .networks:
            newView = PrefsSavedNetworksView(frame: contentView!.frame)
        default:
            break
        }

        guard newView != nil else {
            Log.error("Toolbar Item not implemented: \(identifier)")
            return
        }

        toolbar!.selectedItemIdentifier = identifier

        if oldView.className != newView!.className {
            contentView?.replaceSubview(oldView, with: newView!)
            oldView = newView!
        } else {
            Log.debug("Toolbar Item already showing \(identifier)")
        }
    }
}

// MARK: NSToolbarItemDelegate

extension PrefsWindow: NSToolbarDelegate {

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.networks]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.networks]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.networks]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.target = self

        switch itemIdentifier {
        case .networks:
            toolbarItem.label = NSLocalizedString("Wi-Fi", comment: "")
            toolbarItem.paletteLabel = NSLocalizedString("Wi-Fi", comment: "")
            toolbarItem.image = #imageLiteral(resourceName: "WiFi")
            toolbarItem.isEnabled = true
            toolbarItem.action = #selector(clickToolbarItem(_:))
            return toolbarItem
        case .general:
            toolbarItem.label = NSLocalizedString("General", comment: "")
            toolbarItem.paletteLabel = NSLocalizedString("General", comment: "")
            toolbarItem.image = NSImage(named: NSImage.preferencesGeneralName)
            toolbarItem.isEnabled = false
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
}
