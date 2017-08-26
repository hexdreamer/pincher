// Pincher
// ViewController.swift
// Copyright © 2017 Kenny Leung
// https://github.com/hexdreamer/pincher
// This code is PUBLIC DOMAIN

import UIKit

class ViewController: UIViewController {

    @IBOutlet var pincherView :PincherView?

    override func viewDidLoad() {
        super.viewDidLoad()
        let image = UIImage(named: "DeliciousLardo")
        self.pincherView!.image = image
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

