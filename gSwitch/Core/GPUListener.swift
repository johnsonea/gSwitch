//
//  GPUListener.swift
//  gSwitch
//
//  Created by Cody Schrank on 4/15/18.
//  Copyright © 2018 CodySchrank. All rights reserved.
//


import Foundation
import CoreGraphics
//eaj import SwiftyBeaver

class GPUListener {
    // private let log = SwiftyBeaver.self
    
    private var notificationQueue: DispatchQueue?
    private var _manager: GPUManager?
    private var _processor: ProcessManager?
    
    init() {
        self.notificationQueue = DispatchQueue.init(label: Constants.NOTIFICATION_QUEUE)
    }
    
    public func listen(manager: GPUManager, processor: ProcessManager) {
        self._manager = manager
        self._processor = processor
        displayCallback()
        NSLog("info: Listening") //eaj log.info("Listening")
    }
    
    private func displayCallback() {
        let callback: @convention(c) (_ display: UInt32, _ flags: CGDisplayChangeSummaryFlags, _ data: UnsafeMutableRawPointer?) -> Void = {
            (display, flags, data) -> Void in
            
            let this = unsafeBitCast(data, to: GPUListener.self)
            
            NSLog("info: NOTIFY: checkForHungryProcesses ~ for menu update") //eaj this.log.info("NOTIFY: checkForHungryProcesses ~ for menu update")
            NotificationCenter.default.post(name: .checkForHungryProcesses, object: nil)
        
            if(this._manager!.CheckGPUStateAndisUsingIntegratedGPU() && this._manager!.requestedMode == SwitcherMode.ForceIntergrated) {
                // calls .checkGPUState
                NSLog("info: Switched from desired integrated to discrete") //eaj this.log.info("Switched from desired integrated to discrete")
            }
            
            
            if Int(flags.rawValue) & Constants.kCGDisplaySetModeFlag > 0 {
                /**
                    Hungry apps usually call the gpu when they start and when they exit
                    If a user is on integrated only this forces it back from discrete.
                 */
                
                NSLog("info: Dedicated Graphics Card Called") //eaj this.log.info("Dedicated Graphics Card Called")
                _ = this._processor?.getHungryProcesses()

                this.notificationQueue?.async(execute: {
                    //let gpu change
                    sleep(1)
                    
                    // calls .checkGPUState
                    
                    let isUsingIntegrated = this._manager!.CheckGPUStateAndisUsingIntegratedGPU()
                    let requestedMode = this._manager!.requestedMode

                    if(!isUsingIntegrated && requestedMode == SwitcherMode.ForceIntergrated) {
                        if(this._manager!.GPUMode(mode: .ForceIntergrated)) {
                            NSLog("info: Forced integrated GPU From dedicated GPU") //eaj this.log.info("Forced integrated GPU From dedicated GPU")
                        }
                    } else {
                        // usually gets called when change but sometimes gets called when no change?
                        NSLog("info: NOTIFY: GPU maybe Changed") //eaj this.log.verbose("NOTIFY: GPU maybe Changed")
                        NotificationCenter.default.post(name: .probableGPUChange, object: this._manager?.currentGPU)
                    }
                })
            }
            
            if Int(flags.rawValue) & Constants.kCGDisplayRemoveFlag > 0 {
                /**
                    usually gets called when switched.
                 */
            }
        }
        
        
        CGDisplayRegisterReconfigurationCallback(callback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
    }
    
}
