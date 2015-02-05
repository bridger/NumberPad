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

extension FTTouchClassification : Printable {
    public
    var description : String {
        switch self {
        case .UnknownDisconnected: return "UnkownDisconnected"
        case .Palm: return "Palm"
        case .Finger: return "Finger"
        case .Eraser: return "Eraser"
        default: return "Unknown"
        }
    }
}

extension UIColor {
    
    func colorWithSaturationComponent(newSaturation: CGFloat) -> UIColor? {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: newSaturation, brightness: brightness, alpha: alpha)
        }
        return nil
    }
    
}

