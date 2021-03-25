//
//  EABase64Util.swift
//  
//
//  Created by Antti Köliö on 16.2.2021.
//

import Foundation

@objc
public class EABase64Util: NSObject {
    
    /**
     '+' -> '-'
     '/' -> '_'
     '=' -> ''
     */
    @objc public class func urlSafeBase64FromData(data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /**
     '-' -> '+'
     '_' -> '/'
     Less than 4 times the length, complement'='
     */
    @objc public class func dataFromUrlSafeBase64(urlSafeBase64: String) -> Data? {
        let base64 = urlSafeBase64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        var mBase64 = String(base64)
        let mod4 = mBase64.count % 4
        let padding = "==="
        if mod4 > 0 {
            let endIndex = padding.index(padding.endIndex, offsetBy: -mod4)
            mBase64.append(contentsOf: "==="[..<endIndex])
        }
        return Data(base64Encoded: mBase64)
    }
}
