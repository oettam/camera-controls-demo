//
//  ControlsSegue.swift
//  Camera
//
//  Created by Matteo Caldari on 05/02/15.
//  Copyright (c) 2015 Matteo Caldari. All rights reserved.
//

import UIKit

class ControlsSegue: UIStoryboardSegue {

	var hostView:UIView?
	var currentViewController:UIViewController?
	
    override init(identifier: String?, source: UIViewController, destination: UIViewController) {
		super.init(identifier: identifier, source: source, destination: destination)
	}
	
	
	override func perform() {
        if let currentControlsViewController = currentViewController {
            currentControlsViewController.willMove(toParentViewController: nil)
            currentControlsViewController.removeFromParentViewController()
            currentControlsViewController.view.removeFromSuperview()
        }
        
        source.addChildViewController(destination)
        hostView!.addSubview(destination.view)
        destination.view.frame = hostView!.bounds
        destination.didMove(toParentViewController: source)
	}
}
