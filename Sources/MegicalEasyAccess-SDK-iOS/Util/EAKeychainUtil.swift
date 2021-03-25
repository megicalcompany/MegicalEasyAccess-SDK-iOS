//
//  EAKeychainUtil.swift
//  
//
//  Created by Antti Köliö on 17.2.2021.
//

import Foundation
import SimpleKeychain

@objc
public class EAKeychainUtil: NSObject {
    
    @objc public class func keychainStore(string: String, key: String) -> Bool {
        let keychain = A0SimpleKeychain.init()
        keychain.useAccessControl = false
        keychain.defaultAccessiblity = A0SimpleKeychainItemAccessible.whenPasscodeSetThisDeviceOnly
        keychain.setTouchIDAuthenticationAllowableReuseDuration(5.0)
        return keychain.setString(string, forKey: key)
    }
    
    @objc public class func keychainReadString(key: String) -> String? {
        let keychain = A0SimpleKeychain.init()
        return keychain.string(forKey: key)
    }
}
