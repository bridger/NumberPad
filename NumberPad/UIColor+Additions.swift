//
//  UIColor+Additions.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 7/2/15.
//  Copyright © 2015 Bridger Maxwell. All rights reserved.
//

import Foundation

extension UIColor {
    class func backgroundColor() -> UIColor {
        return UIColor(red: CGFloat(0.95), green: 0.98, blue: 0.96, alpha: 1.0)
    }
    
    class func selectedBackgroundColor() -> UIColor {
        return UIColor(red: CGFloat(0.47), green: 0.62, blue: 0.62, alpha: 1.0)
    }
    
    class func tintBackgroundColor() -> UIColor {
        return UIColor(red: CGFloat(0.88), green: 0.89, blue: 0.80, alpha: 1.0)
    }
    
    class func adderInputColor() -> UIColor {
        return UIColor(red: CGFloat(0.15), green: 0.66, blue: 0.88, alpha: 1.0)
    }
    
    class func adderOutputColor() -> UIColor {
        return UIColor(red: CGFloat(0.17), green: 0.31, blue: 0.75, alpha: 1.0)
    }
    
    class func multiplierInputColor() -> UIColor {
        return UIColor(red: CGFloat(0.36), green: 0.79, blue: 0.16, alpha: 1.0)
    }
    
    class func multiplierOutputColor() -> UIColor {
        return UIColor(red: CGFloat(0.23), green: 0.51, blue: 0.11, alpha: 1.0)
    }
    
    class func exponentBaseColor() -> UIColor {
        return UIColor(red: CGFloat(1.0), green: 0.52, blue: 0.00, alpha: 1.0)
    }
    
    class func exponentExponentColor() -> UIColor {
        return UIColor(red: CGFloat(0.80), green: 0.03, blue: 0.0, alpha: 1.0)
    }
    
    class func exponentResultColor() -> UIColor {
        return UIColor(red: CGFloat(1.0), green: 0.11, blue: 0.11, alpha: 1.0)
    }
    
    class func textColor() -> UIColor {
        return UIColor(red: CGFloat(0.16), green: 0.25, blue: 0.30, alpha: 1.0)
    }
    
    class func selectedTextColor() -> UIColor {
        return backgroundColor()
        //return UIColor(red: 0.80, green: 0.83, blue: 0.81, alpha: 1.0)
    }
}
