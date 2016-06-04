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
        layer.strokeColor = UIColor.textColor().cgColor
        layer.lineWidth = 2
        layer.fillColor = nil
    }
    
    var layerNeedsUpdate = false
    func append(_ point: CGPoint)
    {
        points.append(point)
        layerNeedsUpdate = true
    }
    
    func updateLayer() {
        if layerNeedsUpdate {
            let path = CGMutablePath()
            for (index, point) in points.enumerated() {
                if index == 0 {
                    path.moveTo(nil, x: point.x, y: point.y)
                } else {
                    path.addLineTo(nil, x: point.x, y: point.y)
                }
            }
            layer.path = path;
            
            layerNeedsUpdate = false
        }
    }
}

