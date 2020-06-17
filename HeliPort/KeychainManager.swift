//
//  KeychainManager.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/4/4.
//  Copyright © 2020 lhy. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation
import Cocoa

class KeychainManager: NSObject {
    // TODO: 创建查询条件
    class func createQuaryMutableDictionary(identifier: String) -> NSMutableDictionary {
        // 创建一个条件字典
        let keychainQuaryMutableDictionary = NSMutableDictionary.init(capacity: 0)
        // 设置条件存储的类型
        keychainQuaryMutableDictionary.setValue(
            kSecClassInternetPassword/*kSecClassGenericPassword*/,
            forKey: kSecClass as String
        )
        // 设置存储数据的标记
        keychainQuaryMutableDictionary.setValue(
            identifier,
            forKey: kSecAttrService as String
        )
        keychainQuaryMutableDictionary.setValue(
            identifier,
            forKey: kSecAttrAccount as String
        )
        // 设置数据访问属性
        keychainQuaryMutableDictionary.setValue(
            kSecAttrAccessibleAfterFirstUnlock,
            forKey: kSecAttrAccessible as String
        )
        // 返回创建条件字典
        return keychainQuaryMutableDictionary
    }

    // TODO: 存储数据
    class func keyChainSaveData(data: Any, withIdentifier identifier: String) -> Bool {
        // 获取存储数据的条件
        let keyChainSaveMutableDictionary = self.createQuaryMutableDictionary(identifier: identifier)
        // 删除旧的存储数据
        SecItemDelete(keyChainSaveMutableDictionary)
        // 设置数据
        keyChainSaveMutableDictionary.setValue(
            NSKeyedArchiver.archivedData(withRootObject: data),
            forKey: kSecValueData as String
        )
        // 进行存储数据
        let saveState = SecItemAdd(
            keyChainSaveMutableDictionary,
            nil
        )
        if saveState == noErr {
            return true
        }
        return false
    }

    // TODO: 更新数据
    class func keyChainUpdata(data: Any, withIdentifier identifier: String) -> Bool {
        // 获取更新的条件
        let keyChainUpdataMutableDictionary = self.createQuaryMutableDictionary(identifier: identifier)
        // 创建数据存储字典
        let updataMutableDictionary = NSMutableDictionary.init(capacity: 0)
        // 设置数据
        updataMutableDictionary.setValue(
            NSKeyedArchiver.archivedData(withRootObject: data),
            forKey: kSecValueData as String
        )
        // 更新数据
        let updataStatus = SecItemUpdate(
            keyChainUpdataMutableDictionary,
            updataMutableDictionary
        )
        if updataStatus == noErr {
            return true
        }
        return false
    }

    // TODO: 获取数据
    class func keyChainReadData(identifier: String)-> Any {
        var idObject: Any?
        // 获取查询条件
        let keyChainReadmutableDictionary = self.createQuaryMutableDictionary(identifier: identifier)
        // 提供查询数据的两个必要参数
        keyChainReadmutableDictionary.setValue(
            kCFBooleanTrue,
            forKey: kSecReturnData as String
        )
        keyChainReadmutableDictionary.setValue(
            kSecMatchLimitOne,
            forKey: kSecMatchLimit as String
        )
        // 创建获取数据的引用
        var queryResult: AnyObject?
        // 通过查询是否存储在数据
        let readStatus = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(
                keyChainReadmutableDictionary,
                UnsafeMutablePointer($0)
            )
        }
        if readStatus == errSecSuccess {
            if let data = queryResult as? NSData {
                idObject = NSKeyedUnarchiver.unarchiveObject(with: data as Data) as Any
            }
        }
        return idObject as Any
    }

    // TODO: 删除数据
    class func keyChianDelete(identifier: String) {
        // 获取删除的条件
        let keyChainDeleteMutableDictionary = self.createQuaryMutableDictionary(identifier: identifier)
        // 删除数据
        SecItemDelete(keyChainDeleteMutableDictionary)
    }
}
