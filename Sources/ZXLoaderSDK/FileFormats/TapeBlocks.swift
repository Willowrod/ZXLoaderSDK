//
//  TapeBlocks.swift
//  
//
//  Created by Mike Hall on 19/07/2023.
//

import Foundation

class BaseTapeBlock {
    var blockType: UInt8 = 0
    var blockLength: UInt16 = 0
    var order: Int = 0
    var blockData: [UInt8] = []
    var blockCounter = 0
    var rawData: [UInt8] = []
    var pause: UInt16 = 0
    var isHeader = false
    var isCodeBlock = true
    var currentByte: Int = 0
    var currentBit = 7
    var isOffPulse = false
    var isPause = false
   // var pulseLength = 855
   // var currentPulseLength = 2168
    var playState: PlayState = .pilot
    var pilotCount = 0
    var workingByte: UInt8 = 0x00
    var currentlySet = false
    var usedBitsInLastByte: UInt8 = 8
    
    var syncPulse1: UInt16 = 667
    var syncPulse2: UInt16 = 735
    var pilotPulse: UInt16 = 2168
    var zeroPulse: UInt16 = 855
    var onePulse: UInt16 = 1710
    var pilotTone: UInt16 = 3223
    var pilotToneHeader: UInt16 = 8063
    var pauseLength: UInt16 = 1000
    
    
    var loggingDelegate: TapeLoggingDelegate? = nil
    
    init(data: ArraySlice<UInt8>, order: Int, delegate: TapeLoggingDelegate?){
        self.loggingDelegate = delegate
        self.order = order
        rawData = Array(data)
        process()
  //      rawData.removeAll()
    }
    
    func reset() {
        blockCounter = 0
        currentBit = 7
    workingByte = 0x00
    currentByte = 0
    }
    
    func process(){}
    
    func read() -> (onPulse: Int, offPulse: Int, pause: Int)?{ //reset: Bool)? {
  //      var reset = false
        switch playState {
        
        case .pilot:
            if isHeader {
                if pilotCount >= pilotToneHeader {
                    playState = .sync
                }
            } else {
                if pilotCount >= pilotTone {
                    playState = .sync
                }
            }
            pilotCount += 2
            return (Int(pilotPulse), Int(pilotPulse), -1)
        case .sync:
            if blockData.isEmpty {
                print("Ouch!")
            }
            workingByte = blockData[0]
            playState = .play
            return (Int(syncPulse1), Int(syncPulse2), -1)
        case .play:
            currentlySet = workingByte.isSet(bit: currentBit)
            currentBit -= 1
            if currentBit < 0 {
                currentByte += 1
                currentBit = 7
                if currentByte < blockData.count {
                workingByte = blockData[currentByte]
                } else {
                    playState = .pause
                }
            }
            if currentlySet {
                return(Int(onePulse), Int(onePulse), -1)
            } else {
                return(Int(zeroPulse), Int(zeroPulse), -1)
            }
        case .pause:
            playState = .complete
            return (0, 3494 * Int(pauseLength), -1)//return (0, 69888 * 50)
        case .pauseBlock:
            return (0, 0, 3494 * Int(pauseLength))//return (0, 69888 * 50)
        case .complete:
        return nil
        }
    }
    
    func fetchByte(byte: Int) -> UInt8 {
        if (rawData.count > byte){
            blockCounter += 1
            return rawData[byte]
        } else {
            loggingDelegate?.log("Error importing byte \(byte) for block type \(blockType) - not enough data!")
        }
        blockCounter += 1
        return 0x00
    }
    
    func fetchWord(byte: Int) -> UInt16 {
        if (rawData.count > byte &+ 1){
            blockCounter += 2
            return UInt16(rawData[byte]) &+ (UInt16(rawData[(byte + 1)]) * 256) // Little Endian
        } else {
            loggingDelegate?.log("Error importing Word \(byte) for block type \(blockType) - not enough data!")
        }
        blockCounter += 2
        return 0x00
    }
}

class TZXHeaderBlock: BaseTapeBlock {
    var majorVersion: UInt8 = 0
    var minorVersion: UInt8 = 0
    
    override func process() {
        isCodeBlock = false
    blockLength = 10
    majorVersion = fetchByte(byte: 8)
    minorVersion = fetchByte(byte: 9)
        blockCounter = 0
        
        loggingDelegate?.log ("TZX Version \(majorVersion).\(minorVersion) being imported")
    }
}

