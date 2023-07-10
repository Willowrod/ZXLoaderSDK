//
//  TAPFormat.swift
//  
//
//  Created by Mike Hall on 06/05/2023.
//

import Foundation

public class TAPFormat: BaseFileFormat , TapeDelegate {

var tapData: [UInt8] = []
var blocks: [BaseTAPBlock] = []
var dataBlocks: [BaseTAPBlock] = []
var currentByte: Int = 0
var currentBlock = 0
var currentBit = 7
var processing = false
var workingBlock: BaseTAPBlock? = nil
var onPulseLength: Int = 0
var offPulseLength: Int = 0
var isOnPulse = true
var controlDelegate: TapeControlDelegate? = nil

public init(filename: String, path: String?) {
    super.init()
    var tapBytes: Data? = nil
    if let filePath = path, filePath.count > 0 {
        var file = "\(filePath)/\(filename)"
        if !file.hasSuffix(".tap") {
            file = "\(file).tap"
        }
        if let contents = NSData(contentsOfFile: file) {
            tapBytes = contents as Data
        }
    } else if let filePath = Bundle.main.path(forResource: filename.replacingOccurrences(of: ".tap", with: ""), ofType: "tap"){
        let contents = NSData(contentsOfFile: filePath)
        tapBytes = contents! as Data
    } else {
        print("file not found")
    }
    if let tapStream = tapBytes?.hexString?.splitToBytes(separator: " "){
        tapStream.forEach{byte in
            tapData.append(UInt8(byte, radix: 16) ?? 0x00)
        }
    process()
    }
}

public init(path: String) {
    super.init()
    var tapBytes: Data? = nil
        var file = path
        if !file.hasSuffix(".tap") {
            file = "\(file).tap"
        }
        if let contents = NSData(contentsOfFile: file) {
            tapBytes = contents as Data
        }

    if let tapStream = tapBytes?.hexString?.splitToBytes(separator: " "){
        tapStream.forEach{byte in
            tapData.append(UInt8(byte, radix: 16) ?? 0x00)
        }
    process()
    }
}

public init(data: Data){
    super.init()
    if let tapBytes = data.hexString?.splitToBytes(separator: " "){
        tapBytes.forEach{byte in
            tapData.append(UInt8(byte, radix: 16) ?? 0x00)
        }
    process()
    }
}

public init(data: [UInt8]){
    super.init()
    tapData = data
    process()
}

public init(data: String?){
   super.init()
    if let tapBytes = data?.splitToBytes(separator: " "){
        tapBytes.forEach{byte in
            tapData.append(UInt8(byte, radix: 16) ?? 0x00)
        }
    process()
    }
}

public func setControlDelegate(del: TapeControlDelegate?) {
    controlDelegate = del
    updateBlockName()
}

func updateBlockName(){
//           DispatchQueue.main.sync {
            controlDelegate?.setCurrentBlock(name: "Block: \(currentBlock)")
//        }
}

func process(){
    processing = true
    while currentByte < tapData.count && processing {
    readBlock(fromByte: currentByte)
    }
    print("TAP file imported")
    currentBlock = 0
    dataBlocks.removeAll()
    blocks.forEach {block in
        if block.isCodeBlock {
            dataBlocks.append(block)
        }
    }
}

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

func backOneTrack(){
    if currentBlock > 0 {
        getcurrentBlock()?.reset()
        currentBlock -= 1
        getcurrentBlock()?.reset()
        updateBlockName()
    }
}

func readBlock(fromByte: Int){
    if (fromByte < tapData.count){
        print("Block starts \(fromByte)")
        var addLength = true
//        if fromByte == 0 {
//            // read header - Header should be 10 byters long and start with 'ZXTape!' followed by 0x1A
//            // Byte 0x08 if the major version of the TAP file and 0x09 is the minor version
//            if tapData[0x00...0x07] == [0x5A, 0x58, 0x54, 0x61, 0x70, 0x65, 0x21, 0x1A] {
//                blocks.append(TAPHeaderBlock.init(data: tapData[0x00...0x09], order: currentBlock))
//            } else {
//                processing = false
//                print("Not a valid TAP file")
//            }
//        } else {
//            let id = tapData[fromByte]
//            switch (id){
//
//            case 0x10:
                blocks.append(TAPStandardSpeedBlock.init(data: tapData[fromByte...], order: currentBlock))
//            case 0x11:
//                blocks.append(TAPTurboSpeedBlock.init(data: tapData[fromByte...], order: currentBlock))
//            case 0x20:
//                blocks.append(TAPPauseBlock.init(data: tapData[fromByte...], order: currentBlock))
//            case 0x21:
//                blocks.append(TAPGroupStartBlock.init(data: tapData[fromByte...], order: currentBlock))
//            case 0x22:
//                blocks.append(TAPGroupEndBlock.init(data: tapData[fromByte...], order: currentBlock))
//            case 0x30:
//                blocks.append(TAPTextDescriptionBlock.init(data: tapData[fromByte...], order: currentBlock))
//            case 0x31:
//                blocks.append(TAPTextMessageBlock.init(data: tapData[fromByte...], order: currentBlock))
//            case 0x32:
//                blocks.append(TAPTextArchiveBlock.init(data: tapData[fromByte...], order: currentBlock))
//
//            default:
//                let length = fetchWord(byte: fromByte + 1)
//                print("Cannot import block type \(id.hex()) of length \(length)")
//                addLength = false
//                currentByte += 3
//                currentByte += Int(length)
//            }
//        }
        if addLength {
        currentByte += Int(blocks.last?.blockLength ?? 0) + Int(blocks.last?.blockCounter ?? 0)
        }
    } else {
        print("End of file reached or block out of scope")
    }
    currentBlock += 1
}




func fetchByte(byte: Int) -> UInt8 {
    if (tapData.count > byte){
        return tapData[byte]
    } else {
        print("Error importing byte \(byte) from TAP root - not enough data!")
        processing = false
    }
    return 0x00
}

func fetchWord(byte: Int) -> UInt16 {
    if (tapData.count > byte &+ 1){
        return UInt16(tapData[byte]) &+ (UInt16(tapData[(byte + 1)]) * 256) // Little Endian
    } else {
        print("Error importing Word \(byte) from TAP root - not enough data!")
        processing = false
    }
    return 0x00
}

// Delegate Methods


//    func callNextBlock() -> BaseTAPBlock? {
//        while currentBlock < blocks.count {
//            if let block = blocks.first(where: {$0.order == currentBlock}){
//                if block.isCodeBlock {
//                    currentBlock += 1
//                    return block
//                }
//            } else {
//            currentBlock += 1
//            }
//        }
//        return nil
//    }

func callNextBlock() -> BaseTAPBlock? {
    currentBlock += 1
    while currentBlock < dataBlocks.count {
        updateBlockName()
                return dataBlocks[currentBlock]
            }
    return nil
        }

//    func getcurrentBlock() -> BaseTAPBlock? {
//        while currentBlock < blocks.count {
//            if blocks[currentBlock].isCodeBlock {
//                print("Current block = \(currentBlock)")
//                return blocks[currentBlock]
//            }
//            currentBlock += 1
//        }
//        return nil
//    }

func getcurrentBlock() -> BaseTAPBlock? {
    while currentBlock < dataBlocks.count {
                return dataBlocks[currentBlock]
            }
    return nil
}

