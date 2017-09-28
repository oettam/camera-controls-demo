//
//  CameraController.swift
//  Camera
//
//  Created by Matteo Caldari on 20/01/15.
//  Copyright (c) 2015 Matteo Caldari. All rights reserved.
//

import AVFoundation
import UIKit
import GLKit

let CameraControllerDidStartSession = "CameraControllerDidStartSession"
let CameraControllerDidStopSession = "CameraControllerDidStopSession"

let CameraControlObservableSettingLensPosition = "CameraControlObservableSettingLensPosition"
let CameraControlObservableSettingExposureTargetOffset = "CameraControlObservableSettingExposureTargetOffset"
let CameraControlObservableSettingExposureDuration = "CameraControlObservableSettingExposureDuration"
let CameraControlObservableSettingISO = "CameraControlObservableSettingISO"
let CameraControlObservableSettingWBGains = "CameraControlObservableSettingWBGains"
let CameraControlObservableSettingAdjustingFocus = "CameraControlObservableSettingAdjustingFocus"
let CameraControlObservableSettingAdjustingExposure = "CameraControlObservableSettingAdjustingExposure"
let CameraControlObservableSettingAdjustingWhiteBalance = "CameraControlObservableSettingAdjustingWhiteBalance"

protocol CameraControllerDelegate : class {
	func cameraController(cameraController:CameraController, didDetectFaces faces:Array<(id:Int,frame:CGRect)>)
}

protocol CameraFramesDelegate : class {
	func cameraController(cameraController: CameraController, didOutputImage image: CIImage)
}

enum CameraControllePreviewType {
	case PreviewLayer
	case Manual
}


@objc protocol CameraSettingValueObserver {
	func cameraSetting(setting:String, valueChanged value:AnyObject)
}


extension AVCaptureDevice.WhiteBalanceGains {
	mutating func clampGainsToRange(minVal:Float, maxVal:Float) {
		blueGain = max(min(blueGain, maxVal), minVal)
		redGain = max(min(redGain, maxVal), minVal)
		greenGain = max(min(greenGain, maxVal), minVal)
	}
}


class WhiteBalanceValues {
	var temperature:Float
	var tint:Float
	
	init(temperature:Float, tint:Float) {
		self.temperature = temperature
		self.tint = tint
	}
	
    convenience init(temperatureAndTintValues:AVCaptureDevice.WhiteBalanceTemperatureAndTintValues) {
		self.init(temperature: temperatureAndTintValues.temperature, tint:temperatureAndTintValues.tint)
	}
}


class CameraController: NSObject {

	weak var delegate:CameraControllerDelegate?
	weak var framesDelegate:CameraFramesDelegate?
	
	var previewType:CameraControllePreviewType
	
	var previewLayer:AVCaptureVideoPreviewLayer? {
		didSet {
			previewLayer?.session = session
		}
	}

	var enableBracketedCapture:Bool = false {
		didSet {
			// TODO: if true, prepare for capture
		}
	}
	
	private var currentCameraDevice:AVCaptureDevice?

	
	// MARK: Private properties
	
    private var sessionQueue = DispatchQueue(label: "com.example.session_access_queue")
	
	private var session:AVCaptureSession!
	private var backCameraDevice:AVCaptureDevice?
	private var frontCameraDevice:AVCaptureDevice?
	private var stillCameraOutput:AVCaptureStillImageOutput!
	private var videoOutput:AVCaptureVideoDataOutput!
	private var metadataOutput:AVCaptureMetadataOutput!
	
	private var lensPositionContext = 0
	private var adjustingFocusContext = 0
	private var adjustingExposureContext = 0
	private var adjustingWhiteBalanceContext = 0
	private var exposureDuration = 0
	private var ISO = 0
	private var exposureTargetOffsetContext = 0
	private var deviceWhiteBalanceGainsContext = 0

	private var controlObservers = [String: [AnyObject]]()
	
	// MARK: - Initialization
	
