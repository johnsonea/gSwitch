//
//  GPUView.swift
//  gSwitch
//
//  Created by Cody Schrank on 4/18/18.
//  Copyright © 2018 CodySchrank. All rights reserved.
//

import Cocoa
//eaj import SwiftyBeaver

class GPUView: NSView {

    /**  We use a hidden view to poll for hungry processes or possibly other information like vram */
    
    //eaj private let log = SwiftyBeaver.self
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override func viewWillDraw() {
        NSLog("info: %@","Menu was opened") //eaj log.info("Menu was opened")
        NotificationCenter.default.post(name: .checkForHungryProcesses, object: nil)
    }
    
    override func discardCursorRects() {
        NSLog("info: %@","Menu was closed") //eaj log.info("Menu was closed")
    }


}
