//
//  MegAuthFlow.swift
//  
//
//  Created by Antti Köliö on 11.2.2021.
//

import UIKit
import SwiftyBeaver

@objc
public class MegAuthLoginSessionObject: NSObject {
    @objc var loginCode: String = ""
    @objc var sessionId: String = ""
}

@objc
public class MegAuthFlow: NSObject {
    
    let log = SwiftyBeaver.self
    
    private var authCallback: String = ""
    private var authState: UUID = UUID()
    private var authNonce: UUID = UUID()
    private var authVerifier: String = ""
    private var authCodeChallengeBase64: String = ""
    private var oidConfig: MegOpenIdConfiguration?
    private var sessionObject: MegAuthLoginSessionObject?
        
    @objc public class func auth(clientId: String,
                                 authCallback: String,
                                 authEndpoint: String,
                                 authState: String,
                                 authNonce: String,
                                 authCodeChallengeBase64: String,
                                 completion: @escaping ((_ sessionObject: MegAuthLoginSessionObject?,
                                                         _ error: Error?) -> ())) {
        
        guard var urlComponents = URLComponents(string: authEndpoint) else {
            completion(nil, EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: nil, description: "Could not form auth url"))
            return
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "scope", value: "openid"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value:authCallback),
            URLQueryItem(name: "state", value: authState),
            URLQueryItem(name: "nonce", value: authNonce),
            URLQueryItem(name: "code_challenge", value: authCodeChallengeBase64),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
                
        guard let url = urlComponents.url else {
            completion(nil, EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: nil, description: "Could not form auth url"))
            return
        }
        
        SwiftyBeaver.info("Calling auth at: \(url.absoluteString)")
        
        var urlRequest: URLRequest
        do {
            urlRequest = try MegAuthUrlRequest.jsonRequest(method: "GET", url: url, body: nil)
        } catch {
            completion(nil, EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: error, description: "Could not form auth request"))
            return
        }
        
        let task: URLSessionDataTask = URLSession.shared.dataTask(with: urlRequest) { (data: Data?,
                                                                                       response: URLResponse?,
                                                                                       error: Error?) in
            guard error == nil else {
                completion(nil,EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: error, description: "Error from auth api"))
                return
            }
            
            guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
                completion(nil,EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: nil, description: "Response was not HTTPURLResponse"))
                return
            }
            
            if (httpResponse.statusCode != 200) {
                completion(nil,EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: nil, description: "Response was not 200"))
                return
            }
            
            guard data != nil else {
                completion(nil,EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: nil, description: "No response data"))
                return
            }
            
            var jsonObject: [String: Any]
            do {
                jsonObject = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? [String: Any]  ?? [:]
            } catch {
                completion(nil,EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: error, description: "Could not parse result"))
                return
            }
            
            guard let loginCode = jsonObject["loginCode"] as? String else {
                completion(nil,EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: nil, description: "Could not parse loginCode"))
                return
            }

            guard let sessionId = jsonObject["sessionId"] as? String else {
                completion(nil,EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: nil, description: "Could not parse encryptedDataurlSafeBase64"))
                return
            }
            
            let sessionObject = MegAuthLoginSessionObject()
            sessionObject.loginCode = loginCode
            sessionObject.sessionId = sessionId
            completion(sessionObject, nil)
        }
        
        task.resume()
    }
    
    @objc public func authorize(authServerAddress: String,
                                authCallback: String,
                                keychainKeyClientId: String,
                                completion: @escaping (_ error: Error?) -> Void) {
        
        guard let clientId = EAKeychainUtil.keychainReadString(key: keychainKeyClientId) else {
            completion(EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: nil, description: "Could not get clientId from keychain"))
            return
        }
        
        self.authCallback = authCallback
        self.authState = UUID()
        self.authNonce = UUID()
        
        do {
            self.authVerifier = try MegAuthPkce.generateCodeVerifier()
        } catch {
            completion(EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: error, description: "Failed to create auth verifier"))
            return
        }
        
        self.authCodeChallengeBase64 = MegAuthPkce.generateCodeChallengeBase64(verifier: self.authVerifier)
        
        let authCompletion = { [weak self] (sessionObject: MegAuthLoginSessionObject?, error: Error?) in
            guard let self = self else {
                return
            }
            guard error == nil else {
                let locdesc: String = error!.localizedDescription
                let userInfo = (error! as NSError).userInfo
                self.log.error("Failed to authenticate.\nError: \(locdesc)\nUser info: \(userInfo)")
                
                completion(EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: error, description: "Failed to authenticate"))
                return
            }
            
            guard sessionObject != nil else {
                let locdesc: String = error!.localizedDescription
                let userInfo = (error! as NSError).userInfo
                self.log.error("Failed to get session object.\nError: \(locdesc)\nUser info: \(userInfo)")
                
                completion(EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: error, description: "Failed to get session object"))
                return
            }
            
            self.sessionObject = sessionObject
            completion(nil)
            
            // open easy access
            guard let eaUrl = URL(string: "com.megical.easyaccess:/auth?loginCode=\(sessionObject!.loginCode)&authCallback=\(authCallback)") else {
                completion(EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: nil, description: "Failed to switch to easy access"))
                return
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.open(eaUrl)
            }
        }
        
        let oidConfigCompletion = { [weak self] (oidConfig: MegOpenIdConfiguration?, error: Error?) in
            guard let self = self else {
                return
            }
            guard error == nil else {
                completion(EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: error, description: "Failed to get open id configuration"))
                return
            }
            self.oidConfig = oidConfig
            
            
            MegAuthFlow.auth(clientId: clientId,
                             authCallback: authCallback,
                             authEndpoint: self.oidConfig!.authEndpoint,
                             authState: self.authState.uuidString,
                             authNonce: self.authNonce.uuidString,
                             authCodeChallengeBase64: self.authCodeChallengeBase64,
                             completion: authCompletion)
        }
        
        MegAuthDiscovery.oidConfiguration(authServerAddress: authServerAddress, completion: oidConfigCompletion)
        
    }

}
