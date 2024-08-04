//
//  WiFiMenuItemView.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/4/3.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

protocol WifiMenuItemView: SelectableMenuItemView {
    var networkInfo: NetworkInfo { get set }
    var connected: Bool { get set }
    func updateImages()
}
