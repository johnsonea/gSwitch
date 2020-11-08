//
//  GPUManager.swift
//  gSwitch
//
//  Created by Cody Schrank on 4/14/18.
//  Copyright © 2018 CodySchrank. All rights reserved.
//
//  some logic is from gfxCardStatus
//  https://github.com/codykrieger/gfxCardStatus/blob/master/LICENSE @ Jun 17, 2012
//  Copyright (c) 2010-2012, Cody Krieger
//  All rights reserved.
//

import Foundation
import IOKit
//eaj import SwiftyBeaver

class GPUManager {
    //eaj private let log = SwiftyBeaver.self
    
    public var integratedName: String?
    public var discreteName: String?
    public var currentGPU: String?
    public var requestedMode: SwitcherMode?
    
    private var _connect: io_connect_t = IO_OBJECT_NULL;
    
    public func setGPUNames() {
        let gpus = getGpuNames()
        /**
         This only works if there are exactly 2 gpus
         and the integrated one is intel and the discrete
         one is not intel (AMD or NVIDIA).  The exception
         being the legacy machines that both used NVIDIA
         cards which is handled
         
         If apple changes the status quo this will break
         */
        
        let legacy = gpus.any(Constants.LEGACY)
        
        for gpu in gpus { 
            if legacy {
                if gpu.any(Constants.LEGACY) {
                    self.discreteName = gpu
                } else {
                    self.integratedName = gpu
                }
            } else {
                if gpu.contains(Constants.INTEL_GPU_PREFIX) {
                    self.integratedName = gpu
                } else {
                    self.discreteName = gpu
                }
            }
        }
        
        NSLog("verbose: %@","Integrated: \(integratedName ?? "Unknown")") //eaj log.verbose("Integrated: \(integratedName ?? "Unknown")")
        NSLog("verbose: %@","Discrete: \(discreteName ?? "Unknown")") //eaj log.verbose("Discrete: \(discreteName ?? "Unknown")")
        if  self.discreteName == nil ||
            self.integratedName == nil ||
            self.discreteName == "Unknown" ||
            self.integratedName == "Unknown" {
                NSLog("error: %@","There was an error finding the gpus.. \(gpus.description)") //eaj log.error("There was an error finding the gpus.. \(gpus.description)")
        }
    }
    
    public func connect() throws {
        var kernResult: kern_return_t = 0
        var service: io_service_t = IO_OBJECT_NULL
        var iterator: io_iterator_t = 0
        
        kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(Constants.GRAPHICS_CONTROL), &iterator);
        
        if kernResult != KERN_SUCCESS {
            throw RuntimeError.CanNotConnect("IOServiceGetMatchingServices returned \(kernResult)")
        }
        
        service = IOIteratorNext(iterator);
        IOObjectRelease(iterator);
        
        if service == IO_OBJECT_NULL {
            throw RuntimeError.CanNotConnect("No matching drivers found.");
        }
        
        kernResult = IOServiceOpen(service, mach_task_self_, 0, &self._connect);
        if kernResult != KERN_SUCCESS {
            throw RuntimeError.CanNotConnect("IOServiceOpen returned \(kernResult)");
        }
        
        kernResult = IOConnectCallScalarMethod(self._connect, UInt32(DispatchSelectors.kOpen.rawValue), nil, 0, nil, nil);
        if kernResult != KERN_SUCCESS {
            throw RuntimeError.CanNotConnect("IOConnectCallScalarMethod returned \(kernResult)")
        }
        
