//
//  EAHexUtil.swift
//  
//
//  Created by Antti Köliö on 16.2.2021.
//

import Foundation

@objc
public class EAHexUtil: NSObject {
    
    @objc public class func hexFromInteger(value: Int, lengthInBytes: Int) -> String {
        let format = String(format: "%%0%ldllX", lengthInBytes * 2)
        return String(format: format, value)
    }
    
    @objc public class func integerFromHex(hex: String) -> Int {
        let scanner = Scanner(string: hex)
        var result: UInt64 = 0
        scanner.scanHexInt64(&result)
        return Int(result)
    }
    
    @objc public class func hexFromData(data: Data) -> String {
        var buffer = String()
        for i in 0..<data.count {
            var b: UInt8 = 0
            data.copyBytes(to: &b, from: i..<i+1)
            buffer.append(String(format: "%02x", b))
        }
        return buffer
    }
        
    @objc public class func dataFromHex(hex: String) -> Data {
        var data = Data()
        for index in stride(from: 0, to: hex.count, by: 2) {
            let start = hex.index(hex.startIndex, offsetBy: index)
            let end = hex.index(start, offsetBy: 2)
            let hexPart = String(hex[start..<end])
            let intValue = integerFromHex(hex: hexPart)
            data.append(contentsOf: [UInt8(intValue)])
        }
        return data
    }
}
