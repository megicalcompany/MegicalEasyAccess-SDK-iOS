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
    
    @objc public class func eaAppPath(loginCode: String, authEnv: String?) -> String {
        var address = "\(EAURL.eaAppPath)?\(EAURL.eaAppPathParamLoginCode)=\(loginCode)"
        if let authEnv = authEnv {
            address += "&authEnv=" + authEnv
        }
        return address
    }
    
    @objc public class func eaAppPath(loginCode: String, authCallback: String, authEnv: String?) -> String {
        var address = "\(EAURL.eaAppPath)?\(EAURL.eaAppPathParamLoginCode)=\(loginCode)&\(eaAppPathParamAuthCallback)=\(authCallback)"
        if let authEnv = authEnv {
            address += "&authEnv=" + authEnv
        }
        return address
    }
    
}
