//
//  Constants.swift
//  BluetoothPresence
//
//  Created by Bryan on 12/24/16.
//  Copyright © 2016 bcattle. All rights reserved.
//

import Foundation

struct Constants {
    struct Bluetooth {
        struct Peripheral {
            // App-wide, allows us to search for only peripherals
            // advertising from this app
            static let AppPeripheralUUID = "5066D910-B842-46BD-B694-D94909CF0356"
            // The ID that identifies the "user identity" service of the peripheral
            static let IdentityServiceUUID = "B0804C45-31B1-4862-A173-CC794C09C332"
            static let IdentityCharacteristicUUID = "76B48D0F-3ECD-4957-AA1C-DC52247CF0B6"
        }
    }
}
