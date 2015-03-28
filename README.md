# Camera Controls Demo

Sample project for the article written for [objc.io](http://www.objc.io/issue-21/camera-capture-on-ios.html)

The `CameraController` implements the camera controls using `AVFoundation`. 

There are two types of live preview implemented, one with `AVCapturePreviewLayer` for full-automatic preview, and one with a `GLKView` for manual processing (as an example, the preview is filtered with a monochrome `CIFilter`). To switch between one or the other, change the class of the view controller embedded in the "Video Preview" container (see the view controller that implement the `CameraPreviewController` protovcol)

Requires Xcode 6.3
