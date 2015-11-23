//
//  Toy.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 6/28/15.
//  Copyright © 2015 Bridger Maxwell. All rights reserved.
//

import QuartzCore

// This is a function passed into updateGhostState. The toy will call this for various different values
// for the input connectors and it should return the resolved value for all of the output connectors
typealias GhostValueResolver = (inputValues: [Connector: Double]) -> [Connector: SimulationContext.ResolvedValue]

// This method is called with the value of the current input connector and a lambda which can solve for
// the output connector values given
typealias ConnectorState = (Value: SimulationContext.ResolvedValue, Scale: Int16)


protocol Toy {
    func inputConnectors() -> [Connector]
    func outputConnectors() -> [Connector]
    
    func updateGhosts(inputStates: [Connector: ConnectorState], resolver: GhostValueResolver)
    
    func update(values: [Connector: SimulationContext.ResolvedValue])
}

class MotionToy : UIView, Toy {
    let xConnector: Connector
    let yConnector: Connector
    let driverConnector: Connector
    let image: UIImage
    
    init(image: UIImage, xConnector: Connector, yConnector: Connector, driverConnector: Connector) {
        self.xConnector = xConnector
        self.yConnector = yConnector
        self.driverConnector = driverConnector
        self.image = image
        
        super.init(frame: CGRectZero)
        
        let imageView = UIImageView(image: image)
        imageView.sizeToFit()
        self.frame.size = imageView.frame.size
        imageView.frame = self.bounds
        self.addSubview(imageView)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func inputConnectors() -> [Connector] {
        return [driverConnector]
    }
    
    func outputConnectors() -> [Connector] {
        return [xConnector, yConnector]
    }
    
    func updateGhosts(inputStates: [Connector : ConnectorState], resolver: GhostValueResolver) {
        removeAllGhosts()
        
        guard let driverState = inputStates[self.driverConnector] else {
            return
        }
        
        if driverState.Value.WasDependent {
            // We don't run the simulation if the driver value was dependent on another connector
            return
        }
        
        let range = 5
        for offset in -range...range {
            if offset == 0 {
                continue
            }
            let valueOffset = Double(offset) * pow(10.0, Double(driverState.Scale + 1))
            let offsetDriverValue = driverState.Value.DoubleValue + valueOffset
            
            
            let ghostValues = resolver(inputValues: [self.driverConnector: offsetDriverValue])
            
            if let xPosition = ghostValues[self.xConnector]?.DoubleValue,
                let yPosition = ghostValues[self.yConnector]?.DoubleValue {

                    let percent = Double(offset) / Double(range)
                    let ghost = self.createNewGhost(percent)
                    self.superview?.insertSubview(ghost, belowSubview: self)
                    ghost.center.x = CGFloat(xPosition)
                    let toyYZero = self.superview?.frame.size.height ?? 0
                    ghost.center.y = toyYZero - CGFloat(yPosition)
            }
        }
    }
    
    
    func update(values: [Connector : SimulationContext.ResolvedValue]) {
        removeAllGhosts()
        
        if let xPosition = values[self.xConnector]?.DoubleValue {
            self.center.x = CGFloat(xPosition)
        }
        if let yPosition = values[self.yConnector]?.DoubleValue {
            let toyYZero = self.superview?.frame.size.height ?? 0
            self.center.y = toyYZero - CGFloat(yPosition)
        }
    }
    
    var activeGhosts: [UIView] = []
    var reuseGhosts: [UIView] = []
    
    func createNewGhost(percent: Double) -> UIView {
        let ghost: UIView
        if let oldGhost = reuseGhosts.popLast() {
            ghost = oldGhost
        } else {
            ghost = UIImageView(image: self.image)
            ghost.sizeToFit()
        }
        let alpha = (1.0 - abs(percent)) * 0.35
        ghost.alpha = CGFloat(alpha)
        
        activeGhosts.append(ghost)
        return ghost
    }
    
    func removeAllGhosts() {
        for ghost in activeGhosts {
            ghost.removeFromSuperview()
            reuseGhosts.append(ghost)
        }
        activeGhosts = []
    }
}

class CircleLayer {
    var diameter: Double = 0 {
        didSet {
            update()
        }
    }
    var circumference: Double = 0 {
        didSet {
            update()
        }
    }
    var position: CGPoint = CGPointZero {
        didSet {
            self.mainLayer.position = position
        }
    }
    
