//
//  WhiteBalanceViewController.swift
//  Camera
//
//  Created by Matteo Caldari on 06/02/15.
//  Copyright (c) 2015 Matteo Caldari. All rights reserved.
//

import UIKit
import AVFoundation

class WhiteBalanceViewController: UIViewController, CameraSettingValueObserver, CameraControlsViewControllerProtocol {

	@IBOutlet var modeSwitch:UISwitch!
	@IBOutlet var temperatureSlider:UISlider!
	@IBOutlet var tintSlider:UISlider!
	
	var cameraController:CameraController? {
		willSet {
			if let cameraController = cameraController {
				cameraController.unregisterObserver(self, property: CameraControlObservableSettingWBGains)
			}
		}
		didSet {
			if let cameraController = cameraController {
				cameraController.registerObserver(self, property: CameraControlObservableSettingWBGains)
			}
		}
	}
	
	override func viewDidLoad() {
		
		if let autoWB = cameraController?.isContinuousAutoWhiteBalanceEnabled() {
			modeSwitch.on = autoWB
			temperatureSlider.enabled = !autoWB
			tintSlider.enabled = !autoWB
		}
		
		if let currentTemperature = cameraController?.currentTemperature() {
			temperatureSlider.value = currentTemperature
		}
		
		if let currentTint = cameraController?.currentTint() {
			tintSlider.value = currentTint
		}
	}
	
	
	@IBAction func modeSwitchValueChanged(sender:UISwitch) {
		temperatureSlider.enabled = !sender.on
		tintSlider.enabled = !sender.on
		
		if modeSwitch.on {
			cameraController?.enableContinuousAutoWhiteBalance()
		}
		else {
			cameraController?.setCustomWhiteBalanceWithTint(tintSlider.value)
			cameraController?.setCustomWhiteBalanceWithTemperature(temperatureSlider.value)
		}
	}
	
	
	@IBAction func temperatureSliderValueChanged(sender:UISlider) {
		cameraController?.setCustomWhiteBalanceWithTemperature(sender.value)
	}
	
	
	@IBAction func tintSliderValueChanged(sender:UISlider) {
		cameraController?.setCustomWhiteBalanceWithTint(sender.value)
	}
	
	
	func cameraSetting(setting: String, valueChanged value: AnyObject) {
		if setting == CameraControlObservableSettingWBGains {
			if let wbValues = value as? WhiteBalanceValues {
				temperatureSlider.value = wbValues.temperature
				tintSlider.value = wbValues.tint
			}
		}
	}
	
}
