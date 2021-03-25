//
//  EARedirectURLProtocolBase.swift
//  
//
//  Created by Antti Köliö on 23.2.2021.
//

import Foundation
import SwiftyBeaver

open class EARedirectURLProtocolBase: URLProtocol {
    
    /**
     Override to define callback url
     */
    open class func oauthCallback() -> String {
        return "com.example.app:/oauth-callback"
    }

    /**
     Override to define notification name
     */
    open class func authCodeReceivedNotificationName() -> String {
        return "easyAccessAuthCodeReceived"
    }

    /**
     Override if needed
     */
    open class func authCallbackAction() -> ((_ notificationName: String, _ notificationDict: [String: Any]) -> Void) {
        return { (notificationName: String, notificationDict: [String: Any]) in
            let notification = Notification(name: .init(notificationName), object: notificationDict)
            NotificationCenter.default.post(notification)
        }
    }

    /**
     Override if needed
     */
    open override class func canInit(with request: URLRequest) -> Bool {
        guard let requestURL = request.url else {
            return false
        }
        
        let oauthCallback = Self.oauthCallback()
        guard let callbackComponents = URLComponents(string: oauthCallback) else {
            return false
        }
        
        guard callbackComponents.scheme == requestURL.scheme else {
            return false
        }

        guard callbackComponents.path == requestURL.path else {
            return false
        }

        return true
    }
    
    open override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    open override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        return false
    }

    //components.host: authcallback
    //components.path:
    //query item code: I78CcA7qVMw5ECaG4naRNXhqbGnEdB-2Oi1UK35iDX8.5srB2lUU_RzzaF1wfMgSV4LkS_cfrHH79EEygIITQps
    //query item scope: openid
    //query item state: 1870EA3D-185D-435C-8E77-F795F58BACAA
    open override func startLoading() {
        guard let requestURL = self.request.url else {
            return
        }
        guard let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: true) else {
            return
        }
        
        // already checked in canInitWithRequest
        let oauthCallback = Self.oauthCallback()
        guard let callbackComponents = URLComponents(string: oauthCallback) else {
            return
        }
        
        if components.path == callbackComponents.path {
            
            var code: String?
            var scope: String?
            var state: String?
            
            if let queryItems = components.queryItems {
                for qi: URLQueryItem in queryItems {
                    switch qi.name {
                    case "code":
                        code = qi.value
                    case "scope":
                        scope = qi.value
                    case "state":
                        state = qi.value
                    default:
                        break
                    }
                }
                
                if (code != nil && scope != nil && state != nil) {
                    
                    let notificationDict = [
                        "code": code!,
                        "scope": scope!,
                        "state": state!
                    ] as [String: Any]
                    
                    let notificationName = Self.authCodeReceivedNotificationName()
                    Self.authCallbackAction()(notificationName, notificationDict)
                    
                    
                    
                    if let urlResponse = HTTPURLResponse(url: requestURL,
                                                         statusCode: 200,
                                                         httpVersion: "HTTP/1.1",
                                                         headerFields: nil),
                       let client = self.client {
                        
                        client.urlProtocol(self,
                                           didReceive: urlResponse,
                                           cacheStoragePolicy: .notAllowed)
                        
                        client.urlProtocolDidFinishLoading(self)
                    }
                    
                }
            }
            
        }
    }

    open override func stopLoading() {
        
    }
}
