//
//  AppDelegate.swift
//  gSwitch
//
//  Created by Cody Schrank on 4/15/18.
//  Copyright © 2018 CodySchrank. All rights reserved.
//

/** gSwitch 1.9.7 */

import Cocoa
import ServiceManagement
//eaj import SwiftyBeaver
//eaj import Sparkle
//eaj import LaunchAtLogin


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    //eaj let log = SwiftyBeaver.self
    let manager = GPUManager()
    let listener = GPUListener()
    let processer = ProcessManager()
    let notifications = UserNotificationManager()
    
    //eaj var updater: SPUUpdater?
    //eaj var updaterDelegate: UpdaterDelegate?
    var statusMenu: StatusMenuController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        /** I like me dam logs! <-- get it, because beavers... its swiftybeaver... sorry */
        //eaj let console = ConsoleDestination()
        //eaj let file = FileDestination()
        //eaj log.addDestination(console)
        //eaj log.addDestination(file)
        NSLog("verbose: gSwitch") //eaj log.verbose("gSwitch \(Bundle.main.infoDictionary!["CFBundleShortVersionString"]!)")
        
        /** If we cant connect to gpu there is no point in continuing */
        do {
            try manager.connect()
        } catch RuntimeError.CanNotConnect(let errorMessage) {
            NSLog("error: %@",errorMessage) //eaj log.error(errorMessage)
            appFailure()
        } catch {
            NSLog("error: Unknown error occured") //eaj log.error("Unknown error occured")
            appFailure()
        }
        
        /** Default prefs so shit works */
        setupDefaultPreferences()
        
        /** Startup AutoLauncher */
        //eaj LaunchAtLogin.isEnabled = (UserDefaults.standard.integer(forKey: Constants.LAUNCH_AT_LOGIN) == 1)
        
        /** GPU Names are good */
        manager.setGPUNames()
        
        /** Lets listen to changes! */
        listener.listen(manager: manager, processor: processer)
        
        /** Gets the updates kicking */
        // setupUpdater()
        
        /** What did the beaver say to the tree?  It's been nice gnawing you. */
        deforestation()
        
        /** Was a mode passed in? (If there was, the last gpu state is overridden and not used) */
        var arg = false;
        for argument in CommandLine.arguments {
            switch argument {
            case "--integrated":
                arg = true;
                NSLog("debug: %@","Integrated passed in") //eaj log.debug("Integrated passed in")
                safeIntergratedOnly()
                break
                
            case "--discrete":
                arg = true;
                NSLog("debug: %@","Discrete passed in") //eaj log.debug("Discrete passed in")
                safeDiscreteOnly()
                break
                
            case "--dynamic":
                arg = true;
                NSLog("debug: %@","Dynamic passed in") //eaj log.debug("Dynamic passed in")
                safeDynamicSwitching()
                break
                
            default:
                break
            }
        }
        
        /** Lets set last state on startup if desired (and no arg) */
        if(!arg && UserDefaults.standard.bool(forKey: Constants.USE_LAST_STATE)) {
            switch UserDefaults.standard.integer(forKey: Constants.SAVED_GPU_STATE) {
            //Checking for dependencies could offer a better start up experience here
            case SwitcherMode.ForceDiscrete.rawValue:
                safeDiscreteOnly()
            case SwitcherMode.ForceIntergrated.rawValue:
                safeIntergratedOnly()
            case SwitcherMode.SetDynamic.rawValue:
                safeDynamicSwitching()
            default:
                break;
            }
        } else if(!arg) {
            if(manager.GPUMode(mode: .SetDynamic)) {
                NSLog("info: %@","No default state, Initially set as Dynamic") //eaj log.info("No default state, Initially set as Dynamic")
            }
        }
        
        /** Get current state so current gpu name exists for use in menu */
        _ = manager.CheckGPUStateAndisUsingIntegratedGPU()
        
        /** Are there any hungry processes off the bat?  Updates menu if so */
        processer.updateProcessMenuList()
        
        /** UserNotificationManager likes the manager too. Done last so that the currentGPU is updated and there are no unnessecary notifications on startup */
        notifications.inject(manager: manager)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        /** Clean up gpu change notifications */
        notifications.cleanUp()
        
        /** Lets go back to dynamic when exiting (but don't save it) */
        if(manager.GPUMode(mode: .SetDynamic)) {
            NSLog("info: %@","Set state to dynamic mode") //eaj log.info("Set state to dynamic mode")
        }
        
        _ = manager.close()
    }
    
    public func unsafeIntegratedOnly() {
        statusMenu?.changeGPUButtonToCorrectState(state: .ForceIntergrated)
        
        if(manager.GPUMode(mode: .ForceIntergrated)) {
            NSLog("info: %@","Set Force Integrated") //eaj log.info("Set Force Integrated")
        } else {
            // only fails at this point if already integrated (not really a failure)
            NSLog("warning: %@","Failed to force igpu (probably because already on igpu)") //eaj log.warning("Failed to force igpu (probably because already on igpu)")
        }
        
        UserDefaults.standard.set(SwitcherMode.ForceIntergrated.rawValue, forKey: Constants.SAVED_GPU_STATE)
    }
    
    public func unsafeDiscreteOnly() {
        statusMenu?.changeGPUButtonToCorrectState(state: .ForceDiscrete)
        
        if(manager.GPUMode(mode: .ForceDiscrete)) {
            NSLog("info: %@","Set Force Discrete") //eaj log.info("Set Force Discrete")
        } else {
            // hopefully impossible?
            NSLog("warning: %@","Failed to force Discrete") //eaj log.warning("Failed to force Discrete")
        }
        
        UserDefaults.standard.set(SwitcherMode.ForceDiscrete.rawValue, forKey: Constants.SAVED_GPU_STATE)
    }
    
    public func unsafeDynamicSwitching() {
        statusMenu?.changeGPUButtonToCorrectState(state: .SetDynamic)
        
        if(manager.GPUMode(mode: .SetDynamic)) {
            NSLog("info: %@","Set Dynamic Switching") //eaj log.info("Set Dynamic Switching")
        } else {
            // hopefully impossible?
            NSLog("warning: %@","Failed to set Dynamic Switching") //eaj log.warning("Failed to set Dynamic Switching")
        }
        
        UserDefaults.standard.set(SwitcherMode.SetDynamic.rawValue, forKey: Constants.SAVED_GPU_STATE)
    }
    
    public func safeIntergratedOnly() {
        if(manager.requestedMode == .ForceIntergrated) {
            NSLog("info: %@","Already Force Integrated") //eaj log.info("Already Force Integrated");
            return  //already set
        }
        
        /**
            Check for hungry processes because it could cause a crash
         */
        let hungryProcesses = processer.getHungryProcesses()
        if(hungryProcesses.count > 0 && UserDefaults.standard.integer(forKey: Constants.IGNORE_IGPU_CHANGE_WARNING) == 0) {
            NSLog("warning: %@","SHOW: Can't switch to integrated only, because of \(String(describing: hungryProcesses))") //eaj log.warning("SHOW: Can't switch to integrated only, because of \(String(describing: hungryProcesses))")
            
            let alert = NSAlert.init()
            
            alert.messageText = "Warning!  Are you sure you want to change to integrated only?"
            alert.informativeText = "You currently have GPU dependencies. Changing the mode now could cause these processes to crash.  If there is currently an external display plugged in you cannot change to integrated only."
            
            alert.addButton(withTitle: "Override Once").setAccessibilityFocused(true)
            alert.addButton(withTitle: "Always Override")
            alert.addButton(withTitle: "Never mind")
            
            let modalResult = alert.runModal()
            
            switch modalResult {
            case .alertFirstButtonReturn:
                NSLog("info: %@","Override once clicked!") //eaj log.info("Override once clicked!")
                unsafeIntegratedOnly();
            case .alertSecondButtonReturn:
                NSLog("info: %@","Override always clicked!") //eaj log.info("Override always clicked!")
                UserDefaults.standard.set(1, forKey: Constants.IGNORE_IGPU_CHANGE_WARNING)
                unsafeIntegratedOnly();
            default:
                break;
            }
        } else {
            unsafeIntegratedOnly();
        }
    }
    
    public func safeDiscreteOnly() {
        if(manager.requestedMode == .ForceDiscrete) {
            NSLog("info: %@","Already Force Discrete") //eaj log.info("Already Force Discrete");
            return  //already set
        }
        
        unsafeDiscreteOnly()
    }
    
    public func safeDynamicSwitching() {
        if(manager.requestedMode == .SetDynamic) {
            NSLog("info: %@","Already Dynamic") //eaj log.info("Already Dynamic");
            return  //already set
        }
        
        unsafeDynamicSwitching()
    }

    public func setupDefaultPreferences() {
        UserDefaults.standard.register(defaults: [Constants.LAUNCH_AT_LOGIN : true])
        UserDefaults.standard.register(defaults: [Constants.USE_LAST_STATE: true])
        UserDefaults.standard.register(defaults: [Constants.IGNORE_IGPU_CHANGE_WARNING: false])
        UserDefaults.standard.register(defaults: [Constants.GPU_CHANGE_NOTIFICATIONS : false])
        UserDefaults.standard.register(defaults: [Constants.SAVED_GPU_STATE: SwitcherMode.SetDynamic.rawValue])
    }
    
    public func checkForUpdates() {
        //eaj updater?.checkForUpdates()
    }
    
    /*
    private func setupUpdater() {
        let hostBundle = Bundle.main
        let applicationBundle = hostBundle
        var userDriver: SPUStandardUserDriverProtocol?
        userDriver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: nil)
        
        updaterDelegate = UpdaterDelegate()
        
        updater = SPUUpdater(hostBundle: hostBundle, applicationBundle: applicationBundle, userDriver: userDriver as! SPUUserDriver, delegate: updaterDelegate)
        
        do {
            try updater?.start()
            
            NSLog("info: %@","Updater setup") //eaj log.info("Updater setup")
        } catch {
            NSLog("error: %@",error.localizedDescription) //eaj log.error(error)
        }
    }
    */
    
    /**
        Just Logging
    */
    private func deforestation() {
        NSLog("verbose: %@","Launch at Login set as \(UserDefaults.standard.integer(forKey: Constants.LAUNCH_AT_LOGIN) == 1)") //eaj log.verbose("Launch at Login set as \(UserDefaults.standard.integer(forKey: Constants.LAUNCH_AT_LOGIN) == 1)")
        
        //eaj log.verbose("Automatically update set as \(updater?.automaticallyChecksForUpdates ?? false)")
        
        NSLog("verbose: %@","GPU Change notifications set as \(UserDefaults.standard.integer(forKey: Constants.GPU_CHANGE_NOTIFICATIONS) == 1)") //eaj log.verbose("GPU Change notifications set as \(UserDefaults.standard.integer(forKey: Constants.GPU_CHANGE_NOTIFICATIONS) == 1)")
        
        NSLog("verbose: %@","Use Last State set as \(UserDefaults.standard.integer(forKey: Constants.USE_LAST_STATE) == 1)") //eaj log.verbose("Use Last State set as \(UserDefaults.standard.integer(forKey: Constants.USE_LAST_STATE) == 1)")
        
        NSLog("verbose: %@","Ignore IGPU Warning set as \(UserDefaults.standard.integer(forKey: Constants.IGNORE_IGPU_CHANGE_WARNING) == 1)") //eaj log.verbose("Ignore IGPU Warning set as \(UserDefaults.standard.integer(forKey: Constants.IGNORE_IGPU_CHANGE_WARNING) == 1)")
        
        NSLog("verbose: %@","Saved GPU State set as \(UserDefaults.standard.integer(forKey: Constants.SAVED_GPU_STATE)) (\(SwitcherMode(rawValue: UserDefaults.standard.integer(forKey: Constants.SAVED_GPU_STATE))!))") //eaj log.verbose("Saved GPU State set as \(UserDefaults.standard.integer(forKey: Constants.SAVED_GPU_STATE)) (\(SwitcherMode(rawValue: UserDefaults.standard.integer(forKey: Constants.SAVED_GPU_STATE))!))")
    }
    
    
    /** Warning for not finding multiple gpus */
    private func appFailure() {
        let alert = NSAlert.init()
        
        alert.messageText = "Error!  Failed to find multiple GPUs"
        alert.informativeText = "There are a few reasons this could have happened, but the most likely is that your hardware is not supported at this time.  Please notify us on the gSwitch issue page on github about your current setup and we will let you know why this happened!"
        
        alert.addButton(withTitle: "Quit").setAccessibilityFocused(true)
        alert.addButton(withTitle: "Continue Anyway (App will not function properly)")
        
        let modalResult = alert.runModal()
        
        switch modalResult {
        case .alertFirstButtonReturn:
            NSApplication.shared.terminate(self)
            break;
        default:
            break;
        }
    }
}