    let mainLayer: CAShapeLayer
    let diameterLayer: CAShapeLayer
    let circumferenceLayer: CAShapeLayer

    init() {
        self.mainLayer = CAShapeLayer()
        self.mainLayer.lineWidth = 4
        self.mainLayer.strokeColor = UIColor.multiplierInputColor().CGColor
        self.mainLayer.fillColor = nil
        
        self.diameterLayer = CAShapeLayer()
        self.diameterLayer.lineWidth = 4
        self.diameterLayer.strokeColor = UIColor.multiplierInputColor().CGColor
        self.diameterLayer.fillColor = nil
        
        self.circumferenceLayer = CAShapeLayer()
        self.circumferenceLayer.lineWidth = 7
        self.circumferenceLayer.strokeColor = UIColor.adderOutputColor().CGColor
        self.circumferenceLayer.fillColor = nil
        
        self.mainLayer.addSublayer(self.diameterLayer)
        self.mainLayer.addSublayer(self.circumferenceLayer)
        
        update()
    }
    
    func update() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let cgDiameter = CGFloat(self.diameter)
        let cgRadius = cgDiameter / 2
        if self.mainLayer.frame.size.width != cgDiameter {
            let roundedSize = round(cgDiameter)
            
            self.mainLayer.frame = CGRect(x: 0, y: 0, width: roundedSize, height: roundedSize)
            self.mainLayer.path = CGPathCreateWithEllipseInRect(self.mainLayer.bounds, nil)
            self.mainLayer.position = position
            
            let diameterPath = CGPathCreateMutable()
            CGPathMoveToPoint(diameterPath, nil, 0, cgRadius)
            CGPathAddLineToPoint(diameterPath, nil, cgDiameter, cgRadius)
            self.diameterLayer.path = diameterPath
        }
        
        let circumferencePath = CGPathCreateMutable()
        let angle = -CGFloat(self.circumference) / cgRadius
        let clockwise = angle < 0
        CGPathAddArc(circumferencePath, nil, cgRadius, cgRadius, cgRadius, 0, angle, clockwise)
        
        self.circumferenceLayer.path = circumferencePath
        let expectedCircumference = self.diameter * M_PI
        let difference = abs(self.circumference - expectedCircumference)
        let maxDifference: Double = 6.0
        let minOpacity: Float = 0.3
        if difference < maxDifference {
            self.circumferenceLayer.opacity = 1.0 - Float(difference / maxDifference) * (1.0 - minOpacity)
        } else {
            self.circumferenceLayer.opacity = minOpacity
        }
        
        CATransaction.commit()
    }
}

class CirclesToy : UIView, Toy {
    let diameterConnector: Connector
    let circumferenceConnector: Connector
    
    let mainCircle: CircleLayer
    init(diameterConnector: Connector, circumferenceConnector: Connector) {
        self.diameterConnector = diameterConnector
        self.circumferenceConnector = circumferenceConnector
        self.mainCircle = CircleLayer()
        
        super.init(frame: CGRectZero)
        
        self.layer.addSublayer(self.mainCircle.mainLayer)
        self.userInteractionEnabled = false
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func inputConnectors() -> [Connector] {
        return [diameterConnector]
    }
    
    func outputConnectors() -> [Connector] {
        return [circumferenceConnector]
    }
    
    func updateGhosts(inputStates: [Connector : ConnectorState], resolver: GhostValueResolver) {
        // No ghosts, currently
    }
    
    override func layoutSublayersOfLayer(layer: CALayer) {
        self.mainCircle.position = CGPointMake(layer.bounds.size.width / 2, layer.bounds.size.height / 3)
    }
    
    func update(values: [Connector : SimulationContext.ResolvedValue]) {
        if let diameter = values[self.diameterConnector]?.DoubleValue {
            self.mainCircle.diameter = diameter
        }
        if let circumference = values[self.circumferenceConnector]?.DoubleValue {
            self.mainCircle.circumference = circumference
        }
    }
}


class PythagorasToy : UIView, Toy {
    
