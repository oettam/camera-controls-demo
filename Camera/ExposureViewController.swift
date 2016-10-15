//
//  ExposureViewController.swift
//  Camera
//
//  Created by Matteo Caldari on 05/02/15.
//  Copyright (c) 2015 Matteo Caldari. All rights reserved.
//

import UIKit
import CoreMedia

class ExposureViewController: UIViewController, CameraControlsViewControllerProtocol, CameraSettingValueObserver {

	@IBOutlet var modeSwitch:UISwitch!
	@IBOutlet var biasSlider:UISlider!
	@IBOutlet var durationSlider:UISlider!
	@IBOutlet var isoSlider:UISlider!
	
	var cameraController:CameraController? {
		willSet {
			if let cameraController = cameraController {
				cameraController.unregisterObserver(self, property: CameraControlObservableSettingExposureTargetOffset)
				cameraController.unregisterObserver(self, property: CameraControlObservableSettingExposureDuration)
				cameraController.unregisterObserver(self, property: CameraControlObservableSettingISO)
			}
		}
		didSet {
			if let cameraController = cameraController {
				cameraController.registerObserver(self, property: CameraControlObservableSettingExposureTargetOffset)
				cameraController.registerObserver(self, property: CameraControlObservableSettingExposureDuration)
				cameraController.registerObserver(self, property: CameraControlObservableSettingISO)
			}
		}
	}

	override func viewDidLoad() {
		setInitialValues()
	}
	

	@IBAction func modeSwitchValueChanged(_ sender:UISwitch) {
		if sender.isOn {
			cameraController?.enableContinuousAutoExposure()
		}
		else {
			cameraController?.setCustomExposureWithDuration(durationSlider.value)
		}
	
		updateSliders()
	}
	
	
	@IBAction func sliderValueChanged(_ sender:UISlider) {
		switch sender {
		case biasSlider:
			cameraController?.setExposureTargetBias(sender.value)
		case durationSlider:
			cameraController?.setCustomExposureWithDuration(sender.value)
		case isoSlider:
			cameraController?.setCustomExposureWithISO(sender.value)
		default: break
		}
	}

	
	func cameraSetting(_ setting: String, valueChanged value: AnyObject) {
		if setting == CameraControlObservableSettingExposureDuration {
			if let durationValue = value as? NSValue {
				let duration = CMTimeGetSeconds(durationValue.timeValue)
				durationSlider.value = Float(duration)
			}
		}
		else if setting == CameraControlObservableSettingISO {
			if let iso = value as? Float {
				isoSlider.value = Float(iso)
			}
		}
	}
	
	
	func setInitialValues() {
		if isViewLoaded && cameraController != nil {
			if let autoExposure = cameraController?.isContinuousAutoExposureEnabled() {
				modeSwitch.isOn = autoExposure
				updateSliders()
			}
			
			if let currentDuration = cameraController?.currentExposureDuration() {
				durationSlider.value = currentDuration
			}
			
			if let currentISO = cameraController?.currentISO() {
				isoSlider.value = currentISO
			}
			
			if let currentBias = cameraController?.currentExposureTargetOffset() {
				biasSlider.value = currentBias
			}
		}
	}

	
	func updateSliders() {
		for slider in [durationSlider, isoSlider] as [UISlider] {
			slider.isEnabled = !modeSwitch.isOn
		}
	}
}
