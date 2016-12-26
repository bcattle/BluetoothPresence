//
//  BluetoothController.swift
//  BluetoothPresence
//
//  Created by Bryan on 12/24/16.
//  Copyright © 2016 bcattle. All rights reserved.
//

import Foundation
import CoreBluetooth

class BluetoothController: NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    // Runs the process as a central, scans for peripherals
    private var centralManger: CBCentralManager!
    
    // Publishes our presence as a peripheral
    private var peripheralManager: CBPeripheralManager!
    
    // The service whose existence we are advertising
    // nil if it hasn't been added yet
    private var identityService: CBService?
    
    init(username: String) {
        super.init()
        
        centralManger = CBCentralManager(delegate: self, queue: nil,
                                         options: [CBCentralManagerOptionShowPowerAlertKey: true])
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil,
                                                options: [CBCentralManagerOptionShowPowerAlertKey: true])
        
        setupIdentityService(username: username)
    }
    
    func setupIdentityService(username: String) {
        // Configures the peripheral to publish the user's identity (username and ID)
        // A "Service" has one or more "Characteristics"
        
        let identityCharacteristicID = CBUUID(string: Constants.Bluetooth.Peripheral.IdentityCharacteristicUUID)
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
    
    // MARK: Central Manager Delegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
    }
    
    
    // MARK: Peripheral Manager Delegate
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        identityService = service
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
