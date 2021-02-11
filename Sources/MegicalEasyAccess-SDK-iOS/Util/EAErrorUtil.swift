//
//  EAErrorUtil.swift
//  
//
//  Created by Antti Köliö on 11.2.2021.
//

import Foundation

public struct EAErrorUtil {
    
    public static func error(domain: String,
                             code: Int,
                             underlyingError: Error?,
                             description: String?) -> Error {
        var userInfo: [String: Any] = [:]
        if (underlyingError != nil) {
            userInfo[NSUnderlyingErrorKey] = underlyingError
        }
        if (description != nil) {
            userInfo[NSLocalizedDescriptionKey] = description
        }
        let error = NSError(domain: domain,
                            code: code,
                            userInfo: userInfo)
        return error as Error
    }
}
