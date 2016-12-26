//
//  ViewController.swift
//  BluetoothPresence
//
//  Created by Bryan on 12/24/16.
//  Copyright © 2016 bcattle. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet var usernameInput: UITextField!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var statusLabel: UILabel!

    var bluetooth: BluetoothController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
    }

    @IBAction func advertiseButtonTapped () {
        if let text = usernameInput.text {
            usernameInput.isEnabled = false
            bluetooth = BluetoothController(username: text)
        }
    }

}

