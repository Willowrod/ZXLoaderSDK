# ZXLoaderSDK

A set of tools to read different ZX Spectrum compatable file formats.

Currently supported formats are:
- .sna (48k only)
- .z80
- .tzx (partial)

## How to use ZXLoaderSDK

ZXLoaderSDK can be imported into any Swift 5 codebase using Swift Package Manager.

```
    .package(url: "https://github.com/Willowrod/ZXLoaderSDK.git", .upToNextMinor(from: "0.2"))
```

## Using ZXLoaderSDK

Import ZXLoaderSDK at the top of the Swift file

```
    import ZXLoaderSDK
```

You currently need to unzip a compressed file before using ZXLoaderSDK - this will likely change in the future, but for now, a great unzipping library is https://github.com/marmelroy/Zip

## Importing .sna and .z80 files

The CPU of any emulator should be paused while the RAM is being updated!

### Accessing the memory dump

Once your file is unzipped, the file simply needs passing to the correct file format in ZXLoaderSDK (you should NOT include the file's .sna / .z80 extension)

.sna:
```
    let zxFile = SNAFormat(fileName: your_sna_file)
```

.z80
```
    let zxFile = Z80Format(fileName: your_z80_file)
```

zxFile.ramBanks should now contain the contents of the Spectrum's RAM - in an array of RAM banks - , which you can pass to your emulator / application

Each bank is a simple array of UInt8 objects that are stored exactly as they would be in the Spectrum's RAM

.sna files should only populate zxFile.ramBanks[0] - this is the complete memory dump of the loaded file

.z80 files have a convinience method to retrieve the correct structure of RAM banks for both 48k and 128k Spectrums.

```
    let banks = snapShot.retrieveRam()
```

If banks contains only 1 object, this indicates the .z80 file was a 48k file, the complete memory dump is in this object

If banks contains MORE than 1 object, this indicates that the .z80 file was a 128k file, and all 8 banks should be returned in the correct order

In no instance will the ROM be returned, so RAM should be placed from 0x4000 in the Spectrum's memory

### Accessing the Spectrum's 'state'

When a snapshot is taken of the Spectrum's RAM, extra data is also gathered (the current PC, stack, register and interupt values, etc). The information is packed into the snapshot file (both sna and z80) and must be extracted and restored on an emulator before resuming the CPU. 

zxFile.registers contains this information as detailed here:

```
public struct Z80RegisterSnapshot: Codable {
    // 8 Bit registers
    public var primary: Z80StandardRegisterBank = Z80StandardRegisterBank()
    
    // 8 Bit swap registers
    public var swap: Z80StandardRegisterBank = Z80StandardRegisterBank()
    
    // 8 Bit other registers
    public var registerI: UInt8 = 0
    public var registerR: UInt8 = 0
    
    // 16 Bit other registers
    public var registerIX: UInt16 = 0
    public var registerIY: UInt16 = 0
    // Stack pointer
    public var registerSP: UInt16 = 0
    // Program counter
    public var registerPC: UInt16 = 0
    // Interupt mode (0, 1 or 2)
    public var interuptMode: Int = 0
    // CPU is running an interupt currently
    public var interuptEnabled: Bool = false
    // Colour of the border at the time of the snapshot
    public var borderColour: UInt8 = 0
    // Current PC is at the top of the stack and the CPU should perform a 'RET' before continuing
    public var shouldReturn: Bool = false
    // 128k mode ram bank information
    public var ramBankSetting: UInt8 = 0
    // convenience method to return a register pair value
    public func registerPair(l: UInt8, h: UInt8) -> UInt16{
        return (UInt16(h) * 256) + UInt16(l)
    }

    public init() {
        
    }
}

public struct Z80StandardRegisterBank: Codable {
    public var registerA: UInt8 = 0
    public var registerB: UInt8 = 0
    public var registerC: UInt8 = 0
    public var registerD: UInt8 = 0
    public var registerE: UInt8 = 0
    public var registerH: UInt8 = 0
    public var registerL: UInt8 = 0
    public var registerF: UInt8 = 0
}
``` 

## Importing .tzx files.

TZX files are not snapshots of the RAM of a ZX Spectrum, they are, in fact, a data representation of a cassette tape's audio tracks with headers containing things like timing, pulse length, data and information, as such they cannot be simply condensed into an array of RamBanks.

ZXLoaderSDK effectively mimics a tape deck in this instance, and your emulator or application must listen to the input from the tape.

First you must 'insert' a tape into the sdk

```
    var tapePlayerState: TapePlayerState = .Empty // ZXLoaderSDK enum to track the current tape player 'state'
    var loadingTStates = 0 // We must keep track of the number of TStates since the last pulse. loadingTStates should be incremented at the end of each OPCode with the same value your normal T-State counter is
    var tape: TapeDelegate? = nil // Our currently inserted tape

...
// Create the 'tape' if the tzx file is stored in the source, you just need the file name, if the file is unzipped then you need the path is is unzipped to
    tape = TZXFormat.init(filename: your_tzx_file, path: path_to_tzx_file) 
// Set the delegate for the virtual tape player - required to update tapePlayerState - see 'TapeControlDelegate' below
    tape.setControlDelegate(del: data?.headerData.tapePlayerData)
// Reset loadingTStates - not totally necessary
    loadingTStates = 0
```

To read a TZX file, you should allow the Spectrum to LOAD the file as it would normally do on a real Spectrum (LOAD "")

For an emulator, for example, you must add logic to the Z80 CPU's 'IN' command so the LOAD "" command will act accordingly.

```
    func performInInternal(port: UInt8, map: UInt8, destination: selected_register){
        if (port == 0xfe){
            var byteVal: UInt8 = 0x1f
// Keyboard is generally handled here
            switch map{
// Update bits 0-4 with keyboard data
            }
// If we have set the tape to 'play' we should read it...
            if tapePlayerState == .Playing {
                readTape()
            }
// Write our updated byte to the selected_register
            updateIn(register: destination, value: byteVal)
        } else if port == 0x7f {
// Handle Fuller Joystick
        } else if port == 0x1f {
// Handle Kempston Joystick
        } else {
// Handle other inputs
        }
    }

    func readTape() {
// tape?.fetchData?.signal will return true or false (high or low pulse) if a valid signal is being returned or nil if there is no data to return (or all data has already been returned) 
        if let tapeData = tape?.fetchData(tState: loadingTStates){
// Set bit 6 of the input byte
            byteVal = byteVal.set(bit: 6, value: tapeData.signal)
// tapeData.reset signals the end of a block of data (generally the end of an audio signal)
            if tapeData.reset {
                loadingTStates = 0
            }
        } else {
// If there is no more data to load, we should 'eject' the tape and put the player into a paused state
            data?.headerData.tapePlayerData.tape = nil
            data?.headerData.tapePlayerData.tapePlayerState = .Paused
        }
    }
```

There are four methods that are available on an 'inserted' tape:

```
// Read from a tape
    func fetchData(tState: Int) -> (signal: Bool, reset: Bool)?
// Fully rewind the tape ready to play
    func startTape()
// Move to next data block (for multi-load tapes)
    func fastForward()
// Move to previous data block (for multi-load tapes)
    func rewind()
```

### TapeControlDelegate

The TapeControlDelegate is an optional delegate that is used to keep track of the currently playing tape. To conform to this protocol, the following methods must be implemented:

```
// Receive the current 'TapePlayerState' - This will not affect the playing tape at all, and is used to show changes to any virtual cassette UI
    func setTapeState(state: TapePlayerState)
// Receive the current data block's 'name' - each data block has a (non-unique) name to assist searching for tracks on multi game / multi load tapes - this method is used for updating the UI with this name
    func setCurrentBlock(name: String)
```

### TapePlayerState

The tape can be in any one of five states, represented by an enum:

```
public enum TapePlayerState {
    case Empty, Playing, Paused, Rewound, Ended
}
```

## Example of ZXLoaderSDK in use

The ZXLoaderSDK was created for use in 'Fake-A-Chip', a multi CPU 8 bit computer emulator / disassembler / assembler (in development). Currently the only available computers on this are the Spectrum 48k and the Spectrum 128k, both machines have a working implementation of a tape recorder using ZXLoaderSDK. The project can be found at https://github.com/Willowrod/FakeAChip

## Thanks

Most, if not all, useful information gathered for this project came from various websites, mostly no longer maintained, without which I could not have got as far as I have. These sites are listed below:

TZX file format:  
http://k1.spdns.de/Develop/Projects/zasm/Info/TZX%20format.html#:~:text=TZX%20is%20a%20file%20format,turbo%20or%20custom%20loading%20routines.&text=This%20file%20format%20is%20explicitly,ZX%20Spectrum%20compatible%20computers%20only.  
TAP file format (used as part of the TZX format)  
https://sinclair.wiki.zxnet.co.uk/wiki/TAP_format  
SNA file format  
https://sinclair.wiki.zxnet.co.uk/wiki/SNA_format  
Z80 file format  
https://worldofspectrum.org/faq/reference/z80format.htm  