class TAPStyleBlock: BaseTapeBlock {
    var type: UInt8 = 0x00
    var fileName = ""
    var dataBlockLength: UInt16 = 0x00
    var parameter1: UInt16 = 0x00
    var parameter2: UInt16 = 0x00
    var checkSum: UInt8 = 0x00
    
    func headerType() -> String{
        switch type {
        case 0:
           return "Program"
        case 1:
           return "Number Var"
        case 2:
           return "String Var"
        case 3:
           return "Memory Block"
        default:
           return "Program"
        }
    }
    
    func parameter1Details() -> String {
        switch type {
        case 0:
           return "Auto Start: \(parameter1)"
        case 1:
            return "Number Var: \(String(UnicodeScalar(UInt8(parameter1.highByte()))))"
        case 2:
           return "String Var: \(String(UnicodeScalar(UInt8(parameter1.highByte()))))"
        case 3:
           return "Start Address: \(parameter1)"
        default:
           return "Unknown"
        }
    }
    
    func parameter2Details() -> String {
        switch type {
        case 0:
           return "Program Length: \(parameter2)"
        default:
           return "Parameter 2 Unused: \(parameter2)"
        }
    }
    
}

class TZXMessage {
    var type: UInt8 = 0x00
    var length: Int = 0
    var description: String = ""
    var text: String = ""
    
    init(type: UInt8, block: ArraySlice<UInt8>){
        self.type = type
        
parseText(block: block)
    }
    
    init(type: String, block: ArraySlice<UInt8>){
        self.type = 0xFE
        description = type
        parseText(block: block)
    }
    
    func parseText(block: ArraySlice<UInt8>){
        for char in block{
            text += String(UnicodeScalar(UInt8(char)))
        }
        length = block.count
    }
    
    func setDescript(){
        switch type {
        case 0x00:
            description = "Full title"
        case 0x01:
            description = "Software house/publisher"
        case 0x02:
            description = "Author(s)"
        case 0x03:
            description = "Year of publication"
        case 0x04:
            description = "Language"
        case 0x05:
            description = "Game/utility type"
        case 0x06:
            description = "Price"
        case 0x07:
            description = "Protection scheme/loader"
        case 0x08:
            description = "Origin"
        case 0xFF:
            description = "Comment(s)"
        default:
            description = "Unknown"
        }
    }
}

class TZXMessageStyleBlock: BaseTapeBlock{
    var text: [TZXMessage] = []
    
    override func process() {
        isCodeBlock = false
    }
    
    func displayMessages() {
        text.forEach{message in
            loggingDelegate?.log("... \(message.description): \(message.text)")
        }
    }
}

class TZXTextDescriptionBlock: TZXMessageStyleBlock {
    override func process() {
        super.process()
        blockType = 0x30
        blockCounter += 1
        let length = fetchByte(byte: blockCounter)
        text.append(TZXMessage.init(type: "Text Description", block: rawData[blockCounter...blockCounter + Int(length) - 1]))
        blockCounter += Int(length)
        displayMessages()
    }
}

class TZXTextMessageBlock: TZXMessageStyleBlock {
    var displayTime: UInt8 = 0x00
    override func process() {
        super.process()
        blockType = 0x31
        blockCounter += 1
        displayTime = fetchByte(byte: blockCounter)
        let length = fetchByte(byte: blockCounter)
        text.append(TZXMessage.init(type: "Text Description", block: rawData[blockCounter...blockCounter + Int(length) - 1]))
        blockCounter += Int(length)
        displayMessages()
    }
}


class TZXTextArchiveBlock: TZXMessageStyleBlock {
    var totalTextLength: UInt16 = 0x00
    var numberOfStrings: UInt8 = 0x00
    override func process() {
        super.process()
        blockType = 0x32
        blockCounter += 1
        totalTextLength = fetchWord(byte: blockCounter)
        numberOfStrings = fetchByte(byte: blockCounter)
        for _ in 0..<Int(numberOfStrings){
            let msgType = fetchByte(byte: blockCounter)
            let len = fetchByte(byte: blockCounter)
            text.append(TZXMessage.init(type: msgType, block: rawData[blockCounter...blockCounter + Int(len) - 1]))
            blockCounter += Int(len)
        }
        displayMessages()
    }
}


