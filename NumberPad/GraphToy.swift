//
//  GraphToy.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 10/1/16.
//  Copyright © 2016 Bridger Maxwell. All rights reserved.
//

import QuartzCore
import DigitRecognizerSDK

class GraphToy : UIView, GraphingToy {
    let xConnector: Connector
    let yConnector: Connector
    
    init(xConnector: Connector, yConnector: Connector) {
        self.xConnector = xConnector
        self.yConnector = yConnector
        
        super.init(frame: CGRect.zero)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func inputConnectors() -> [Connector] {
        return [xConnector]
    }
    
    func outputConnectors() -> [Connector] {
        return [yConnector]
    }
    
    var selectedX: CGFloat?
    var selectedY: CGFloat?
    func update(values: ResolvedValues) {
        if let x = values[self.xConnector]?.DoubleValue {
            selectedX = CGFloat(x)
        } else {
            selectedX = nil
        }
        if let y = values[self.yConnector]?.DoubleValue {
            selectedY = CGFloat(y)
        } else {
            selectedY = nil
        }
        self.functionLine = nil
        self.setNeedsDisplay()
    }
    
    let scale: CGFloat = 1 / 16 // This is the scale from drawing to graphing
    func transformFromDrawingToGraphing() -> CGAffineTransform {
        // For now, the graphing coordinate system:
        // The center of the view is 0,0
        // The y axis gets larger going up
        // The scale is several drawing points to each graphing point
        
        var transform = CGAffineTransform.identity
        
        // Scale
        transform = transform.scaledBy(x: scale, y: scale)
        
        // Translate from the center
        transform = transform.translatedBy(x: -bounds.size.width / 2, y: -bounds.size.height / 2)
        
        // Flip the y axis
        transform = transform.scaledBy(x: 1, y: -1)
        transform = transform.translatedBy(x: 0, y: -bounds.size.height)

        return transform
    }
    
    static let xColor = UIColor.multiplierInputColor()
    static let yColor = UIColor.adderInputColor()
    
    override func draw(_ rect: CGRect) {
        // Draw a grid in the background
        let mainColor = UIColor.exponentBaseColor();
        let backgroundColor = mainColor.withAlphaComponent(0.1).cgColor
        let minorAxisColor = mainColor.withAlphaComponent(0.2).cgColor
        let majorAxisColor = mainColor.cgColor
        let functionLineColor = UIColor.functionLineColor().cgColor
        let majorAxisWidth: CGFloat = 2
        let minorAxisWidth: CGFloat = 1
        let selectedPointWidth: CGFloat = 2
        let functionLineWidth: CGFloat = 4
        
        let context = UIGraphicsGetCurrentContext()!
        func stroke(path: CGMutablePath, width: CGFloat, color: CGColor) {
            context.setLineWidth(width)
            context.setStrokeColor(color)
            context.addPath(path)
            context.strokePath()
        }
        func drawLine(start: CGPoint, end: CGPoint, color: CGColor, width: CGFloat) {
            context.move(to: start)
            context.addLine(to: end)
            context.setLineWidth(width)
            context.setStrokeColor(color)
            context.strokePath()
        }
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(self.bounds)
        
        context.setFillColor(backgroundColor)
        context.fill(self.bounds)
        
        let drawingToGraphing = transformFromDrawingToGraphing()
        let graphingToDrawing = drawingToGraphing.inverted()
        
        // Draw the minor grid lines
        let topLeft = CGPoint.zero.applying(drawingToGraphing)
        let maxX = self.bounds.maxX
        let maxY = self.bounds.maxY
        let bottomRight = CGPoint(x: maxX, y: maxY).applying(drawingToGraphing)
        
        let minorAxisPaths = CGMutablePath()
        let majorAxisPaths = CGMutablePath()
        
        // Add the vertical axis lines
        for x in Int(ceil(topLeft.x))...Int(floor(bottomRight.x)) {
            let drawingX = CGPoint(x: x, y: 0).applying(graphingToDrawing).x
            
            let path = x == 0 ? majorAxisPaths : minorAxisPaths
            path.move(to: CGPoint(x: drawingX, y: 0))
            path.addLine(to: CGPoint(x: drawingX, y: maxY))
        }
        // Add the horizontal axis lines
        for y in Int(ceil(bottomRight.y))...Int(floor(topLeft.y)) {
            let drawingY = CGPoint(x: 0, y: y).applying(graphingToDrawing).y
            
            let path = y == 0 ? majorAxisPaths : minorAxisPaths
            path.move(to: CGPoint(x: 0, y: drawingY))
            path.addLine(to: CGPoint(x: maxX, y: drawingY))
        }
        
        stroke(path: minorAxisPaths, width: minorAxisWidth, color: minorAxisColor)
        stroke(path: majorAxisPaths, width: majorAxisWidth, color: majorAxisColor)
        
        // Draw the function line
        if let functionLine = self.functionLine {
            context.saveGState()
            
            context.concatenate(graphingToDrawing)
            context.addPath(functionLine)
            
            context.setLineWidth(functionLineWidth * scale)
            context.setLineCap(.round)
            context.setStrokeColor(functionLineColor)
            context.strokePath()
            
            context.restoreGState()
        }
        
        // Draw the crosshairs indicating the current X and Y values
        if let selectedX = selectedX {
            let drawingX = CGPoint(x: selectedX, y: 0).applying(graphingToDrawing).x
            
            drawLine(start: CGPoint(x: drawingX, y: 0), end: CGPoint(x: drawingX, y: maxY), color: GraphToy.xColor.cgColor, width: selectedPointWidth)
        }
        if let selectedY = selectedY {
            let drawingY = CGPoint(x: 0, y: selectedY).applying(graphingToDrawing).y
            
            drawLine(start: CGPoint(x: 0, y: drawingY), end: CGPoint(x: maxX, y: drawingY), color: GraphToy.yColor.cgColor, width: selectedPointWidth)
        }
    }
    
    
    var functionLine: CGMutablePath? = nil
    func update(currentStates: [Connector: ConnectorState], resolver: InputResolver) {
        
        let drawingToGraphing = transformFromDrawingToGraphing()
        var lastPoint: CGPoint?
        let functionLine = CGMutablePath()
        
        // For each X in our bounds, figure out the Y and add the resulting graphPoint to the line
        for drawingX in 0...Int(self.bounds.size.width) {
            let graphX = CGPoint(x: drawingX, y: 0).applying(drawingToGraphing).x
            
            let values = resolver([self.xConnector: Double(graphX)])
            
            guard let graphY = values[self.yConnector]?.DoubleValue, graphY.isFinite else {
                lastPoint = nil
                continue
            }

            let newPoint = CGPoint(x: graphX, y: CGFloat(graphY))
            if lastPoint == nil {
                functionLine.move(to: newPoint)
            } else {
                functionLine.addLine(to: newPoint)
            }
            lastPoint = newPoint
        }
        self.functionLine = functionLine
        self.setNeedsDisplay()
    }
    
    func valuesForTap(at point: CGPoint) -> [Connector: Double] {
        let poinInside = point - self.frame.origin
        let graphPoint = poinInside.applying(transformFromDrawingToGraphing())
        
        return [xConnector: Double(graphPoint.x), yConnector: Double(graphPoint.y)]
    }
    
    func contains(_ point: CGPoint) -> Bool {
        return self.frame.contains(point)
    }
}