    let aConnector: Connector
    let bConnector: Connector
    let cConnector: Connector
    
    init(aConnector: Connector, bConnector: Connector, cConnector: Connector) {
        self.aConnector = aConnector
        self.bConnector = bConnector
        self.cConnector = cConnector
        
        super.init(frame: CGRectZero)
        
        self.userInteractionEnabled = false
        self.backgroundColor = UIColor.clearColor()
    }
    
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func inputConnectors() -> [Connector] {
        return [aConnector, bConnector]
    }
    
    func outputConnectors() -> [Connector] {
        return [cConnector]
    }
    
    func updateGhosts(inputStates: [Connector : ConnectorState], resolver: GhostValueResolver) {
        // No ghosts, currently
    }
    
    
    var a: Double = 0
    var b: Double = 0
    var c: Double = 0
    func update(values: [Connector : SimulationContext.ResolvedValue]) {
        if let a = values[self.aConnector]?.DoubleValue, let b = values[self.bConnector]?.DoubleValue {
            if self.a != a || self.b != b {
                self.a = max(a, 0)
                self.b = max(b, 0)
                self.setNeedsDisplay()
            }
        }
        if let c = values[self.cConnector]?.DoubleValue {
            if self.c != c {
                self.c = max(c, 0)
                self.setNeedsDisplay()
            }
        }
    }
    
