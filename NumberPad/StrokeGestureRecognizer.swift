//
//  StrokeGestureRecognizer.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/13/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit


class StrokeGestureRecognizer: UIGestureRecognizer {
    
    override func touchesBegan(touches: NSSet!, withEvent event: UIEvent!) {
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
    
    override func touchesMoved(touches: NSSet!, withEvent event: UIEvent!) {
        super.touchesMoved(touches, withEvent: event)
        if self.state == UIGestureRecognizerState.Possible {
            self.state = UIGestureRecognizerState.Began
        }
    }
    
    override func touchesEnded(touches: NSSet!, withEvent event: UIEvent!) {
        super.touchesEnded(touches, withEvent: event)
        if (self.state == UIGestureRecognizerState.Possible || self.state == UIGestureRecognizerState.Began || self.state == UIGestureRecognizerState.Changed) {
            self.state = UIGestureRecognizerState.Ended
        }
    }
    
    override func touchesCancelled(touches: NSSet!, withEvent event: UIEvent!) {
        super.touchesCancelled(touches, withEvent: event)
        self.state = UIGestureRecognizerState.Cancelled
    }
}
