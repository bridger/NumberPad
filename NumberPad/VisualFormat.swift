//
//  VisualFormat.swift
//  SwiftVisualFormat
//
//  Created by Bridger Maxwell on 8/1/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

#if os(OSX)
    import AppKit
    public typealias ALVFView = NSView
    #elseif os(iOS)
    import UIKit
    public typealias ALVFView = UIView
#endif

extension ALVFView {
    public func addVerticalConstraints(constraintAble: [ConstraintAble]) {
        self.addConstraints(verticalConstraints(constraintAble))
    }
    
    public func addHorizontalConstraints(constraintAble: [ConstraintAble]) {
        self.addConstraints(horizontalConstraints(constraintAble))
    }
}

@objc public protocol ConstraintAble {
    func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint];
}

public func constraints(axis: UILayoutConstraintAxis, constraintAble: [ConstraintAble]) -> [NSLayoutConstraint] {
    return constraintAble[0].toConstraints(axis)
}

public func horizontalConstraints(constraintAble: [ConstraintAble]) -> [NSLayoutConstraint] {
    return constraints(.Horizontal, constraintAble: constraintAble)
}

public func verticalConstraints(constraintAble: [ConstraintAble]) -> [NSLayoutConstraint] {
    return constraints(.Vertical, constraintAble: constraintAble)
}


@objc public protocol ViewContainingToken : ConstraintAble {
    var firstView: ALVFView? { get }
    var lastView: ALVFView? { get }
}

protocol ConstantToken {
    var ALConstant: CGFloat { get }
}

// This is half of a space constraint, [view]-space
class ViewAndSpaceToken : NSObject {
    let view: ViewContainingToken
    let space: ConstantToken
    let relation: NSLayoutRelation
    init(view: ViewContainingToken, space: ConstantToken, relation: NSLayoutRelation) {
        self.view = view
        self.space = space
        self.relation = relation
    }
}

// This is half of a space constraint, |-5
class LeadingSuperviewAndSpaceToken : NSObject {
    let space: ConstantToken
    let relation: NSLayoutRelation
    init(space: ConstantToken, relation: NSLayoutRelation) {
        self.space = space
        self.relation = relation
    }
}
// This is half of a space constraint, 5-|
class TrailingSuperviewAndSpaceToken : NSObject {
    let space: ConstantToken
    init(space: ConstantToken) {
        self.space = space
    }
}

// [view]-5-[view2]
class SpacedViewsConstraintToken: NSObject, ConstraintAble, ViewContainingToken {
    let leadingView: ViewContainingToken
    let trailingView: ViewContainingToken
    let space: ConstantToken
    
    init(leadingView: ViewContainingToken, trailingView: ViewContainingToken, space: ConstantToken) {
        self.leadingView = leadingView
        self.trailingView = trailingView
        self.space = space
    }
    
    var firstView: UIView? {
        get {
            return self.leadingView.firstView
        }
    }
    var lastView: UIView? {
        get {
            return self.trailingView.lastView
        }
    }
    
    
    func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint] {
        if let leadingView = self.leadingView.lastView {
            if let trailingView = self.trailingView.firstView {
                let space = self.space.ALConstant
                
                var leadingAttribute: NSLayoutAttribute!
                var trailingAttribute: NSLayoutAttribute!
                if (axis == .Horizontal) {
                    leadingAttribute = .Leading
                    trailingAttribute = .Trailing
                } else {
                    leadingAttribute = .Top
                    trailingAttribute = .Bottom
                }
                
                var constraints = [NSLayoutConstraint(
                    item: trailingView, attribute: leadingAttribute,
                    relatedBy: .Equal,
                    toItem: leadingView, attribute: trailingAttribute,
                    multiplier: 1.0, constant: space)]
                
                constraints += self.leadingView.toConstraints(axis)
                constraints += self.trailingView.toConstraints(axis)
                
                return constraints
            }
        }
        
        NSException(name: NSInvalidArgumentException, reason: "This space constraint was between two view items that couldn't fit together. Weird?", userInfo: nil).raise()
        return [] // To appease the compiler, which doesn't realize this branch dies
    }
}

// [view == 50]
class SizeConstantConstraintToken: NSObject, ConstraintAble, ViewContainingToken {
    let view: ALVFView
    let size: ConstantToken
    let relation: NSLayoutRelation
    init(view: ALVFView, size: ConstantToken, relation: NSLayoutRelation) {
        self.view = view
        self.size = size
        self.relation = relation
    }
    
