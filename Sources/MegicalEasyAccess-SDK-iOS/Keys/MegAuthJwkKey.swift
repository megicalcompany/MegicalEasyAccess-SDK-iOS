//
//  MegAuthJwkKey.swift
//  
//
//  Created by Antti Köliö on 15.2.2021.
//

import Foundation
import SwiftyBeaver
import JOSESwift
import CryptoKit

@objc
public class MegAuthJwkKey: NSObject {
    
    private let log = SwiftyBeaver.self
    
    private var keychainTagPrivate: Data = "com.example.private".data(using: .utf8)!
    private var keychainTagPublic: Data = "com.example.private".data(using: .utf8)!
    
    /**
     sig or enc
     */
    @objc var jwkUseClause = "sig"
    
    /**
     Example tags:
     "com.company.appname.client.private"
     "com.company.appname.client.public"
     
     jwkUseClause is 'sig' or 'enc' (use 'sig')
     */
    @objc public init(keychainTagPrivate: String,
                      keychainTagPublic: String,
                      jwkUseClause: String = "sig") {
        super.init()
        self.keychainTagPrivate = keychainTagPrivate.data(using: .utf8)!
        self.keychainTagPublic = keychainTagPublic.data(using: .utf8)!
        self.jwkUseClause = jwkUseClause
    }
    
    @objc open func privateKeyParams() -> [String: Any] {
        log.info("Private key params with tag \(String.init(data: self.keychainTagPrivate, encoding: .utf8)!)")
        return [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: self.keychainTagPrivate
        ]
    }
    
    @objc open func publicKeyParams() -> [String: Any] {
        log.info("Public key params with tag \(String.init(data: self.keychainTagPublic, encoding: .utf8)!)")
        return [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: self.keychainTagPublic
        ]
    }
    
    @objc open func keyCreationAttributes() -> [String: Any] {
        return [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeySizeInBits as String: 2048,
                kSecPrivateKeyAttrs as String: privateKeyParams(),
                kSecPublicKeyAttrs as String: publicKeyParams()
        ]
    }
    
    @objc open func createKeypair() throws -> SecKey {
        let keyCreationAttr = keyCreationAttributes()

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyCreationAttr as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        log.info("Private key created with tag \(String.init(data: self.keychainTagPrivate, encoding: .utf8) ?? "")")
        return privateKey
    }
    
    @objc open func getPrivateKeyRef() throws -> SecKey {
        let getquery: [String: Any] = [kSecClass as String: kSecClassKey,
                                       kSecAttrApplicationTag as String: self.keychainTagPrivate,
                                       kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                                       kSecReturnRef as String: true]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(getquery as CFDictionary, &item)
        guard status == errSecSuccess else {
            log.info("Key not found with tag \(String.init(data: self.keychainTagPrivate, encoding: .utf8) ?? "")")
            return try createKeypair()
        }
        log.info("Key found with tag \(String.init(data: self.keychainTagPrivate, encoding: .utf8) ?? "")")
        let key = item as! SecKey
        return key
    }
    
    @objc open func signJwt(clientId:String, message:String) throws -> String {
        var header = JWSHeader(algorithm: .RS256)
        header.kid = clientId as String
        let messageData = message.data(using: .utf8)!
        let payload = Payload(messageData)
        
        let privateKey: SecKey = try getPrivateKeyRef()

        let signer = Signer(signingAlgorithm: .RS256, privateKey: privateKey)!
        
        guard let jws = try? JWS(header: header, payload: payload, signer: signer) else {
            throw NSError(domain: "JoseSwiftInterface::signJwt", code: -1, userInfo: [NSLocalizedDescriptionKey : "could not sign"])
        }

        log.info(jws.compactSerializedString) // ey (...) J9.U3 (...) LU.na (...) 1A
        return jws.compactSerializedString
    }
    
    @objc open func getJwtPublicKey() throws -> SecKey {
        let privateKey: SecKey = try getPrivateKeyRef()
        let publicKey = SecKeyCopyPublicKey(privateKey)
        guard publicKey != nil else {
            throw NSError(domain: "jwt keys", code: -1, userInfo: [NSLocalizedDescriptionKey : "could not get public key"])
        }
        return publicKey!
    }
    
    @objc open func getJwtPublicKeyAsBase64() throws -> String {
        let publicKey = try getJwtPublicKey()
        
        var error:Unmanaged<CFError>?
        guard let cfdata = SecKeyCopyExternalRepresentation(publicKey, &error) else {
           throw error!.takeRetainedValue() as Error
        }
        
        let data:Data = cfdata as Data
        let b64Key = data.base64EncodedString()
        return b64Key
    }
    
    @objc open func jwkJsonDataFromPublicKey() throws -> Data {
        let publicKey = try getJwtPublicKey()
        let jwk = try! RSAPublicKey(publicKey: publicKey)
        let jsonData = jwk.jsonData()! // {"kty":"RSA","n":"MHZ4L...uS2d3","e":"QVFBQg"}
        var jsonDict:Dictionary = try JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as? [String: Any] ?? [:]
        jsonDict["use"] = self.jwkUseClause
        let jsonDataWithUse = try JSONSerialization.data(withJSONObject: jsonDict)
        return jsonDataWithUse
    }
    
    // MARK: - sig
    @objc open func verifyIdTokenWithJwksKey(idToken:String, jwksKeyData:Data) throws -> String {
        
        let jwk = try! RSAPublicKey(data: jwksKeyData)

        let publicKey: SecKey = try! jwk.converted(to: SecKey.self)
        
        guard let idTokenData:Data = idToken.data(using: .utf8) else {
            log.error("idToken to data failed")
            throw NSError(domain: "JoseSwiftInterface", code: -1, userInfo: [NSLocalizedDescriptionKey : "idToken to data failed"])
        }
        
        let jws = try JWS(compactSerialization: idTokenData)
        let verifier = Verifier(verifyingAlgorithm: .RS256, publicKey: publicKey)!
        let payload = try jws.validate(using: verifier).payload
        let message = String(data: payload.data(), encoding: .utf8)!

        return message
    }
    
    // MARK: - enc
    @objc open func decrypt(cipherText:Data) throws -> Data {
        let privateKey: SecKey = try getPrivateKeyRef()
        
        var error: Unmanaged<CFError>?
        
        guard let clearText = SecKeyCreateDecryptedData(privateKey, .rsaEncryptionPKCS1, cipherText as CFData, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        return clearText
    }
    
    @objc open func decryptAesGcm(ivData:Data, cipherTextData:Data, tagData:Data, key:Data) throws -> Data {
        let symmKey = CryptoKit.SymmetricKey.init(data: key)
        let nonce = try AES.GCM.Nonce(data: ivData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: cipherTextData, tag: tagData)
        let decryptedMessage = try AES.GCM.open(sealedBox, using: symmKey)
        return decryptedMessage
    }
}
