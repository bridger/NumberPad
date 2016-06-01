//
//  Utils.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 1/12/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import UIKit


func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

func euclidianDistanceSquared(a: CGPoint, b: CGPoint) -> CGFloat {
    let dx = a.x - b.x
    let dy = a.y - b.y
    return dx*dx + dy*dy
}

extension FTTouchClassification : CustomStringConvertible {
    public
    var description : String {
        switch self {
        case .unknownDisconnected: return "UnkownDisconnected"
        case .palm: return "Palm"
        case .finger: return "Finger"
        case .eraser: return "Eraser"
        default: return "Unknown"
        }
    }
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

