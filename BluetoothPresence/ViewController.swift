//
//  ViewController.swift
//  BluetoothPresence
//
//  Created by Bryan on 12/24/16.
//  Copyright © 2016 bcattle. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet var textView: UITextView!
    @IBOutlet var advertisingSwitch: UISwitch!
    @IBOutlet var scanningSwitch: UISwitch!
//    @IBOutlet var activityIndicator: UIActivityIndicatorView!
//    @IBOutlet var statusLabel: UILabel!
    
    var bluetooth: BluetoothController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        textView.text = ""
        
        let userID = UUID()
        textView.text = textView.text + "\nGenerated user ID \(userID)"
        
        bluetooth = BluetoothController(userID: userID)
    }

    @IBAction func advertiseSwitchFlipped (sender:UISwitch) {
        if sender.isOn {
            bluetooth.startAdvertising()
        } else {
            bluetooth.stopAdvertising()
        }
    }
    
    @IBAction func scanSwitchFlipped (sender:UISwitch) {
        if sender.isOn {
            bluetooth.startScanning()
        } else {
            bluetooth.stopScanning()
        }
    }

}

