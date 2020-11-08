//
//  AdvancedWindow.swift
//  gSwitch
//
//  Created by Cody Schrank on 6/6/18.
//  Copyright © 2018 CodySchrank. All rights reserved.
//

import Cocoa

class AdvancedWindow: BossyWindow {
    
    @IBOutlet weak var getGPUStateState: NSTextField!

    @IBOutlet weak var setGPUStateState: NSTextField!
    
    @IBOutlet weak var setGPUStateArg: NSTextField!
    
    @IBOutlet weak var setGPUFeatureBool: NSTextField!
    
    @IBOutlet weak var setGPUFeatureFeature: NSTextField!
    
    let alert = NSAlert.init()
    
    private var helpWindow: HelpWindow!

    override func windowDidLoad() {
        super.windowDidLoad()
        
        helpWindow = HelpWindow(windowNibName: "HelpWindow")
        
        alert.addButton(withTitle: "OK")
        
        let numberOnlyFormatter = OnlyIntegerValueFormatter()
        getGPUStateState.formatter = numberOnlyFormatter
        setGPUStateState.formatter = numberOnlyFormatter
        setGPUStateArg.formatter = numberOnlyFormatter
        
        NSLog("info: %@","Advanced was opened") //eaj log.info("Advanced was opened")
    }
    
    @IBAction func unsafeIntegratedOnlyClicked(_ sender: NSButton) {
        NSLog("info: %@","Unsafe Integrated Only clicked") //eaj log.info("Unsafe Integrated Only clicked")
        appDelegate.unsafeIntegratedOnly()
    }
    
    @IBAction func unsafeDiscreteOnlyClicked(_ sender: NSButton) {
        NSLog("info: %@","Unsafe Discrete Only clicked") //eaj log.info("Unsafe Discrete Only clicked")
        appDelegate.unsafeDiscreteOnly()
    }
    
    @IBAction func unsafeDynamicSwitchingClicked(_ sender: NSButton) {
        NSLog("info: %@","Unsafe Dynamic Switching clicked") //eaj log.info("Unsafe Dynamic Switching clicked")
        appDelegate.unsafeDynamicSwitching()
    }
    
    @IBAction func getGPUStateCheckClicked(_ sender: NSButton) {
        let state = appDelegate.manager.getGPUState(input: GPUState(rawValue: Int(getGPUStateState.intValue))!)
        let message = String(state) + " (0x" + String(format:"%2X", state) + ")"  //decimal and hex
        
        alert.messageText = message
        alert.runModal()
    }
    
    @IBAction func getGPUStateHelpClicked(_ sender: NSButton) {
        let message = """
            These are tested values
            
            0: DisableFeatureORFeatureInfo
            returns a uint64_t with bits set according to FeatureInfos, 1=enabled
            
            1: EnableFeatureORFeatureInfo2
            same as FeatureInfo
        
            2: ForceSwitch
            always returns 0xdeadbeef
            
            3: PowerGPU
            returns powered on graphics cards, 0x8 = integrated, 0x88 = discrete
            
            4: GpuSelect
            Dynamic Switching on/off
            
            5: SwitchPolicy
            possibly inverted?
            
            6: Unknown
            always 0xdeadbeef
            
            7: GraphicsCard
            returns active graphics card
            
            8: Unknown2
            sometimes 0xffffffff
        """
        
        helpWindow.showWindow(nil)
        helpWindow.helpText.stringValue = message
        helpWindow.pushToFront()
    }
    
    @IBAction func setGPUStateCheckClicked(_ sender: NSButton) {
        let state = setGPUStateState.intValue
        let arg = setGPUStateArg.intValue
        
        let success = appDelegate.manager.setGPUState(state: GPUState(rawValue: Int(state))!, arg: UInt64(arg))
        
        let message = success ? "Successfully set state: \(state) and arg: \(arg)" : "Did not set state: \(state) and arg: \(arg)"
        
        alert.messageText = message
        alert.runModal()
    }
    
    @IBAction func setGPUStateHelpClicked(_ sender: NSButton) {
        let message = """
            These are tested state and arg values
            
            2: ForceSwitch
            force Graphics Switch regardless of arg
            
            3: PowerGPU
            power down a gpu, arg unknown
            
            4: GpuSelect
            Dynamic Switching on/off
            (arg = 0: instant switching, arg = 2: user needs to logout before switching)
            
            5: SwitchPolicy
            arg = 0: dynamic switching,
            arg = 2: no dynamic switching (legacy computers)
            arg = 3: no dynamic stuck, others unsupported
        """
        
        helpWindow.showWindow(nil)
        helpWindow.helpText.stringValue = message
        helpWindow.pushToFront()
    }
    
    @IBAction func dumpStateClicked(_ sender: NSButton) {
        let state = appDelegate.manager.dumpState()
        
        let message = state.field.map { String($0) }
        
        alert.messageText = message.description
        alert.runModal()
    }
    
    @IBAction func setGPUFeatureHelpClicked(_ sender: NSButton) {
        let message = """
            Tested Features

            Policy = 0,
            Auto_PowerDown_GPU = 1,
            Dynamic_Switching = 2,
            GPU_Powerpolling = 3 (Inverted),
            Defer_Policy = 4,
            Synchronous_Launch = 5,
            Backlight_Control = 8,
            Recovery_Timeouts = 9,
            Power_Switch_Debounce = 10,
            Logging = 16,
            Display_Capture_Switch = 17,
            No_GL_HDA_busy_idle_registration = 18,
            muxFeaturesCount = 19
        """
        
        helpWindow.showWindow(nil)
        helpWindow.helpText.stringValue = message
        helpWindow.pushToFront()
    }
    
    
    @IBAction func setGPUFeatureRunClicked(_ sender: NSButton) {
        let boolean = setGPUFeatureBool.intValue == 1
        let feature = setGPUStateArg.intValue
        
        let success = appDelegate.manager
            .setFeatureInfo(feature: Features(rawValue: Int(feature))!, enabled: boolean)

        let message = success ? "Successfully set feature: \(Features(rawValue: Int(feature))!) to \(boolean)" : "Did not set feature: \(Features(rawValue: Int(feature))!) to \(boolean)"

        alert.messageText = message
        alert.runModal()
    }
}































