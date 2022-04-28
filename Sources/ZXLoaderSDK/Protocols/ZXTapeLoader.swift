//
//  ZXTapeLoader.swift
//  FakeAChip
//
//  Created by Mike Hall on 05/05/2021.
//

import Foundation



public protocol TapeDelegate {
    func fetchData(tState: Int) -> (signal: Bool, reset: Bool)?
    func startTape()
    func fastForward()
    func rewind()
}

public protocol TapeControlDelegate {
    func setTapeState(state: TapePlayerState)
    func setCurrentBlock(name: String)
}

public enum TapePlayerState {
    case Empty, Playing, Paused, Rewound, Ended
}
