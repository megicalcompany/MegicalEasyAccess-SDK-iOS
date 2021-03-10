//
//  MegAuthRegistrationFlow.swift
//  
//
//  Created by Antti Köliö on 11.2.2021.
//

import UIKit
import SwiftyBeaver

@objc
public class MegAuthRegistrationFlow: NSObject {
    
    
    /**
            clientToken: Token from the app backend we have registered to.
     */
    @objc
    public class func registerClient(authServerAddress: String,
                                     clientToken: String,
                                     clientType: String,
                                     appId: String,
                                     authCallback: String,
                                     jwkPublicKeyData: Data,
                                     keychainKeyClientId: String,
                                     completion: @escaping ((_ clientId: String?, _ error: Error?) -> Void)) {
        
        let registerClientAddress = "\(authServerAddress)/api/v1/client"
        SwiftyBeaver.info("Registering client at \(registerClientAddress)")
        guard let registerClientUrl = URL(string: registerClientAddress) else {
            completion(nil, EAErrorUtil.error(domain: "MegAuthRegistrationFlow", code: -1, underlyingError: nil, description: "Error failed to form register client URL"))
            return
        }
        
        var jwkPublicKeyDict: [String: Any]
        do {
            jwkPublicKeyDict = try JSONSerialization.jsonObject(with: jwkPublicKeyData, options: []) as? [String: Any] ?? [:]
        } catch {
            completion(nil, EAErrorUtil.error(domain: "MegAuthRegistrationFlow", code: -1, underlyingError: error, description: "Error in jwk key data"))
            return
        }
        
        guard let deviceForVendor: UUID = UIDevice.current.identifierForVendor else {
            completion(nil, EAErrorUtil.error(domain: "MegAuthRegistrationFlow", code: -1, underlyingError: nil, description: "Could not get identifierForVendor"))
            return
        }
        
        let bodyDict = [
            "key": jwkPublicKeyDict,
            "redirectUrls": [authCallback],
            "clientToken": clientToken,
            "deviceId": deviceForVendor.uuidString,
            "redirect": false
        ] as [String : Any]
        
        var request: URLRequest
        do {
            request = try MegAuthUrlRequest.jsonRequest(method: "POST", url: registerClientUrl, body: bodyDict)
        } catch {
            completion(nil, EAErrorUtil.error(domain: "MegAuthRegistrationFlow", code: -1, underlyingError: error, description: "Could not create url request"))
            return
        }
    
        let task: URLSessionDataTask = URLSession.shared.dataTask(with: request) { (data: Data?,
                                                                                    response: URLResponse?,
                                                                                    error: Error?) in
            guard error == nil else {
                completion(nil, EAErrorUtil.error(domain: "MegAuthRegistrationFlow", code: -1, underlyingError: error, description: "Error from client registration api"))
                return
            }
            
            guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
                completion(nil, EAErrorUtil.error(domain: "MegAuthRegistrationFlow", code: -1, underlyingError: nil, description: "Response was not HTTPURLResponse"))
                return
            }
            
            if (httpResponse.statusCode != 200 && httpResponse.statusCode != 201) {
                completion(nil, EAErrorUtil.error(domain: "MegAuthRegistrationFlow", code: -1, underlyingError: nil, description: "Response was not 200 or 201"))
                return
            }
            
            guard data != nil else {
                completion(nil, EAErrorUtil.error(domain: "MegAuthRegistrationFlow", code: -1, underlyingError: nil, description: "No response data"))
                return
            }
            
            var jsonObject: [String: Any]
            do {
                jsonObject = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? [String: Any]  ?? [:]
            } catch {
                completion(nil, EAErrorUtil.error(domain: "MegAuthRegistrationFlow", code: -1, underlyingError: error, description: "Could not parse result"))
                return
            }
            
            let clientId: String = jsonObject["clientId"] as? String ?? ""
            if !EAKeychainUtil.keychainStore(string: clientId, key: keychainKeyClientId) {
                completion(nil, EAErrorUtil.error(domain: "MegAuthRegistrationFlow", code: -1, underlyingError: nil, description: "Failed to save clientId to keychain"))
                return
            }
            
            completion(clientId, nil)
        }
        
        task.resume()
    }
}
