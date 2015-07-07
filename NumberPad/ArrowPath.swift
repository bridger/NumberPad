//
//  ArrowPath.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 7/6/15.
//  Copyright © 2015 Bridger Maxwell. All rights reserved.
//

import Foundation
import CoreGraphics
import DigitRecognizerSDK

func createPointingLine(startPoint: CGPoint, endPoint: CGPoint, dash: Bool, arrowHead: Bool) -> CGPathRef {
    let length = (endPoint - startPoint).length()
    let headWidth: CGFloat = 10
    let headLength: CGFloat = 10
    
    // We draw a straight line along going from the origin over to the right
    var path = CGPathCreateMutable()
    CGPathMoveToPoint(path, nil, 0, 0)
    CGPathAddLineToPoint(path, nil, length, 0)
    
    if dash {
        let dashPattern: [CGFloat] = [4, 6]
        if let dashedPath = CGPathCreateMutableCopy(CGPathCreateCopyByDashingPath(path, nil, 0, dashPattern, dashPattern.count)) {
            path = dashedPath
        }
    }
    
    if arrowHead {
        /* Now add the arrow head
        *
        *   \
        *    \
        *    /
        *   /
        *
        */
        let arrowStartX = length / 2
        CGPathMoveToPoint(path, nil, arrowStartX - headLength, headWidth / 2) // top
        CGPathAddLineToPoint(path, nil, arrowStartX, 0) // middle
        CGPathAddLineToPoint(path, nil, arrowStartX - headLength, -headWidth / 2) // bottom
    }
    
    // Now transform it so that it starts and ends at the right points
    let angle = (endPoint - startPoint).angle
    
    var transform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(startPoint.x, startPoint.y), angle)
    return CGPathCreateCopyByTransformingPath(path, &transform)!
}