	required init(previewType:CameraControllePreviewType, delegate:CameraControllerDelegate) {
		self.delegate = delegate
		self.previewType = previewType
	
		super.init()
		
		initializeSession()
	}
	
	
	convenience init(delegate:CameraControllerDelegate) {
		self.init(previewType: .PreviewLayer, delegate: delegate)
	}
	
	
	func initializeSession() {
		
		session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
		
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
		
		switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video,
				completionHandler: { (granted:Bool) -> Void in
					if granted {
						self.configureSession()
					}
					else {
						self.showAccessDeniedMessage()
					}
			})
		case .authorized:
			configureSession()
		case .denied, .restricted:
			showAccessDeniedMessage()
        }
	}
	
	
	// MARK: - Camera Control
    
    func startRunning() {
        performConfiguration { () -> Void in
            self.observeValues()
            self.session.startRunning()
            NotificationCenter
                .default
                .post(name: NSNotification.Name(rawValue: CameraControllerDidStartSession),
                      object: self)
        }
    }

	
	func stopRunning() {
		performConfiguration { () -> Void in
			self.unobserveValues()
			self.session.stopRunning()
		}
	}
	
	
    func registerObserver<T>(observer:T, property:String) where T:NSObject, T:CameraSettingValueObserver {
		var propertyObservers = controlObservers[property]
		if propertyObservers == nil {
			propertyObservers = [AnyObject]()
		}
		
		propertyObservers?.append(observer)
		controlObservers[property] = propertyObservers
	}
	
	
    func unregisterObserver<T>(observer:T, property:String) where T:NSObject, T:CameraSettingValueObserver {
		if let propertyObservers = controlObservers[property] {
			let filteredPropertyObservers = propertyObservers.filter({ (obs) -> Bool in
				obs as! NSObject != observer
			})
			controlObservers[property] = filteredPropertyObservers
		}
	}

	
	// MARK: Focus

	func enableContinuousAutoFocus() {
		performConfigurationOnCurrentCameraDevice { (currentDevice) -> Void in
            if currentDevice.isFocusModeSupported(.continuousAutoFocus) {
                currentDevice.focusMode = .continuousAutoFocus
			}
		}
	}

	
	func isContinuousAutoFocusEnabled() -> Bool {
        return currentCameraDevice!.focusMode == .continuousAutoFocus
	}

	
	func lockFocusAtPointOfInterest(pointInView:CGPoint) {
		var pointInCamera:CGPoint
		if let previewLayer = previewLayer {
            pointInCamera = previewLayer.captureDevicePointConverted(fromLayerPoint: pointInView)
		}
		else {
			// TODO: calculate the point without the preview layer
			pointInCamera = pointInView
		}

		performConfigurationOnCurrentCameraDevice { (currentDevice) -> Void in
            if currentDevice.isFocusPointOfInterestSupported {
				currentDevice.focusPointOfInterest = pointInCamera
                currentDevice.focusMode = .autoFocus
			}
		}
	}

	
	func lockFocusAtLensPosition(lensPosition:CGFloat) {
		performConfigurationOnCurrentCameraDevice { (currentDevice) -> Void in
            currentDevice.setFocusModeLocked(lensPosition: Float(lensPosition)) {
				(time:CMTime) -> Void in
				
			}
		}
	}
	
	
	func currentLensPosition() -> Float? {
		return self.currentCameraDevice?.lensPosition
	}
	
	
	// MARK: Exposure
	

	func enableContinuousAutoExposure() {
		performConfigurationOnCurrentCameraDevice { (currentDevice) -> Void in
            if currentDevice.isExposureModeSupported(.continuousAutoExposure) {
                currentDevice.exposureMode = .continuousAutoExposure
			}
		}
	}
	
	
	func isContinuousAutoExposureEnabled() -> Bool {
        return currentCameraDevice!.exposureMode == .continuousAutoExposure
	}
	
	
	func lockExposureAtPointOfInterest(pointInView:CGPoint) {
		var pointInCamera:CGPoint
		
		if let previewLayer = previewLayer {
            pointInCamera = previewLayer.captureDevicePointConverted(fromLayerPoint: pointInView)
		}
		else {
			// TODO: calculate point without preview layer
			pointInCamera = pointInView
		}
		performConfigurationOnCurrentCameraDevice { (currentDevice) -> Void in
            if currentDevice.isExposurePointOfInterestSupported {
				currentDevice.exposurePointOfInterest = pointInCamera
                currentDevice.exposureMode = .autoExpose
			}
		}
	}
	
	
	func setCustomExposureWithISO(iso:Float) {
		performConfigurationOnCurrentCameraDevice { (currentDevice) -> Void in
            currentDevice.setExposureModeCustom(duration: AVCaptureDevice.currentExposureDuration, iso: iso, completionHandler: nil)
		}
	}
	
	
	func setCustomExposureWithDuration(duration:Float) {
		performConfigurationOnCurrentCameraDevice { (currentDevice) -> Void in
			let activeFormat = currentDevice.activeFormat
			let finalDuration = CMTimeMakeWithSeconds(Float64(duration), 1_000_000)
			let durationRange = CMTimeRangeFromTimeToTime(activeFormat.minExposureDuration, activeFormat.maxExposureDuration)

			if CMTimeRangeContainsTime(durationRange, finalDuration) {
                currentDevice.setExposureModeCustom(duration: finalDuration, iso: AVCaptureDevice.currentISO, completionHandler: nil)
			}
		}
	}
	
	
	func setExposureTargetBias(bias:Float) {
		performConfigurationOnCurrentCameraDevice { (currentDevice) -> Void in
			currentDevice.setExposureTargetBias(bias, completionHandler: nil)
		}
	}
	
	
	func currentExposureDuration() -> Float? {
		if let exposureDuration = currentCameraDevice?.exposureDuration {
			return Float(CMTimeGetSeconds(exposureDuration))
		}
		else {
			return nil
		}
	}
	
	
	func currentISO() -> Float? {
        return currentCameraDevice?.iso
	}

	
	func currentExposureTargetOffset() -> Float? {
		return currentCameraDevice?.exposureTargetOffset
	}
	
	
	// MARK: White balance
	
	func enableContinuousAutoWhiteBalance() {
		performConfigurationOnCurrentCameraDevice { (currentDevice) -> Void in
            if currentDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                currentDevice.whiteBalanceMode = .continuousAutoWhiteBalance
			}
		}
	}
	
	
	func isContinuousAutoWhiteBalanceEnabled() -> Bool {
        return currentCameraDevice!.whiteBalanceMode == .continuousAutoWhiteBalance
	}

	
	func setCustomWhiteBalanceWithTemperature(temperature:Float) {
		
		performConfigurationOnCurrentCameraDevice { (currentDevice) -> Void in
            if currentDevice.isWhiteBalanceModeSupported(.locked) {
				let currentGains = currentDevice.deviceWhiteBalanceGains
                let currentTint = currentDevice.temperatureAndTintValues(for: currentGains).tint
                let temperatureAndTintValues = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: temperature, tint: currentTint)
				
                var deviceGains = currentDevice.deviceWhiteBalanceGains(for: temperatureAndTintValues)
                let maxWhiteBalanceGain = currentDevice.maxWhiteBalanceGain
                deviceGains.clampGainsToRange(minVal: 1, maxVal: maxWhiteBalanceGain)
				
                currentDevice.setWhiteBalanceModeLocked(with: deviceGains) {
					(timestamp:CMTime) -> Void in
				}
			}
		}
	}

	
	func setCustomWhiteBalanceWithTint(tint:Float) {
		
		performConfigurationOnCurrentCameraDevice { (currentDevice) -> Void in
            if currentDevice.isWhiteBalanceModeSupported(.locked) {
                let maxWhiteBalanceGain = currentDevice.maxWhiteBalanceGain
				var currentGains = currentDevice.deviceWhiteBalanceGains
                currentGains.clampGainsToRange(minVal: 1, maxVal: maxWhiteBalanceGain)
                let currentTemperature = currentDevice.temperatureAndTintValues(for: currentGains).temperature
                let temperatureAndTintValues = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: currentTemperature, tint: tint)
				
                var deviceGains = currentDevice.deviceWhiteBalanceGains(for: temperatureAndTintValues)
                deviceGains.clampGainsToRange(minVal: 1, maxVal: maxWhiteBalanceGain)

                currentDevice.setWhiteBalanceModeLocked(with: deviceGains) {
					(timestamp:CMTime) -> Void in
				}
			}
		}
	}

	
	func currentTemperature() -> Float? {
		if let gains = currentCameraDevice?.deviceWhiteBalanceGains {
            let tempAndTint = currentCameraDevice?.temperatureAndTintValues(for: gains)
			return tempAndTint?.temperature
		}
		return nil
	}
	
	
	func currentTint() -> Float? {
		if let gains = currentCameraDevice?.deviceWhiteBalanceGains {
            let tempAndTint = currentCameraDevice?.temperatureAndTintValues(for: gains)
			return tempAndTint?.tint
		}
		return nil
	}

	// MARK: Still image capture
	
    func captureStillImage(completionHandler handler:@escaping ((_ image:UIImage, _ metadata:NSDictionary) -> Void)) {
		if enableBracketedCapture {
			bracketedCaptureStillImage(completionHandler:handler);
		}
		else {
			captureSingleStillImage(completionHandler:handler)
		}
	}
	
	/*!
	Capture a photo
	
	:param: handler executed on the main queue
	*/
    func captureSingleStillImage(completionHandler handler: @escaping ((_ image:UIImage, _ metadata:NSDictionary) -> Void)) {
        sessionQueue.async() { () -> Void in

            let connection = self.stillCameraOutput.connection(with: AVMediaType.video)
			
            connection?.videoOrientation = AVCaptureVideoOrientation(rawValue: UIDevice.current.orientation.rawValue)!
			
            self.stillCameraOutput.captureStillImageAsynchronously(from: connection!) {
				(imageDataSampleBuffer, error) -> Void in
				
				if error == nil {
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer!)

                    let metadata = CMCopyDictionaryOfAttachments(nil, imageDataSampleBuffer!, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))

                    if let metadata = metadata, let image = UIImage(data: imageData!) {
                        DispatchQueue.main.async() { () -> Void in
                            handler(image, metadata)
						}
					}
				}
				else {
                    NSLog("error while capturing still image: \(String(describing: error))")
				}
			}
		}
	}
	
	
    func bracketedCaptureStillImage(completionHandler handler: @escaping ((_ image:UIImage, _ metadata:NSDictionary) -> Void)) {
        sessionQueue.async() { () -> Void in
			
            let connection = self.stillCameraOutput.connection(with: AVMediaType.video)
            connection?.videoOrientation = AVCaptureVideoOrientation(rawValue: UIDevice.current.orientation.rawValue)!

			let settings = [-1.0, 0.0, 1.0].map {
				(bias:Float) -> AVCaptureAutoExposureBracketedStillImageSettings in
				
                AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: bias)
			}
			
            self.stillCameraOutput.captureStillImageBracketAsynchronously(from: connection!, withSettingsArray: settings, completionHandler: {
				(sampleBuffer, captureSettings, error) -> Void in

				// TODO: stitch images
				
				if error == nil {
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer!)
					
                    let metadata = CMCopyDictionaryOfAttachments(nil, sampleBuffer!, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
					
                    if let metadata = metadata, let image = UIImage(data: imageData!) {
                        DispatchQueue.main.async() { () -> Void in
                            handler(image, metadata)
						}
					}
				}
				else {
                    NSLog("error while capturing still image: \(String(describing: error))")
				}
			})
		}
	}
	

	// MARK: - Notifications
	
	func subjectAreaDidChange(notification:NSNotification) {
	}
	
	
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		var key = ""
        var newValue: AnyObject = change![NSKeyValueChangeKey.newKey]! as AnyObject
		
		switch context! {
        case &lensPositionContext:
			key = CameraControlObservableSettingLensPosition
			
		case &exposureDuration:
			key = CameraControlObservableSettingExposureDuration
			
		case &ISO:
			key = CameraControlObservableSettingISO
			
		case &deviceWhiteBalanceGainsContext:
			key = CameraControlObservableSettingWBGains
			
			if let newNSValue = newValue as? NSValue {
                var gains:AVCaptureDevice.WhiteBalanceGains? = nil
				newNSValue.getValue(&gains)
                if let newGains = gains,
                    let newTemperatureAndTint = currentCameraDevice?.temperatureAndTintValues(for: newGains) {
					newValue = WhiteBalanceValues(temperatureAndTintValues: newTemperatureAndTint)
				}
			}
		case &adjustingFocusContext:
			key = CameraControlObservableSettingAdjustingFocus
		case &adjustingExposureContext:
			key = CameraControlObservableSettingAdjustingExposure
		case &adjustingWhiteBalanceContext:
			key = CameraControlObservableSettingAdjustingWhiteBalance
		default:
			key = "unknown context"
		}
		
        notifyObservers(key: key, value: newValue)
	}
}


	// MARK: - Delegate methods

