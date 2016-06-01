//
//  NumberSlideView.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 1/17/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import UIKit

public protocol NumberSlideViewDelegate: NSObjectProtocol {
    func numberSlideView(numberSlideView: NumberSlideView, didSelectNewValue newValue: NSDecimalNumber, scale: Int16)
    func numberSlideView(numberSlideView: NumberSlideView, didSelectNewScale scale: Int16)
}

class ScaleButton: UIButton {
    var scale: Int16 = 0
    
    override var isSelected: Bool {
        didSet {
            if self.isSelected {
                self.backgroundColor = UIColor.textColor()
            } else {
                self.backgroundColor = UIColor.selectedBackgroundColor()
            }
        }
    }
}

public class NumberSlideView: UIView, UIScrollViewDelegate {
    let scrollView: UIScrollView = UIScrollView()
    var valueAnchor: (Value: NSDecimalNumber, Offset: CGFloat)?
    var scaleButtons: [ScaleButton] = []
    
    public weak var delegate: NumberSlideViewDelegate?
    
    var scale: Int16 = 0
    public func resetToValue(value: NSDecimalNumber, scale: Int16) {
        for label in visibleLabels {
            label.removeFromSuperview()
        }
        visibleLabels.removeAll(keepingCapacity: true)
        
        // Stop the scrolling
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        
        self.scale = scale
        let center = self.convert(scrollView.center, to: scrollingContentContainer)
        valueAnchor = (Value: value, Offset: center.x)
        
        fixScrollableContent()
        updateScaleButtons()
    }
    
    public func selectedValue() -> NSDecimalNumber? {
        if let valueAnchor = valueAnchor {
            let offsetFromAnchor = self.scrollView.contentOffset.x + self.bounds.midX - valueAnchor.Offset
            
            let spacePerTick = spacingBetweenLabels / 10.0
            let ticks = Int(round(offsetFromAnchor / spacePerTick))
            
            let valuePerTick = NSDecimalNumber(mantissa: 1, exponent: self.scale, isNegative: false)
            return valueAnchor.Value.adding( NSDecimalNumber(value: ticks).multiplying(by: valuePerTick) )
        }
        return nil
    }
    