//class TZXPauseBlock: TZXTAPStyleBlock {
//    override func process() {
//        blockType = 0x20
//        blockCounter += 1
//        pauseLength = fetchWord(byte: blockCounter)
//        blockData = []
//        print("Pause block imported - Length: \(pauseLength)ms")
//    }
//}

class StandardSpeedBlock: TAPStyleBlock {
    override func process() {
        blockType = 0x10
        blockCounter += 1
        pauseLength = fetchWord(byte: blockCounter)
        blockLength = fetchWord(byte: blockCounter)
        if blockCounter + Int(blockLength) < rawData.count {
        blockData = Array(rawData[blockCounter...blockCounter + Int(blockLength - 1)])
        } else {
            blockData = Array(rawData[blockCounter...])
        }
        let tempByteCount = blockCounter
        
        if fetchByte(byte: blockCounter) == 0x00{
            isHeader = true
            type = fetchByte(byte: blockCounter)
            for char in blockData[1...10]{
                fileName += String(UnicodeScalar(UInt8(char)))
            }
            blockCounter += 10
            dataBlockLength = fetchWord(byte: blockCounter)
            parameter1 = fetchWord(byte: blockCounter)
            parameter2 = fetchWord(byte: blockCounter)
            loggingDelegate?.log("Header imported - Type: \(headerType()) - Name: \(fileName) - Block Length: \(dataBlockLength) - \(parameter1Details()) - \(parameter2Details()) - Length: \(blockLength) - Pause: \(pauseLength)")
        } else {
            isHeader = false
            loggingDelegate?.log ("Standard Speed block imported of length \(blockLength) - Pause: \(pauseLength)")
        }
 //       printBlockData(data: blockData)
        blockCounter = tempByteCount
    }
}

class TZXTurboSpeedBlock: TAPStyleBlock {
    override func process() {
        loggingDelegate?.log("Parsing Turbo Speed Block")
        blockType = 0x11
        blockCounter += 1
        pilotPulse = fetchWord(byte: blockCounter)
        syncPulse1 = fetchWord(byte: blockCounter)
        syncPulse2 = fetchWord(byte: blockCounter)
        zeroPulse = fetchWord(byte: blockCounter)
        onePulse = fetchWord(byte: blockCounter)
        pilotToneHeader = fetchWord(byte: blockCounter)
        pilotTone = pilotToneHeader
        usedBitsInLastByte = fetchByte(byte: blockCounter)
        pauseLength = fetchWord(byte: blockCounter)
        blockLength = fetchWord(byte: blockCounter)
        blockCounter += 1
        loggingDelegate?.log("Data left: \(rawData.count) - Length of block: \(blockLength)")
   
        if blockCounter + Int(blockLength) < rawData.count {
        blockData = Array(rawData[blockCounter...blockCounter + Int(blockLength - 1)])
        } else {
            blockData = Array(rawData[blockCounter...])
        }
        let tempByteCount = blockCounter
        
        if fetchByte(byte: blockCounter) == 0x00{
            isHeader = true
            type = fetchByte(byte: blockCounter)
            for char in blockData[1...10]{
                fileName += String(UnicodeScalar(UInt8(char)))
            }
            blockCounter += 10
            dataBlockLength = fetchWord(byte: blockCounter)
            parameter1 = fetchWord(byte: blockCounter)
            parameter2 = fetchWord(byte: blockCounter)
            
            loggingDelegate?.log("Header imported - Type: \(headerType()) - Name: \(fileName) - Block Length: \(dataBlockLength) - \(parameter1Details()) - \(parameter2Details()) - Length: \(blockLength) - ")
        } else {
            isHeader = false
            loggingDelegate?.log ("Standard Speed block imported of length \(blockLength)")
        }
 //       printBlockData(data: blockData)
        blockCounter = tempByteCount

    }
}

