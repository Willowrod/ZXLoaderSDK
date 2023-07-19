//
//  TXZFormat.swift
//  inSpeccytor
//
//  Created by Mike Hall on 07/01/2021.
//

import Foundation

public class TZXFormat: BaseTapeFileFormat  {
    
    

    public init(filename: String, path: String?, loggingDelegate: TapeLoggingDelegate?) {
        super.init()
        self.loggingDelegate = loggingDelegate
        var tzxBytes: Data? = nil
        if let filePath = path, filePath.count > 0 {
            var file = "\(filePath)/\(filename)"
            if !file.hasSuffix(".tzx") {
                file = "\(file).tzx"
            }
            if let contents = NSData(contentsOfFile: file) {
                tzxBytes = contents as Data
            }
        } else if let filePath = Bundle.main.path(forResource: filename.replacingOccurrences(of: ".tzx", with: ""), ofType: "tzx"){
            let contents = NSData(contentsOfFile: filePath)
            tzxBytes = contents! as Data
        } else {
            print("file not found")
        }
        if let tzxStream = tzxBytes?.hexString?.splitToBytes(separator: " "){
            tzxStream.forEach{byte in
                tapeData.append(UInt8(byte, radix: 16) ?? 0x00)
            }
        process()
        }
    }

    public init(path: String, loggingDelegate: TapeLoggingDelegate?) {
        super.init()
        self.loggingDelegate = loggingDelegate
        var tzxBytes: Data? = nil
            var file = path
            if !file.hasSuffix(".tzx") {
                file = "\(file).tzx"
            }
            if let contents = NSData(contentsOfFile: file) {
                tzxBytes = contents as Data
            }

        if let tzxStream = tzxBytes?.hexString?.splitToBytes(separator: " "){
            tzxStream.forEach{byte in
                tapeData.append(UInt8(byte, radix: 16) ?? 0x00)
            }
        process()
        }
    }

    public init(data: Data, loggingDelegate: TapeLoggingDelegate?) {
        super.init()
        self.loggingDelegate = loggingDelegate
        if let tzxBytes = data.hexString?.splitToBytes(separator: " "){
            tzxBytes.forEach{byte in
                tapeData.append(UInt8(byte, radix: 16) ?? 0x00)
            }
        process()
        }
    }
    
    public init(data: [UInt8], loggingDelegate: TapeLoggingDelegate?) {
        super.init()
        self.loggingDelegate = loggingDelegate
        tapeData = data
        process()
    }
    
    public init(data: String?, loggingDelegate: TapeLoggingDelegate?) {
       super.init()
        self.loggingDelegate = loggingDelegate
        if let tzxBytes = data?.splitToBytes(separator: " "){
            tzxBytes.forEach{byte in
                tapeData.append(UInt8(byte, radix: 16) ?? 0x00)
            }
        process()
        }
    }
    
    func process(){
        processing = true
        while currentByte < tapeData.count && processing {
        readBlock(fromByte: currentByte)
        }
        loggingDelegate?.log("TZX file imported")
        currentBlock = 0
        dataBlocks.removeAll()
        blocks.forEach {block in
            if block.isCodeBlock {
                dataBlocks.append(block)
            }
        }
    }
    
    func readBlock(fromByte: Int){
        if (fromByte < tapeData.count){
            loggingDelegate?.log("Block starts \(fromByte)")
            var addLength = true
            if fromByte == 0 {
                // read header - Header should be 10 byters long and start with 'ZXTape!' followed by 0x1A
                // Byte 0x08 if the major version of the TZX file and 0x09 is the minor version
                if tapeData[0x00...0x07] == [0x5A, 0x58, 0x54, 0x61, 0x70, 0x65, 0x21, 0x1A] {
                    blocks.append(TZXHeaderBlock.init(data: tapeData[0x00...0x09], order: currentBlock, delegate: loggingDelegate))
                } else {
                    processing = false
                    loggingDelegate?.log("Not a valid TZX file")
                }
            } else {
                let id = tapeData[fromByte]
                loggingDelegate?.log("Current block starts: \(fromByte)")
                switch (id){
                
                case 0x10:
                    blocks.append(StandardSpeedBlock.init(data: tapeData[fromByte...], order: currentBlock, delegate: loggingDelegate))
                case 0x11:
                    blocks.append(TZXTurboSpeedBlock.init(data: tapeData[fromByte...], order: currentBlock, delegate: loggingDelegate))
                case 0x13:
                    blocks.append(TZXPulseSequenceBlock.init(data: tapeData[fromByte...], order: currentBlock, delegate: loggingDelegate))
                case 0x14:
                    blocks.append(TZXPureDataBlock.init(data: tapeData[fromByte...], order: currentBlock, delegate: loggingDelegate))
                case 0x20:
                    blocks.append(TZXPauseBlock.init(data: tapeData[fromByte...], order: currentBlock, delegate: loggingDelegate))
                case 0x21:
                    blocks.append(TZXGroupStartBlock.init(data: tapeData[fromByte...], order: currentBlock, delegate: loggingDelegate))
                case 0x22:
                    blocks.append(TZXGroupEndBlock.init(data: tapeData[fromByte...], order: currentBlock, delegate: loggingDelegate))
                case 0x24:
                    currentBlockRepeats = Int(fetchWord(byte: fromByte))
                    loggingDelegate?.log("Block repeats: \(currentBlockRepeats)")
                    currentByte += 2
                case 0x25:
                    currentBlockRepeats = 0
                case 0x30:
                    blocks.append(TZXTextDescriptionBlock.init(data: tapeData[fromByte...], order: currentBlock, delegate: loggingDelegate))
                case 0x31:
                    blocks.append(TZXTextMessageBlock.init(data: tapeData[fromByte...], order: currentBlock, delegate: loggingDelegate))
                case 0x32:
                    blocks.append(TZXTextArchiveBlock.init(data: tapeData[fromByte...], order: currentBlock, delegate: loggingDelegate))
                
                default:
                    let length = fetchWord(byte: fromByte + 1)
                    loggingDelegate?.log("Cannot import block type \(id.hex()) of length \(length)")
                    addLength = false
                    currentByte += 3
                    currentByte += Int(length)
                }
            }
            if addLength {
            currentByte += Int(blocks.last?.blockLength ?? 0) + Int(blocks.last?.blockCounter ?? 0)
            }
        } else {
            loggingDelegate?.log("End of file reached or block out of scope")
        }
        currentBlock += 1
    }
}

