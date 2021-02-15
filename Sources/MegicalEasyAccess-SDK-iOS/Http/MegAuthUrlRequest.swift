//
//  MegAuthUrlRequest.swift
//  
//
//  Created by Antti Köliö on 12.2.2021.
//

import Foundation

@objc
public class MegAuthUrlRequest: NSObject {
    
    @objc
    public class func jsonRequest(method: String,
                                  url: URL,
                                  body: [String: Any]) throws -> URLRequest {
        
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
        
        var request: URLRequest = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        return request
    }
}
