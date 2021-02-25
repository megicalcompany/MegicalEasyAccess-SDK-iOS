//
//  MegAuthAccessTokenResult.swift
//  
//
//  Created by Antti Köliö on 24.2.2021.
//

import Foundation

@objc
public class MegAuthAccessTokenResult: NSObject {
    @objc public var accessToken: String = ""
    @objc public var expiresIn: Int = 0
    @objc public var idToken: String = ""
    @objc public var scope: String = ""
    @objc public var tokenType: String = ""
    
    public override init() {
        super.init()
    }
    
    public init(accessToken: String,
                expiresIn: Int,
                idToken: String,
                scope: String,
                tokenType: String) {
        super.init()
        self.accessToken = accessToken
        self.expiresIn = expiresIn
        self.idToken = idToken
        self.scope = scope
        self.tokenType = tokenType
    }
}

