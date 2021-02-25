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
    
}
