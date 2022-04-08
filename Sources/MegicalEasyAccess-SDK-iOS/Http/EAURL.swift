//
//  EAURL.swift
//  
//
//  Created by Antti Köliö on 8.3.2021.
//

import Foundation

@objc
public class EAURL: NSObject {
    public static let eaAppPathAuth = "com.megical.easyaccess:/auth"
    public static let eaAppPathSignature = "com.megical.easyaccess:/signature"
    public static let eaAppPathParamLoginCode = "loginCode"
    public static let eaAppPathParamAuthCallback = "authCallback"
    public static let eaAppPathParamSignatureCode = "signatureCode"
    public static let eaAppPathParamSignatureCallback = "signatureCallback"
    
    @objc public class func eaAppPath(loginCode: String, authEnv: String?) -> String {
        var address = "\(EAURL.eaAppPathAuth)?\(EAURL.eaAppPathParamLoginCode)=\(loginCode)"
        if let authEnv = authEnv {
            address += "&authEnv=" + authEnv
        }
        return address
    }
    
    @objc public class func eaAppPath(loginCode: String, authCallback: String, authEnv: String?) -> String {
        var address = "\(EAURL.eaAppPathAuth)?\(EAURL.eaAppPathParamLoginCode)=\(loginCode)&\(eaAppPathParamAuthCallback)=\(authCallback)"
        if let authEnv = authEnv {
            address += "&authEnv=" + authEnv
        }
        return address
    }
    
    @objc public class func eaAppPath(signatureCode: String, authEnv: String?) -> String {
        var address = "\(EAURL.eaAppPathSignature)?\(EAURL.eaAppPathParamSignatureCode)=\(signatureCode)"
        if let authEnv = authEnv {
            address += "&authEnv=" + authEnv
        }
        return address
    }
    
    @objc public class func eaAppPath(signatureCode: String, signatureCallback: String, authEnv: String?) -> String {
        var address = "\(EAURL.eaAppPathSignature)?\(EAURL.eaAppPathParamSignatureCode)=\(signatureCode)&\(eaAppPathParamSignatureCallback)=\(signatureCallback)"
        if let authEnv = authEnv {
            address += "&authEnv=" + authEnv
        }
        return address
    }
    
}
