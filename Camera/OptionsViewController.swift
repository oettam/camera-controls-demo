//
//  OptionsViewController.swift
//  Camera
//
//  Created by Matteo Caldari on 08/02/15.
//  Copyright (c) 2015 Matteo Caldari. All rights reserved.
//

import UIKit

class OptionsViewController: UIViewController, CameraControlsViewControllerProtocol {

	var cameraController:CameraController?
	
	@IBOutlet var bracketedCaptureSwitch:UISwitch!
	
	override func viewDidLoad() {
		if let cameraController = cameraController {
            bracketedCaptureSwitch.isOn = cameraController.enableBracketedCapture
		}
	}
	
	@IBAction func bracketedCaptureSwitchValueChanged(sender:UISwitch) {
        cameraController?.enableBracketedCapture = sender.isOn
	}
	
}
