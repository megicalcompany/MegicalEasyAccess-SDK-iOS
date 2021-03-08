//
//  EAURL.swift
//  
//
//  Created by Antti Köliö on 8.3.2021.
//

import Foundation

@objc
public class EAURL: NSObject {
    public static let eaAppPath = "com.megical.easyaccess:/auth"
    public static let eaAppPathParamLoginCode = "loginCode"
    public static let eaAppPathParamAuthCallback = "authCallback"
    
    @objc public class func eaAppPath(loginCode: String) -> String {
        return "\(EAURL.eaAppPath)?\(EAURL.eaAppPathParamLoginCode)=\(loginCode)"
    }
    
    @objc public class func eaAppPath(loginCode: String, authCallback: String) -> String {
        return "\(EAURL.eaAppPath)?\(EAURL.eaAppPathParamLoginCode)=\(loginCode)&\(eaAppPathParamAuthCallback)=\(authCallback)"
    }
    
    
}
