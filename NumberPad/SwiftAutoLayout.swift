//  Copyright (c) 2014 Indragie Karunaratne. All rights reserved.
//  Licensed under the MIT license, see LICENSE file for more info.

#if os(OSX)
    import AppKit
    public typealias ALView = NSView
#elseif os(iOS)
    import UIKit
    public typealias ALView = UIView
#endif

public struct ALLayoutItem {
    public let view: ALView
    public let attribute: NSLayoutAttribute
    public let multiplier: CGFloat
    public let constant: CGFloat
    
    init (view: ALView, attribute: NSLayoutAttribute, multiplier: CGFloat, constant: CGFloat) {
        self.view = view
        self.attribute = attribute
        self.multiplier = multiplier
        self.constant = constant
    }
    
    init (view: ALView, attribute: NSLayoutAttribute) {
        self.view = view
        self.attribute = attribute
        self.multiplier = 1.0
        self.constant = 0.0
    }
    
    // relateTo(), equalTo(), greaterThanOrEqualTo(), and lessThanOrEqualTo() used to be overloaded functions
    // instead of having two separately named functions (e.g. relateTo() and relateToConstant()) but they had
    // to be renamed due to a compiler bug where the compiler chose the wrong function to call.
    //
    // Repro case: http://cl.ly/3S0a1T0Q0S1D
    // rdar://17412596, OpenRadar: http://www.openradar.me/radar?id=5275533159956480
    
    /// Builds a constraint by relating the item to another item.
    public func relateTo(right: ALLayoutItem, relation: NSLayoutRelation) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: view, attribute: attribute, relatedBy: relation, toItem: right.view, attribute: right.attribute, multiplier: right.multiplier, constant: right.constant)
    }
    
    /// Builds a constraint by relating the item to a constant value.
    public func relateToConstant(right: CGFloat, relation: NSLayoutRelation) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: view, attribute: attribute, relatedBy: relation, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: right)
    }
    
    /// Equivalent to NSLayoutRelation.Equal
    public func equalTo(right: ALLayoutItem) -> NSLayoutConstraint {
        return relateTo(right: right, relation: .equal)
    }
    
    /// Equivalent to NSLayoutRelation.Equal
    public func equalToConstant(right: CGFloat) -> NSLayoutConstraint {
        return relateToConstant(right: right, relation: .equal)
    }
    
    /// Equivalent to NSLayoutRelation.GreaterThanOrEqual
    public func greaterThanOrEqualTo(right: ALLayoutItem) -> NSLayoutConstraint {
        return relateTo(right: right, relation: .greaterThanOrEqual)
    }
    
    /// Equivalent to NSLayoutRelation.GreaterThanOrEqual
    public func greaterThanOrEqualToConstant(right: CGFloat) -> NSLayoutConstraint {
        return relateToConstant(right: right, relation: .greaterThanOrEqual)
    }
    
    /// Equivalent to NSLayoutRelation.LessThanOrEqual
    public func lessThanOrEqualTo(right: ALLayoutItem) -> NSLayoutConstraint {
        return relateTo(right: right, relation: .lessThanOrEqual)
    }
    
    /// Equivalent to NSLayoutRelation.LessThanOrEqual
    public func lessThanOrEqualToConstant(right: CGFloat) -> NSLayoutConstraint {
        return relateToConstant(right: right, relation: .lessThanOrEqual)
    }
}

/// Multiplies the operand's multiplier by the RHS value
public func * (left: ALLayoutItem, right: CGFloat) -> ALLayoutItem {
	return ALLayoutItem(view: left.view, attribute: left.attribute, multiplier: left.multiplier * right, constant: left.constant)
}

/// Divides the operand's multiplier by the RHS value
public func / (left: ALLayoutItem, right: CGFloat) -> ALLayoutItem {
	return ALLayoutItem(view: left.view, attribute: left.attribute, multiplier: left.multiplier / right, constant: left.constant)
}

/// Adds the RHS value to the operand's constant
public func + (left: ALLayoutItem, right: CGFloat) -> ALLayoutItem {
	return ALLayoutItem(view: left.view, attribute: left.attribute, multiplier: left.multiplier, constant: left.constant + right)
}

/// Subtracts the RHS value from the operand's constant
public func - (left: ALLayoutItem, right: CGFloat) -> ALLayoutItem {
	return ALLayoutItem(view: left.view, attribute: left.attribute, multiplier: left.multiplier, constant: left.constant - right)
}

/// Equivalent to NSLayoutRelation.Equal
public func == (left: ALLayoutItem, right: ALLayoutItem) -> NSLayoutConstraint {
	return left.equalTo(right: right)
}

/// Equivalent to NSLayoutRelation.Equal
public func == (left: ALLayoutItem, right: CGFloat) -> NSLayoutConstraint {
    return left.equalToConstant(right: right)
}

/// Equivalent to NSLayoutRelation.GreaterThanOrEqual
public func >= (left: ALLayoutItem, right: ALLayoutItem) -> NSLayoutConstraint {
	return left.greaterThanOrEqualTo(right: right)
}

/// Equivalent to NSLayoutRelation.GreaterThanOrEqual
public func >= (left: ALLayoutItem, right: CGFloat) -> NSLayoutConstraint {
    return left.greaterThanOrEqualToConstant(right: right)
}

/// Equivalent to NSLayoutRelation.LessThanOrEqual
public func <= (left: ALLayoutItem, right: ALLayoutItem) -> NSLayoutConstraint {
	return left.lessThanOrEqualTo(right: right)
}

/// Equivalent to NSLayoutRelation.LessThanOrEqual
public func <= (left: ALLayoutItem, right: CGFloat) -> NSLayoutConstraint {
    return left.lessThanOrEqualToConstant(right: right)
}

public extension ALView {
    func al_operand(attribute: NSLayoutAttribute) -> ALLayoutItem {
        return ALLayoutItem(view: self, attribute: attribute)
    }
    
    /// Equivalent to NSLayoutAttribute.Left
    var al_left: ALLayoutItem {
        return al_operand(attribute: .left)
    }
    
    /// Equivalent to NSLayoutAttribute.Right
    var al_right: ALLayoutItem {
        return al_operand(attribute: .right)
    }
    
    /// Equivalent to NSLayoutAttribute.Top
    var al_top: ALLayoutItem {
        return al_operand(attribute: .top)
    }
    
    /// Equivalent to NSLayoutAttribute.Bottom
    var al_bottom: ALLayoutItem {
        return al_operand(attribute: .bottom)
    }
    
    /// Equivalent to NSLayoutAttribute.Leading
    var al_leading: ALLayoutItem {
        return al_operand(attribute: .leading)
    }
    
    /// Equivalent to NSLayoutAttribute.Trailing
    var al_trailing: ALLayoutItem {
        return al_operand(attribute: .trailing)
    }
    
    /// Equivalent to NSLayoutAttribute.Width
    var al_width: ALLayoutItem {
        return al_operand(attribute: .width)
    }
    
    /// Equivalent to NSLayoutAttribute.Height
    var al_height: ALLayoutItem {
        return al_operand(attribute: .height)
    }
    
    /// Equivalent to NSLayoutAttribute.CenterX
    var al_centerX: ALLayoutItem {
        return al_operand(attribute: .centerX)
    }
    
    /// Equivalent to NSLayoutAttribute.CenterY
    var al_centerY: ALLayoutItem {
        return al_operand(attribute: .centerY)
    }
    
    /// Equivalent to NSLayoutAttribute.Baseline
    var al_baseline: ALLayoutItem {
        return al_operand(attribute: .baseline)
    }
}
