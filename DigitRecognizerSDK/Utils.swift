//
//  Utils.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 1/16/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import UIKit

// I put this here because it really benefits from compiler optimization
public func optimizeAngles(angles: [(ChangeableAngle: CGFloat, TargetAngle: CGFloat)]) -> (Angle: CGFloat, FlipVertically: Bool) {
    
    if angles.count == 0 {
        return (0, false)
    } else {
        var minError: Double?
        var minAngle: CGFloat = 0
        var minFlip: Bool = false
        let angleStep: CGFloat = CGFloat(2 * M_PI) / 270.0
        
        // We don't flip if there is only one angle to optimize
        var possibleFlips = angles.count > 1 ? [false, true] : [false]
        
        for flip in possibleFlips {
            for var testAngle: CGFloat = 0; testAngle < CGFloat(2 * M_PI); testAngle += angleStep {
                
                var error: Double = 0.0
                for angleSet in angles {
                    let angleDifference = (flip
                        ? -angleSet.ChangeableAngle - angleSet.TargetAngle
                        :  angleSet.ChangeableAngle - angleSet.TargetAngle)
                    error += 1.0 - cos(Double(testAngle + angleDifference))
                }
                if minError == nil || error < minError! {
                    minError = error
                    minAngle = flip ? -testAngle : testAngle
                    minFlip = flip
                }
            }
        }
        
        return (minAngle, minFlip)
    }
}


public func visualizeNormalizedStrokes(strokes: DTWDigitClassifier.DigitStrokes, imageSize: CGSize) -> UIImage {
    
    UIGraphicsBeginImageContextWithOptions(imageSize, true, 0)
    let ctx = UIGraphicsGetCurrentContext()
    
    let transformPointLambda: (CGPoint) -> CGPoint = { point -> CGPoint in
        return CGPointMake((point.x * 0.9 + 0.5) * imageSize.width,
            (point.y * 0.9 + 0.5) * imageSize.height)
    }
    for stroke in strokes {
        var firstPoint = true
        for point in stroke {
            let transformedPoint = transformPointLambda(point)
            
            if firstPoint {
                firstPoint = false
                CGContextMoveToPoint(ctx, transformedPoint.x, transformedPoint.y)
            } else {
                CGContextAddLineToPoint(ctx, transformedPoint.x, transformedPoint.y)
            }
        }
        CGContextSetStrokeColorWithColor(ctx, UIColor.whiteColor().CGColor)
        CGContextSetLineWidth(ctx, 2)
        CGContextStrokePath(ctx)
        
        for (index, point) in enumerate(stroke) {
            let transformedPoint = transformPointLambda(point)
            let indexRatio = CGFloat(index) / 32.0
            let color = UIColor(red: indexRatio, green: 0, blue: (1.0 - indexRatio), alpha: 1)
            CGContextSetFillColorWithColor(ctx, color.CGColor)
            CGContextFillEllipseInRect(ctx, CGRectMake(transformedPoint.x-2, transformedPoint.y-2, 4, 4))
        }
    }
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return image
}

