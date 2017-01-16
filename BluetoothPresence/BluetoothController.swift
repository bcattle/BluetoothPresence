//
//  BluetoothController.swift
//  BluetoothPresence
//
//  Created by Bryan on 12/24/16.
//  Copyright © 2016 bcattle. All rights reserved.
//

import Foundation
import CoreBluetooth

class PresenceSighting {
    var username:String?
    var lastSeenAt:Date?
    var lastRSSI:Int?
}

class BluetoothController: NSObject {
    var sightingsByPeripheralID = [UUID:PresenceSighting]()
    var peripherals = Set<CBPeripheral>()
    let userID: UUID
    
    // Runs the process as a central, scans for peripherals
    fileprivate var centralManger: CBCentralManager!
    
    // Publishes our presence as a peripheral
    private var peripheralManager: CBPeripheralManager!
    
    init(userID: UUID) {
        self.userID = userID
        super.init()
        
        centralManger = CBCentralManager(delegate: self, queue: nil,
                                         options: [CBCentralManagerOptionShowPowerAlertKey: true])
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil,
                                                options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    func setupIdentityService() {
        // Configures the peripheral to publish the user's identity (username and ID)
        // A "Service" has one or more "Characteristics"
        
        let identityCharacteristicID = CBUUID(string: Constants.Bluetooth.Peripheral.IdentityCharacteristicUUID)
        let username = "bryan"
        let identityData = username.data(using: .utf8)
        let characteristic = CBMutableCharacteristic(type: identityCharacteristicID,
                                              properties: .read,
                                              value: identityData,
                                              permissions: .readable)
        
        let identityServiceID = CBUUID(string: Constants.Bluetooth.Peripheral.IdentityServiceUUID)
        let service = CBMutableService(type: identityServiceID, primary: true)
        service.characteristics = [characteristic]
        peripheralManager.add(service)
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
        let identityServiceID = CBUUID(string: Constants.Bluetooth.Peripheral.IdentityServiceUUID)
        centralManger.scanForPeripherals(withServices: [identityServiceID], options: nil)
    }
    
    func stopScanning() {
        centralManger.stopScan()
    }
    
}

extension BluetoothController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if #available(iOS 10.0, *) {
            print("centralManagerDidUpdateState to \(getStringForCBManagerState(state:central.state))")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("discovered peripheral \(peripheral.identifier)")
        if let sighting = sightingsByPeripheralID[peripheral.identifier] {
            print("Known user \"\(sighting.username!)\"")
            // Known user, no need to connect
            // update its last seen and signal strength
            sighting.lastRSSI = RSSI.intValue
            sighting.lastSeenAt = Date()
        }
        else {
            // Unknown user, connect to get their userID
            print("Unknown user, connecting")
            let sighting = PresenceSighting()
            sighting.lastRSSI = RSSI.intValue
            sighting.lastSeenAt = Date()
            sightingsByPeripheralID[peripheral.identifier] = sighting
            peripheral.delegate = self
            peripherals.insert(peripheral)
            central.connect(peripheral, options: nil)
        }
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
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("discovered servicess")
        let firstService = peripheral.services!.first!
        peripheral.discoverCharacteristics(nil, for: firstService)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics for service: \(error)")
        } else {
            print("discovered characteristics, reading")
            let firstCharacteristic = service.characteristics!.first!
            peripheral.readValue(for: firstCharacteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // print("didUpdateValueFor characteristic \(characteristic)")
        let username = String(data:characteristic.value!, encoding:String.Encoding.utf8)!
        print("Retrieved username \(username) from peripheral \(peripheral.identifier)")
        sightingsByPeripheralID[peripheral.identifier]!.username = username
        // Done
        centralManger.cancelPeripheralConnection(peripheral)
    }
    
//    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
//        print("read RSSI")
//    }
//
//    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
//        print("updated name")
//    }
}

extension BluetoothController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if #available(iOS 10.0, *) {
            print("peripheralManagerDidUpdateState to \(getStringForCBManagerState(state:peripheral.state))")
        }
        setupIdentityService()
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
