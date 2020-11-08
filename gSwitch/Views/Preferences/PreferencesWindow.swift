//
//  PreferencesWindow.swift
//  gSwitch
//
//  Created by Cody Schrank on 4/18/18.
//  Copyright © 2018 CodySchrank. All rights reserved.
//

import Cocoa
//eaj import LaunchAtLogin

class PreferencesWindow: BossyWindow {
    @IBOutlet weak var toggleOpenAppLogin: NSButton!
    
    @IBOutlet weak var toggleGPUChangeNotifications: NSButton!
    
    @IBOutlet weak var useLastState: NSButton!
    
    @IBOutlet weak var automaticallyUpdate: NSButton!
    
    @IBOutlet weak var ignoreIGPUChangeWarning: NSButton!
    
    private var advancedWindow: AdvancedWindow!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(_updatePreferencesState(notification:)), name: .checkForHungryProcesses, object: nil)
        
        advancedWindow = AdvancedWindow(windowNibName: "AdvancedWindow")
        
        NSLog("info: %@","Preferences Opened") //eaj log.info("Preferences Opened")
        
        updatePreferencesList();
    }
    
    @IBAction func gpuChangeNotificationsPressed(_ sender: NSButton) {
        let status = sender.state.rawValue
        
        NSLog("info: %@","Successfully set gpuChangeNotifications item to be \(status == 1)") //eaj log.info("Successfully set gpuChangeNotifications item to be \(status == 1)")
        UserDefaults.standard.set(status, forKey: Constants.GPU_CHANGE_NOTIFICATIONS)
    }
    
    @IBAction func loginItemPressed(_ sender: NSButton) {
        if toggleOpenAppLogin.state.rawValue == 1 {
            NSLog("info: %@","Successfully set LAUNCH_AT_LOGIN to be true") //eaj log.info("Successfully set LAUNCH_AT_LOGIN to be true")
            UserDefaults.standard.set(1, forKey: Constants.LAUNCH_AT_LOGIN)
            //eaj LaunchAtLogin.isEnabled = true;
        }
        else {
            NSLog("info: %@","Successfully set LAUNCH_AT_LOGIN to be false") //eaj log.info("Successfully set LAUNCH_AT_LOGIN to be false")
            UserDefaults.standard.set(0, forKey: Constants.LAUNCH_AT_LOGIN)
            //eaj LaunchAtLogin.isEnabled = false;
        }
        
    }
    
    @IBAction func automaticallyUpdateClicked(_ sender: NSButton) {
        let status = sender.state.rawValue
        
        NSLog("info: %@","Successfully set automatically update to be \(status == 1)") //eaj log.info("Successfully set automatically update to be \(status == 1)")
        //eaj appDelegate.updater?.automaticallyChecksForUpdates = (status == 1);
    }
    
    @IBAction func useLastStateClicked(_ sender: NSButton) {
        let status = sender.state.rawValue
        
        NSLog("info: %@","Successfully set useLastState item to be \(status == 1)") //eaj log.info("Successfully set useLastState item to be \(status == 1)")
        UserDefaults.standard.set(status, forKey: Constants.USE_LAST_STATE)
    }
    
    @IBAction func ignoreIGPUChangeWarningClicked(_ sender: NSButton) {
        let status = sender.state.rawValue
        
        NSLog("info: %@","Successfully set IGNORE_IGPU_CHANGE_WARNING item to be \(status == 1)") //eaj log.info("Successfully set IGNORE_IGPU_CHANGE_WARNING item to be \(status == 1)")
        UserDefaults.standard.set(status, forKey: Constants.IGNORE_IGPU_CHANGE_WARNING)
    }
    
    @IBAction func checkForUpdatesClicked(_ sender: NSButton) {
        appDelegate.checkForUpdates()
        NSLog("info: %@","Checking for updates..") //eaj log.info("Checking for updates..")
        self.window?.close()
    }
    
    @IBAction func openAdvancedPaneClicked(_ sender: NSButton) {
        advancedWindow.showWindow(nil)
        advancedWindow.pushToFront()
        self.close()
    }
    
    public func updatePreferencesList() {
        toggleOpenAppLogin.state = NSControl.StateValue(rawValue: UserDefaults.standard.integer(forKey: Constants.LAUNCH_AT_LOGIN))
        
        automaticallyUpdate.state = NSControl.StateValue(rawValue: 0) //eaj automaticallyUpdate.state = NSControl.StateValue(rawValue: (appDelegate.updater?.automaticallyChecksForUpdates)! ? 1 : 0)
        
        useLastState.state = NSControl.StateValue(rawValue: UserDefaults.standard.integer(forKey: Constants.USE_LAST_STATE))
        
        toggleGPUChangeNotifications.state = NSControl.StateValue(rawValue: UserDefaults.standard.integer(forKey: Constants.GPU_CHANGE_NOTIFICATIONS))
        
        ignoreIGPUChangeWarning.state = NSControl.StateValue(rawValue: UserDefaults.standard.integer(forKey: Constants.IGNORE_IGPU_CHANGE_WARNING))
    }
    
    @objc private func _updatePreferencesState(notification: NSNotification) {
        self.updatePreferencesList();
    }
}