        NSLog("info: %@","Successfully connected") //eaj log.info("Successfully connected")
    }
    
    public func close() -> Bool {
        var kernResult: kern_return_t = 0
        if self._connect == IO_OBJECT_NULL {
            return true;
        }
        
        kernResult = IOConnectCallScalarMethod(self._connect, UInt32(DispatchSelectors.kClose.rawValue), nil, 0, nil, nil);
        if kernResult != KERN_SUCCESS {
            NSLog("error: %@","IOConnectCallScalarMethod returned \(kernResult)") //eaj log.error("IOConnectCallScalarMethod returned \(kernResult)")
            return false
        }
        
        kernResult = IOServiceClose(self._connect);
        if kernResult != KERN_SUCCESS {
            NSLog("error: %@","IOServiceClose returned \(kernResult)") //eaj log.error("IOServiceClose returned \(kernResult)")
            return false
        }
        
        self._connect = IO_OBJECT_NULL
        NSLog("info: %@","Driver Connection Closed") //eaj log.info("Driver Connection Closed")
        return true
    }
    
    /**
        Instead of calling this directly use the methods in appDelegate because they provide safegaurds
    */
    public func GPUMode(mode: SwitcherMode) -> Bool {
        let connect = self._connect
        
        requestedMode = mode
        
        var status = false
        
        if connect == IO_OBJECT_NULL {
            return status
        }
        
        switch mode {
        case .ForceIntergrated:
            let integrated = CheckGPUStateAndisUsingIntegratedGPU()
            NSLog("info: %@","Requesting integrated, are we integrated?  \(integrated)") //eaj log.info("Requesting integrated, are we integrated?  \(integrated)")
            if !integrated {
                status = SwitchGPU(connect: connect)
            }
            
        case .ForceDiscrete:
            NSLog("info: %@","Requesting discrete") //eaj log.info("Requesting discrete")
            /** Essientialy ticks and unticks the box in system prefs, which by design forces discrete */
            
            _ = setFeatureInfo(connect: connect, feature: Features.Policy, enabled: true)
            _ = setSwitchPolicy(connect: connect)
            
            status = setDynamicSwitching(connect: connect, enabled: true)
            
            // give the gpu a second to switch
            sleep(1)
            
            status = setDynamicSwitching(connect: connect, enabled: false)
        case .SetDynamic:
            NSLog("info: %@","Requesting Dynamic") //eaj log.info("Requesting Dynamic")
            /** Set switch policy back, makes it think its on auto switching */
            _ = setFeatureInfo(connect: connect, feature: Features.Policy, enabled: true)
            _ = setSwitchPolicy(connect: connect)
            
            status = setDynamicSwitching(connect: connect, enabled: true)
        }
        
        return status
    }
    
    /**
        Returns the gpu name from a gpu_int
    */
    public func resolveGPUName(gpu: GPU_INT) -> String? {
        return gpu == .Integrated ? self.integratedName : self.discreteName
    }
    
    /**
        We should never assume gpu state that is why we always check.
        Anytime we get state of gpu we might as well:
     
        Change the active name
        NOTIFY checkGPUState in case it changed
        return whether we are integrated or discrete
    */
    public func CheckGPUStateAndisUsingIntegratedGPU() -> Bool {
        if self._connect == IO_OBJECT_NULL {
            NSLog("error: %@","Lost connection to gpu") //eaj log.error("Lost connection to gpu")
            return false  //probably need to throw or exit if lost connection?
        }
        
        let gpu_int = GPU_INT(rawValue: Int(getGPUState(connect: self._connect, input: GPUState.GraphicsCard)))
        
        NotificationCenter.default.post(name: .checkGPUState, object: gpu_int)
        NSLog("info: %@","NOTIFY: checkGPUState ~ Checking GPU...") //eaj log.info("NOTIFY: checkGPUState ~ Checking GPU...")
        if gpu_int == .Integrated {
            currentGPU = self.integratedName
        } else {
            currentGPU = self.discreteName
        }
        
        return gpu_int == .Integrated
    }
    
    public func setGPUState(state: GPUState, arg: UInt64) -> Bool {
        return self.setGPUState(connect: self._connect, state: state, arg: arg)
    }
    
    private func setGPUState(connect: io_connect_t, state: GPUState, arg: UInt64) -> Bool {
        var kernResult: kern_return_t = 0
        
        let scalar: [UInt64] = [ 1, UInt64(state.rawValue), arg ];
        
        kernResult = IOConnectCallScalarMethod(
            // an io_connect_t returned from IOServiceOpen().
            connect,
            
            // selector of the function to be called via the user client.
            UInt32(DispatchSelectors.kSetMuxState.rawValue),
            
            // array of scalar (64-bit) input values.
            scalar,
            
            // the number of scalar input values.
            3,
            
            // array of scalar (64-bit) output values.
            nil,
            
            // pointer to the number of scalar output values.
            nil
        );

        if kernResult == KERN_SUCCESS {
            NSLog("verbose: %@","SET: Modified state with \(state)") //eaj log.verbose("SET: Modified state with \(state)")
        } else {
            NSLog("error: %@","Set state returned \(kernResult)") //eaj log.error("Set state returned \(kernResult)")
        }
            
        return kernResult == KERN_SUCCESS
    }
    
    public func getGPUState(input: GPUState) -> UInt64 {
        return self.getGPUState(connect: self._connect, input: input)
    }
    
    private func getGPUState(connect: io_connect_t, input: GPUState) -> UInt64 {
        var kernResult: kern_return_t = 0
        let scalar: [UInt64] = [ 1, UInt64(input.rawValue) ];
        var output: UInt64 = 0
        var outputCount: UInt32 = 1
        
        kernResult = IOConnectCallScalarMethod(
            // an io_connect_t returned from IOServiceOpen().
            connect,
            
            // selector of the function to be called via the user client.
            UInt32(DispatchSelectors.kGetMuxState.rawValue),
            
            // array of scalar (64-bit) input values.
            scalar,
            
            // the number of scalar input values.
            2,
            
            // array of scalar (64-bit) output values.
            &output,
            
            // pointer to the number of scalar output values.
            &outputCount
        );
        
        var successMessage = "GET: count \(outputCount), value \(output)"
        
        if(input == .GraphicsCard) {
            let gpu_int = GPU_INT(rawValue: Int(output))!
            successMessage += " (\(gpu_int))"
        }
        
        if kernResult == KERN_SUCCESS {
            NSLog("verbose: %@",successMessage) //eaj log.verbose(successMessage)
        } else {
            NSLog("error: %@","Get state returned \(kernResult)") //eaj log.error("Get state returned \(kernResult)")
        }
        
        return output
    }
    
    struct StateStruct {
        var field = [uint32](repeating: 0, count: 25) // State Struct has to be 100 bytes long
    }
    
    public func dumpState() -> StateStruct {
        return self.dumpState(connect: self._connect)
    }
    
    private func dumpState(connect: io_connect_t) -> StateStruct {
        var kernResult: kern_return_t = 0
        var stateStruct = StateStruct()
        var structSize = MemoryLayout<StateStruct>.stride
        
        kernResult = IOConnectCallMethod(
            // an io_connect_t returned from IOServiceOpen().
            connect,
            
            // selector of the function to be called via the user client.
            UInt32(DispatchSelectors.kDumpState.rawValue),
            
            // array of scalar (64-bit) input values.
            nil,
            
            // the number of scalar input values.
            0,
            
            // a pointer to the struct input parameter.
            nil,
            
            // the size of the input structure parameter.
            0,
            
            // array of scalar (64-bit) output values.
            nil,
            
            // pointer to the number of scalar output values.
            nil,
            
            // pointer to the struct output parameter.
            &stateStruct,
            
            // pointer to the size of the output structure parameter.
            &structSize)
        
        if kernResult == KERN_SUCCESS {
            NSLog("info: %@","Dumped state") //eaj log.info("Dumped state")
        } else {
            NSLog("error: %@","Did not dump state") //eaj log.error("Did not dump state")
        }
        
        return stateStruct
    }
    
    /**
     Kind of a misnomer because it only sets it to integrated (this is what its called for kernal mux)
     ie. switch back from discrete (used to force integrated)
     */
    private func SwitchGPU(connect: io_connect_t) -> Bool {
        let _ = setDynamicSwitching(connect: connect, enabled: false)
        
        sleep(1)
        
        return setGPUState(connect: connect, state: GPUState.ForceSwitch, arg: 0)
    }
    
    public func setFeatureInfo(feature: Features, enabled: Bool) -> Bool {
        return self.setFeatureInfo(connect: self._connect, feature: feature, enabled: enabled)
    }
    
    private func setFeatureInfo(connect: io_connect_t, feature: Features, enabled: Bool) -> Bool {
        return setGPUState(
            connect: connect,
            state: enabled ? GPUState.EnableFeatureORFeatureInfo2 : GPUState.DisableFeatureORFeatureInfo,
            arg: 1 << feature.rawValue)
    }
    
    private func setSwitchPolicy(connect: io_connect_t, dynamic: Bool = true) -> Bool {
        /** dynamic = 0: instant switching, dynamic = 2: user needs to logout before switching */
        return setGPUState(connect: connect, state: GPUState.SwitchPolicy, arg: dynamic ? 0 : 2)
    }
    
    private func setDynamicSwitching(connect: io_connect_t, enabled: Bool) -> Bool {
        return setGPUState(connect: connect, state: GPUState.GpuSelect, arg: enabled ? 1 : 0);
    }
    
    private func getGpuNames() -> [String] {
        let ioProvider = IOServiceMatching(Constants.IO_PCI_DEVICE)
        var iterator: io_iterator_t = 0
        
        var gpus = [String]()
        
        if(IOServiceGetMatchingServices(kIOMasterPortDefault, ioProvider, &iterator) == kIOReturnSuccess) {
            var device: io_registry_entry_t = 0
            
            repeat {
                device = IOIteratorNext(iterator)
                var serviceDictionary: Unmanaged<CFMutableDictionary>?;
                
                if (IORegistryEntryCreateCFProperties(device, &serviceDictionary, kCFAllocatorDefault, 0) != kIOReturnSuccess) {
                    // Couldn't get the properties
                    IOObjectRelease(device)
                    continue;
                }
                
                if let props = serviceDictionary {
                    let dict = props.takeRetainedValue() as NSDictionary
                    
                    if let d = dict.object(forKey: Constants.IO_NAME_KEY) as? String {
                        if d == Constants.DISPLAY_KEY {
                            let model = dict.object(forKey: Constants.MODEL_KEY) as! Data
                            gpus.append(String(data: model, encoding: .ascii)!)
                        }
                    }
                }
            } while (device != 0)
        }
        
        return gpus
    }
    
}