    var firstView: ALVFView? {
        get {
            return self.view.firstView
        }
    }
    var lastView: ALVFView? {
        get {
            return self.view.lastView
        }
    }
    
    func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint] {
        let constant = self.size.ALConstant
        
        var attribute: NSLayoutAttribute!
        if (axis == .Horizontal) {
            attribute = .Width
        } else {
            attribute = .Height
        }
        let constraint = NSLayoutConstraint(
            item: self.view, attribute: attribute,
            relatedBy: self.relation,
            toItem: nil, attribute: .NotAnAttribute,
            multiplier: 1.0, constant: constant)
        
        return [constraint]
    }
    
}

// [view == view2]
class SizeRelationConstraintToken: NSObject, ConstraintAble, ViewContainingToken {
    let view: ALVFView
    let relatedView: ALVFView
    let relation: NSLayoutRelation
    init(view: ALVFView, relatedView: ALVFView, relation: NSLayoutRelation) {
        self.view = view
        self.relatedView = relatedView
        self.relation = relation
    }
    
    var firstView: ALVFView? {
        get {
            return self.view.firstView
        }
    }
    var lastView: ALVFView? {
        get {
            return self.view.lastView
        }
    }
    
    func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint] {
        var attribute: NSLayoutAttribute!
        if (axis == .Horizontal) {
            attribute = .Width
        } else {
            attribute = .Height
        }
        return [ NSLayoutConstraint(
            item: self.view, attribute: attribute,
            relatedBy: self.relation,
            toItem: self.relatedView, attribute: attribute,
            multiplier: 1.0, constant: 0) ]
    }
}

// |-5-[view]
public class LeadingSuperviewConstraintToken: NSObject, ConstraintAble, ViewContainingToken {
    let viewContainer: ViewContainingToken
    let space: ConstantToken
    init(viewContainer: ViewContainingToken, space: ConstantToken) {
        self.viewContainer = viewContainer
        self.space = space
    }
    public var firstView: UIView? {
        get {
            return nil // No one can bind to our first view, is the superview
        }
    }
    public var lastView: UIView? {
        get {
            return self.viewContainer.lastView
        }
    }
    
    public func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint] {
        if let view = self.viewContainer.firstView {
            let constant = self.space.ALConstant
            
            if let superview = view.superview {
                var constraint: NSLayoutConstraint!
                
                if (axis == .Horizontal) {
                    constraint = NSLayoutConstraint(
                        item: view, attribute: .Leading,
                        relatedBy: .Equal,
                        toItem: superview, attribute: .Leading,
                        multiplier: 1.0, constant: constant)
                } else {
                    constraint = NSLayoutConstraint(
                        item: view, attribute: .Top,
                        relatedBy: .Equal,
                        toItem: superview, attribute: .Top,
                        multiplier: 1.0, constant: constant)
                }
                
                return viewContainer.toConstraints(axis) + [constraint]
            }
            NSException(name: NSInvalidArgumentException, reason: "You tried to create a constraint to \(view)'s superview, but it has no superview yet!", userInfo: nil).raise()
        }
        NSException(name: NSInvalidArgumentException, reason: "This superview bar | was before something that doesn't have a view. Weird?", userInfo: nil).raise()
        return [] // To appease the compiler, which doesn't realize this branch dies
    }
}

// [view]-5-|
public class TrailingSuperviewConstraintToken: NSObject, ConstraintAble, ViewContainingToken {
    let viewContainer: ViewContainingToken
    let space: ConstantToken
    init(viewContainer: ViewContainingToken, space: ConstantToken) {
        self.viewContainer = viewContainer
        self.space = space
    }
    public var firstView: UIView? {
        get {
            return self.viewContainer.firstView
        }
    }
    public var lastView: UIView? {
        get {
            return nil // No one can bind to our last view, is the superview
        }
    }
    
    public func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint] {
        if let view = self.viewContainer.lastView {
            let constant = self.space.ALConstant
            
            if let superview = view.superview {
                var constraint: NSLayoutConstraint!
                
                if (axis == .Horizontal) {
                    constraint = NSLayoutConstraint(
                        item: superview, attribute: .Trailing,
                        relatedBy: .Equal,
                        toItem: view, attribute: .Trailing,
                        multiplier: 1.0, constant: constant)
                } else {
                    constraint = NSLayoutConstraint(
                        item: superview, attribute: .Bottom,
                        relatedBy: .Equal,
                        toItem: view, attribute: .Bottom,
                        multiplier: 1.0, constant: constant)
                }
                
                return viewContainer.toConstraints(axis) + [constraint]
            }
            NSException(name: NSInvalidArgumentException, reason: "You tried to create a constraint to \(view)'s superview, but it has no superview yet!", userInfo: nil).raise()
        }
        NSException(name: NSInvalidArgumentException, reason: "This superview bar | was after something that doesn't have a view. Weird?", userInfo: nil).raise()
        
        return [] // To appease the compiler, which doesn't realize this branch dies
    }
}

