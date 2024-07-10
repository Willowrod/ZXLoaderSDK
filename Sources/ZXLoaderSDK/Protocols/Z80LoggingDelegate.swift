//
//  Z80LoggingDelegate.swift
//  
//
//  Created by Mike Hall on 07/07/2023.
//

import Foundation

public protocol TapeLoggingDelegate {
    func logError(_ message: String)
    func logInfo(_ message: String)
    func logWarning(_ message: String)
    func logNetwork(_ message: String)
    func log(_ message: String)
    //func clearLogcat()
}
