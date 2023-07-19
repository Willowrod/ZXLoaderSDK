//
//  BaseTapeFileFormat.swift
//  
//
//  Created by Mike Hall on 19/07/2023.
//

import Foundation

open class BaseTapeFileFormat: BaseFileFormat, TapeDelegate {
    
    var tapeData: [UInt8] = []
    var blocks: [BaseTapeBlock] = []
    var dataBlocks: [BaseTapeBlock] = []
    var currentByte: Int = 0
    var currentBlock = 0
    var currentBit = 7
    var processing = false
    var workingBlock: BaseTapeBlock? = nil
    var onPulseLength: Int = 0
    var offPulseLength: Int = 0
    var pauseLength: Int = 0
    var isOnPulse = true
    var controlDelegate: TapeControlDelegate? = nil
    
    var loggingDelegate: TapeLoggingDelegate? = nil
    
    var currentBlockRepeats = 0
    
    public func fastForward() {
        controlDelegate?.setTapeState(state: .Paused)
        if currentBlock < dataBlocks.count {
            currentBlock += 1
            getcurrentBlock()?.reset()
            updateBlockName()
        }
    }
    
    public func rewind() {
        controlDelegate?.setTapeState(state: .Paused)
        if let current = getcurrentBlock() {
            if current.currentByte > 0 && current.currentBit < 7 {
                current.reset()
            } else {
                backOneTrack()
            }
        } else {
            backOneTrack()
        }
      
    }
    
    public func setControlDelegate(del: TapeControlDelegate?) {
        controlDelegate = del
        updateBlockName()
    }
    
    func updateBlockName(){
            DispatchQueue.main.async {
                self.controlDelegate?.setCurrentBlock(name: "Block: \(self.currentBlock)")
        }
    }
    
    func backOneTrack(){
        if currentBlock > 0 {
            getcurrentBlock()?.reset()
            currentBlock -= 1
            getcurrentBlock()?.reset()
            updateBlockName()
        }
    }
    
    func fetchByte(byte: Int) -> UInt8 {
        if (tapeData.count > byte){
            return tapeData[byte]
        } else {
            loggingDelegate?.log("Error importing byte \(byte) from TZX root - not enough data!")
            processing = false
        }
        return 0x00
    }
    
    func fetchWord(byte: Int) -> UInt16 {
        if (tapeData.count > byte &+ 1){
            return UInt16(tapeData[byte]) &+ (UInt16(tapeData[(byte + 1)]) * 256) // Little Endian
        } else {
            loggingDelegate?.log("Error importing Word \(byte) from tapeData root - not enough data!")
            processing = false
        }
        return 0x00
    }
    
    func callNextBlock() -> BaseTapeBlock? {
        currentBlock += 1
        while currentBlock < dataBlocks.count {
            updateBlockName()
                    return dataBlocks[currentBlock]
                }
        return nil
            }
    
    func getcurrentBlock() -> BaseTapeBlock? {
        while currentBlock < dataBlocks.count {
                    return dataBlocks[currentBlock]
                }
        return nil
    }
    
    public func fetchData(tState: Int) -> (signal: Bool, reset: Bool, pause: Bool)? {
        if workingBlock == nil {
            workingBlock = getcurrentBlock()
            if let thisBlock = workingBlock {
            if let thisBlockData = thisBlock.read() {
                onPulseLength = thisBlockData.onPulse
                offPulseLength = thisBlockData.offPulse
                pauseLength = thisBlockData.pause
            }
            } else {
                loggingDelegate?.log ("End of TZX file")
                return nil
            }
        }
        if pauseLength > -1 {
            if tState < onPulseLength {
                return(false, false, true)
            } else {
                isOnPulse = true
                return(false, true, false)
            }
        }
        switch isOnPulse {
        case true:
            
            if tState < onPulseLength {
                return(true, false, false)
            } else {
                isOnPulse = false
                return(true, true, false)
            }
            
        case false:
            if tState < onPulseLength {
                return(false, false, false)
            } else {
                isOnPulse = true
                if let thisBlock = workingBlock, thisBlock.blockType != 0x20, let thisBlockData = thisBlock.read() {
                    onPulseLength = thisBlockData.onPulse
                    offPulseLength = thisBlockData.offPulse
                } else {
                    currentBlock += 1
                    workingBlock = nil//getcurrentBlock()
                    updateBlockName()
                }
                return(false, true, false)
            }
        }
    }
    
    public func startTape() {
        currentBlock = 0
        currentByte = 0
        currentBit = 7
    }
    
}
