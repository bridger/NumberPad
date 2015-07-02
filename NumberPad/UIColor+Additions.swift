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
        return UIColor(red: 0.80, green: 0.83, blue: 0.81, alpha: 1.0)
    }
    
    class func selectedBackgroundColor() -> UIColor {
        return UIColor(red: 0.47, green: 0.62, blue: 0.62, alpha: 1.0)
    }
    
    class func tintBackgroundColor() -> UIColor {
        return UIColor(red: 0.88, green: 0.89, blue: 0.80, alpha: 1.0)
    }
    
    class func adderInputColor() -> UIColor {
        return UIColor(red: 0.25, green: 0.75, blue: 0.80, alpha: 1.0)
    }
    
    class func adderOutputColor() -> UIColor {
        return UIColor(red: 0.0, green: 0.66, blue: 0.78, alpha: 1.0)
    }
    
    class func multiplierInputColor() -> UIColor {
        return UIColor(red: 0.68, green: 0.8, blue: 0.22, alpha: 1.0)
    }
    
    class func multiplierOutputColor() -> UIColor {
        return UIColor(red: 0.56, green: 0.75, blue: 0.0, alpha: 1.0)
    }
    
    class func exponentBaseColor() -> UIColor {
        return UIColor(red: 0.95, green: 0.53, blue: 0.19, alpha: 1.0)
    }
    
    class func exponentExponentColor() -> UIColor {
        return UIColor.whiteColor()
    }
    
    class func exponentResultColor() -> UIColor {
        return UIColor(red: 0.98, green: 0.41, blue: 0.0, alpha: 1.0)
    }
    
    class func textColor() -> UIColor {
        return UIColor(red: 0.16, green: 0.25, blue: 0.30, alpha: 1.0)
    }
    
    class func selectedTextColor() -> UIColor {
        return UIColor(red: 0.80, green: 0.83, blue: 0.81, alpha: 1.0)
    }
}