class TZXPulseSequenceBlock: TAPStyleBlock {
    override func process() {
        blockType = 0x13
        blockCounter += 1
        var length = fetchByte(byte: blockCounter)
        blockLength = UInt16(length * 2)
      //  if blockCounter + Int(blockLength) < rawData.count {
        blockData = []//Array(rawData[blockCounter...blockCounter + Int(blockLength - 1)])
//        } else {
//            blockData = Array(rawData[blockCounter...])
//        }
        let tempByteCount = blockCounter
        
        if fetchByte(byte: blockCounter) == 0x00{
            isHeader = true
            type = fetchByte(byte: blockCounter)
            for char in blockData[1...10]{
                fileName += String(UnicodeScalar(UInt8(char)))
            }
            blockCounter += 10
            dataBlockLength = fetchWord(byte: blockCounter)
            parameter1 = fetchWord(byte: blockCounter)
            parameter2 = fetchWord(byte: blockCounter)
            loggingDelegate?.log("Header imported - Type: \(headerType()) - Name: \(fileName) - Block Length: \(dataBlockLength) - \(parameter1Details()) - \(parameter2Details()) - Length: \(blockLength) - Pause: \(pauseLength)")
        } else {
            isHeader = false
            loggingDelegate?.log ("Standard Speed block imported of length \(blockLength) - Pause: \(pauseLength)")
        }
 //       printBlockData(data: blockData)
        blockCounter = tempByteCount
    }
}

class TZXPureDataBlock: TAPStyleBlock {
    override func process() {
        loggingDelegate?.log("Parsing Pure Data Block")
        blockType = 0x14
        blockCounter += 1
        pilotPulse = 0
        syncPulse1 = 0
        syncPulse2 = 0
        zeroPulse = fetchWord(byte: blockCounter)
        onePulse = fetchWord(byte: blockCounter)
        pilotToneHeader = 0
        pilotTone = 0
        usedBitsInLastByte = fetchByte(byte: blockCounter)
        pauseLength = fetchWord(byte: blockCounter)
        blockLength = fetchWord(byte: blockCounter)
        blockCounter += 1
        playState = .play
        loggingDelegate?.log("Data left: \(rawData.count) - Length of block: \(blockLength)")
   
        if blockCounter + Int(blockLength) < rawData.count {
        blockData = Array(rawData[blockCounter...blockCounter + Int(blockLength - 1)])
        } else {
            blockData = Array(rawData[blockCounter...])
        }
        let tempByteCount = blockCounter
        
        if fetchByte(byte: blockCounter) == 0x00{
            isHeader = true
            type = fetchByte(byte: blockCounter)
            for char in blockData[1...10]{
                fileName += String(UnicodeScalar(UInt8(char)))
            }
            blockCounter += 10
            dataBlockLength = fetchWord(byte: blockCounter)
            parameter1 = fetchWord(byte: blockCounter)
            parameter2 = fetchWord(byte: blockCounter)
            
            loggingDelegate?.log("Header imported - Type: \(headerType()) - Name: \(fileName) - Block Length: \(dataBlockLength) - \(parameter1Details()) - \(parameter2Details()) - Length: \(blockLength) - ")
        } else {
            isHeader = false
            loggingDelegate?.log ("Pure data block imported of length \(blockLength)")
        }
 //       printBlockData(data: blockData)
        blockCounter = tempByteCount

    }
}

class TZXGroupStartBlock: TZXMessageStyleBlock {
    override func process() {
        super.process()
        blockType = 0x21
        blockCounter += 1
        let length = fetchByte(byte: blockCounter)
        if length > 0 {
        text.append(TZXMessage.init(type: "Found Group Block called", block: rawData[blockCounter...blockCounter + Int(length) - 1]))
        blockCounter += Int(length)
        } else {
            text.append(TZXMessage.init(type: "Found unnamed Group Block", block: []))
        }
        displayMessages()
    }
}

class TZXGroupEndBlock: TZXMessageStyleBlock {
    override func process() {
        super.process()
        blockType = 0x22
        blockCounter += 1
        text.append(TZXMessage.init(type: "Group Block Ends", block: []))
        displayMessages()
    }
}

func printBlockData(data: [UInt8]){
    var blockD = ""
    data.forEach{ byte in
        blockD += "\(byte.hex()), "
    }
    print(blockD)
}

class TZXPauseBlock: BaseTapeBlock {
    override func process() {
        blockType = 0x20
        blockCounter += 1
        pauseLength = fetchWord(byte: blockCounter)
        playState = .pauseBlock
        blockData = []

        
        loggingDelegate?.log ("Pause block imported of length \(blockLength)")
    }
}
