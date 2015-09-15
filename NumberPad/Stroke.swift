//
//  Stroke.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 7/19/15.
//  Copyright © 2015 Bridger Maxwell. All rights reserved.
//

import CoreGraphics

class Stroke {
    var points: [CGPoint] = []
    var layer: CAShapeLayer
    
    init(){
        layer = CAShapeLayer()
        layer.strokeColor = UIColor.textColor().CGColor
        layer.lineWidth = 2
        layer.fillColor = nil
    }
    
    var layerNeedsUpdate = false
    func addPoint(point: CGPoint)
    {
        points.append(point)
        layerNeedsUpdate = true
    }
    
    func updateLayer() {
        if layerNeedsUpdate {
            let path = CGPathCreateMutable()
            for (index, point) in points.enumerate() {
                if index == 0 {
                    CGPathMoveToPoint(path, nil, point.x, point.y)
                } else {
                    CGPathAddLineToPoint(path, nil, point.x, point.y)
                }
            }
            layer.path = path;
            
            layerNeedsUpdate = false
        }
    }
}

