//
//  WiFiConfigWindow.swift
//  HeliPort
//
//  Created by Erik Bautista on 8/7/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa
import LocalAuthentication

class WiFiConfigWindow: NSWindow {

    // MARK: Initializers

    private var view: NSView!
    private var gridView: NSGridView!
    private var windowState: WindowState
    private var networkInfo: NetworkInfo?
    private var authenticated = false
    private var getAuthInfoCallback: ((_ auth: NetworkAuth, _ savePassword: Bool) -> Void)?
    private var errorState: ErrorState?

    private let icon: NSImageView = {
        let image = NSImageView(frame: NSRect.zero)
        image.image = #imageLiteral(resourceName: "WiFi")
        return image
    }()

    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private let subTitleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private let networkLabel: NSTextField = {
        let label = NSTextField(labelWithString: .networkName)
        label.alignment = .right
        label.font = NSFont.systemFont(ofSize: 13)
        return label
    }()

    private let networkBox: NSTextField = {
        let box = NSTextField(frame: NSRect.zero)
        box.font = .systemFont(ofSize: 13)
        box.usesSingleLineMode = true
        return box
    }()

    private let securityLabel: NSTextField = {
        let label = NSTextField(labelWithString: .security)
        label.alignment = .right
        label.font = .systemFont(ofSize: 13)
        return label
    }()

    private let securityPop: NSPopUpButton = {
        let pop = NSPopUpButton(frame: .zero, pullsDown: false)
        pop.addItem(withTitle: .none)
        pop.menu?.addItem(.separator())

        // swiftlint:disable comment_spacing

        pop.addItems(withTitles: [

            //.wep,
            .wpa_1_2_Personal,
            //.wpa_2_3_Personal,
            .wpaPersonal,
            .wpa2Personal
            //,.wpa3Personal
        ])

        pop.menu?.addItem(.separator())
        pop.addItems(withTitles: [
            // Only the modes the EAP supplicant actually implements are
            // exposed here. WPA3-Enterprise (192-bit Suite B) and Dynamic
            // WEP are deliberately left out until/unless there's an engine
            // behind them — an unimplemented menu item just confuses users.
            .wpa_1_2_Enterprise,
            .wpa2Enterprise
        ])
        // swiftlint:enable comment_spacing

        pop.action = #selector(security(_:))
        return pop
    }()

    private let usernameLabel: NSTextField = {
        let label = NSTextField(labelWithString: .username)
        label.font = .systemFont(ofSize: 13)
        label.alignment = .right
        return label
    }()

    private let usernameBox: NSTextField = {
        let box = NSTextField(frame: NSRect.zero)
        box.font = .systemFont(ofSize: 13)
        box.usesSingleLineMode = true
        return box
    }()

    private let passwdLabel: NSTextField = {
        let label = NSTextField(labelWithString: .password)
        label.alignment = .right
        label.font = .systemFont(ofSize: 13)
        return label
    }()

    private let passwdInputBox: NSTextField = {
        let box = NSTextField(frame: NSRect.zero)
        box.font = NSFont.systemFont(ofSize: 13)
        box.usesSingleLineMode = true
        box.isHidden = true
        (box.cell as? NSTextFieldCell)?.allowedInputSourceLocales = [NSAllRomanInputSourcesLocaleIdentifier]
        return box
    }()

    private let passwdSecureBox: NSSecureTextField = {
        let box = NSSecureTextField(frame: NSRect.zero)
        box.font = NSFont.systemFont(ofSize: 13)
        box.drawsBackground = false
        box.usesSingleLineMode = true
        return box
    }()

    private let isShowPasswd: NSButton = {
        let button = NSButton(frame: NSRect.zero)
        button.setButtonType(.switch)
        button.title = .showPassword
        button.action = #selector(showPasswd(_:))
        button.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return button
    }()

    private let isSave: NSButton = {
        let button = NSButton(frame: NSRect.zero)
        button.setButtonType(.switch)
        button.font = .systemFont(ofSize: 13)
        button.title = .rememberNetwork
        button.setContentHuggingPriority(.defaultHigh, for: .vertical)
        button.state = .on
        return button
    }()

