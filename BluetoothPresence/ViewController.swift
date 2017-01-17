//
//  ViewController.swift
//  BluetoothPresence
//
//  Created by Bryan on 12/24/16.
//  Copyright © 2016 bcattle. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var advertisingSwitch: UISwitch!
    @IBOutlet weak var scanningSwitch: UISwitch!
    @IBOutlet weak var scanningIndicator: UIActivityIndicatorView!
    @IBOutlet weak var scanningLabel: UILabel!
    
//    var bluetooth: BluetoothController!
    var displayUpdateTimer:Timer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        textView.text = ""
        scanningIndicator.isHidden = true
        scanningLabel.isHidden = true
        
        let userID = UUID()
        textView.text = textView.text + "\nGenerated user ID \(userID)"
        
//        bluetooth = BluetoothController()
//        bluetooth.delegate = self
        BluetoothController.sharedInstance.delegate = self
        
        displayUpdateTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(ViewController.updateDisplay), userInfo: nil, repeats: true)
        
        if let defaultUsername = UserDefaults.standard.string(forKey: Constants.Defaults.DefaultUsernameKeyName) {
            usernameField.text = defaultUsername
        }
    }
    
    @IBAction func advertiseSwitchFlipped (sender:UISwitch) {
        if sender.isOn {
            guard usernameField.text != nil && usernameField.text!.trimmingCharacters(in: NSCharacterSet.whitespaces) != "" else {
                let alert = UIAlertController.alertWithOK(title: "Uh oh", message: "Please enter a username", completionHandler: {
                    sender.isOn = false
                })
                self.present(alert, animated: true, completion: nil)
                return
            }
            
            // Show an alert for the iOS 10 background advertising issue
            let os = ProcessInfo().operatingSystemVersion
//            if (os.majorVersion, os.minorVersion, os.patchVersion) == (10, 0, 0) {
            if (os.majorVersion, os.minorVersion) == (10, 0) {
                let alert = UIAlertController.alertWithOK(title: "Version warning", message: "You're runnning an old version of iOS 10. Your version has a known bug that will prevent people from seeing you nearby when Nearly is not running. Consider upgrading to the latest iOS. It's free! :)", completionHandler: nil)
                self.present(alert, animated: true, completion: nil)
            }
            
            let username = usernameField.text!.trimmingCharacters(in: NSCharacterSet.whitespaces)
            UserDefaults.standard.set(username, forKey: Constants.Defaults.DefaultUsernameKeyName)
            BluetoothController.sharedInstance.username = username
            
            BluetoothController.sharedInstance.startAdvertising()
            usernameField.isEnabled = false
            
        } else {
            BluetoothController.sharedInstance.stopAdvertising()
            usernameField.isEnabled = true
        }
    }
    
    @IBAction func scanSwitchFlipped (sender:UISwitch) {
        if sender.isOn {
            BluetoothController.sharedInstance.startScanning()
        } else {
            BluetoothController.sharedInstance.stopScanning()
        }
    }

    @objc
    func updateDisplay() {
        let str = NSMutableAttributedString()
        for sighting in BluetoothController.sharedInstance.sightingsByPeripheralID.values {
            if let username = sighting.username, let rssi = sighting.lastRSSI, let lastSeen = sighting.lastSeenAt {
                let ageSecs = lastSeen.timeIntervalSinceNow
                if ageSecs < -60 {
                    // Ignore, this is an old sighting
                    continue
                }
                var attrs:[String:Any]? = nil
                if ageSecs < -45 {
                    // Color red
                    attrs = [NSForegroundColorAttributeName:UIColor.red]
                }
                else if ageSecs < -30 {
                    // Color yellow
                    attrs = [NSForegroundColorAttributeName:UIColor.init(colorLiteralRed: 0.5, green: 0.5, blue: 0, alpha: 1)]
                }
                else {
                    // Default
                    attrs = [NSForegroundColorAttributeName:UIColor.black]
                }
                let userStr = "\(username)\t\t\(rssi)\t\t\(lastSeen.timeAgoSinceNow()!)\n"
                str.append(NSAttributedString(string: userStr, attributes: attrs))
            }
        }
        textView.attributedText = str
    }
}

extension ViewController: BluetoothControllerDelegate {
    func bluetoothControllerStartedScanning(controller: BluetoothController) {
        scanningIndicator.startAnimating()
        scanningIndicator.isHidden = false
        scanningLabel.isHidden = false
    }
    
    func bluetoothControllerStoppedScanning(controller: BluetoothController) {
        scanningIndicator.isHidden = true
        scanningLabel.isHidden = true
        scanningIndicator.stopAnimating()
    }
    
    func bluetoothController(controller: BluetoothController, sightingUpdated sighting: PresenceSighting) {
//        textView.text = controller.getAllSightingsString()
    }
}

extension UIAlertController {
    class func alertWithOK(title:String, message:String, completionHandler:(()->Void)?) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            if let onComplete = completionHandler {
                onComplete()
            }
        }))
        return alert
    }
}
