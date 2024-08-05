//
//  Z80Type1FormatWrite.swift
//  Z80Type1FormatWrite
//
//  Created by Mike Hall on 27/08/2021.
//

import Foundation

public class Z80Type1FormatWrite {
    
    public init() {
        
    }
    
    public var ramDump: [UInt8] = []
    
    public func add(_ byte: UInt8) {
        ramDump.append(byte)
    }
    
    public func add(_ byte: UInt16) {
        ramDump.append(byte.lowByte())
        ramDump.append(byte.highByte())
    }
    
    public func add(_ bytes: [UInt8]) {
        ramDump.append(contentsOf: bytes)
    }
    
    public func write() -> String {
        var returnString: String = ""
        ramDump.forEach{ byte in
            returnString += "\(byte.hex()) "
        }
        if !returnString.isEmpty {
            returnString.removeLast()
        }
        return returnString
    }
}