    private let errorImage: NSImageView = {
        let imageView = NSImageView(image: NSImage(named: NSImage.cautionName)!)
        imageView.image?.size = NSSize(width: 20, height: 20)
        imageView.isHidden = true
        return imageView
    }()

    private let errorLabel: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 12)
        textField.isHidden = true
        return textField
    }()

    private let leftButton: NSButton = {
        let button = NSButton()
        button.action = #selector(buttonClicked(_:))
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 13)
        button.keyEquivalent = String(format: "%c", 0x001b) // esc key
        return button
    }()

    private let rightButton: NSButton = {
        let button = NSButton()
        button.action = #selector(buttonClicked(_:))
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 13)
        button.keyEquivalent = String(format: "%c", NSCarriageReturnCharacter)
        return button
    }()

    convenience init(windowState: WindowState = .joinWiFi,
                     networkInfo: NetworkInfo? = nil,
                     error: ErrorState? = nil,
                     getAuthInfoCallback: ((_ auth: NetworkAuth, _ savePassword: Bool) -> Void)? = nil) {
        self.init(contentRect: NSRect(x: 0, y: 0, width: 450, height: 247),
                  styleMask: .titled,
                  backing: .buffered,
                  defer: false,
                  windowState: windowState,
                  networkInfo: networkInfo,
                  error: error,
                  getAuthInfoCallback: getAuthInfoCallback)
    }

    init(contentRect: NSRect,
         styleMask style: NSWindow.StyleMask,
         backing backingStoreType: NSWindow.BackingStoreType,
         defer flag: Bool,
         windowState: WindowState,
         networkInfo: NetworkInfo?,
         error: ErrorState?,
         getAuthInfoCallback: ((_ auth: NetworkAuth, _ savePassword: Bool) -> Void)? = nil) {

        self.windowState = windowState
        super.init(contentRect: contentRect,
                   styleMask: style,
                   backing: backingStoreType,
                   defer: flag)

        self.networkInfo = networkInfo
        self.getAuthInfoCallback = getAuthInfoCallback
        self.errorState = error

        NSApplication.shared.activate(ignoringOtherApps: true)

        isReleasedWhenClosed = false
        level = .floating
        center()

        view = NSView(frame: contentRect)
        contentView = view

        networkBox.delegate = self
        securityPop.target = self
        usernameBox.target = self
        usernameBox.delegate = self
        passwdInputBox.delegate = self
        passwdSecureBox.delegate = self
        isShowPasswd.target = self
        rightButton.target = self
        leftButton.target = self

        let empty = NSGridCell.emptyContentView
        gridView = NSGridView(views: [
            [networkLabel, networkBox],
            [securityLabel, securityPop],
            [usernameLabel, usernameBox],
            [passwdLabel, passwdSecureBox],
            [empty, isShowPasswd],
            [empty, isSave]
        ])
        gridView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        gridView.column(at: 0).xPlacement = .trailing
        gridView.column(at: 0).width = contentRect.width * 2/6
        gridView.rowAlignment = .lastBaseline

        view.addSubview(icon)
        view.addSubview(titleLabel)
        view.addSubview(subTitleLabel)
        view.addSubview(gridView)
        view.addSubview(errorImage)
        view.addSubview(errorLabel)
        view.addSubview(rightButton)
        view.addSubview(leftButton)

        setupConstraints()
        configureState()
    }

    private func setupConstraints() {
        view.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        let inset: CGFloat = 20

        icon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: inset).isActive = true
        icon.topAnchor.constraint(equalTo: view.topAnchor, constant: inset - 8).isActive = true
        icon.widthAnchor.constraint(equalToConstant: 66).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 66).isActive = true

        titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: inset).isActive = true
        titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: inset).isActive = true
        titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -inset).isActive = true

        subTitleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: inset).isActive = true
        subTitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10).isActive = true
        subTitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor).isActive = true

        gridView.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 18).isActive = true
        gridView.leadingAnchor.constraint(equalTo: icon.leadingAnchor).isActive = true
        gridView.trailingAnchor.constraint(equalTo: subTitleLabel.trailingAnchor).isActive = true

        errorImage.leadingAnchor.constraint(equalTo: icon.leadingAnchor).isActive = true
        errorImage.topAnchor.constraint(equalTo: gridView.bottomAnchor, constant: 8).isActive = true
        errorLabel.leadingAnchor.constraint(equalTo: errorImage.trailingAnchor, constant: 8).isActive = true
        errorLabel.centerYAnchor.constraint(equalTo: errorImage.centerYAnchor).isActive = true

        rightButton.topAnchor.constraint(equalTo: errorImage.bottomAnchor, constant: 16).isActive = true
        rightButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -inset).isActive = true
        rightButton.trailingAnchor.constraint(equalTo: gridView.trailingAnchor).isActive = true
        rightButton.widthAnchor.constraint(equalToConstant: 70).isActive = true

        leftButton.topAnchor.constraint(equalTo: rightButton.topAnchor).isActive = true
        leftButton.bottomAnchor.constraint(equalTo: rightButton.bottomAnchor).isActive = true
        leftButton.trailingAnchor.constraint(equalTo: rightButton.leadingAnchor, constant: -12).isActive = true
        leftButton.widthAnchor.constraint(equalToConstant: 70).isActive = true
    }

    private func configureState() {
        guard networkInfo != nil || windowState == .joinWiFi else {
            Log.error("Network info cannot be nil for \(String(describing: windowState)) state")
            return
        }

        if let errorState = errorState {
            errorLabel.stringValue = errorState.localizedString
            errorLabel.isHidden = false
            errorImage.isHidden = false
            Log.debug(errorState.rawValue)
        }

        switch windowState {
        case .joinWiFi:
            titleLabel.stringValue = .joinTitle
            subTitleLabel.stringValue = .joinSubtitle
            rightButton.title = .join
            leftButton.title = .cancel
            securityPop.selectItem(withTitle: .wpa2Personal)
            security(nil)
        case .connectWiFi:
            let securityString = NSLocalizedString(networkInfo!.auth.security.description)
            titleLabel.stringValue = String(format: .connectTitle, networkInfo!.ssid, securityString)
            subTitleLabel.isHidden = true
            rightButton.title = .join
            leftButton.title = .cancel
            networkBox.stringValue = networkInfo!.ssid
            gridView.row(at: .networkRow).isHidden = true
            gridView.row(at: .securityRow).isHidden = true
            securityPop.selectItem(withTitle: securityString)
            security(nil)
        case .viewCredentialsWiFi:
            titleLabel.stringValue = String(format: .credentialsTitle, networkInfo!.ssid)
            subTitleLabel.stringValue = .credentialsSubtitle
            gridView.row(at: .networkRow).isHidden = true
            gridView.row(at: .saveRow).isHidden = true
            leftButton.isHidden = true
            securityPop.isEnabled = false
            usernameBox.isSelectable = false
            passwdInputBox.isSelectable = false
            passwdSecureBox.isSelectable = false
            securityPop.selectItem(withTitle: NSLocalizedString(networkInfo!.auth.security.description))
            security(nil)
            passwdSecureBox.stringValue = networkInfo!.auth.password
            passwdInputBox.stringValue = networkInfo!.auth.password
            rightButton.title = .close
            rightButton.isEnabled = true
        }
    }

    private func resetInputBoxes() {
        passwdInputBox.stringValue = ""
        passwdSecureBox.stringValue = ""
        usernameBox.stringValue = ""
    }

    func show() {
        guard !securityPop.title.isEmpty else {
            Log.error("WiFiConfigWindow not shown due to unsupported security type: " +
                      (networkInfo?.auth.security.description ?? "unknown"))
            return
        }
        makeKeyAndOrderFront(self)
    }

    override func close() {
        // checks if window was shown as a sheet
        if let sheet = sheetParent {
            sheet.endSheet(self, returnCode: .cancel)
        } else {
            super.close()
        }
    }
}

