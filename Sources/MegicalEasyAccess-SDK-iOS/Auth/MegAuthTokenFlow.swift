//
//  MegAuthTokenFlow.swift
//  
//
//  Created by Antti Köliö on 24.2.2021.
//

import Foundation
import SwiftyBeaver

@objc
public class MegAuthTokenFlow: NSObject {
    
    /**
     https://openid.net/specs/openid-connect-core-1_0.html
     
     iss
     REQUIRED. Issuer. This MUST contain the client_id of the OAuth Client.
     sub
     REQUIRED. Subject. This MUST contain the client_id of the OAuth Client.
     aud
     REQUIRED. Audience. The aud (audience) Claim. Value that identifies the Authorization Server as an intended audience. The Authorization Server MUST verify that it is an intended audience for the token. The Audience SHOULD be the URL of the Authorization Server's Token Endpoint.
     jti
     REQUIRED. JWT ID. A unique identifier for the token, which can be used to prevent reuse of the token. These tokens MUST only be used once, unless conditions for reuse were negotiated between the parties; any such negotiation is beyond the scope of this specification.
     exp
     REQUIRED. Expiration time on or after which the ID Token MUST NOT be accepted for processing.
     iat
     OPTIONAL. Time at which the JWT was issued.
     */
    @objc public static func createTokenRequestJwt(oidConfig: MegOpenIdConfiguration,
                                                   clientId: String,
                                                   clientKeyTagPrivate: String,
                                                   clientKeyTagPublic: String) throws -> String {
        let aud = oidConfig.tokenEndpoint
        let iat: TimeInterval = Date().timeIntervalSince1970
        let exp: TimeInterval = iat + 60
        
        let payload = [
            "iss": clientId,
            "sub": clientId,
            "aud": aud,
            "jti": UUID().uuidString,
            "iat": iat,
            "exp": exp
            ] as [String: Any]
        
        let payloadData: Data = try JSONSerialization.data(withJSONObject: payload)
        
        guard let payloadString: String = String(data: payloadData, encoding: .utf8) else {
            throw EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Failed to form token request jwt")
        }
        
        let clientKey = MegAuthJwkKey.init(keychainTagPrivate: clientKeyTagPrivate, keychainTagPublic: clientKeyTagPublic, jwkUseClause: "sig")
        let jwsString: String = try clientKey.signJwt(clientId: clientId, message: payloadString)
        
        return jwsString
    }
    
    
    @objc public class func token(oidConfig: MegOpenIdConfiguration,
                                  authCode: String,
                                  authCallback: String,
                                  authVerifier: String,
                                  keychainKeyClientId: String,
                                  clientKeyTagPrivate: String,
                                  clientKeyTagPublic: String,
                                  completion: @escaping (_ accessTokenResult: MegAuthAccessTokenResult?, _ error: Error?) -> Void
    ) {
        guard let clientId = EAKeychainUtil.keychainReadString(key: keychainKeyClientId) else {
            completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Could not get clientId from keychain"))
            return
        }
        
        var clientAssertionOpt: String?
        do {
            clientAssertionOpt = try Self.createTokenRequestJwt(oidConfig: oidConfig,
                                                             clientId: clientId,
                                                             clientKeyTagPrivate: clientKeyTagPrivate,
                                                             clientKeyTagPublic: clientKeyTagPublic)
        } catch {
            completion(nil, error)
            return
        }
        
        guard let clientAssertion = clientAssertionOpt else {
            completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Could not form clientAssertion"))
            return
        }

        var postStr = "grant_type=authorization_code"
        postStr.append("&code_verifier=\(authVerifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")
        postStr.append("&code=\(authCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")
        postStr.append("&client_id=\(clientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")
        postStr.append("&redirect_uri=\(authCallback)")
        postStr.append("&client_assertion=\(clientAssertion)")
        postStr.append("&client_assertion_type=\("urn:ietf:params:oauth:client-assertion-type:jwt-bearer".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")

        guard let postData = postStr.data(using: .utf8) else {
            completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Could not form post data for token endpoint"))
            return
        }

        let postLength: String = String(format: "%lu", postData.count) // (unsigned long)postData.length]; ?

        guard let url: URL = URL(string: oidConfig.tokenEndpoint) else {
            completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Could not form token endpoint url: \(oidConfig.tokenEndpoint)"))
            return
        }
        
        SwiftyBeaver.debug("Calling token endpoint: \(url.absoluteString)\nwith data: \(postStr)\nContent-Length: \(postLength)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
        request.setValue(postLength, forHTTPHeaderField: "Content-Length")
        request.httpBody = postData
        
        let task: URLSessionDataTask = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            guard error == nil else {
                completion(nil, error)
                return
            }
            
            guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
                completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Response was not HTTPURLResponse"))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                SwiftyBeaver.warning("Response \(httpResponse.statusCode), data: \(data == nil ? "nil" : String(data: data!, encoding: .utf8)!)")
                completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Response was not 200 (\(httpResponse.statusCode))"))
                return
            }
            
            guard data != nil else {
                completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "No response data"))
                return
            }
            
            var jsonObject: [String: Any]
            do {
                jsonObject = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? [String: Any]  ?? [:]
            } catch {
                completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: error, description: "Could not parse result"))
                return
            }
            
            SwiftyBeaver.info("token result jsonObject: \(jsonObject)")
            
            guard let accessToken: String = jsonObject["access_token"] as? String,
                  let expiresIn: Int = jsonObject["expires_in"] as? Int,
                  let idToken: String = jsonObject["id_token"] as? String,
                  let scope: String = jsonObject["scope"] as? String,
                  let tokenType: String = jsonObject["token_type"] as? String else {
                
                completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Did not get access token data"))
                return
            }
            
            let tokenResult = MegAuthAccessTokenResult(accessToken: accessToken, expiresIn: expiresIn, idToken: idToken, scope: scope, tokenType: tokenType)
            completion(tokenResult, nil)
        }
        
        task.resume()
    }
    
    /**
        Url request returns:
        {"keys":[{
        "use":"sig",
        "kty":"RSA",
        "kid":"public:5e491c7f-506a-476b-9624-9c2ac190ce5d",
        "alg":"RS256",
        "n":"wDPL *** 8ZxmfU",
        "e":"AQAB"}]}
    */
    @objc public static func getServerJwks(oidConfig: MegOpenIdConfiguration,
                                           completion: @escaping (_ jwksKeys: [String: Any]?, _ error: Error?) -> Void) {
        
        guard let url: URL = URL(string: oidConfig.jwksUri) else {
            completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Could not form jwksUri"))
            return
        }
        
        let urlRequest = URLRequest(url: url)
        let task: URLSessionDataTask = URLSession.shared.dataTask(with: urlRequest) { (data: Data?, response: URLResponse?, error: Error?) in
            guard error == nil else {
                completion(nil, error)
                return
            }
            
            guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
                completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Response was not HTTPURLResponse"))
                return
            }
            
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                SwiftyBeaver.warning("Response \(httpResponse.statusCode), data: \(data == nil ? "nil" : String(data: data!, encoding: .utf8)!)")
                completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Response was not 200 or 201 (\(httpResponse.statusCode))"))
                return
            }
            
            guard data != nil else {
                completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "No response data"))
                return
            }
            
            var jsonObject: [String: Any]
            do {
                jsonObject = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? [String: Any] ?? [:]
            } catch {
                completion(nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: error, description: "Could not parse result"))
                return
            }
            
            completion(jsonObject, nil)
        }
        task.resume()
    }
    
    @objc public static func validateIdToken(accessTokenResult: MegAuthAccessTokenResult,
                                             oidConfig: MegOpenIdConfiguration,
                                             serverJwksKey: [String: Any],
                                             keychainKeyClientId: String,
                                             clientKeyTagPrivate: String,
                                             clientKeyTagPublic: String,
                                             authNonce: String) throws {
        
        guard let clientId = EAKeychainUtil.keychainReadString(key: keychainKeyClientId) else {
            throw EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Could not get clientId from keychain")
        }
        
        let jwksKeyData = try JSONSerialization.data(withJSONObject: serverJwksKey)
        
        let clientKey = MegAuthJwkKey.init(keychainTagPrivate: clientKeyTagPrivate, keychainTagPublic: clientKeyTagPublic, jwkUseClause: "sig")
        
        let idTokenMessageJsonString: String = try clientKey.verifyIdTokenWithJwksKey(idToken: accessTokenResult.idToken, jwksKeyData: jwksKeyData)
        
        guard let idTokenMessageJsonData: Data = idTokenMessageJsonString.data(using: .utf8) else {
            throw EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Faulty id token data")
        }
        let idTokenMessageJson: [String: Any] = try JSONSerialization.jsonObject(with: idTokenMessageJsonData) as? [String: Any] ?? [:]
     
        try MegAuthIdTokenValidator.validateIdToken(idTokenMessageJson: idTokenMessageJson,
                                                    discoveryIssuer: oidConfig.issuer,
                                                    clientId: clientId,
                                                    authNonce: authNonce)
        
    }
    
    @objc public static func handleAuthCodeNotificationObject(notificationObject: [String: Any],
                                                              authFlow: MegAuthFlow,
                                                              keychainKeyClientId: String,
                                                              clientKeyTagPrivate: String,
                                                              clientKeyTagPublic: String,
                                                              completion: @escaping ((_ handled: Bool, _ tokenResult: MegAuthAccessTokenResult?, _ error: Error?) -> Void)) {
        
        guard let authorizationCode: String = notificationObject["code"] as? String,
              let _: String = notificationObject["scope"] as? String,
              let state: String = notificationObject["state"] as? String,
              state == authFlow.authState.uuidString else {
            completion(false, nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Invalid auth token data"))
            return
        }
        
        guard let oidConfig = authFlow.oidConfig else {
            completion(false, nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "No oid config in auth flow object"))
            return
        }
        
        MegAuthTokenFlow.token(oidConfig: oidConfig,
                               authCode: authorizationCode,
                               authCallback: authFlow.authCallbackOauth,
                               authVerifier: authFlow.authVerifier,
                               keychainKeyClientId: keychainKeyClientId,
                               clientKeyTagPrivate: clientKeyTagPrivate,
                               clientKeyTagPublic: clientKeyTagPublic) { (accessTokenResult: MegAuthAccessTokenResult?, error: Error?) in
            guard error == nil else {
                let locdesc: String = error!.localizedDescription
                let userInfo = (error! as NSError).userInfo
                SwiftyBeaver.error("Failed to get access token.\nError: \(locdesc)\nUser info: \(userInfo)")
                completion(false, nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: error, description: "Failed to get access token"))
                return
            }
            
            guard accessTokenResult != nil else {
                completion(false, nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Got nil accessTokenResult"))
                return
            }
            
            MegAuthTokenFlow.getServerJwks(oidConfig: oidConfig) { (jwksKeys: [String : Any]?,
                                                                    error: Error?) in
                guard error == nil else {
                    let locdesc: String = error!.localizedDescription
                    let userInfo = (error! as NSError).userInfo
                    SwiftyBeaver.error("Failed to get server jwks keys.\nError: \(locdesc)\nUser info: \(userInfo)")
                    completion(false, nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: error, description: "Failed to get server jwks keys"))
                    return
                }
                
                guard jwksKeys != nil else {
                    completion(false, nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Got nil jwksKeys"))
                    return
                }
                
                guard let keysArray: [Any] = jwksKeys!["keys"] as? [Any] else {
                    completion(false, nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "No jwks keys returned from server"))
                    return
                }
                
                guard let key: [String: Any] = keysArray[0] as? [String: Any] else {
                    completion(false, nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: nil, description: "Faulty jwks key returned from server"))
                    return
                }
                
                do {
                    try MegAuthTokenFlow.validateIdToken(accessTokenResult: accessTokenResult!,
                                                         oidConfig: oidConfig,
                                                         serverJwksKey: key,
                                                         keychainKeyClientId: keychainKeyClientId,
                                                         clientKeyTagPrivate: clientKeyTagPrivate,
                                                         clientKeyTagPublic: clientKeyTagPublic,
                                                         authNonce: authFlow.authNonce.uuidString)
                } catch {
                    let locdesc: String = error.localizedDescription
                    let userInfo = (error as NSError).userInfo
                    SwiftyBeaver.error("Id token validation failed.\nError: \(locdesc)\nUser info: \(userInfo)")
                    completion(false, nil, EAErrorUtil.error(domain: "MegAuthTokenFlow", code: -1, underlyingError: error, description: "Id token validation failed"))
                    return
                }
                
                SwiftyBeaver.info("id token validated")
                completion(true, accessTokenResult, nil)
            }
        }
    }
}