    var spacing: CGFloat = 25
    var topMargin: CGFloat = 80
    override func drawRect(rect: CGRect) {
        
        let a = CGFloat(self.a)
        let b = CGFloat(self.b)
        let c = CGFloat(self.c)
        
        let context = UIGraphicsGetCurrentContext()
        CGContextClearRect(context, rect)
        let lineWidth: CGFloat = 4
        func drawLine(startPoint: CGPoint, delta: CGPoint, color: CGColorRef) -> CGPoint {
            let endPoint = CGPointMake(startPoint.x + delta.x, startPoint.y + delta.y)
            CGContextMoveToPoint(context, startPoint.x, startPoint.y)
            CGContextAddLineToPoint(context, endPoint.x, endPoint.y)
            CGContextSetLineWidth(context, lineWidth)
            CGContextSetLineCap(context, .Round)
            CGContextSetStrokeColorWithColor(context, color)
            CGContextStrokePath(context)
            return endPoint
        }
        
        func fillSquare(corner: CGPoint, size: CGSize, color: CGColorRef) -> CGPoint {
            let rect = CGRectMake(corner.x, corner.y, size.width, size.height)
            
            CGContextSetFillColorWithColor(context, color)
            CGContextFillRect(context, CGRectInset(rect, -lineWidth/2, -lineWidth/2))
            
            return CGPointMake(corner.x + size.width, corner.y + size.height)
        }
        
        let lightness: CGFloat = 0.25
        let aColor = UIColor.multiplierInputColor().CGColor
        let aColorLight = CGColorCreateCopyWithAlpha(aColor, lightness)!
        let bColor = UIColor.adderInputColor().CGColor
        let bColorLight = CGColorCreateCopyWithAlpha(bColor, lightness)!
        let cColor = UIColor.exponentBaseColor().CGColor
        let cColorLight = CGColorCreateCopyWithAlpha(cColor, lightness)!
        
        let squareSide = CGFloat(a + b)
        let totalWidth = squareSide * 2 + spacing
        let minX = (self.bounds.size.width - totalWidth) / 2
        
        
        /* --- Left square --- */
        var currentPoint = CGPointMake(minX, topMargin + a)
        // Bottom-left square
        currentPoint = fillSquare(currentPoint, size: CGSizeMake(b, b), color: bColorLight)
        
        // Bottom-right triangles
        drawLine(currentPoint, delta: CGPointMake(a, -b), color: cColor)
        currentPoint = drawLine(currentPoint, delta: CGPointMake(a, 0), color: aColor)
        currentPoint = drawLine(currentPoint, delta: CGPointMake(0, -b), color: bColor)
        
        // Top-right square
        currentPoint = fillSquare(currentPoint, size: CGSizeMake(-a, -a), color: aColorLight)
        
        // Top-left triangles
        drawLine(currentPoint, delta: CGPointMake(-b, a), color: cColor)
        drawLine(currentPoint, delta: CGPointMake(0, a), color: aColor)
        currentPoint = drawLine(currentPoint, delta: CGPointMake(-b, 0), color: bColorLight)
        currentPoint = drawLine(currentPoint, delta: CGPointMake(0, a), color: aColorLight)
        drawLine(currentPoint, delta: CGPointMake(b, 0), color: bColor)
        
        
        /* --- Right square --- */
        // Top-left
        currentPoint = CGPointMake( (self.bounds.size.width + spacing) / 2 + b, topMargin)
        currentPoint = drawLine(currentPoint, delta: CGPointMake(-b, 0), color: bColorLight)
        currentPoint = drawLine(currentPoint, delta: CGPointMake(0, a), color: aColorLight)
        drawLine(currentPoint, delta: CGPointMake(b, -a), color: cColorLight)
        
        // Bottom-left
        currentPoint = drawLine(currentPoint, delta: CGPointMake(0, b), color: bColor)
        currentPoint = drawLine(currentPoint, delta: CGPointMake(a, 0), color: aColor)
        drawLine(currentPoint, delta: CGPointMake(-a, -b), color: cColor)
        
        // Bottom-right
        currentPoint = drawLine(currentPoint, delta: CGPointMake(b, 0), color: bColorLight)
        currentPoint = drawLine(currentPoint, delta: CGPointMake(0, -a), color: aColorLight)
        drawLine(currentPoint, delta: CGPointMake(-b, a), color: cColorLight)
        
        // Top-right
        currentPoint = drawLine(currentPoint, delta: CGPointMake(0, -b), color: bColor)
        currentPoint = drawLine(currentPoint, delta: CGPointMake(-a, 0), color: aColor)
        drawLine(currentPoint, delta: CGPointMake(a, b), color: cColor)
        
        
        // Draw the square for the current value of C
        // Figure how dark it should be depending on how close they got
        let expectedC = sqrt(pow(a, 2) + pow(b, 2))
        let difference = abs(c - expectedC)
        let maxDifference: CGFloat = 6.0
        let minOpacity = lightness
        let cOpacity: CGFloat
        if difference < maxDifference {
            cOpacity = 1.0 - (difference / maxDifference) * (1.0 - minOpacity)
        } else {
            cOpacity = minOpacity
        }
        let cColorResult = CGColorCreateCopyWithAlpha(cColor, cOpacity)!
        
        CGContextSaveGState(context)
        // Translate to the center of the right square, and rotate to match the hyp sides
        CGContextTranslateCTM(context, (self.bounds.size.width + spacing + squareSide) / 2, topMargin + squareSide / 2)
        CGContextRotateCTM(context, -atan2(a, b))
        
        CGContextSetFillColorWithColor(context, cColorResult)
        let cRect = CGRectMake(-c/2, -c/2, c, c)
        CGContextFillRect(context, CGRectInset(cRect, -lineWidth/2, -lineWidth/2))
        
        let darkCSegments = [
            CGPointMake(-c/2, c/2), CGPointMake(c/2, c/2),
            CGPointMake(-c/2, -c/2), CGPointMake(c/2, -c/2)
            ]
        CGContextSetStrokeColorWithColor(context, cColor)
        CGContextStrokeLineSegments(context, darkCSegments, darkCSegments.count)
        
        
        CGContextRestoreGState(context)
    }
    
}

