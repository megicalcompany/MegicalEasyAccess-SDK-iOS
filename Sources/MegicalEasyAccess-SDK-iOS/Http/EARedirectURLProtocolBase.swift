//
//  File.swift
//  
//
//  Created by Antti Köliö on 23.2.2021.
//

import Foundation
import SwiftyBeaver

@objc
public class EARedirectURLProtocolBase: URLProtocol {
    
    let log = SwiftyBeaver.self
    
    /**
     Override to define callback url
     */
    @objc open class func oauthCallback() -> String {
        return "com.example.app:/oauth-callback"
    }
    
    /**
     Override to define notification name
     */
    @objc open class func tokenReceivedNotificationName() -> String {
        return "easyAccessTokenReceived"
    }
    
    /**
     Override if needed. Default ops:
     #swift
     let notification = Notification(name: Notification.Name(notificationName), object: notificationDict)
     NotificationCenter.default.post(notification)
     
     #objc
     NSNotification *notification = [NSNotification notificationWithName:notificationName object:notificationDict];
     [[NSNotificationCenter defaultCenter] postNotification:notification];
     */
    @objc public class func authCallbackAction() -> ((_ notificationName: String, _ notificationDict: [String: Any]) -> Void) {
        return { (notificationName: String, notificationDict: [String: Any]) in
            let notification = Notification(name: Notification.Name(notificationName), object: notificationDict)
            NotificationCenter.default.post(notification)
        }
    }
    
    /**
     Override with something like:
      return [request.URL.scheme isEqualToString:@"com.example.app"];
     */
    @objc public override class func canInit(with request: URLRequest) -> Bool {
        return false
    }
    
    @objc public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    @objc public override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        return false
    }
    
    @objc public override func startLoading() {
        log.info("EARedirectURLProtocolBase.startLoading \(self.request)")
        
        guard let url = self.request.url else {
            return
        }
        
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }
        
        let oauthCallback = Self.oauthCallback()
        guard let callbackComponents = URLComponents(string: oauthCallback) else {
            return
        }
        
        guard urlComponents.host == callbackComponents.host else {
            return
        }
        
        guard urlComponents.path == callbackComponents.path else {
            return
        }
        
        guard let queryItems = urlComponents.queryItems else {
            return
        }
        
        var code = ""
        var scope = ""
        var state = ""
        
        for qi: URLQueryItem in queryItems {
            if qi.name == "code" {
                code = qi.value ?? ""
            } else if qi.name == "scope" {
                scope = qi.value ?? ""
            } else if qi.name == "state" {
                state = qi.value ?? ""
            }
        }
        
        log.info("code \(code)\nscope \(scope)\nstate \(state)")
        
        let notificationDict = ["code": code,
                                "scope": scope,
                                "state": state]
        let notificationName = Self.tokenReceivedNotificationName()
        let authCallbackAction = Self.authCallbackAction()
        authCallbackAction(notificationName, notificationDict)
        
        if let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil) {
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        self.client?.urlProtocolDidFinishLoading(self)
    }
        
    @objc public override func stopLoading() {
        
    }
}
