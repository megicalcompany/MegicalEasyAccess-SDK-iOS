//
//  MegSignFlow.swift
//  
//
//  Created by Antti Köliö on 22.3.2022.
//

import UIKit
import SwiftyBeaver
import CryptoKit

@objc
public class MegSignFlow: NSObject {
    
    @objc public static let ERROR_CODE_EASY_ACCESS_APP_LAUNCH_FAILED = 1
    
    /**
     Requires signatureEndpoint for the client backend.
     For the example this would be
     https://playground.megical.com/easyaccess/api/v1/sign/signature
     dataToSign can be plaintext or encoded with e.g. base64
     */
    @objc public static func initiateSign(signatureEndpoint: String,
                                          dataToSign: String,
                                          completion: @escaping (_ signatureCode: String?, _ error: Error?) -> Void) {
        SwiftyBeaver.debug("MegSignFlow.initiateSign")
        guard var urlComponents = URLComponents(string: signatureEndpoint) else {
            completion(nil, EAErrorUtil.error(domain: "MegSignFlow", code: -1, underlyingError: nil, description: "Could not form url"))
            return
        }
        
        guard let url = urlComponents.url else {
            completion(nil, EAErrorUtil.error(domain: "MegSignFlow", code: -1, underlyingError: nil, description: "Could not form url"))
            return
        }
        
        let bodyDict: [String: Any] = ["signData": dataToSign]
        
        SwiftyBeaver.info("Calling sign at: \(url.absoluteString)")
        var urlRequest: URLRequest
        do {
            urlRequest = try MegAuthUrlRequest.jsonRequest(method: "POST", url: url, body: bodyDict)
        } catch {
            completion(nil, EAErrorUtil.error(domain: "MegSignFlow", code: -1, underlyingError: error, description: "Could not form request"))
            return
        }
        
        let task: URLSessionDataTask = URLSession.shared.dataTask(with: urlRequest) { (data: Data?,
                                                                                       response: URLResponse?,
                                                                                       error: Error?) in
            if let data = data {
                SwiftyBeaver.info("data: \(String(data: data, encoding: .utf8))")
            }
              
            guard error == nil else {
                SwiftyBeaver.warning(error?.localizedDescription)
                completion(nil, EAErrorUtil.error(domain: "MegSignFlow", code: -1, underlyingError: error, description: "Error from api"))
                return
            }
            
            guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
                completion(nil, EAErrorUtil.error(domain: "MegSignFlow", code: -1, underlyingError: nil, description: "Response was not HTTPURLResponse"))
                return
            }
            
            guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                completion(nil, EAErrorUtil.error(domain: "MegSignFlow", code: -1, underlyingError: nil, description: "Response was not 2XX"))
                return
            }
            
            guard data != nil else {
                completion(nil, EAErrorUtil.error(domain: "MegSignFlow", code: -1, underlyingError: nil, description: "No response data"))
                return
            }
            
            var jsonObject: [String: Any]
            do {
                jsonObject = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? [String: Any] ?? [:]
            } catch {
                SwiftyBeaver.debug("data: \(String(data: data!, encoding: .utf8))")
                completion(nil, EAErrorUtil.error(domain: "MegSignFlow", code: -1, underlyingError: error, description: "Could not parse result"))
                return
            }
            
            guard let signatureCode = jsonObject["signatureCode"] as? String else {
                completion(nil, EAErrorUtil.error(domain: "MegSignFlow", code: -1, underlyingError: nil, description: "Could not parse signatureCode"))
                return
            }
            
            completion(signatureCode, nil)
        }
        
        task.resume()
        
    }
    
    @objc public static func sign(authEnv: String?,
                                  signatureCallbackEA: String,
                                  signatureCode: String,
                                  completion: @escaping (_ error: Error?) -> Void) {
        
        
        guard let eaUrl = URL(string: EAURL.eaAppPath(signatureCode: signatureCode,
                                                      signatureCallback: signatureCallbackEA,
                                                      authEnv: authEnv)) else {
            completion(EAErrorUtil.error(domain: "MegSignFlow", code: MegAuthFlow.ERROR_CODE_EASY_ACCESS_APP_LAUNCH_FAILED, underlyingError: nil, description: "Failed to switch to easy access"))
            return
        }
    
        DispatchQueue.main.async {
            UIApplication.shared.open(eaUrl) { (handled: Bool) in
                if (!handled) {
                    completion(EAErrorUtil.error(domain: "MegSignFlow", code: MegAuthFlow.ERROR_CODE_EASY_ACCESS_APP_LAUNCH_FAILED, underlyingError: nil, description: "Failed to switch to easy access"))
                }
            }
        }
    }
}
