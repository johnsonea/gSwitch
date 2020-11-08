//
//  StatusMenuController.swift
//  gSwitch
//
//  Created by Cody Schrank on 4/15/18.
//  Copyright © 2018 CodySchrank. All rights reserved.
//

import Cocoa
//eaj import SwiftyBeaver

class StatusMenuController: NSViewController {
    @IBOutlet weak var statusMenu: NSMenu!
    
    @IBOutlet weak var IntegratedOnlyItem: NSMenuItem!
    
    @IBOutlet weak var GPUViewLabel: NSMenuItem!
    
    @IBOutlet weak var Dependencies: NSMenuItem!
    
    @IBOutlet weak var DiscreteOnlyItem: NSMenuItem!
    
    @IBOutlet weak var DynamicSwitchingItem: NSMenuItem!
    
    @IBOutlet weak var CurrentGPU: NSMenuItem!
    
    @IBOutlet weak var GPUViewController: GPUView!
    
    private var preferencesWindow: PreferencesWindow!
    private var aboutWindow: AboutWindow!
    
    //eaj private let log = SwiftyBeaver.self
    
    private var modeWasForcedFromDisplay = false;
    
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    weak private var appDelegate: AppDelegate?
    
    override func awakeFromNib() {
        appDelegate = (NSApplication.shared.delegate as! AppDelegate)
        
        appDelegate?.statusMenu = self
        
        statusItem.menu = statusMenu
        GPUViewLabel.view = GPUViewController  // hidden view
        
        preferencesWindow = PreferencesWindow(windowNibName: "PreferencesWindow")
        
        aboutWindow = AboutWindow(windowNibName: "AboutWindow")
        
        CurrentGPU.title = "GPU: \(appDelegate?.manager.currentGPU ?? "Unknown")"
        
        self.changeMenuIcon(currentGPU: .Integrated) // set default menu icon
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeGPUNameInMenu(notification:)), name: .checkGPUState, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateProcessList(notification:)), name: .updateProcessListInMenu, object: nil)
    }
    
    @IBAction func helpClicked(_ sender: NSMenuItem) {
        if let url = URL(string: Constants.HELP_URL), NSWorkspace.shared.open(url) {
            NSLog("info: %@","Opened help") //eaj log.info("Opened help")
        }
    }
    
    @IBAction func preferencesClicked(_ sender: NSMenuItem) {
        preferencesWindow.showWindow(nil)
        preferencesWindow.pushToFront()
    }
    
    @IBAction func aboutClicked(_ sender: NSMenuItem) {
        aboutWindow.showWindow(nil)
        aboutWindow.pushToFront()
    }
    
    @IBAction func intergratedOnlyClicked(_ sender: NSMenuItem) {
        appDelegate?.safeIntergratedOnly()
    }
    
    @IBAction func discreteOnlyClicked(_ sender: NSMenuItem) {
        appDelegate?.safeDiscreteOnly()
    }
    
    @IBAction func dynamicSwitchingClicked(_ sender: NSMenuItem) {
        appDelegate?.safeDynamicSwitching()
    }
    
    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
    
    public func changeGPUButtonToCorrectState(state: SwitcherMode) {
        switch state {
        case .ForceIntergrated:
            IntegratedOnlyItem.state = .on
            DynamicSwitchingItem.state = .off
            DiscreteOnlyItem.state = .off
            
        case .SetDynamic:
            IntegratedOnlyItem.state = .off
            DynamicSwitchingItem.state = .on
            DiscreteOnlyItem.state = .off
            
        case .ForceDiscrete:
            IntegratedOnlyItem.state = .off
            DynamicSwitchingItem.state = .off
            DiscreteOnlyItem.state = .on
        }
    }
    
    /**
        shows the current active gpu
    */
    private func changeMenuIcon(currentGPU: GPU_INT) {
        let icon: NSImage?
        
        switch currentGPU {
        case .Integrated:
            icon = NSImage(named: "ic_brightness_low")
        case .Discrete:
            icon = NSImage(named: "ic_brightness_high")
        }

        icon?.isTemplate = true // best for dark mode
        statusItem.button?.image = icon
    }
    
    @objc private func changeGPUNameInMenu(notification: NSNotification) {
        // this function always gets called from a non-main thread
        DispatchQueue.main.async {
            guard let gpu = notification.object as? GPU_INT else {
                NSLog("warning: %@","Failed to convert to GPU object") //eaj self.log.warning("Failed to convert to GPU object")
                return
            }
            
            guard let currentGPU = self.appDelegate?.manager.resolveGPUName(gpu: gpu) else {
                NSLog("warning: %@","Can't change gpu name in menu, Current GPU Unknown") //eaj self.log.warning("Can't change gpu name in menu, Current GPU Unknown")
                return
            }
            
            /** Update the menu icon and text in dropdown */
            self.changeMenuIcon(currentGPU: gpu)
            
            self.CurrentGPU.title = "GPU: \(currentGPU)"

        }
    }
    
    @objc private func updateProcessList(notification: NSNotification) {
        guard var hungry = notification.object as? [Process] else {
            NSLog("warning: %@","Could not update process list, invalid object received") //eaj log.warning("Could not update process list, invalid object received")
            return
        }
        
        // get rid of old dependencies
        for item in statusMenu.items {
            if item.tag == Constants.STATUS_MENU_DEPENDENCY_TAG {
                statusMenu.removeItem(item)
            }
        }
        
        if(modeWasForcedFromDisplay) {
            NSLog("warning: %@","Mode was forced from external display.  Going back to integrated only when the display is disconnected") //eaj log.warning("Mode was forced from external display.  Going back to integrated only when the display is disconnected")
        }
        
        var isDisplayConnected = false;
        
        for process in hungry {
            if process.name.contains("External Display") {
                isDisplayConnected = true;
                
                if appDelegate?.manager.requestedMode == SwitcherMode.ForceIntergrated {
                    if (appDelegate?.manager.GPUMode(mode: SwitcherMode.SetDynamic))! {
                        NSLog("warning: %@","External display connected, going back to dynamic") //eaj log.warning("External display connected, going back to dynamic")
                        modeWasForcedFromDisplay = true;
                        
                        NotificationCenter.default.post(name: .externalDisplayConnect, object: nil)
                        
                        changeGPUButtonToCorrectState(state: .SetDynamic)
                        return
                    }
                }
            }
        }
        
        if(modeWasForcedFromDisplay && !isDisplayConnected) {
            modeWasForcedFromDisplay = false;
            appDelegate?.safeIntergratedOnly()
        }
        
        if hungry.count > 0 {
            Dependencies.isHidden = false
            
            if appDelegate?.manager.requestedMode == SwitcherMode.ForceIntergrated {
                Dependencies.title = "Hungry"
            } else {
                Dependencies.title = "Dependencies"
            }
            
            hungry.reverse() // because of insert
            
            let seperator = NSMenuItem.separator()
            seperator.tag = Constants.STATUS_MENU_DEPENDENCY_TAG
            statusMenu.insertItem(seperator, at: Constants.STATUS_MENU_DEPENDENCY_APPEND_INDEX)
            
            for process in hungry {
                var title = "\t\(process.name)"
                if process.pid != "" {
                    title += " (\(process.pid))"
                }
                let newDependency = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                newDependency.isEnabled = false
                newDependency.tag = Constants.STATUS_MENU_DEPENDENCY_TAG
                statusMenu.insertItem(newDependency, at: Constants.STATUS_MENU_DEPENDENCY_APPEND_INDEX + 2)
            }
            
        } else {
            Dependencies.isHidden = true
            
            Dependencies.title = "Dependencies"
        }
    }
}
