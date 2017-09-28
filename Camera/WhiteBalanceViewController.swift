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
				cameraController.unregisterObserver(observer: self, property: CameraControlObservableSettingWBGains)
			}
		}
		didSet {
			if let cameraController = cameraController {
                cameraController.registerObserver(observer: self, property: CameraControlObservableSettingWBGains)
			}
		}
	}
	
	override func viewDidLoad() {
		
		if let autoWB = cameraController?.isContinuousAutoWhiteBalanceEnabled() {
            modeSwitch.isOn = autoWB
            temperatureSlider.isEnabled = !autoWB
            tintSlider.isEnabled = !autoWB
		}
		
		if let currentTemperature = cameraController?.currentTemperature() {
			temperatureSlider.value = currentTemperature
		}
		
		if let currentTint = cameraController?.currentTint() {
			tintSlider.value = currentTint
		}
	}
	
	
	@IBAction func modeSwitchValueChanged(sender:UISwitch) {
        temperatureSlider.isEnabled = !sender.isOn
		tintSlider.isEnabled = !sender.isOn
		
        if modeSwitch.isOn {
			cameraController?.enableContinuousAutoWhiteBalance()
		}
		else {
            cameraController?.setCustomWhiteBalanceWithTint(tint: tintSlider.value)
            cameraController?.setCustomWhiteBalanceWithTemperature(temperature: temperatureSlider.value)
		}
	}
	
	
	@IBAction func temperatureSliderValueChanged(sender:UISlider) {
        cameraController?.setCustomWhiteBalanceWithTemperature(temperature: sender.value)
	}
	
	
	@IBAction func tintSliderValueChanged(sender:UISlider) {
        cameraController?.setCustomWhiteBalanceWithTint(tint: sender.value)
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
