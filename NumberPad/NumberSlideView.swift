//
//  NumberSlideView.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 1/17/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import UIKit


public protocol NumberSlideViewDelegate: NSObjectProtocol {
    func numberSlideView(NumberSlideView, didSelectNewValue newValue: NSDecimalNumber)
}

public class NumberSlideView: UIView, UIScrollViewDelegate {
    let scrollView: UIScrollView = UIScrollView()
    var valueAnchor: (Value: NSDecimalNumber, Offset: CGFloat)?
    
    public weak var delegate: NumberSlideViewDelegate?
    
    var scale: Int16 = 0
    public func resetToValue(value: NSDecimalNumber, scale: Int16) {
        for label in visibleLabels {
            label.removeFromSuperview()
        }
        visibleLabels.removeAll(keepCapacity: true)
        
        // Stop the scrolling
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        
        self.scale = scale
        let center = self.convertPoint(scrollView.center, toView: scrollingContentContainer)
        valueAnchor = (Value: value, Offset: center.x)
        
        fixScrollableContent()
    }
    
    public func selectedValue() -> NSDecimalNumber? {
        if let valueAnchor = valueAnchor {
            let offsetFromAnchor = self.scrollView.contentOffset.x + CGRectGetMidX(self.bounds) - valueAnchor.Offset
            
            let spacePerTick = spacingBetweenLabels / 10.0
            let ticks = Int(round(offsetFromAnchor / spacePerTick))
            
            let valuePerTick = NSDecimalNumber(mantissa: 1, exponent: self.scale - 1, isNegative: false)
            return valueAnchor.Value.decimalNumberByAdding( NSDecimalNumber(integer: ticks).decimalNumberByMultiplyingBy(valuePerTick) )
        }
        return nil
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    var visibleLabels: [NumberLabel] = []
    let scrollingContentContainer = UIView()
    let centerMarker = UIView()
    func setup() {
        self.backgroundColor = UIColor.darkGrayColor()
        centerMarker.backgroundColor = UIColor.redColor()
        self.addSubview(centerMarker)
        
        scrollView.frame = self.bounds
        scrollView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        self.addSubview(scrollView)
        scrollView.delegate = self
        self.scrollView.showsHorizontalScrollIndicator = false
        
        self.scrollView.addSubview(scrollingContentContainer)
        scrollingContentContainer.userInteractionEnabled = false
        
        self.layoutIfNeeded()
        resetToValue(NSDecimalNumber.zero(), scale: 0)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.contentSize = CGSizeMake(5000, self.frame.size.height)
        scrollingContentContainer.frame = CGRectMake(0, 0, self.scrollView.contentSize.width, self.scrollView.contentSize.height)
        
        centerMarker.frame = CGRectMake(CGRectGetMidX(self.bounds) - 1.0, 0, 2.0, self.bounds.size.height)
        
        let yPosition = scrollingContentContainer.bounds.size.height / 2.0
        for label in visibleLabels {
            label.center.y = yPosition
        }
        
        fixScrollableContent()
    }
    
    var centerValue: CGFloat = 0.0
    func recenterIfNecessary() {
        let currentOffset = scrollView.contentOffset
        let contentWidth = scrollView.contentSize.width
        
        let centerOffsetX = (contentWidth - scrollView.bounds.size.width) / 2.0
        let distanceFromCenter = abs(currentOffset.x - centerOffsetX)
        
        if distanceFromCenter > contentWidth / 4.0 {
            let moveAmount = centerOffsetX - currentOffset.x
            scrollView.contentOffset = CGPointMake(centerOffsetX, currentOffset.y)
            
            for label in self.visibleLabels {
                var center = scrollingContentContainer.convertPoint(label.center, toView: scrollView)
                center.x += moveAmount
                label.center = scrollView.convertPoint(center, toView: scrollingContentContainer)
            }
            
            if let valueAnchor = self.valueAnchor {
                self.valueAnchor = (Value: valueAnchor.Value, Offset: valueAnchor.Offset + moveAmount)
            }
        }
    }
    
    var lastSelectedValue: NSDecimalNumber?
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        fixScrollableContent()
        
        // Figure out which new value is selected. If it is new, pass it on to the delegate
        if let delegate = delegate {
            if let selectedValue = selectedValue() {
                if selectedValue != lastSelectedValue {
                    delegate.numberSlideView(self, didSelectNewValue: selectedValue)
                    lastSelectedValue = selectedValue
                }
            }
        }
    }
    
