//
//  MegAuthPkce.swift
//  
//
//  Created by Antti Köliö on 16.2.2021.
//

import Foundation
import CryptoKit
import SwiftyBeaver

@objc
public class MegAuthPkce: NSObject {
    private static let CODE_VERIFIER_SIZE = 128
    private static let UNRESERVED_URI_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._~"
    
    private class func randomInt() throws -> UInt64 {
        var intData = Data(count: 8)
        let res = SecRandomCopyBytes(kSecRandomDefault, 8, &intData)
        guard res == errSecSuccess else {
            SwiftyBeaver.error("SecRandomCopyBytes fails with: \(res)")
            throw EAErrorUtil.error(domain: "MegAuthPkce", code: Int(res), underlyingError: nil, description: "SecRandomCopyBytes fails with: \(res)")
        }
        let intHex = EAHexUtil.hexFromData(data: intData)
        let uint64 = EAHexUtil.uint64FromHex(hex: intHex)
        return uint64
    }
    
    @objc public class func generateCodeVerifier() throws -> String {
        var verifier = ""
        
        for _ in 0 ..< CODE_VERIFIER_SIZE {
            var random: UInt64
            do {
                random = try MegAuthPkce.randomInt()
            } catch {
                throw EAErrorUtil.error(domain: "MegAuthPkce", code: -1, underlyingError: error, description: "Failed to create random for code verifier")
            }
            let offset: Int = Int(random % UInt64(UNRESERVED_URI_CHARS.count))
            let charIndex = UNRESERVED_URI_CHARS.index(UNRESERVED_URI_CHARS.startIndex, offsetBy: offset)
            let nextChar: String = String(UNRESERVED_URI_CHARS[charIndex ..< UNRESERVED_URI_CHARS.index(after: charIndex)])
            verifier.append(nextChar)
        }
        SwiftyBeaver.info("Code verifier: \(verifier)")
        return verifier
    }

    @objc public class func generateCodeChallengeBase64(verifier: String) -> String {
        let verifierData = verifier.data(using: .ascii)!
        let digestHash = SHA256.hash(data: verifierData)
        let digestHashHex = digestHash.compactMap { String(format: "%02x", $0) }.joined()
        SwiftyBeaver.info("digestHashHex: \(digestHashHex)")
        let codeChallengeBase64 = EABase64Util.urlSafeBase64FromData(data: EAHexUtil.dataFromHex(hex: digestHashHex))
        SwiftyBeaver.info("codeChallengeBase64: \(codeChallengeBase64)")
        return codeChallengeBase64
    }
}
