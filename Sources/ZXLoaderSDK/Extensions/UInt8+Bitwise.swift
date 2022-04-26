//
//  UInt8+Bitwise.swift
//  inSpeccytor
//
//  Created by Mike Hall on 24/12/2020.
//

import Foundation
extension UInt8 {
    func clear(bit: Int) -> UInt8 {
        return (self & ~(1 << bit))
    }
    
     func set(bit: Int) -> UInt8 {
        return (self | (1 << bit))
    }
    
    func set(bit: Int, value: Bool) -> UInt8 {
        if (value){
           return set(bit: bit)
        } else {
           return clear(bit: bit)
        }
    }
    
    func twosCompliment() -> UInt8 {
        return ~self &+ 1
    }
    
    func lowerNibble() -> UInt8 {
        return self & 15
    }
    
    func upperNibble() -> UInt8 {
        return (self & 240) >> 4
    }
    
    func twosComplimentString() -> String {
        if self.isSet(bit: 7){
            return "-\(self.twosCompliment())"
        } else {
            return "\(self)"
        }
    }
  
    
    func hex() -> String {
        return String(self, radix: 16).padded(size: 2)
    }
    
    func bin() -> String {
        return String(self, radix: 2).padded(size: 8)
    }

    func isSet(bit: Int) -> Bool {
        return (self & (1 << bit)) > 0
    }
    
}