    let spacingBetweenLabels: CGFloat = 70.0
    func fixScrollableContent() {
        recenterIfNecessary()
        
        let visibleBounds = scrollView.convertRect(scrollView.bounds, toView: scrollingContentContainer)
        let minVisibleX = CGRectGetMinX(visibleBounds)
        let maxVisibileX = CGRectGetMaxX(visibleBounds)
        
        self.tileLabelsFromMinX(minVisibleX - spacingBetweenLabels * 2, maxX: maxVisibileX + spacingBetweenLabels * 2)
    }
    
    func addLabelCenteredAt(value: NSDecimalNumber, centerX: CGFloat) -> NumberLabel {
        let newLabel = NumberLabel(number: value)
        newLabel.font = UIFont.systemFontOfSize(22)
        newLabel.sizeToFit()
        newLabel.center = CGPointMake(centerX, CGRectGetMidY(scrollingContentContainer.bounds))
        scrollingContentContainer.addSubview(newLabel)
        return newLabel
    }
    
    func tileLabelsFromMinX(minX: CGFloat, maxX: CGFloat) {
        if var valueAnchor = valueAnchor {
            let valueBetweenLabels = NSDecimalNumber(mantissa: 1, exponent: self.scale, isNegative: false)
            
            // Move the anchor closer to the center, if it isn't in the visible region
            if valueAnchor.Offset < minX || valueAnchor.Offset > maxX {
                let distanceFromCenter = (minX + maxX) / 2.0 - valueAnchor.Offset
                let placesToMove = Int(distanceFromCenter / spacingBetweenLabels)
                
                let newValue = valueAnchor.Value.decimalNumberByAdding( NSDecimalNumber(integer: placesToMove).decimalNumberByMultiplyingBy(valueBetweenLabels) )
                let newOffset = valueAnchor.Offset + CGFloat(placesToMove) * spacingBetweenLabels
                valueAnchor = (Value: newValue, Offset: newOffset)
                self.valueAnchor = valueAnchor
            }
            
            // the upcoming tiling logic depends on there already being at least one label in the visibleLabels array, so
            // to kick off the tiling we need to make sure there's at least one label
            if visibleLabels.count == 0 {
                // We need to add the first label! If we have a valueAnchor at 60.6 and a scale of 0, then we would place a label of 60 at (60% * spacing) to the left of the anchor.
                let labelRoundBehavior = NSDecimalNumberHandler(roundingMode: .RoundDown, scale: scale, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
                let labelValue = valueAnchor.Value.decimalNumberByRoundingAccordingToBehavior(labelRoundBehavior)
                
                let offset = CGFloat(labelValue.doubleValue - valueAnchor.Value.doubleValue) * spacingBetweenLabels
                let label = addLabelCenteredAt(labelValue, centerX: valueAnchor.Offset + offset)
                visibleLabels.append(label)
            }
            
            // Add labels missing on the left side
            var firstLabel = visibleLabels.first!
            while firstLabel.center.x - spacingBetweenLabels > minX {
                let newCenter = firstLabel.center.x - spacingBetweenLabels
                let newValue = firstLabel.number.decimalNumberBySubtracting(valueBetweenLabels)
                let label = addLabelCenteredAt(newValue, centerX: newCenter)
                visibleLabels.insert(label, atIndex: 0)
                firstLabel = label
            }
            
            // Add labels missing on the right side
            var lastLabel = visibleLabels.last!
            while lastLabel.center.x + spacingBetweenLabels < maxX {
                let newCenter = lastLabel.center.x + spacingBetweenLabels
                let newValue = lastLabel.number.decimalNumberByAdding(valueBetweenLabels)
                let label = addLabelCenteredAt(newValue, centerX: newCenter)
                visibleLabels.append(label)
                lastLabel = label
            }
            
            // Remove labels that have fallen off the left edge
            while true {
                if let firstLabel = visibleLabels.first {
                    if CGRectGetMidX(firstLabel.frame) < minX {
                        visibleLabels.removeAtIndex(0)
                        firstLabel.removeFromSuperview()
                        continue
                    }
                }
                break
            }
            
            // Remove labels that have fallen off the right edge
            while true {
                if let lastLabel = visibleLabels.last {
                    if CGRectGetMidX(lastLabel.frame) > maxX {
                        visibleLabels.removeLast()
                        lastLabel.removeFromSuperview()
                        continue
                    }
                }
                break
            }
        }
    }
}

class NumberLabel: UILabel {
    let number: NSDecimalNumber
    init(number: NSDecimalNumber) {
        self.number = number
        super.init(frame: CGRectZero)
        self.text = number.description
        self.textColor = UIColor.whiteColor()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

