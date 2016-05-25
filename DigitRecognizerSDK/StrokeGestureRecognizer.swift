//
//  StrokeGestureRecognizer.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/13/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit


public class StrokeGestureRecognizer: UIGestureRecognizer {
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if (self.numberOfTouches() != 1) {
            if (self.state == UIGestureRecognizerState.possible) {
                self.state = UIGestureRecognizerState.failed
            } else {
                for touch in touches {
                    let touch = touch as UITouch
                    self.ignore(touch, for: event)
                }
            }
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        if self.state == UIGestureRecognizerState.possible {
            self.state = UIGestureRecognizerState.began
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        if (self.state == UIGestureRecognizerState.possible || self.state == UIGestureRecognizerState.began || self.state == UIGestureRecognizerState.changed) {
            self.state = UIGestureRecognizerState.ended
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        self.state = UIGestureRecognizerState.cancelled
    }
}