    public func fetchData(tState: Int) -> (signal: Bool, reset: Bool, pause: Bool)? {
  //  return (true, true)
    if workingBlock == nil {
        workingBlock = getcurrentBlock()
        if let thisBlock = workingBlock {
        if let thisBlockData = thisBlock.read() {
            onPulseLength = thisBlockData.onPulse
            offPulseLength = thisBlockData.offPulse
        }
        } else {
            print ("End of TAP file")
            return nil
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
            if let thisBlock = workingBlock, let thisBlockData = thisBlock.read() {
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
//        if let thisBlock = workingBlock, let thisBlockData = thisBlock.read(tStates: tState) {
//            return thisBlockData
//        }
//        currentBlock += 1
//        workingBlock = getcurrentBlock()
//        return (false, false)
}

public func startTape() {
    currentBlock = 0
    currentByte = 0
    currentBit = 7
}
}

class BaseTAPBlock {
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

init(data: ArraySlice<UInt8>, order: Int){
    self.order = order
    rawData = Array(data)
    process()
}

func reset() {
    blockCounter = 0
    currentBit = 7
workingByte = 0x00
currentByte = 0
}

func process(){}

func read() -> (onPulse: Int, offPulse: Int)?{ //reset: Bool)? {
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
        return (Int(pilotPulse), Int(pilotPulse))
    case .sync:
        workingByte = blockData[0]
        playState = .play
        return (Int(syncPulse1), Int(syncPulse2))
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
            return(Int(onePulse), Int(onePulse))
        } else {
            return(Int(zeroPulse), Int(zeroPulse))
        }
    case .pause:
        playState = .complete
        return (0, 3494 * Int(pauseLength))//return (0, 69888 * 50)
    case .pauseBlock:
        return (0, 3494 * Int(pauseLength))//return (0, 69888 * 50)
    case .complete:
    return nil
    }
}

func fetchByte(byte: Int) -> UInt8 {
    if (rawData.count > byte){
        blockCounter += 1
        return rawData[byte]
    } else {
        print("Error importing byte \(byte) for block type \(blockType) - not enough data!")
    }
    blockCounter += 1
    return 0x00
}

func fetchWord(byte: Int) -> UInt16 {
    if (rawData.count > byte &+ 1){
        blockCounter += 2
        return UInt16(rawData[byte]) &+ (UInt16(rawData[(byte + 1)]) * 256) // Little Endian
    } else {
        print("Error importing Word \(byte) for block type \(blockType) - not enough data!")
    }
    blockCounter += 2
    return 0x00
}
}

class TAPHeaderBlock: BaseTAPBlock {
var majorVersion: UInt8 = 0
var minorVersion: UInt8 = 0

override func process() {
    isCodeBlock = false
blockLength = 10
majorVersion = fetchByte(byte: 8)
minorVersion = fetchByte(byte: 9)
    blockCounter = 0

    print ("TAP Version \(majorVersion).\(minorVersion) being imported")
}
}

class TAPTAPStyleBlock: BaseTAPBlock {
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

class TAPMessage {
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

class TAPMessageStyleBlock: BaseTAPBlock{
var text: [TAPMessage] = []

override func process() {
    isCodeBlock = false
}

func displayMessages() {
    text.forEach{message in
        print("... \(message.description): \(message.text)")
    }
}
}

class TAPTextDescriptionBlock: TAPMessageStyleBlock {
override func process() {
    super.process()
    blockType = 0x30
    blockCounter += 1
    let length = fetchByte(byte: blockCounter)
    text.append(TAPMessage.init(type: "Text Description", block: rawData[blockCounter...blockCounter + Int(length) - 1]))
    blockCounter += Int(length)
    displayMessages()
}
}

class TAPTextMessageBlock: TAPMessageStyleBlock {
var displayTime: UInt8 = 0x00
override func process() {
    super.process()
    blockType = 0x31
    blockCounter += 1
    displayTime = fetchByte(byte: blockCounter)
    let length = fetchByte(byte: blockCounter)
    text.append(TAPMessage.init(type: "Text Description", block: rawData[blockCounter...blockCounter + Int(length) - 1]))
    blockCounter += Int(length)
    displayMessages()
}
}


class TAPTextArchiveBlock: TAPMessageStyleBlock {
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
        text.append(TAPMessage.init(type: msgType, block: rawData[blockCounter...blockCounter + Int(len) - 1]))
        blockCounter += Int(len)
    }
    displayMessages()
}
}


//class TAPPauseBlock: TAPTAPStyleBlock {
//    override func process() {
//        blockType = 0x20
//        blockCounter += 1
//        pauseLength = fetchWord(byte: blockCounter)
//        blockData = []
//        print("Pause block imported - Length: \(pauseLength)ms")
//    }
//}

class TAPStandardSpeedBlock: TAPTAPStyleBlock {
override func process() {
    blockType = 0x10
    //blockCounter += 1
    pauseLength = 1000 //fetchWord(byte: blockCounter)
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
        print("Header imported - Type: \(headerType()) - Name: \(fileName) - Block Length: \(dataBlockLength) - \(parameter1Details()) - \(parameter2Details()) - Length: \(blockLength) - Pause: \(pauseLength)")
    } else {
        isHeader = false
        print ("Standard Speed block imported of length \(blockLength) - Pause: \(pauseLength)")
    }
//       printBlockData(data: blockData)
    blockCounter = tempByteCount
}
}

