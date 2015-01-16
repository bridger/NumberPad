//
//  Utils.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 1/16/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import UIKit


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