    public func roundedSelectedValue() -> NSDecimalNumber? {
        if let value = self.selectedValue() {
            let roundBehavior = NSDecimalNumberHandler(roundingMode: .roundDown, scale: -scale, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
            return value.rounding(accordingToBehavior: roundBehavior)
        }
        return nil
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    var visibleLabels: [NumberLabel] = []
    let scrollingContentContainer = UIView()
    let centerMarker = UIView()
    func setup() {
        self.backgroundColor = UIColor.selectedBackgroundColor()
        centerMarker.translatesAutoresizingMaskIntoConstraints = false
        centerMarker.backgroundColor = UIColor.textColor()
        self.addSubview(centerMarker)
        
        self.addAutoLayoutSubview(subview: scrollView)
        self.addHorizontalConstraints( |-0-[scrollView]-0-| )
        scrollView.delegate = self
        self.scrollView.showsHorizontalScrollIndicator = false
        
        self.scrollView.addSubview(scrollingContentContainer)
        scrollingContentContainer.isUserInteractionEnabled = false
        
        self.layoutIfNeeded()
        resetToValue(value: NSDecimalNumber.zero(), scale: 0)
        
        let scales = [(-4, ".1%"), (-3, ".01"), (-2, ".1"), (-1, "1"), (0, "10"), (1, "10²")]
        for (scale, label) in scales {
            let button = ScaleButton()
            button.translatesAutoresizingMaskIntoConstraints = false
            button.scale = Int16(scale)
            button.setTitle(label, for: [])
            self.addSubview(button)
            
            // The following broke in swift 2.0, so they are expressed more explicity directly below
            self.addVerticalConstraints( [button]-0-| )
            self.addConstraint(button.al_bottom == self.al_bottom)
            if let previousButton = self.scaleButtons.last {
                self.addHorizontalConstraints( [previousButton]-0-[button == previousButton] )
                
                self.addConstraint( previousButton.al_height == button.al_height )
            } else {
                // The first button!
                self.addConstraints(horizontalConstraints( |-0-[button] ))
            }
            button.addTarget(self, action: #selector(NumberSlideView.scaleButtonTapped(button:)), for: .touchUpInside)
            
            self.scaleButtons.append(button)
        }
        
        let lastScaleButton = self.scaleButtons.last!
        self.addHorizontalConstraints( [lastScaleButton]-0-| )
        self.addVerticalConstraints( |-0-[scrollView]-0-[lastScaleButton]-0-| )
        
        self.addConstraint(centerMarker.al_height == scrollView.al_height)
        self.addConstraint(centerMarker.al_bottom == scrollView.al_bottom)
        self.addConstraint(centerMarker.al_centerX == scrollView.al_centerX)
        self.addConstraint(centerMarker.al_width == 2.0)
        
        updateScaleButtons()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.contentSize = CGSize(width: 5000, height: scrollView.frame.size.height)
        scrollingContentContainer.frame = CGRect(x: 0, y:  0, width:  self.scrollView.contentSize.width, height: self.scrollView.contentSize.height)
        
        let yPosition = scrollingContentContainer.bounds.size.height / 2.0
        for label in visibleLabels {
            label.center.y = yPosition
        }
        
        fixScrollableContent()
    }
    
    func scaleButtonTapped(button: ScaleButton) {
        if let selectedValue = selectedValue() {
            self.resetToValue(value: selectedValue, scale: button.scale)
            if let delegate = delegate {
                delegate.numberSlideView(numberSlideView: self, didSelectNewScale: button.scale)
            }
        }
    }
    
    func updateScaleButtons() {
        for button in self.scaleButtons {
            button.isSelected = button.scale == self.scale
        }
    }
    
    var centerValue: CGFloat = 0.0
    func recenterIfNecessary() {
        let currentOffset = scrollView.contentOffset
        let contentWidth = scrollView.contentSize.width
        
        let centerOffsetX = (contentWidth - scrollView.bounds.size.width) / 2.0
        let distanceFromCenter = abs(currentOffset.x - centerOffsetX)
        
        if distanceFromCenter > contentWidth / 4.0 {
            let moveAmount = centerOffsetX - currentOffset.x
            scrollView.contentOffset = CGPoint(x: centerOffsetX, y: currentOffset.y)
            
            for label in self.visibleLabels {
                var center = scrollingContentContainer.convert(label.center, to: scrollView)
                center.x += moveAmount
                label.center = scrollView.convert(center, to: scrollingContentContainer)
            }
            
            if let valueAnchor = self.valueAnchor {
                self.valueAnchor = (Value: valueAnchor.Value, Offset: valueAnchor.Offset + moveAmount)
            }
        }
    }
    
    var lastSelectedValue: NSDecimalNumber?
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        fixScrollableContent()
        
        // Figure out which new value is selected. If it is new, pass it on to the delegate
        if let delegate = delegate {
            if let selectedValue = roundedSelectedValue() {
                if selectedValue != lastSelectedValue {
                    delegate.numberSlideView(numberSlideView: self, didSelectNewValue: selectedValue, scale: self.scale)
                    lastSelectedValue = selectedValue
                }
            }
        }
    }
    
    let spacingBetweenLabels: CGFloat = 70.0
    func fixScrollableContent() {
        recenterIfNecessary()
        
        let visibleBounds = scrollView.convert(scrollView.bounds, to: scrollingContentContainer)
        let minVisibleX = visibleBounds.minX
        let maxVisibileX = visibleBounds.maxX
        
        self.tileLabelsFromMinX(minX: minVisibleX - spacingBetweenLabels * 2, maxX: maxVisibileX + spacingBetweenLabels * 2)
    }
    
    func addLabelCenteredAt(value: NSDecimalNumber, centerX: CGFloat) -> NumberLabel {
        let newLabel = NumberLabel(number: value)
        newLabel.font = UIFont.systemFont(ofSize: 22)
        newLabel.sizeToFit()
        newLabel.center = CGPoint(x: centerX, y: scrollingContentContainer.bounds.midY)
        newLabel.textColor = UIColor.selectedTextColor()
        scrollingContentContainer.addSubview(newLabel)
        return newLabel
    }
    
    func tileLabelsFromMinX(minX: CGFloat, maxX: CGFloat) {
        if var valueAnchor = valueAnchor {
            let valueBetweenLabels = NSDecimalNumber(mantissa: 1, exponent: self.scale + 1, isNegative: false)
            
            // Move the anchor closer to the center, if it isn't in the visible region
            if valueAnchor.Offset < minX || valueAnchor.Offset > maxX {
                let distanceFromCenter = (minX + maxX) / 2.0 - valueAnchor.Offset
                let placesToMove = Int(distanceFromCenter / spacingBetweenLabels)
                
                let newValue = valueAnchor.Value.adding( NSDecimalNumber(value: placesToMove).multiplying(by: valueBetweenLabels) )
                let newOffset = valueAnchor.Offset + CGFloat(placesToMove) * spacingBetweenLabels
                valueAnchor = (Value: newValue, Offset: newOffset)
                self.valueAnchor = valueAnchor
            }
            
            // the upcoming tiling logic depends on there already being at least one label in the visibleLabels array, so
            // to kick off the tiling we need to make sure there's at least one label
            if visibleLabels.count == 0 {
                // We need to add the first label! If we have a valueAnchor at 60.6 and a scale of 0, then we would place a label of 60 at (60% * spacing) to the left of the anchor.
                let labelRoundBehavior = NSDecimalNumberHandler(roundingMode: .roundDown, scale: -(scale + 1), raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
                let closestLabelValue = valueAnchor.Value.rounding(accordingToBehavior: labelRoundBehavior)
                
                let valueDifference = (closestLabelValue.doubleValue - valueAnchor.Value.doubleValue)
                let offset = CGFloat(valueDifference / valueBetweenLabels.doubleValue) * spacingBetweenLabels
                let label = addLabelCenteredAt(value: closestLabelValue, centerX: valueAnchor.Offset + offset)
                visibleLabels.append(label)
            }
            
            // Add labels missing on the left side
            var firstLabel = visibleLabels.first!
            while firstLabel.center.x - spacingBetweenLabels > minX {
                let newCenter = firstLabel.center.x - spacingBetweenLabels
                let newValue = firstLabel.number.subtracting(valueBetweenLabels)
                let label = addLabelCenteredAt(value: newValue, centerX: newCenter)
                visibleLabels.insert(label, at: 0)
                firstLabel = label
            }
            
            // Add labels missing on the right side
            var lastLabel = visibleLabels.last!
            while lastLabel.center.x + spacingBetweenLabels < maxX {
                let newCenter = lastLabel.center.x + spacingBetweenLabels
                let newValue = lastLabel.number.adding(valueBetweenLabels)
                let label = addLabelCenteredAt(value: newValue, centerX: newCenter)
                visibleLabels.append(label)
                lastLabel = label
            }
            
            // Remove labels that have fallen off the left edge
            while true {
                if let firstLabel = visibleLabels.first {
                    if firstLabel.frame.midX < minX {
                        visibleLabels.remove(at: 0)
                        firstLabel.removeFromSuperview()
                        continue
                    }
                }
                break
            }
            
            // Remove labels that have fallen off the right edge
            while true {
                if let lastLabel = visibleLabels.last {
                    if lastLabel.frame.midX > maxX {
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
        super.init(frame: CGRect.zero)
        self.text = number.description
        self.textColor = UIColor.selectedTextColor()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

