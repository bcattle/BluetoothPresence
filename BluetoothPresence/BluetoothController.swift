//
//  BluetoothController.swift
//  BluetoothPresence
//
//  Created by Bryan on 12/24/16.
//  Copyright © 2016 bcattle. All rights reserved.
//

import Foundation
import CoreBluetooth

// NOTE: There is a bug in iOS 10.0 (10.0.0, 10.0.1): 
// background advertising doesn't work.
// see https://forums.developer.apple.com/thread/51309

class PresenceSighting {
    var username:String?
    var lastSeenAt:NSDate?
    var lastRSSI:Int?
}

protocol BluetoothControllerDelegate {
    func bluetoothControllerStartedScanning(controller:BluetoothController)
    func bluetoothControllerStoppedScanning(controller:BluetoothController)
    func bluetoothController(controller:BluetoothController, sightingUpdated sighting:PresenceSighting)
}

class BluetoothController: NSObject {
    // Singleton, to support state restoration
    static let sharedInstance = BluetoothController()
    
    var delegate:BluetoothControllerDelegate?

    var peripheralIsRunning = false
    private var usernameCharacteristic:CBMutableCharacteristic?
    var username: String? {
        didSet {
            if peripheralIsRunning {
                if let username = username {
                    setIdentityServiceUsername(username: username)
                }
            }
        }
    }
    
    var scanPeriodSecs = 5.0    // 10.0
    private var scanTimer:Timer?
    private var isScanning = false
    fileprivate var centralStateWasRestored = false
        
    var sightingsByPeripheralID = [UUID:PresenceSighting]()
    // We have to retain a reference to periphals while we're connected to them
    var peripherals = Set<CBPeripheral>()
    
    // Runs the process as a central, scans for peripherals
    fileprivate var centralManger: CBCentralManager!
    
    // Publishes our presence as a peripheral
    private var peripheralManager: CBPeripheralManager!
    
    private override init() {
        super.init()
        
        centralManger = CBCentralManager(delegate: self, queue: nil,
                                         options: [CBCentralManagerOptionShowPowerAlertKey: true,
                                                   CBCentralManagerOptionRestoreIdentifierKey: "com.getnearly.BluetoothController.central"])
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil,
                                                options: [CBPeripheralManagerOptionShowPowerAlertKey: true,
                                                          CBPeripheralManagerOptionRestoreIdentifierKey: "com.getnearly.BluetoothController.peripheral"])
        
        NotificationCenter.default.addObserver(self, selector: #selector(BluetoothController.handleAppEnteredBackground), name: Notification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(BluetoothController.handleAppEnteredForeground), name: Notification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    fileprivate func setIdentityServiceUsername(username:String) {
        // Configures the peripheral to publish the user's identity (username and ID)
        // A "Service" has one or more "Characteristics"
        
        let identityData = username.data(using: .utf8)!
        
        if usernameCharacteristic == nil {
            let identityCharacteristicID = CBUUID(string: Constants.Bluetooth.Peripheral.IdentityCharacteristicUUID)
            usernameCharacteristic = CBMutableCharacteristic(type: identityCharacteristicID,
                                                             properties: .read,
                                                             value: identityData,
                                                             permissions: .readable)
            
            let identityServiceID = CBUUID(string: Constants.Bluetooth.Peripheral.IdentityServiceUUID)
            let service = CBMutableService(type: identityServiceID, primary: true)
            service.characteristics = [usernameCharacteristic!]
            peripheralManager.add(service)
        }
        else {
            usernameCharacteristic!.value = identityData
        }
    }
    
    // Advertising
    
