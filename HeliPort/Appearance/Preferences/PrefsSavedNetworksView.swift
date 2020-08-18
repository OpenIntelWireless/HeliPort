//
//  PrefsSavedNetworksView.swift
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

class PrefsSavedNetworksView: NSView {

    // MARK: Saved networks array

    var savedNetworks: [NetworkInfoStorageEntity] = []

    // MARK: Properties

    let savedNetworksLabel: NSTextField = {
        let label = NSTextField(labelWithString: .savedNetworks)
        return label
    }()

    let scrollView: NSScrollView = {
        let view = NSScrollView()
        view.hasHorizontalScroller = true
        view.hasVerticalScroller = true
        view.autohidesScrollers = true
        view.focusRingType = .exterior
        return view
    }()

    let tableView: NSTableView = {
        let table = NSTableView()
        table.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle
        table.registerForDraggedTypes([.rowOrder])

        let font = NSFont.systemFont(ofSize: 12)
        let attributes = [NSAttributedString.Key.font: font]

        let ssidColumn = NSTableColumn(identifier: .ssidId)
        ssidColumn.title = .networkName
        ssidColumn.minWidth = (ssidColumn.title as NSString).size(withAttributes: attributes).width
        table.addTableColumn(ssidColumn)

        let securityColumn = NSTableColumn(identifier: .securityId)
        securityColumn.title = .security
        securityColumn.minWidth = (securityColumn.title as NSString).size(withAttributes: attributes).width
        table.addTableColumn(securityColumn)

        let autoenabledColumn = NSTableColumn(identifier: .autoenabledId)
        autoenabledColumn.title = .autoJoin
        autoenabledColumn.minWidth = (autoenabledColumn.title as NSString).size(withAttributes: attributes).width
        table.addTableColumn(autoenabledColumn)

        return table
    }()

    let orderItemsLabel: NSTextField = {
        let orderPreferenceString: String = .dragNetworks
        let label = NSTextField(labelWithString: orderPreferenceString)
        return label
    }()

    let modifyItemSegment: NSSegmentedControl = {
        let removeImage = NSImage(named: NSImage.removeTemplateName)!
        let viewImage = NSImage(named: NSImage.quickLookTemplateName)!
        let button = NSSegmentedControl(images: [removeImage, viewImage],
                                        trackingMode: .momentary,
                                        target: self,
                                        action: #selector(modifyItemClicked(_:)))
        button.setEnabled(false, forSegment: .remove)
        button.setEnabled(false, forSegment: .view)
        return button
    }()

    convenience init() {
        self.init(frame: NSRect.zero)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        tableView.delegate = self
        tableView.dataSource = self
        scrollView.documentView = tableView

        addSubview(savedNetworksLabel)
        addSubview(scrollView)
        addSubview(modifyItemSegment)
        addSubview(orderItemsLabel)

        setupConstraints()

        DispatchQueue.global(qos: .background).async {
            self.savedNetworks = CredentialsManager.instance.getSavedNetworksEntity()
            DispatchQueue.main.async {
                self.tableView.reloadData()
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupConstraints() {
        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let inset: CGFloat = 20
        savedNetworksLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset).isActive = true
        savedNetworksLabel.topAnchor.constraint(equalTo: topAnchor, constant: inset).isActive = true

        scrollView.leadingAnchor.constraint(equalTo: savedNetworksLabel.leadingAnchor).isActive = true
        scrollView.topAnchor.constraint(equalTo: savedNetworksLabel.bottomAnchor, constant: 8).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset).isActive = true

        modifyItemSegment.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8).isActive = true
        modifyItemSegment.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor).isActive = true
        modifyItemSegment.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset).isActive = true

        orderItemsLabel.leadingAnchor.constraint(equalTo: modifyItemSegment.trailingAnchor, constant: 4).isActive = true
        orderItemsLabel.centerYAnchor.constraint(equalTo: modifyItemSegment.centerYAnchor).isActive = true
    }

    private func updateNetworkPriority() {
        Log.debug("Updating network priority")
        for order in 0..<savedNetworks.count {
            let entity = savedNetworks[order]
            if entity.order != order {
                entity.order = order
                DispatchQueue.global(qos: .background).async {
                    CredentialsManager.instance.setPriority(entity.network.ssid, order)
                }
            }
        }
    }
}

// MARK: Action Items

extension PrefsSavedNetworksView {

    @objc func modifyItemClicked(_ sender: NSSegmentedControl) {
        let selectedSegment = sender.selectedSegment
        switch selectedSegment {
        case .remove:
            removeNetwork()
        case .view:
            viewNetwork()
        default:
            Log.debug("Modify item not implemented \(selectedSegment)")
        }
    }

    private func viewNetwork() {
        let index = tableView.selectedRow
        let networkInfo = savedNetworks[index].network

        guard let currentWindow = window else {
            Log.error("Could not show view window due to window == nil")
             return
        }

        let viewCredentials = WiFiConfigWindow(windowState: .viewCredentialsWiFi, networkInfo: networkInfo)
        currentWindow.beginSheet(viewCredentials)
    }

    private func removeNetwork() {
        let index = tableView.selectedRow
        let networkEntity = savedNetworks[index]

        guard let currentWindow = window else {
            Log.error("Could not show remove alert due to window == nil")
             return
        }

        let alert = NSAlert()
        alert.informativeText = .macWillNotJoin
        alert.messageText = String(format: .removeNetwork, "\(networkEntity.network.ssid)")
        alert.addButton(withTitle: .remove)
        alert.addButton(withTitle: .cancel)
        alert.icon = #imageLiteral(resourceName: "WiFi")
        alert.alertStyle = .warning
        alert.beginSheetModal(for: currentWindow) { response in
            switch response {
            case .alertFirstButtonReturn:
                DispatchQueue.global(qos: .background).async {
                    CredentialsManager.instance.remove(networkEntity.network)
                    DispatchQueue.main.async {
                        self.savedNetworks.remove(at: index)
                        self.tableView.removeRows(at: IndexSet(integer: index), withAnimation: .effectFade)
                    }
                }
            default:
                break
            }
        }
    }

