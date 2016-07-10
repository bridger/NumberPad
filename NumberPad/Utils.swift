//
//  Utils.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 1/12/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import UIKit


func delay(after: Double, closure: () -> Void) {
    DispatchQueue.main.after(when: .now() + after, execute: closure)
}

func euclidianDistanceSquared(a: CGPoint, b: CGPoint) -> CGFloat {
    let dx = a.x - b.x
    let dy = a.y - b.y
    return dx*dx + dy*dy
}

extension UIColor {
    
    func colorWithSaturationComponent(saturation: CGFloat, brightness: CGFloat ) -> UIColor {
        var hue: CGFloat = 0
        var oldSaturation: CGFloat = 0
        var oldBrightness: CGFloat = 0
        var alpha: CGFloat = 0
        if self.getHue(&hue, saturation: &oldSaturation, brightness: &oldBrightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        }
        return self
    }
    
}

