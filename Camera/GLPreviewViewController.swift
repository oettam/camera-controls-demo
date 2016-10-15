//
//  GLPreviewViewController.swift
//  Camera
//
//  Created by Matteo Caldari on 28/01/15.
//  Copyright (c) 2015 Matteo Caldari. All rights reserved.
//

import UIKit
import GLKit
import CoreImage
import OpenGLES

class GLPreviewViewController: UIViewController, CameraPreviewViewController, CameraFramesDelegate {


	var cameraController:CameraController? {
		didSet {
			cameraController?.framesDelegate = self
		}
	}
	
	fileprivate var glContext:EAGLContext?
	fileprivate var ciContext:CIContext?
	fileprivate var renderBuffer:GLuint = GLuint()
	
	fileprivate var filter = CIFilter(name:"CIPhotoEffectMono")!
	fileprivate var glView:GLKView {
			return view as! GLKView
	}

	override func loadView() {
		self.view = GLKView()
	}

	override func viewDidLoad() {
        super.viewDidLoad()
	
		glContext = EAGLContext(api: .openGLES2)
		
		
		glView.context = glContext!
//		glView.drawableDepthFormat = .Format24
		glView.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
		if let window = glView.window {
			glView.frame = window.bounds
		}
		
		ciContext = CIContext(eaglContext: glContext!)
	}


	// MARK: CameraControllerDelegate

	func cameraController(cameraController: CameraController, didOutputImage image: CIImage) {

		if glContext != EAGLContext.current() {
			EAGLContext.setCurrent(glContext)
		}
		
		glView.bindDrawable()
		
		filter.setValue(image, forKey: "inputImage")
		let outputImage = filter.outputImage!
        
        ciContext?.draw(outputImage, in: image.extent, from: image.extent)

		glView.display()
	}

}