    @objc func autoJoinCheckboxChanged(_ sender: NSButton) {
        let rowIndex = tableView.row(for: sender)
        let columnIndex = tableView.column(for: sender)
        let networkEntity = savedNetworks[rowIndex]
        Log.debug("Auto join checkbox changed for \(networkEntity.network.ssid)")
        let autoJoinEnabled = sender.state == .on
        networkEntity.autoJoin = autoJoinEnabled

        DispatchQueue.global(qos: .background).async {
            CredentialsManager.instance.setAutoJoin(networkEntity.network.ssid, autoJoinEnabled)
            DispatchQueue.main.async {
                self.savedNetworks[rowIndex] = networkEntity
                self.tableView.reloadData(forRowIndexes: IndexSet(integer: rowIndex),
                                          columnIndexes: IndexSet(integer: columnIndex))
            }
        }
    }
}

// MARK: Modify index

private extension Int {
    static let remove = 0
    static let view = 1
}

// MARK: Table view delegate

extension PrefsSavedNetworksView: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard tableColumn != nil else { return nil }

        var view: NSView? = tableView.makeView(withIdentifier: .textViewId, owner: self) as? NSTextField
        if view == nil {
            view = NSTextField(labelWithString: "")
            view?.identifier = .textViewId
        }

        let networkEntity = savedNetworks[row]

        switch tableColumn!.identifier {
        case .ssidId:
            (view as? NSTextField)!.stringValue = networkEntity.network.ssid
        case .securityId:
            (view as? NSTextField)!.stringValue = networkEntity.network.auth.security.description
        case .autoenabledId:
            view = tableView.makeView(withIdentifier: .checkboxId, owner: self) as? NSButton
            if view == nil {
                view = NSButton(checkboxWithTitle: "",
                                target: self,
                                action: #selector(autoJoinCheckboxChanged(_:)))
                view?.identifier = .checkboxId
            }
            (view as? NSButton)!.state = networkEntity.autoJoin ? .on : .off
        default:
            break
        }

        return view
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selected = tableView.selectedRow != -1
        modifyItemSegment.setEnabled(selected, forSegment: .remove)
        modifyItemSegment.setEnabled(selected, forSegment: .view)
    }
}

// MARK: Table view data source

extension PrefsSavedNetworksView: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return savedNetworks.count
    }

    // Called by aTableView when the mouse button is released over a table view that previously decided to allow a drop.

    func tableView(_ tableView: NSTableView,
                   acceptDrop info: NSDraggingInfo,
                   row: Int,
                   dropOperation: NSTableView.DropOperation) -> Bool {
        let pasteBoard = info.draggingPasteboard
        if let itemData = pasteBoard.pasteboardItems?.first?.data(forType: .rowOrder),
            let indexes = NSKeyedUnarchiver.unarchiveObject(with: itemData) as? IndexSet,
            let originalRow = indexes.first {

            var newRow = row
            if originalRow < newRow {
                newRow = row - 1
            }

            let oldEntity = savedNetworks[originalRow]
            savedNetworks.remove(at: originalRow)
            savedNetworks.insert(oldEntity, at: newRow)

            updateNetworkPriority()

            tableView.reloadData()

            // Select item at new location
            tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)

            return true
        }
        return false
    }

    // Allows drag operation

    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        let data = NSKeyedArchiver.archivedData(withRootObject: rowIndexes)
        let item = NSPasteboardItem()
        item.setData(data, forType: .rowOrder)
        pboard.writeObjects([item])
        return true
    }

    // Used by aTableView to determine a valid drop target.

    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard let source = info.draggingSource as? NSTableView, source == self.tableView else { return [] }
        if dropOperation == .above {
            return .move
        }

        return []
    }
}

private extension NSPasteboard.PasteboardType {
    static let rowOrder: NSPasteboard.PasteboardType = .init("private.row-order")
}

// MARK: User Interface Identifiers

private extension NSUserInterfaceItemIdentifier {

    static let ssidId: NSUserInterfaceItemIdentifier = .init(rawValue: "ssidColumn")
    static let securityId: NSUserInterfaceItemIdentifier = .init(rawValue: "securityColumn")
    static let autoenabledId: NSUserInterfaceItemIdentifier = .init(rawValue: "autoenabledColumn")

    static let textViewId: NSUserInterfaceItemIdentifier = .init(rawValue: "textViewId")
    static let checkboxId: NSUserInterfaceItemIdentifier = .init(rawValue: "checkboxId")
}

// MARK: Localized Strings

private extension String {
    static let savedNetworks = NSLocalizedString("Saved Networks:")
    static let networkName = NSLocalizedString("Network Name")
    static let security = NSLocalizedString("Security")
    static let autoJoin = NSLocalizedString("Auto Join")
    static let dragNetworks = NSLocalizedString("Drag networks into the order you prefer.")
    static let macWillNotJoin = NSLocalizedString("Your Mac will no longer join this Wi-Fi network.")
    static let removeNetwork = NSLocalizedString("Remove Wi-Fi network %@?")
    static let remove = NSLocalizedString("Remove")
    static let cancel = NSLocalizedString("Cancel")
}
