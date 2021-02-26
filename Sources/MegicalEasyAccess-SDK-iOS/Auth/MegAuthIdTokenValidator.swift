//
//  MegAuthIdTokenValidator.swift
//  
//
//  Created by Antti Köliö on 26.2.2021.
//

import Foundation

@objc
public class MegAuthIdTokenValidator: NSObject {
    
//    https://openid.net/specs/openid-connect-core-1_0.html#IDTokenValidation
//    3.1.3.7.  ID Token Validation
//
//    Clients MUST validate the ID Token in the Token Response in the following manner:
//
//    1. If the ID Token is encrypted, decrypt it using the keys and algorithms that the Client specified during Registration that the OP was to use to encrypt the ID Token. If encryption was negotiated with the OP at Registration time and the ID Token is not encrypted, the RP SHOULD reject it.
//    2. The Issuer Identifier for the OpenID Provider (which is typically obtained during Discovery) MUST exactly match the value of the iss (issuer) Claim.
//    3. The Client MUST validate that the aud (audience) Claim contains its client_id value registered at the Issuer identified by the iss (issuer) Claim as an audience. The aud (audience) Claim MAY contain an array with more than one element. The ID Token MUST be rejected if the ID Token does not list the Client as a valid audience, or if it contains additional audiences not trusted by the Client.
//    4. If the ID Token contains multiple audiences, the Client SHOULD verify that an azp Claim is present.
//    5. If an azp (authorized party) Claim is present, the Client SHOULD verify that its client_id is the Claim Value.
//    6. If the ID Token is received via direct communication between the Client and the Token Endpoint (which it is in this flow), the TLS server validation MAY be used to validate the issuer in place of checking the token signature. The Client MUST validate the signature of all other ID Tokens according to JWS [JWS] using the algorithm specified in the JWT alg Header Parameter. The Client MUST use the keys provided by the Issuer.
//    7. The alg value SHOULD be the default of RS256 or the algorithm sent by the Client in the id_token_signed_response_alg parameter during Registration.
//    8. If the JWT alg Header Parameter uses a MAC based algorithm such as HS256, HS384, or HS512, the octets of the UTF-8 representation of the client_secret corresponding to the client_id contained in the aud (audience) Claim are used as the key to validate the signature. For MAC based algorithms, the behavior is unspecified if the aud is multi-valued or if an azp value is present that is different than the aud value.
//    9. The current time MUST be before the time represented by the exp Claim.
//    10. The iat Claim can be used to reject tokens that were issued too far away from the current time, limiting the amount of time that nonces need to be stored to prevent attacks. The acceptable range is Client specific.
//    11. If a nonce value was sent in the Authentication Request, a nonce Claim MUST be present and its value checked to verify that it is the same value as the one that was sent in the Authentication Request. The Client SHOULD check the nonce value for replay attacks. The precise method for detecting replay attacks is Client specific.
//    12. If the acr Claim was requested, the Client SHOULD check that the asserted Claim Value is appropriate. The meaning and processing of acr Claim Values is out of scope for this specification.
//    31. If the auth_time Claim was requested, either through a specific request for this Claim or by using the max_age parameter, the Client SHOULD check the auth_time Claim value and request re-authentication if it determines too much time has elapsed since the last End-User authentication.
//
//             {"at_hash":"mg0jnAWwqg8H7f7w6omIGw",
//            "aud":["public_dev:2646ac34-b499-41b3-8e4b-2c2c4698cc45"],
//            "auth_time":1588240476,
//            "exp":1588244076,
//            "iat":1588240476,
//            "iss":"http://127.0.0.1:4444/",
//            "jti":"77982b01-0539-4cf3-96d8-4eafce130606",
//            "nonce":"D2263205-E607-44CD-B372-3D66EA7D1E39",
//            "rat":1588240476,
//            "sid":"28392582-51e1-41dd-8281-38249c0fb5d7",
//            "sub":"foo@bar.com"}
    
    @objc public class func validateIdToken(idTokenMessageJson: [String: Any],
                                            discoveryIssuer: String,
                                            clientId: String,
                                            authNonce: String) throws {
        
        // 2. iss
        let iss: String = idTokenMessageJson["iss"] as? String ?? ""
        guard iss == discoveryIssuer else {
            throw EAErrorUtil.error(domain: "MegAuthIdTokenValidator", code: -1, underlyingError: nil, description: "wrong idToken iss")
        }
        
        // 3. aud
        let audiences: [String] = idTokenMessageJson["aud"] as? [String] ?? []
        guard audiences.count == 1 else {
            throw EAErrorUtil.error(domain: "MegAuthIdTokenValidator", code: -1, underlyingError: nil, description: "wrong idToken aud count")
        }
        guard audiences[0] == clientId else {
            throw EAErrorUtil.error(domain: "MegAuthIdTokenValidator", code: -1, underlyingError: nil, description: "wrong idToken aud doesn't match clientId")
        }
        
        // 9. current time after exp
        let now: TimeInterval = Date().timeIntervalSince1970
        let exp: Int = idTokenMessageJson["exp"] as? Int ?? ""
        guard now >= Double(exp) {
            throw EAErrorUtil.error(domain: "MegAuthIdTokenValidator", code: -1, underlyingError: nil, description: "idToken has expired")
        }
        
        // 11. nonce
        let nonce: String = idTokenMessageJson["nonce"] as? String ?? ""
        guard nonce == authNonce else {
            throw EAErrorUtil.error(domain: "MegAuthIdTokenValidator", code: -1, underlyingError: nil, description: "wrong idToken nonce")
        }
        
    }
    
}
