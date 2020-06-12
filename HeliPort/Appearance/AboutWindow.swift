//
//  AboutWindow.swift
//  HeliPort
//
//  Created by OpenIntelWireless on 2020/6/11.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

import Foundation
import Cocoa

class AboutWindow: NSWindow {

    let width = 300, height = 700
    private static let detailsMarkdownUrl = "https://api.github.com/repos/zxystd/HeliPort/contents/README.md"
    private static var instance: AboutWindow?

    let logoView: NSImageView = {
        let logoView = NSImageView(image: NSImage.init(named: "WiFi")!)
        logoView.translatesAutoresizingMaskIntoConstraints = false
        return logoView
    }()

    private class func createTextLabel(_ text: String, _ font: NSFont) -> NSTextField {
        let textField = NSTextField()
        textField.stringValue = text
        textField.drawsBackground = false
        textField.isBordered = false
        textField.isSelectable = false
        textField.alignment = .center
        textField.font = font
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }

    let titleTextField: NSTextField = {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String
        return AboutWindow.createTextLabel(appName!, NSFont.boldSystemFont(ofSize: 14))
    }()

    let versionTextField: NSTextField = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return AboutWindow.createTextLabel("\(NSLocalizedString("Version", comment: "")) \(version!) (\(build!))", NSFont.labelFont(ofSize: 10))
    }()

    let copyrightTextField: NSTextField = {
        let copyrightInfoString = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
        return AboutWindow.createTextLabel(copyrightInfoString!, NSFont.labelFont(ofSize: 10))
    }()

    let detailTextView: NSScrollView = {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        var request = URLRequest(url: URL(string: AboutWindow.detailsMarkdownUrl)!)
        // get markdown HTML document rendered by GitHub
        request.setValue("application/vnd.github.VERSION.html", forHTTPHeaderField: "Accept")
        let task = URLSession.shared.dataTask(with: request) {(data, _, _) in
            guard let data = data else { return }
            DispatchQueue.main.async {
                textView.textStorage?.setAttributedString(NSAttributedString(html: data, documentAttributes: nil)!)
            }
        }
        task.resume()

        textView.isEditable = false
        textView.isRichText = true
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        if #available(OSX 10.14, *) {
            textView.usesAdaptiveColorMappingForDarkAppearance = true
        }

        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        return scrollView
    }()

    private init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        level = .normal

        contentView?.addSubview(logoView)
        contentView?.addSubview(titleTextField)
        contentView?.addSubview(versionTextField)
        contentView?.addSubview(copyrightTextField)
        contentView?.addSubview(detailTextView)
        setupLayout()

        center()
    }

    private func setupLayout() {
        logoView.centerXAnchor.constraint(equalTo: contentView!.centerXAnchor).isActive = true
        logoView.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: 10).isActive = true

        titleTextField.centerXAnchor.constraint(equalTo: contentView!.centerXAnchor).isActive = true
        titleTextField.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 10).isActive = true

        versionTextField.centerXAnchor.constraint(equalTo: contentView!.centerXAnchor).isActive = true
        versionTextField.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 5).isActive = true

        copyrightTextField.centerXAnchor.constraint(equalTo: contentView!.centerXAnchor).isActive = true
        copyrightTextField.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor, constant: -20).isActive = true

        detailTextView.topAnchor.constraint(equalTo: versionTextField.bottomAnchor, constant: 10).isActive = true
        detailTextView.bottomAnchor.constraint(equalTo: copyrightTextField.topAnchor, constant: -10).isActive = true
        detailTextView.widthAnchor.constraint(equalTo: contentView!.widthAnchor).isActive = true
    }

    @objc class func show() {
        if instance == nil {
            instance = AboutWindow.init()
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        instance?.makeKeyAndOrderFront(nil)
    }
}
