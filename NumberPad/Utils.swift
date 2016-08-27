//
//  Utils.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 1/12/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import UIKit


func delay(after: Double, closure: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + after, execute: closure)
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

public extension Comparable {
    func clamp(lower: Self, upper: Self) -> Self {
        return min(max(self, lower), upper)
    }
}

public extension Double {
    func lerp(lower: Double, upper: Double) -> Double {
        return lower + (upper - lower) * self
    }
    
    func clampedLerp(lower: Double, upper: Double) -> Double {
        return self.clamp(lower: 0, upper: 1.0).lerp(lower: lower, upper: upper)
    }
}

