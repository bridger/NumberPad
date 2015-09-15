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
    
    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return 0.2
    }

    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        guard let toViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey),
            fromViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey),
            containerView = transitionContext.containerView() else {
                return
        }
        
        if (presenting) {
            containerView.addAutoLayoutSubview(toViewController.view)
            
            // Slide the toViewController from the bottom
            containerView.addConstraint( toViewController.view.al_centerY == containerView.al_centerY )
            let centeringConstraint = toViewController.view.al_centerX == containerView.al_centerX
            centeringConstraint.priority = UILayoutPriorityRequired - 1
            containerView.addConstraint(centeringConstraint)
            
            let hideConstraint = toViewController.view.al_left == containerView.al_right
            containerView.addConstraint(hideConstraint)
            
            containerView.layoutIfNeeded()
            containerView.backgroundColor = UIColor.clearColor()
            UIView.animateWithDuration(self.transitionDuration(transitionContext), animations: {
                containerView.removeConstraint(hideConstraint)
                containerView.layoutIfNeeded()
                containerView.backgroundColor = UIColor(white: 1.0, alpha: 0.7)
                
                }, completion: { (bool) in
                    transitionContext.completeTransition(true)
            })
        } else {
            let hideConstraint = fromViewController.view.al_left == containerView.al_right
            
            UIView.animateWithDuration(self.transitionDuration(transitionContext), animations: {
                containerView.addConstraint(hideConstraint)
                containerView.layoutIfNeeded()
                containerView.backgroundColor = UIColor.clearColor()
                
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
        self.view.addAutoLayoutSubview(self.canvasView)
        self.canvasView.backgroundColor = UIColor.selectedBackgroundColor()
        self.canvasView.clipsToBounds = true
        
        self.label = UILabel()
        self.view.addAutoLayoutSubview(self.label)
        self.label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        self.label.textColor = UIColor.textColor()
        self.label.text = "Draw a name"
        
        self.doneButton = UIButton()
        self.view.addAutoLayoutSubview(self.doneButton)
        self.doneButton.setTitle("Done", forState: .Normal)
        self.doneButton.setTitleColor(UIColor.textColor(), forState: .Normal)
        self.doneButton.setContentHuggingPriority(UILayoutPriorityDefaultHigh, forAxis: .Horizontal)
        self.doneButton.addTarget(self, action: "doneButtonPressed", forControlEvents: [.TouchUpInside])
        
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
    var boundingRect: CGRect = CGRectNull
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let point = touch.locationInView(self.canvasView)
            
            if CGRectContainsPoint(self.canvasView.bounds, point) {
                let touchID = FTPenManager.sharedInstance().classifier.idForTouch(touch)
                
                let stroke = Stroke()
                activeStrokes[touchID] = stroke
                
                stroke.addPoint(point)
                self.boundingRect = CGRectUnion(self.boundingRect,  CGRectMake(point.x, point.y, 0, 0))
                self.canvasView.layer.addSublayer(stroke.layer)
                stroke.layer.strokeColor = UIColor.selectedTextColor().CGColor
            }
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let touchID = FTPenManager.sharedInstance().classifier.idForTouch(touch)
            
            if let stroke = activeStrokes[touchID] {
                let point = touch.locationInView(self.canvasView)
                
                self.boundingRect = CGRectUnion(self.boundingRect,  CGRectMake(point.x, point.y, 0, 0))
                stroke.addPoint(point)
                stroke.updateLayer()
            }
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let touchID = FTPenManager.sharedInstance().classifier.idForTouch(touch)
            
            if let stroke = activeStrokes[touchID] {
                completedStrokes.append(stroke)
                activeStrokes[touchID] = nil
            }
        }
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        guard let touches = touches else {
            return
        }
        for touch in touches {
            let touchID = FTPenManager.sharedInstance().classifier.idForTouch(touch)
            
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
        
        delegate.nameCanvasViewControllerDidFinish(self)
    }
    
    // The image will be tightly fitting on the x axis, but on the y axis it will be positioned just
    // like it is within the canvas view itself. This way, all drawings will be a consistent height.
    // This returns nil if the user didn't draw anything
    func renderedImage(pointHeight: CGFloat, scale: CGFloat, color: CGColorRef) -> UIImage? {
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
        let graphicsContext = CGBitmapContextCreate(nil, width, height, 8, 0, colorSpace, CGImageAlphaInfo.PremultipliedLast.rawValue)
        
        // Flip the y axis
        var transform = CGAffineTransformMakeScale(1, -1)
        transform = CGAffineTransformTranslate(transform, 0, CGFloat(-height))
        
        // Scale the points down to fit into the image
        transform = CGAffineTransformScale(transform, ratio, ratio)
        transform = CGAffineTransformTranslate(transform, -self.boundingRect.origin.x + strokeWidth, 0)
        CGContextConcatCTM(graphicsContext, transform)
        
        for stroke in completedStrokes {
            var firstPoint = true
            for point in stroke.points {
                
                if firstPoint {
                    CGContextMoveToPoint(graphicsContext, point.x, point.y)
                    firstPoint = false
                } else {
                    CGContextAddLineToPoint(graphicsContext, point.x, point.y)
                }
            }
            
            CGContextSetLineCap(graphicsContext, .Round)
            CGContextSetStrokeColorWithColor(graphicsContext, color)
            CGContextSetLineWidth(graphicsContext, strokeWidth)
            CGContextStrokePath(graphicsContext)
        }
        
        if let cgImage = CGBitmapContextCreateImage(graphicsContext) {
            return UIImage(CGImage: cgImage, scale: scale, orientation: .Up)
        }
        return nil
    }
    
}
