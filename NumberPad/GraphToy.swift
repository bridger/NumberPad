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
    
    let gridLineView: GridLineView
    let functionLayer: CAShapeLayer
    let selectedPointLayer: CAShapeLayer
    
    init(xConnector: Connector, yConnector: Connector) {
        self.xConnector = xConnector
        self.yConnector = yConnector
        
        gridLineView = GridLineView(frame: CGRect.zero)
        functionLayer = CAShapeLayer()
        selectedPointLayer = CAShapeLayer()
        
        super.init(frame: CGRect.zero)
        self.isUserInteractionEnabled = false
        
        self.addSubview(gridLineView)
        gridLineView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        functionLayer.strokeColor = GraphToy.yColor.cgColor
        functionLayer.fillColor = nil
        functionLayer.lineCap = "round"
        functionLayer.lineWidth = 4
        self.layer.addSublayer(functionLayer)
        
        selectedPointLayer.fillColor = GraphToy.xColor.cgColor
        self.layer.addSublayer(selectedPointLayer)
        
        self.clipsToBounds = true
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
        
        if let selectedX = selectedX, let selectedY = selectedY {
            let drawingToGraphing = gridLineView.transformFromDrawingToGraphing()
            let graphingToDrawing = drawingToGraphing.inverted()
            
            let drawingPoint = CGPoint(x: selectedX, y: selectedY).applying(graphingToDrawing)
            
            let clampedY = drawingPoint.y.clamp(lower: self.bounds.minY, upper: self.bounds.maxY)
            
            let selectedPointRadius: CGFloat = 7
            let ellipseRect = CGRect(x: drawingPoint.x, y: clampedY, width: 0, height: 0).insetBy(dx: -selectedPointRadius, dy: -selectedPointRadius)
            
            self.selectedPointLayer.path = CGPath(ellipseIn: ellipseRect, transform: nil)
        } else {
            self.selectedPointLayer.path = nil
        }
    }
    
    static let xColor = UIColor.multiplierInputColor()
    static let yColor = UIColor.adderInputColor()
    
    func update(currentStates: [Connector: ConnectorState], resolver: InputResolver) {
        
        let drawingToGraphing = gridLineView.transformFromDrawingToGraphing()
        let graphingToDrawing = drawingToGraphing.inverted()

        var lastPoint: CGPoint?
        let functionLine = CGMutablePath()
        self.functionLayer.path = nil
        
        // For each X in our bounds, figure out the Y and add the resulting graphPoint to the line
        let xVariable = "x"
        let resolvedContext = resolver([self.xConnector: 5], [self.xConnector: xVariable])
        guard let yExpression = resolvedContext.connectorValues[self.yConnector]?.Expression else {
            return
        }
        
        for drawingX in 0...Int(self.bounds.size.width) {
            let graphX = CGPoint(x: drawingX, y: 0).applying(drawingToGraphing).x
            
            var graphYNumber: NSNumber?
            graphYNumber = try? resolvedContext.mathEvaluator.evaluateExpression(yExpression, withSubstitutions:
                [ xVariable : constantExpression(number: Double(graphX)) ])
            
            guard let graphY = graphYNumber as? Double, graphY.isFinite else {
                lastPoint = nil
                continue
            }

            let newPoint = CGPoint(x: graphX, y: CGFloat(graphY)).applying(graphingToDrawing)
            let maxDrawableMagnitude: CGFloat = 10000
            guard newPoint.x.isFinite && newPoint.y.isFinite,
                abs(newPoint.x) < maxDrawableMagnitude && abs(newPoint.y) < maxDrawableMagnitude else {
                    lastPoint = nil
                    continue
            }
            
            if lastPoint == nil {
                functionLine.move(to: newPoint)
            } else {
                functionLine.addLine(to: newPoint)
            }
            lastPoint = newPoint
        }
        self.functionLayer.path = functionLine
    }
    
    func valuesForTap(at point: CGPoint) -> [Connector: Double] {
        let poinInside = point - self.frame.origin
        let graphPoint = poinInside.applying(gridLineView.transformFromDrawingToGraphing())
        
        return [xConnector: Double(graphPoint.x)]
    }
    
    var graphOffset: CGPoint {
        get {
            return gridLineView.offset
        }
        set {
            gridLineView.offset = newValue
            gridLineView.setNeedsDisplay()
        }
    }
    
    var graphScale: CGFloat {
        get {
            return gridLineView.scale
        }
        set {
            gridLineView.scale = newValue
            gridLineView.setNeedsLayout()
        }
    }
}

class GridLineView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isOpaque = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.isOpaque = true
    }
    
    var offset: CGPoint = CGPoint.zero // This is the graph coordinates which is at the center
    var scale: CGFloat = 1 / 16 // This is the scale from drawing to graphing
    func transformFromDrawingToGraphing() -> CGAffineTransform {
        // For now, the graphing coordinate system:
        // The center of the view is 0,0
        // The y axis gets larger going up
        // The scale is several drawing points to each graphing point
        
        var transform = CGAffineTransform.identity
        
        // Scale
        transform = transform.translatedBy(x: offset.x, y: offset.y)
        transform = transform.scaledBy(x: scale, y: scale)
        
        // Translate from the center
        transform = transform.translatedBy(x: -bounds.size.width / 2, y: -bounds.size.height / 2)
        
        // Flip the y axis
        transform = transform.scaledBy(x: 1, y: -1)
        transform = transform.translatedBy(x: 0, y: -bounds.size.height)
        
        return transform
    }
    
    override func draw(_ rect: CGRect) {
        let mainColor = UIColor.exponentBaseColor();
        let backgroundColor = mainColor.withAlphaComponent(0.1).cgColor
        let minorAxisColor = mainColor.withAlphaComponent(0.2).cgColor
        let majorAxisColor = mainColor.cgColor
        let majorAxisWidth: CGFloat = 2
        let minorAxisWidth: CGFloat = 1
        
        let context = UIGraphicsGetCurrentContext()!
        func stroke(path: CGMutablePath, width: CGFloat, color: CGColor) {
            context.setLineWidth(width)
            context.setStrokeColor(color)
            context.addPath(path)
            context.strokePath()
        }
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(self.bounds)
        
        context.setFillColor(backgroundColor)
        context.fill(self.bounds)
        
        let drawingToGraphing = transformFromDrawingToGraphing()
        let graphingToDrawing = drawingToGraphing.inverted()
        
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
    }
}