let RequiredPriority: Float = 1000 // For some reason, the linker can't find UILayoutPriorityRequired. Not sure what I am doing wrong

prefix operator | {}
prefix public func | (tokenArray: [ViewContainingToken]) -> [LeadingSuperviewConstraintToken] {
    // |[view]
    return [LeadingSuperviewConstraintToken(viewContainer: tokenArray[0], space: 0)]
}

postfix operator | {}
postfix public func | (tokenArray: [ViewContainingToken]) -> [TrailingSuperviewConstraintToken] {
    // [view]|
    return [TrailingSuperviewConstraintToken(viewContainer: tokenArray[0], space: 0)]
}

func >= (left: ALVFView, right: ConstantToken) -> SizeConstantConstraintToken {
    // [view >= 50]
    return SizeConstantConstraintToken(view: left, size: right, relation: .GreaterThanOrEqual)
}
func >= (left: ALVFView, right: ALVFView) -> SizeRelationConstraintToken {
    // [view >= view2]
    return SizeRelationConstraintToken(view: left, relatedView: right, relation: .GreaterThanOrEqual)
}

func <= (left: ALVFView, right: ConstantToken) -> SizeConstantConstraintToken {
    // [view <= 50]
    return SizeConstantConstraintToken(view: left, size: right, relation: .LessThanOrEqual)
}
func <= (left: ALVFView, right: ALVFView) -> SizeRelationConstraintToken {
    // [view <= view2]
    return SizeRelationConstraintToken(view: left, relatedView: right, relation: .LessThanOrEqual)
}

func == (left: ALVFView, right: ConstantToken) -> SizeConstantConstraintToken {
    // [view == 50]
    return SizeConstantConstraintToken(view: left, size: right, relation: .Equal)
}
func == (left: ALVFView, right: ALVFView) -> SizeRelationConstraintToken {
    // [view == view2]
    return SizeRelationConstraintToken(view: left, relatedView: right, relation: .Equal)
}

func - (left: [ViewContainingToken], right: ConstantToken) -> ViewAndSpaceToken {
    // [view]-5
    return ViewAndSpaceToken(view: left[0], space: right, relation: .Equal)
}

func - (left: ViewAndSpaceToken, right: [ViewContainingToken]) -> [SpacedViewsConstraintToken] {
    // [view]-5-[view2]
    return [SpacedViewsConstraintToken(leadingView: left.view, trailingView: right[0], space: left.space)]
}

func - (left: [ViewContainingToken], right: TrailingSuperviewAndSpaceToken) -> [TrailingSuperviewConstraintToken] {
    // [view]-5-|
    return [TrailingSuperviewConstraintToken(viewContainer: left[0], space: right.space)]
}

func - (left: LeadingSuperviewAndSpaceToken, right: [ViewContainingToken]) -> [LeadingSuperviewConstraintToken] {
    // |-5-[view]
    return [LeadingSuperviewConstraintToken(viewContainer: right[0], space: left.space)]
}

postfix operator -| {}
postfix func -| (constant: ConstantToken) -> TrailingSuperviewAndSpaceToken {
    // 5-|
    return TrailingSuperviewAndSpaceToken(space: constant)
}

prefix operator |- {}
prefix func |- (constant: ConstantToken) -> LeadingSuperviewAndSpaceToken {
    // |-5
    return LeadingSuperviewAndSpaceToken(space: constant, relation: .Equal)
}


extension ALVFView: ViewContainingToken {
    public var firstView: ALVFView? {
        get {
            return self
        }
    }
    public var lastView: ALVFView? {
        get {
            return self
        }
    }
    
    public func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint] {
        return []
    }
}

extension CGFloat: ConstantToken {
    var ALConstant: CGFloat {
        get {
            return self
        }
    }
}

extension NSInteger: ConstantToken {
    var ALConstant: CGFloat {
        get {
            return CGFloat(self)
        }
    }
}

