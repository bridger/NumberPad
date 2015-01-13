//
//  Utils.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 1/12/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import UIKit


func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

func euclidianDistanceSquared(a: CGPoint, b: CGPoint) -> CGFloat {
    let dx = a.x - b.x
    let dy = a.y - b.y
    return dx*dx + dy*dy
}

func closestPointOnRectPerimeter(point: CGPoint, rect: CGRect) -> CGPoint {
    let maxX = CGRectGetMaxX(rect)
    let minX = CGRectGetMinX(rect)
    let maxY = CGRectGetMaxY(rect)
    let minY = CGRectGetMinY(rect)
    
    if point.x <= minX {
        // It is to the left of the rectange. Either we return a left corner or point
        if point.y <= minY {
            // It is on the top-left corner
            return CGPointMake(minX, minY)
        } else if point.y >= maxY {
            // It is on the bottom-left corner
            return CGPointMake(minX, maxY)
        } else {
            // It is on the left size
            return CGPointMake(minX, point.y)
        }
        
    } else if point.x >= maxX {
        // It is to the right of the rectangle. Either we return a right corner or a point
        if point.y <= minY {
            // It is on the top-right corner
            return CGPointMake(maxX, minY)
        } else if point.y >= maxY {
            // It is on the bottom-right corner
            return CGPointMake(maxX, maxY)
        } else {
            // It is on the right size
            return CGPointMake(maxX, point.y)
        }
        
    } else {
        // It is either directly above, directly below, or inside the rectange
        if point.y <= minY {
            // It is on the top side
            return CGPointMake(point.x, minY)
        } else if point.y >= maxY {
            // It is on the bottom side
            return CGPointMake(point.x, maxY)
        }
        
        // Uh oh, it is inside the rectangle! For now, we just return the rectangle center
        return CGPointMake((maxX + minX) / 2.0, (maxY + minY) / 2.0)
    }
}


