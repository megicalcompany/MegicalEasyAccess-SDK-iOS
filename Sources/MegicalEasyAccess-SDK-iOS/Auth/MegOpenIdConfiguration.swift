//
//  MegOpenIdConfiguration.swift
//  
//
//  Created by Antti Köliö on 10.2.2021.
//

import Foundation

@objc
public class MegOpenIdConfiguration: NSObject {
    @objc public var issuer: String = ""
    @objc public var authEndpoint: String = ""
    @objc public var tokenEndpoint: String = ""
    @objc public var jwksUri: String = ""
    
    @objc
    public class func configuration(issuer: String,
                                    authEndpoint: String,
                                    tokenEndpoint: String,
                                    jwksUri: String) -> MegOpenIdConfiguration {
        let config = MegOpenIdConfiguration()
        config.issuer = issuer
        config.authEndpoint = authEndpoint
        config.tokenEndpoint = tokenEndpoint
        config.jwksUri = jwksUri
        return config
    }
    
    @objc
    public class func configuration(dict: [String: Any]) -> MegOpenIdConfiguration {
        let config = MegOpenIdConfiguration()
        config.issuer = dict["issuer"] as? String ?? ""
        config.authEndpoint = dict["authorization_endpoint"] as? String ?? ""
        config.tokenEndpoint = dict["token_endpoint"] as? String ?? ""
        config.jwksUri = dict["jwks_uri"] as? String ?? ""
        return config
    }
}