// MARK: NSTextFieldDelegate

extension WiFiConfigWindow: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        // if clear password box is visible, copy password to secure box
        if !passwdInputBox.isHidden {
            passwdSecureBox.stringValue = passwdInputBox.stringValue
        }

        // if clear password box is not visible, copy password from secure box to password box
        if passwdInputBox.isHidden {
            passwdInputBox.stringValue = passwdSecureBox.stringValue
        }

        // WPA passphrases max out at 63/64 characters; enterprise (RADIUS)
        // passwords have no such limit, so don't truncate those.
        guard !isEnterpriseSelected else {
            controlJoinButton()
            return
        }

        // trim secure box to 64 characters
        if passwdSecureBox.stringValue.count > 64 {
            passwdSecureBox.stringValue = String(passwdSecureBox.stringValue[..<passwdSecureBox.stringValue.index(
                passwdSecureBox.stringValue.startIndex,
                offsetBy: 64
            )])
        }

        // trim password box to 64 characters
        if passwdInputBox.stringValue.count > 64 {
            passwdInputBox.stringValue = String(passwdInputBox.stringValue[..<passwdInputBox.stringValue.index(
                passwdInputBox.stringValue.startIndex,
                offsetBy: 64
            )])
        }

        controlJoinButton()
    }

    private func controlJoinButton() {
        // SSID needs to be filled in and shorter than 32 characters
        guard !networkBox.stringValue.isEmpty, networkBox.stringValue.count <= 32 else {
            rightButton.isEnabled = false
            return
        }

        // Visibility is controlled per grid row (see security(_:)), not on
        // the boxes themselves, so the rows are the source of truth here.
        let passwordShown = !gridView.row(at: .passwordRow).isHidden
        let usernameShown = !gridView.row(at: .usernameRow).isHidden

        // no password used (open network)
        guard passwordShown else {
            rightButton.isEnabled = true
            return
        }

        let password = currentPassword
        if isEnterpriseSelected {
            // RADIUS passwords have no WPA passphrase length rules.
            guard !password.isEmpty else {
                rightButton.isEnabled = false
                return
            }
        } else {
            // WPA passphrase is too short, less than 8 characters
            guard password.count >= 8 else {
                rightButton.isEnabled = false
                return
            }
        }

        // user name input shown but not filled in
        if usernameShown, trimmedUsername.isEmpty {
            rightButton.isEnabled = false
            return
        }

        // everything is OK
        rightButton.isEnabled = true
    }

    private var isEnterpriseSelected: Bool {
        [String.wpa_1_2_Enterprise, .wpa_2_3_Enterprise, .wpa2Enterprise, .wpa3Enterprise]
            .contains(securityPop.title)
    }

    private var currentPassword: String {
        passwdInputBox.isHidden ? passwdSecureBox.stringValue : passwdInputBox.stringValue
    }

    private var trimmedUsername: String {
        usernameBox.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: Action Items

extension WiFiConfigWindow {

    @objc private func security(_ sender: Any?) {
        switch securityPop.title {
        case .none:
            gridView.row(at: .usernameRow).isHidden = true
            gridView.row(at: .passwordRow).isHidden = true
            gridView.row(at: .showPassRow).isHidden = true
            networkBox.becomeFirstResponder()
        case .wpa_1_2_Personal,
             .wpa_2_3_Personal,
             .wpaPersonal,
             .wpa2Personal,
             .wpa3Personal:
            gridView.row(at: .usernameRow).isHidden = true
            gridView.row(at: .passwordRow).isHidden = false
            gridView.row(at: .showPassRow).isHidden = false
            if networkBox.isHidden || !networkBox.stringValue.isEmpty {
                passwdSecureBox.becomeFirstResponder()
            } else {
                networkBox.becomeFirstResponder()
            }
        case .wpa_1_2_Enterprise,
             .wpa_2_3_Enterprise,
             .wpa2Enterprise,
             .wpa3Enterprise:
            gridView.row(at: .usernameRow).isHidden = false
            gridView.row(at: .passwordRow).isHidden = false
            gridView.row(at: .showPassRow).isHidden = false
            usernameBox.becomeFirstResponder()
        default:
            let alert = NSAlert()
            alert.messageText = .encryptionUnsupported
            alert.informativeText = networkInfo?.auth.security.description ?? ""
            alert.alertStyle = .critical
            alert.runModal()
            return
        }
        resetInputBoxes()
        controlJoinButton()

        // Allows animation resize, Need fix for animation when frame is increased
        let heightDelta = view.fittingSize.height - view.frame.size.height
        var windowFrame = frame
        windowFrame.size.height += heightDelta
        windowFrame.origin.y -= heightDelta
        setFrame(windowFrame, display: false, animate: true)
    }

    @objc private func showPasswd(_ sender: Any?) {
        passwdSecureBox.stringValue = passwdInputBox.stringValue
        let showPass = isShowPasswd.state == .on

        if showPass && windowState == .viewCredentialsWiFi && !authenticated {
            let auth = LAContext()
            auth.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: .authReason) { (success, error) in
                self.authenticated = success
                if success {
                    // If succeeds with no errors, show password
                    DispatchQueue.main.async { self.showPasswd(nil) }
                } else {
                    Log.error("Unable to show password due to \(String(describing: error))")
                    DispatchQueue.main.async { self.isShowPasswd.state = .off }
                }
                DispatchQueue.main.async {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
        }

        guard authenticated || windowState != .viewCredentialsWiFi else { return }
        passwdInputBox.isHidden = !showPass
        passwdSecureBox.isHidden = showPass
        let cell = gridView.cell(atColumnIndex: 1, rowIndex: .passwordRow)
        cell.contentView = showPass ? passwdInputBox : passwdSecureBox

        guard let textBox = cell.contentView as? NSTextField else { return }
        textBox.becomeFirstResponder()
        textBox.selectText(self)
        textBox.currentEditor()?.selectedRange = NSRange(location: "\(textBox)".count, length: 0)
    }

    private func connect() {
        guard let network = networkInfo else { return }
        guard credentialsComplete(for: network.ssid) else { return }
        network.auth.password = currentPassword
        network.auth.username = trimmedUsername
        getAuthInfoCallback?(network.auth, isSave.state == .on)
        close()
    }

    /// Belt-and-braces for the Join button: refuses (and logs) instead of
    /// handing an enterprise attempt an empty identity.
    private func credentialsComplete(for ssid: String) -> Bool {
        let usernameShown = !gridView.row(at: .usernameRow).isHidden
        Log.debug("WiFiConfigWindow: join \(ssid) security=\(securityPop.title) " +
                  "enterprise=\(isEnterpriseSelected) usernameShown=\(usernameShown) " +
                  "usernameLength=\(trimmedUsername.count) passwordLength=\(currentPassword.count) " +
                  "remember=\(isSave.state == .on)")
        if isEnterpriseSelected, trimmedUsername.isEmpty || currentPassword.isEmpty {
            Log.error("WiFiConfigWindow: refusing to join \(ssid) with an empty username or password")
            NSSound.beep()
            let field: NSTextField
            if trimmedUsername.isEmpty {
                field = usernameBox
            } else if passwdInputBox.isHidden {
                field = passwdSecureBox
            } else {
                field = passwdInputBox
            }
            field.becomeFirstResponder()
            return false
        }
        return true
    }

    private func joinWiFi() {
        let network = NetworkInfo(ssid: networkBox.stringValue)
        guard credentialsComplete(for: network.ssid) else { return }
        network.auth.password = currentPassword
        network.auth.username = trimmedUsername

        switch securityPop.title {
        case .none:
            network.auth.security = ITL80211_SECURITY_NONE
        case .wpa_1_2_Personal:
            network.auth.security = ITL80211_SECURITY_WPA_PERSONAL_MIXED
        case .wpaPersonal:
            network.auth.security = ITL80211_SECURITY_WPA_PERSONAL
        case .wpa2Personal:
            network.auth.security = ITL80211_SECURITY_WPA2_PERSONAL
        case .wpa_1_2_Enterprise:
            network.auth.security = ITL80211_SECURITY_WPA_ENTERPRISE_MIXED
        case .wpa2Enterprise:
            network.auth.security = ITL80211_SECURITY_WPA2_ENTERPRISE
        default:
            network.auth.security = ITL80211_SECURITY_UNKNOWN
        }
        NetworkManager.connect(networkInfo: network, saveNetwork: isSave.state == .on)
        close()
    }

    @objc private func buttonClicked(_ sender: NSButton) {
        switch sender.title {
        case .cancel, .close:
            close()
        case .join:
            windowState == .joinWiFi ? joinWiFi() : connect()
        default:
            Log.error("Unknown button pressed")
        }
    }
}

// MARK: Row index

private extension Int {
    static let networkRow = 0
    static let securityRow = 1
    static let usernameRow = 2
    static let passwordRow = 3
    static let showPassRow = 4
    static let saveRow = 5
}

// MARK: Window state

enum WindowState {
    case joinWiFi
    case connectWiFi
    case viewCredentialsWiFi
}

// MARK: Error state

enum ErrorState: String {
    case timeout = "Connection timeout."
    case failed = "Connection failed."
    case cannotConnect = "Cannot connect."
    case incorrectPassword = "Incorrect password."
    var localizedString: String {
        return NSLocalizedString(self.rawValue)
    }
}

// MARK: Localization strings

private extension String {

    // MARK: View Credential strings

    static let credentialsTitle = NSLocalizedString("%@'s Credentials")
    static let credentialsSubtitle = NSLocalizedString("View saved credentials from keychain for the selected network.")
    static let authReason = NSLocalizedString("verify your credentials to show the stored password")

    // MARK: Join WiFi Strings

    static let joinTitle = NSLocalizedString("Find and join a Wi-Fi network.")
    static let joinSubtitle = NSLocalizedString("Enter the name and security type of the network you want to join.")

    // MARK: Connect to WiFi

    static let connectTitle = NSLocalizedString("The Wi-Fi network \"%@\" requires %@ credentials.")

    static let networkName = NSLocalizedString("Network Name:")
    static let none = NSLocalizedString(ITL80211_SECURITY_NONE.description)
    static let wep = NSLocalizedString(ITL80211_SECURITY_WEP.description)
    static let wpa_1_2_Personal = NSLocalizedString(ITL80211_SECURITY_WPA_PERSONAL_MIXED.description)
    static let wpa_2_3_Personal = NSLocalizedString("WPA2/WPA3 Personal")
    static let wpaPersonal = NSLocalizedString(ITL80211_SECURITY_WPA_PERSONAL.description)
    static let wpa2Personal = NSLocalizedString(ITL80211_SECURITY_WPA2_PERSONAL.description)
    static let wpa3Personal = NSLocalizedString(ITL80211_SECURITY_WPA3_PERSONAL.description)
    static let dynamicWEP = NSLocalizedString(ITL80211_SECURITY_DYNAMIC_WEP.description)
    static let wpa_1_2_Enterprise = NSLocalizedString(ITL80211_SECURITY_WPA_ENTERPRISE_MIXED.description)
    static let wpa_2_3_Enterprise = NSLocalizedString("WPA2/WPA3 Enterprise")
    static let wpa2Enterprise = NSLocalizedString(ITL80211_SECURITY_WPA2_ENTERPRISE.description)
    static let wpa3Enterprise = NSLocalizedString(ITL80211_SECURITY_WPA3_ENTERPRISE.description)
    static let encryptionUnsupported = NSLocalizedString("Encryption type unsupported")
    static let security = NSLocalizedString("Security:")
    static let username = NSLocalizedString("Username:")
    static let password = NSLocalizedString("Password:")
    static let cancel = NSLocalizedString("Cancel")
    static let close = NSLocalizedString("Close")
    static let join = NSLocalizedString("Join")
    static let showPassword = NSLocalizedString("Show password")
    static let rememberNetwork = NSLocalizedString("Remember this network")
}
