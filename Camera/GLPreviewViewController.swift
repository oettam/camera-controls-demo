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
	
	private var glContext:EAGLContext?
	private var ciContext:CIContext?
	private var renderBuffer:GLuint = GLuint()
	
	private var filter = CIFilter(name:"CIPhotoEffectMono")
	
	private var glView:GLKView {
		get {
			return view as! GLKView
		}
	}

	override func loadView() {
		self.view = GLKView()
	}

	override func viewDidLoad() {
        super.viewDidLoad()
	
        glContext = EAGLContext(api: .openGLES2)
		
        glView.context = glContext!
        glView.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
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
		
        filter?.setValue(image, forKey: "inputImage")
        let outputImage = filter?.outputImage

        ciContext?.draw(outputImage!, in:image.extent, from: image.extent)

		glView.display()
	}
}