extension CameraController: AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
	
	func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
		
		if let framesDelegate = framesDelegate {
			let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            let image = CIImage(cvPixelBuffer: pixelBuffer!)
			
            framesDelegate.cameraController(cameraController: self, didOutputImage: image)
		}
	}
	
	
	func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
		
		var faces = Array<(id:Int,frame:CGRect)>()
		
		for metadataObject in metadataObjects as! [AVMetadataObject] {
            if metadataObject.type == AVMetadataObject.ObjectType.face {
				if let faceObject = metadataObject as? AVMetadataFaceObject {
					// TODO: transform object without preview layer?
					if let previewLayer = previewLayer {
                        let transformedMetadataObject = previewLayer.transformedMetadataObject(for: metadataObject)
                        let face:(id: Int, frame: CGRect) = (faceObject.faceID, transformedMetadataObject!.bounds)
						faces.append(face)
					}
				}
			}
		}
		
		if let delegate = self.delegate {
            DispatchQueue.main.async() {
                delegate.cameraController(cameraController: self, didDetectFaces: faces)
			}
		}
	}
}



// MARK: - Private

private extension CameraController {
	
    func performConfiguration(block: @escaping (() -> Void)) {
        sessionQueue.async() { () -> Void in
			block()
		}
	}

	
    func performConfigurationOnCurrentCameraDevice(block: @escaping ((_ currentDevice:AVCaptureDevice) -> Void)) {
		if let currentDevice = self.currentCameraDevice {
			performConfiguration { () -> Void in
                do {
                    try currentDevice.lockForConfiguration()
                    block(currentDevice)
                    currentDevice.unlockForConfiguration()
                }
                catch {}
			}
		}
	}
	
	
	func configureSession() {
		configureDeviceInput()
		configureStillImageCameraOutput()
		configureFaceDetection()
		configureVideoOutput()
	}
	
	
	func configureDeviceInput() {
		
		performConfiguration { () -> Void in
			
            let availableCameraDevices = AVCaptureDevice.devices(for: AVMediaType.video)
            for device in availableCameraDevices {
                if device.position == .back {
					self.backCameraDevice = device
				}
                else if device.position == .front {
					self.frontCameraDevice = device
				}
			}
			
			
			// let's set the back camera as the initial device
			
			self.currentCameraDevice = self.backCameraDevice
			
            let possibleCameraInput: AnyObject? = try? AVCaptureDeviceInput(device: self.currentCameraDevice!)
			if let backCameraInput = possibleCameraInput as? AVCaptureDeviceInput {
				if self.session.canAddInput(backCameraInput) {
					self.session.addInput(backCameraInput)
				}
			}
		}
	}
	
	
	func configureStillImageCameraOutput() {
		performConfiguration { () -> Void in
			self.stillCameraOutput = AVCaptureStillImageOutput()
			self.stillCameraOutput.outputSettings = [
				AVVideoCodecKey  : AVVideoCodecJPEG,
				AVVideoQualityKey: 0.9
			]
			
			if self.session.canAddOutput(self.stillCameraOutput) {
				self.session.addOutput(self.stillCameraOutput)
			}
		}
	}
	
	
	func configureVideoOutput() {
		performConfiguration { () -> Void in
			self.videoOutput = AVCaptureVideoDataOutput()
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer delegate"))
			if self.session.canAddOutput(self.videoOutput) {
				self.session.addOutput(self.videoOutput)
			}
		}
	}
	
	
	func configureFaceDetection() {
		performConfiguration { () -> Void in
			self.metadataOutput = AVCaptureMetadataOutput()
			self.metadataOutput.setMetadataObjectsDelegate(self, queue: self.sessionQueue)
			
			if self.session.canAddOutput(self.metadataOutput) {
				self.session.addOutput(self.metadataOutput)
			}
			
            if self.metadataOutput.availableMetadataObjectTypes.contains(AVMetadataObject.ObjectType.face) {
                self.metadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.face]
			}
		}
	}
	
	
	func observeValues() {
        currentCameraDevice?.addObserver(self, forKeyPath: "lensPosition", options: .new, context: &lensPositionContext)
        currentCameraDevice?.addObserver(self, forKeyPath: "adjustingFocus", options: .new, context: &adjustingFocusContext)
        currentCameraDevice?.addObserver(self, forKeyPath: "adjustingExposure", options: .new, context: &adjustingExposureContext)
		currentCameraDevice?.addObserver(self, forKeyPath: "adjustingWhiteBalance", options: .new, context: &adjustingWhiteBalanceContext)
		currentCameraDevice?.addObserver(self, forKeyPath: "exposureDuration", options: .new, context: &exposureDuration)
		currentCameraDevice?.addObserver(self, forKeyPath: "ISO", options: .new, context: &ISO)
		currentCameraDevice?.addObserver(self, forKeyPath: "deviceWhiteBalanceGains", options: .new, context: &deviceWhiteBalanceGainsContext)
	}
	
	
	func unobserveValues() {
		currentCameraDevice?.removeObserver(self, forKeyPath: "lensPosition", context: &lensPositionContext)
		currentCameraDevice?.removeObserver(self, forKeyPath: "adjustingFocus", context: &adjustingFocusContext)
		currentCameraDevice?.removeObserver(self, forKeyPath: "adjustingExposure", context: &adjustingExposureContext)
		currentCameraDevice?.removeObserver(self, forKeyPath: "adjustingWhiteBalance", context: &adjustingWhiteBalanceContext)
		currentCameraDevice?.removeObserver(self, forKeyPath: "exposureDuration", context: &exposureDuration)
		currentCameraDevice?.removeObserver(self, forKeyPath: "ISO", context: &ISO)
		currentCameraDevice?.removeObserver(self, forKeyPath: "deviceWhiteBalanceGains", context: &deviceWhiteBalanceGainsContext)
	}
	
	
	func showAccessDeniedMessage() {
		
	}


	func notifyObservers(key:String, value:AnyObject) {
		if let lensPositionObservers = controlObservers[key] {
			for obj in lensPositionObservers as [AnyObject] {
				if let observer = obj as? CameraSettingValueObserver {
                    notifyObserver(observer: observer, setting: key, value: value)
				}
			}
		}
	}
	
	
    func notifyObserver<T>(observer:T, setting:String, value:AnyObject) where T:CameraSettingValueObserver {
        observer.cameraSetting(setting: setting, valueChanged: value)
	}
}


