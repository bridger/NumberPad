//
//  NameCanvasViewController.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 7/19/15.
//  Copyright © 2015 Bridger Maxwell. All rights reserved.
//

import UIKit

protocol NameCanvasDelegate {
    func nameCanvasViewControllerDidFinish(nameCanvasViewController: NameCanvasViewController)
}

class NameCanvasAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    var presenting = false
    
    func transitionDuration(_ transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return 0.2
    }

    @objc(animateTransition:) func animateTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        guard let toViewController = transitionContext.viewController(forKey: UITransitionContextToViewControllerKey),
            fromViewController = transitionContext.viewController(forKey: UITransitionContextFromViewControllerKey),
            containerView = transitionContext.containerView() else {
                return
        }
        
        if (presenting) {
            containerView.addAutoLayoutSubview(subview: toViewController.view)
            
            // Slide the toViewController from the bottom
            containerView.addConstraint( toViewController.view.al_centerY == containerView.al_centerY )
            let centeringConstraint = toViewController.view.al_centerX == containerView.al_centerX
            centeringConstraint.priority = UILayoutPriorityRequired - 1
            containerView.addConstraint(centeringConstraint)
            
            let hideConstraint = toViewController.view.al_left == containerView.al_right
            containerView.addConstraint(hideConstraint)
            
            containerView.layoutIfNeeded()
            containerView.backgroundColor = UIColor.clear()
            UIView.animate(withDuration: self.transitionDuration(transitionContext), animations: {
                containerView.removeConstraint(hideConstraint)
                containerView.layoutIfNeeded()
                containerView.backgroundColor = UIColor(white: 1.0, alpha: 0.7)
                
                }, completion: { (bool) in
                    transitionContext.completeTransition(true)
            })
        } else {
            let hideConstraint = fromViewController.view.al_left == containerView.al_right
            
            UIView.animate(withDuration: self.transitionDuration(transitionContext), animations: {
                containerView.addConstraint(hideConstraint)
                containerView.layoutIfNeeded()
                containerView.backgroundColor = UIColor.clear()
                
                }, completion: { (bool) in
                    fromViewController.view.removeFromSuperview()
                    transitionContext.completeTransition(true)
            })
        }
    }
}

class NameCanvasViewController: UIViewController {
    var canvasView: UIView!
    var label: UILabel!
    var doneButton: UIButton!
    var delegate: NameCanvasDelegate?
    
    override func viewDidLoad() {
        self.view.translatesAutoresizingMaskIntoConstraints = false
        
        self.canvasView = UIView()
        self.view.addAutoLayoutSubview(subview: self.canvasView)
        self.canvasView.backgroundColor = UIColor.selectedBackgroundColor()
        self.canvasView.clipsToBounds = true
        
        self.label = UILabel()
        self.view.addAutoLayoutSubview(subview: self.label)
        self.label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyleHeadline)
        self.label.textColor = UIColor.textColor()
        self.label.text = "Draw a name"
        
        self.doneButton = UIButton()
        self.view.addAutoLayoutSubview(subview: self.doneButton)
        self.doneButton.setTitle("Done", for: [])
        self.doneButton.setTitleColor(UIColor.textColor(), for: [])
        self.doneButton.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .horizontal)
        self.doneButton.addTarget(self, action: #selector(NameCanvasViewController.doneButtonPressed), for: [.touchUpInside])
        
        self.view.addVerticalConstraints( |[self.label]-0-[self.canvasView]| )
        
        self.view.addHorizontalConstraints( |[self.label]-0-[self.doneButton]| )
        self.view.addConstraint(self.label.al_baseline == self.doneButton.al_baseline)
        self.view.addConstraint( self.label.al_leading == self.canvasView.al_leading )
        self.view.addConstraint( self.doneButton.al_trailing == self.canvasView.al_trailing )
        
        self.canvasView.addConstraint( self.canvasView.al_width == 300 )
        self.canvasView.addConstraint( self.canvasView.al_height == 110 )
    }
    
    typealias TouchID = NSInteger
    var activeStrokes: [TouchID: Stroke] = [:]
    var completedStrokes: [Stroke] = []
    var boundingRect: CGRect = CGRect.null
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self.canvasView)
            
            if self.canvasView.bounds.contains(point) {
                let touchID = FTPenManager.sharedInstance().classifier.id(for: touch)
                
                let stroke = Stroke()
                activeStrokes[touchID] = stroke
                
                stroke.addPoint(point: point)
                self.boundingRect = self.boundingRect.union(CGRect(x: point.x, y:  point.y, width:  0, height: 0))
                self.canvasView.layer.addSublayer(stroke.layer)
                stroke.layer.strokeColor = UIColor.selectedTextColor().cgColor
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchID = FTPenManager.sharedInstance().classifier.id(for: touch)
            
            if let stroke = activeStrokes[touchID] {
                let point = touch.location(in: self.canvasView)
                
                self.boundingRect = self.boundingRect.union(CGRect(x: point.x, y:  point.y, width:  0, height: 0))
                stroke.addPoint(point: point)
                stroke.updateLayer()
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchID = FTPenManager.sharedInstance().classifier.id(for: touch)
            
            if let stroke = activeStrokes[touchID] {
                completedStrokes.append(stroke)
                activeStrokes[touchID] = nil
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        guard let touches = touches else {
            return
        }
        for touch in touches {
            let touchID = FTPenManager.sharedInstance().classifier.id(for: touch)
            
            if let stroke = activeStrokes[touchID] {
                activeStrokes[touchID] = nil
                stroke.layer.removeFromSuperlayer()
            }
        }
    }

    func doneButtonPressed() {
        guard let delegate = delegate else {
            return
        }
        
        delegate.nameCanvasViewControllerDidFinish(nameCanvasViewController: self)
    }
    
    // The image will be tightly fitting on the x axis, but on the y axis it will be positioned just
    // like it is within the canvas view itself. This way, all drawings will be a consistent height.
    // This returns nil if the user didn't draw anything
    func renderedImage(pointHeight: CGFloat, scale: CGFloat, color: CGColor) -> UIImage? {
        if completedStrokes.count == 0 {
            return nil
        }
        
        let strokeWidth = 2.5 * scale
        let height = Int(pointHeight * scale)
        let ratio = CGFloat(height) / self.canvasView.frame.size.height
        let width = Int(self.boundingRect.size.width * ratio + strokeWidth * 2)
        
        guard width > 0 && height > 0 else {
            return nil
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let graphicsContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        
        // Flip the y axis
        var transform = CGAffineTransform(scaleX: 1, y: -1)
        transform = transform.translateBy(x: 0, y: CGFloat(-height))
        
        // Scale the points down to fit into the image
        transform = transform.scaleBy(x: ratio, y: ratio)
        transform = transform.translateBy(x: -self.boundingRect.origin.x + strokeWidth, y: 0)
        graphicsContext.concatCTM(transform)
        
        for stroke in completedStrokes {
            var firstPoint = true
            for point in stroke.points {
                
                if firstPoint {
                    graphicsContext.moveTo(x: point.x, y: point.y)
                    firstPoint = false
                } else {
                    graphicsContext.addLineTo(x: point.x, y: point.y)
                }
            }
            
            graphicsContext.setLineCap(.round)
            graphicsContext.setStrokeColor(color)
            graphicsContext.setLineWidth(strokeWidth)
            graphicsContext.strokePath()
        }
        
        if let cgImage = graphicsContext.makeImage() {
            return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
        }
        return nil
    }
    
}
