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

func createPointingLine(startPoint: CGPoint, endPoint: CGPoint, dash: Bool, arrowHeadPosition: CGFloat?) -> CGPath {
    let length = (endPoint - startPoint).length()
    let headWidth: CGFloat = 10
    let headLength: CGFloat = 10
    
    // We draw a straight line along going from the origin over to the right
    var path = CGMutablePath()
    path.move(to: CGPoint.zero)
    path.addLine(to: CGPoint(x: length, y: 0))
    
    if dash {
        let dashPattern: [CGFloat] = [4, 6]
        if let dashedPath = path.copy(dashingWithPhase: 0, lengths: dashPattern).mutableCopy() {
            path = dashedPath
      }
    }
    
    if let arrowHeadPosition = arrowHeadPosition {
        /* Now add the arrow head
        *
        *   \
        *    \
        *    /
        *   /
        *
        */
        let arrowStartX = length * arrowHeadPosition
        path.move(to: CGPoint(x: arrowStartX - headLength, y: headWidth / 2)) // top
        path.addLine(to: CGPoint(x: arrowStartX, y: 0)) // middle
        path.addLine(to: CGPoint(x: arrowStartX - headLength, y: -headWidth / 2)) // bottom
    }
    
    // Now transform it so that it starts and ends at the right points
    let angle = (endPoint - startPoint).angle
    
    var transform = CGAffineTransform(translationX: startPoint.x, y: startPoint.y).rotated(by: angle)
    return path.copy(using: &transform)!
}