    func startAdvertising() {
        let identityServiceID = CBUUID(string: Constants.Bluetooth.Peripheral.IdentityServiceUUID)
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [identityServiceID]])
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
    }
    
    // Scanning
    
    func startScanning() {
        // Start the scan
        scanTimerFired()
        // Start the timer
        scanTimer = Timer.scheduledTimer(timeInterval: scanPeriodSecs, target: self, selector: #selector(BluetoothController.scanTimerFired), userInfo: nil, repeats: true)
    }
    
    func stopScanning() {
        // Stops the scan timer
        if let timer = scanTimer {
            timer.invalidate()
            scanTimer = nil
        }
        if isScanning {
            scanTimerFired()
        }
    }
    
    @objc
    private func scanTimerFired() {
        if isScanning {
            print("Timer fired, scan finished")
            centralManger.stopScan()
            isScanning = false
            // printKnownUsers()
            if let delegate = delegate {
                delegate.bluetoothControllerStoppedScanning(controller: self)
            }
            
        } else {
            print("Timer fired, starting scan")
            let identityServiceID = CBUUID(string: Constants.Bluetooth.Peripheral.IdentityServiceUUID)
            centralManger.scanForPeripherals(withServices: [identityServiceID], options: nil)
            isScanning = true
            if let delegate = delegate {
                delegate.bluetoothControllerStartedScanning(controller: self)
            }
            
        }
    }
    
    @objc
    private func handleAppEnteredBackground() {
        if scanTimer != nil {
            print("App entering background, starting to scan forever")
            // Start scanning forever
            stopScanning()
            scanTimerFired()
        }
    }
    
    @objc
    private func handleAppEnteredForeground() {
        if centralStateWasRestored || isScanning {
            print("App entering foreground, starting intermittent scan")
            // Disable continous scan and switch to scan timer
            stopScanning()
            startScanning()
        }
    }
}

extension BluetoothController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if #available(iOS 10.0, *) {
            print("centralManagerDidUpdateState to \(getStringForCBManagerState(state:central.state))")
        }
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        print("central manager restored state")
        centralStateWasRestored = true
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("discovered peripheral \(peripheral.identifier)")
        if let sighting = sightingsByPeripheralID[peripheral.identifier] {
            if let username = sighting.username {
                print("Known user \"\(username)\"")
                // Known user, no need to connect
                // update its last seen and signal strength
                sighting.lastRSSI = RSSI.intValue
                sighting.lastSeenAt = NSDate()
                if let delegate = delegate {
                    delegate.bluetoothController(controller: self, sightingUpdated: sighting)
                }
                return
            } else {
                // No username, remove the old sighting object
                sightingsByPeripheralID.removeValue(forKey: peripheral.identifier)
            }
        }
        // Unknown user, connect to get their username
        print("Unknown user, connecting")
        let sighting = PresenceSighting()
        sighting.lastRSSI = RSSI.intValue
        sighting.lastSeenAt = NSDate()
        sightingsByPeripheralID[peripheral.identifier] = sighting
        peripheral.delegate = self
        peripherals.insert(peripheral)
        central.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected to peripheral \(peripheral.identifier)")
        // Discover services to get the user ID
        // peripheral.discoverServices(nil)
        let identityServiceID = CBUUID(string: Constants.Bluetooth.Peripheral.IdentityServiceUUID)
        peripheral.discoverServices([identityServiceID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("failed to connect to peripheral \(peripheral.identifier)")
        peripherals.remove(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("disconnected from peripheral \(peripheral.identifier)")
        peripherals.remove(peripheral)
    }
}

extension BluetoothController: CBPeripheralDelegate {
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        print("peripheral manager will restore state")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
//        print("discovered services")
        let firstService = peripheral.services!.first!
        peripheral.discoverCharacteristics(nil, for: firstService)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics for service: \(error)")
        } else {
//            print("discovered characteristics, reading")
            let firstCharacteristic = service.characteristics!.first!
            peripheral.readValue(for: firstCharacteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // print("didUpdateValueFor characteristic \(characteristic)")
        let username = String(data:characteristic.value!, encoding:String.Encoding.utf8)!
        print("Retrieved username \(username) from peripheral \(peripheral.identifier)")
        let sighting = sightingsByPeripheralID[peripheral.identifier]!
        sighting.username = username
        // Done
        centralManger.cancelPeripheralConnection(peripheral)
        if let delegate = delegate {
            delegate.bluetoothController(controller: self, sightingUpdated: sighting)
        }
    }
}

extension BluetoothController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if #available(iOS 10.0, *) {
            print("peripheralManagerDidUpdateState to \(getStringForCBManagerState(state:peripheral.state))")
        }
        peripheralIsRunning = true
        // Now that the peripheral manager is running, we can set up the services
        if let username = username {
            setIdentityServiceUsername(username: username)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        //identityService = service
        if let error = error {
            print("Error adding service \(error)")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Error starting to advertise \(error)")
        }
    }
}

extension BluetoothController {
    @available(iOS 10.0, *)
    func getStringForCBManagerState(state:CBManagerState) -> String {
        switch (state) {
        case .unknown:
            return "unknown"
        case .unsupported:
            return "unsupported"
        case .unauthorized:
            return "unauthorized"
        case.poweredOn:
            return "poweredOn"
        case .poweredOff:
            return "poweredOff"
        case .resetting:
            return "resetting"
        }
    }
}
