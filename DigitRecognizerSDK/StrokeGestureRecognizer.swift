//
//  StrokeGestureRecognizer.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/13/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit


public class StrokeGestureRecognizer: UIGestureRecognizer {
    
    public override func touchesBegan(touches: NSSet!, withEvent event: UIEvent!) {
        super.touchesBegan(touches, withEvent: event)
        
        if (self.numberOfTouches() != 1) {
            if (self.state == UIGestureRecognizerState.Possible) {
                self.state = UIGestureRecognizerState.Failed
            } else {
                for touch in touches {
                    let touch = touch as UITouch
                    self.ignoreTouch(touch, forEvent: event)
                }
            }
        }
    }
    
    public override func touchesMoved(touches: NSSet!, withEvent event: UIEvent!) {
        super.touchesMoved(touches, withEvent: event)
        if self.state == UIGestureRecognizerState.Possible {
            self.state = UIGestureRecognizerState.Began
        }
    }
    
    public override func touchesEnded(touches: NSSet!, withEvent event: UIEvent!) {
        super.touchesEnded(touches, withEvent: event)
        if (self.state == UIGestureRecognizerState.Possible || self.state == UIGestureRecognizerState.Began || self.state == UIGestureRecognizerState.Changed) {
            self.state = UIGestureRecognizerState.Ended
        }
    }
    
    public override func touchesCancelled(touches: NSSet!, withEvent event: UIEvent!) {
        super.touchesCancelled(touches, withEvent: event)
        self.state = UIGestureRecognizerState.Cancelled
    }
}