class TAPTurboSpeedBlock: TAPTAPStyleBlock {
override func process() {
    print("Parsing Turbo Speed Block")
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
    print("Data left: \(rawData.count) - Length of block: \(blockLength)")

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

        print("Header imported - Type: \(headerType()) - Name: \(fileName) - Block Length: \(dataBlockLength) - \(parameter1Details()) - \(parameter2Details()) - Length: \(blockLength) - ")
    } else {
        isHeader = false
        print ("Standard Speed block imported of length \(blockLength)")
    }
//       printBlockData(data: blockData)
    blockCounter = tempByteCount

}
}

class TAPGroupStartBlock: TAPMessageStyleBlock {
override func process() {
    super.process()
    blockType = 0x21
    blockCounter += 1
    let length = fetchByte(byte: blockCounter)
    if length > 0 {
    text.append(TAPMessage.init(type: "Found Group Block called", block: rawData[blockCounter...blockCounter + Int(length) - 1]))
    blockCounter += Int(length)
    } else {
        text.append(TAPMessage.init(type: "Found unnamed Group Block", block: []))
    }
    displayMessages()
}
}

class TAPGroupEndBlock: TAPMessageStyleBlock {
override func process() {
    super.process()
    blockType = 0x22
    blockCounter += 1
    text.append(TAPMessage.init(type: "Group Block Ends", block: []))
    displayMessages()
}
}

class TAPPauseBlock: BaseTAPBlock {
override func process() {
    blockType = 0x20
    blockCounter += 1
    pause = fetchWord(byte: blockCounter)


    print ("Pause block imported of length \(blockLength)")
}
}
