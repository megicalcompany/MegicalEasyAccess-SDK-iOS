//
//  EALogging.swift
//  
//
//  Created by Antti Köliö on 15.2.2021.
//

import Foundation
import SwiftyBeaver

@objc
public class EALog: NSObject {
    
    @objc public class func config() {
        let log = SwiftyBeaver.self
        let console = ConsoleDestination()
        console.minLevel = .info
        log.addDestination(console)
    }
}

