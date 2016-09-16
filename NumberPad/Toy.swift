//
//  Toy.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 6/28/15.
//  Copyright © 2015 Bridger Maxwell. All rights reserved.
//

import QuartzCore
import DigitRecognizerSDK

// This is a function passed into updateGhostState. The toy will call this for various different values
// for the input connectors and it should return the resolved value for all of the output connectors
typealias ResolvedValues = [Connector: SimulationContext.ResolvedValue]
typealias GhostValueResolver = ([Connector: Double]) -> ResolvedValues

// This method is called with the value of the current input connector and a lambda which can solve for
// the output connector values given
typealias ConnectorState = (Value: SimulationContext.ResolvedValue, Scale: Int16)


protocol Toy: class {
    func inputConnectors() -> [Connector]
    func outputConnectors() -> [Connector]
    
    func update(values: ResolvedValues)
}

protocol GhostableToy: Toy {
    func updateGhosts(inputStates: [Connector: ConnectorState], resolver: GhostValueResolver)
    
    func ghostState(at point: CGPoint) -> ResolvedValues?

    var ghostsHidden: Bool { get set }
}

protocol SelectableToy: Toy {
    func contains(_ point: CGPoint) -> Bool
    
    var center: CGPoint { get }
    
    var selected: Bool { get set }
    
    func valuesForDrag(to newCenter: CGPoint) -> [Connector: Double]
}

class MotionToy : UIView, SelectableToy, GhostableToy {
    let xConnector: Connector
    let yConnector: Connector
    let driverConnector: Connector
    let image: UIImage
    let imageView: UIImageView
    var yOffset: CGFloat = 0

    init(image: UIImage, xConnector: Connector, yConnector: Connector, driverConnector: Connector) {
        self.xConnector = xConnector
        self.yConnector = yConnector
        self.driverConnector = driverConnector
        self.image = image
        self.imageView = UIImageView(image: image)
        
        super.init(frame: CGRect.zero)
        
        imageView.sizeToFit()
        self.frame.size = imageView.frame.size
        imageView.frame = self.bounds
        self.addSubview(imageView)
    }
    
    func contains(_ point: CGPoint) -> Bool {
        return self.frame.contains(point)
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
        
        let range = 10
        for offset in -range...range {
            if offset == 0 {
                continue
            }
            let valueOffset = Double(offset) * pow(10.0, Double(driverState.Scale + 1))
            let offsetDriverValue = driverState.Value.DoubleValue + valueOffset
            
            let ghostValues = resolver([self.driverConnector: offsetDriverValue])
            
            guard let xPosition = ghostValues[self.xConnector]?.DoubleValue,
                let yPosition = ghostValues[self.yConnector]?.DoubleValue,
                xPosition.isFinite, yPosition.isFinite else {
                    continue
            }
            
            let percent = Double(offset) / Double(range)
            let ghost = self.createNewGhost(percent: percent)
            ghost.simulationContext = ghostValues
            self.superview?.insertSubview(ghost, belowSubview: self)
            ghost.center.x = CGFloat(xPosition)
            ghost.center.y = toyYZero() - CGFloat(yPosition)
        }
    }
    
    func toyYZero() -> CGFloat {
        return (self.superview?.frame.size.height ?? 0) - yOffset
    }
    
    func update(values: [Connector : SimulationContext.ResolvedValue]) {
        removeAllGhosts()
        
        if let xPosition = values[self.xConnector]?.DoubleValue, xPosition.isFinite {
            self.center.x = CGFloat(xPosition)
        }
        if let yPosition = values[self.yConnector]?.DoubleValue, yPosition.isFinite {
            self.center.y = toyYZero() - CGFloat(yPosition)
        }
    }
    
    func valuesForDrag(to newCenter: CGPoint) -> [Connector: Double] {
        return [xConnector: Double(newCenter.x), yConnector: Double(toyYZero() - newCenter.y)]
    }
    
    func ghostState(at point: CGPoint) -> ResolvedValues? {
        var minDistance = CGFloat.greatestFiniteMagnitude
        var bestMatch: ResolvedValues? = nil
        for ghostView in activeGhosts where ghostView.frame.contains(point) {
            let score = ghostView.center.distanceTo(point: point)
            if score < minDistance {
                minDistance = score
                bestMatch = ghostView.simulationContext
            }
        }
        if minDistance < self.center.distanceTo(point: point) {
            return bestMatch
        } else {
            return nil
        }
    }
    
    class GhostView: UIImageView {
        var simulationContext: ResolvedValues? = nil
    }

    var activeGhosts: [GhostView] = []
    var reuseGhosts: [GhostView] = []
    
    func createNewGhost(percent: Double) -> GhostView {
        let ghost: GhostView
        if let oldGhost = reuseGhosts.popLast() {
            ghost = oldGhost
        } else {
            ghost = GhostView(image: self.image)
            ghost.sizeToFit()
        }
        let alpha = (1.0 - abs(percent)) * 0.3
        ghost.alpha = CGFloat(alpha)
        
        activeGhosts.append(ghost)
        ghost.isHidden = ghostsHidden
        return ghost
    }
    
    func removeAllGhosts() {
        for ghost in activeGhosts {
            ghost.removeFromSuperview()
            reuseGhosts.append(ghost)
        }
        activeGhosts = []
    }

    var ghostsHidden: Bool = false {
        didSet {
            for ghost in activeGhosts + reuseGhosts {
                ghost.isHidden = ghostsHidden
            }
        }
    }

    var selected: Bool = false {
        didSet {
            if selected {
                imageView.layer.shadowColor = UIColor.selectedBackgroundColor().cgColor
                imageView.layer.shadowOpacity = 0.8
                imageView.layer.shadowRadius = 5
            } else {
                imageView.layer.shadowOpacity = 0
            }
        }
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
    var position: CGPoint = CGPoint.zero {
        didSet {
            self.mainLayer.position = position
        }
    }
    
    static let valueToPointScale: Double = UIDevice.current.userInterfaceIdiom == .pad ? 20 : 7
    
    var centerOffset = CGPoint.zero
    
    var simulationContext: ResolvedValues? = nil
    
    let mainLayer: CAShapeLayer
    let diameterLayer: CAShapeLayer
    let circumferenceLayer: CAShapeLayer
    let overshootCircumferenceLayer: CAShapeLayer
    
    init() {
        self.mainLayer = CAShapeLayer()
        self.mainLayer.lineWidth = 4
        self.mainLayer.strokeColor = UIColor.multiplierInputColor().withAlphaComponent(0.1).cgColor
        self.mainLayer.fillColor = nil
        
        self.diameterLayer = CAShapeLayer()
        self.diameterLayer.lineWidth = 4
        self.diameterLayer.strokeColor = UIColor.multiplierInputColor().cgColor
        self.diameterLayer.fillColor = nil
        
        self.circumferenceLayer = CAShapeLayer()
        self.circumferenceLayer.lineWidth = 7
        self.circumferenceLayer.strokeColor = UIColor.adderOutputColor().cgColor
        self.circumferenceLayer.fillColor = nil
        
        self.overshootCircumferenceLayer = CAShapeLayer()
        self.overshootCircumferenceLayer.lineWidth = 7
        self.overshootCircumferenceLayer.strokeColor = UIColor.errorColor().cgColor
        self.overshootCircumferenceLayer.fillColor = nil
        
        self.mainLayer.addSublayer(self.diameterLayer)
        self.mainLayer.addSublayer(self.circumferenceLayer)
        self.mainLayer.addSublayer(self.overshootCircumferenceLayer)
        
        update()
    }
    
    func update() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let cgDiameter = CGFloat(self.diameter * CircleLayer.valueToPointScale)
        let cgRadius = cgDiameter / 2
        let roundedSize = round(cgDiameter)
        if self.mainLayer.frame.size.width != roundedSize {
            
            self.mainLayer.frame = CGRect(x: 0, y: 0, width: roundedSize, height: roundedSize)
            self.mainLayer.path = CGPath(ellipseIn: self.mainLayer.bounds, transform: nil)
            self.mainLayer.position = position
            
            let diameterPath = CGMutablePath()
            diameterPath.move(to: CGPoint(x: 0, y: cgRadius))
            diameterPath.addLine(to: CGPoint(x: cgDiameter, y: cgRadius))
            self.diameterLayer.path = diameterPath
        }
        
        let expectedCircumference = self.diameter * M_PI
        let inRangeCircumference = self.circumference.clamp(lower: 0, upper: expectedCircumference)
        let overCircumfererence = self.circumference - inRangeCircumference // Can be negative, if circumference negative
        
        func circumferencePath(length circumference: Double) -> CGPath {
            let circumferencePath = CGMutablePath()
            let angle = -CGFloat(circumference * CircleLayer.valueToPointScale) / cgRadius
            let clockwise = angle < 0
            circumferencePath.addArc(center: CGPoint(x: cgRadius, y: cgRadius), radius: cgRadius, startAngle: 0, endAngle: angle, clockwise: clockwise)
            return circumferencePath
        }
        
        let maxDifference = self.diameter * 0.0375
        let difference = abs(self.circumference - expectedCircumference)
        let percentError = (difference / maxDifference).clamp(lower: 0, upper: 1.0)
        
        let lineWidth = CGFloat(percentError.lerp(lower: 9, upper: 7))
        self.circumferenceLayer.lineWidth = lineWidth
        self.overshootCircumferenceLayer.lineWidth = lineWidth
        
        self.circumferenceLayer.path = circumferencePath(length: inRangeCircumference)
        let minOpacity: Double = 0.3
        self.circumferenceLayer.opacity = Float(percentError.lerp(lower: 1.0, upper: minOpacity))
        
        self.overshootCircumferenceLayer.path = circumferencePath(length: overCircumfererence)
        self.overshootCircumferenceLayer.opacity = Float(abs(overCircumfererence / maxDifference).lerp(lower: minOpacity, upper: 1.0))
        
        CATransaction.commit()
    }
}

class CirclesToy : UIView, GhostableToy {
    let diameterConnector: Connector
    let circumferenceConnector: Connector
    
    let mainCircle: CircleLayer
    init(diameterConnector: Connector, circumferenceConnector: Connector) {
        self.diameterConnector = diameterConnector
        self.circumferenceConnector = circumferenceConnector
        self.mainCircle = CircleLayer()
        
        super.init(frame: CGRect.zero)
        
        self.layer.addSublayer(self.mainCircle.mainLayer)
        self.isUserInteractionEnabled = false
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
    
    override func layoutSublayers(of layer: CALayer) {
        let center = CGPoint(x: layer.bounds.size.width / 2, y: layer.bounds.size.height * 2 / 3)
        
        self.mainCircle.position = center
        for ghost in self.activeGhosts {
            ghost.position = center + ghost.centerOffset
        }
    }
    
    func update(values: [Connector : SimulationContext.ResolvedValue]) {
        if let diameter = values[self.diameterConnector]?.DoubleValue, diameter.isFinite {
            self.mainCircle.diameter = diameter
        }
        if let circumference = values[self.circumferenceConnector]?.DoubleValue, circumference.isFinite {
            self.mainCircle.circumference = circumference
        }
    }
    
    var activeGhosts: [CircleLayer] = []
    var reuseGhosts: [CircleLayer] = []

    func createNewGhost() -> CircleLayer {
        let ghost: CircleLayer
        if let oldGhost = reuseGhosts.popLast() {
            ghost = oldGhost
        } else {
            ghost = CircleLayer()
        }
        ghost.mainLayer.opacity = 0.35
        ghost.mainLayer.isHidden = ghostsHidden
        
        activeGhosts.append(ghost)
        self.layer.addSublayer(ghost.mainLayer)
        return ghost
    }
    
    func removeAllGhosts() {
        for ghost in activeGhosts.reversed() {
            ghost.mainLayer.removeFromSuperlayer()
            reuseGhosts.append(ghost)
        }
        activeGhosts = []
    }

    var ghostsHidden: Bool = false {
        didSet {
            for ghost in activeGhosts + reuseGhosts {
                ghost.mainLayer.isHidden = ghostsHidden
            }
        }
    }

    func updateGhosts(inputStates: [Connector : ConnectorState], resolver: GhostValueResolver) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        
        removeAllGhosts()
        
        let driverConnector = self.diameterConnector
        guard let driverState = inputStates[driverConnector] else {
            return
        }
        let driverValue = driverState.Value.DoubleValue
        
        func diameter(at index: Int) -> Double {
            return pow(1.3, Double(index)) * driverValue
        }
        
        let range = 4
        for offsetIndex in -range...range {
            if offsetIndex == 0 {
                continue
            }
            
            let offsetDriverValue = diameter(at: offsetIndex)
            
            if offsetDriverValue <= 0 || !offsetDriverValue.isFinite {
                continue
            }
            
            let ghostValues = resolver([driverConnector: offsetDriverValue])
            
            guard let circumference = ghostValues[self.circumferenceConnector]?.DoubleValue,
                circumference.isFinite else {
                    continue
            }
            
            let ghost = self.createNewGhost()
            ghost.simulationContext = ghostValues
            ghost.circumference = circumference
            ghost.diameter = offsetDriverValue
            
            // We need to space this out so it accounts for the main circle's width, it's own width, and the
            // width of each ghost in between
            let spacing: Double = 15
            let offsetDirection: Int = offsetIndex > 0 ? 1 : -1
            let halfWidths = (driverValue + offsetDriverValue) / 2 * CircleLayer.valueToPointScale
            var xOffset = Double(offsetDirection) * (halfWidths + spacing)
            
            // Figure the size of each ghost between this ghost and the real circle, and account for its size
            var inBetweenGhostIndex = offsetIndex - offsetDirection
            while inBetweenGhostIndex != 0 {
                xOffset += Double(offsetDirection) * (diameter(at: inBetweenGhostIndex) * CircleLayer.valueToPointScale + spacing)
                inBetweenGhostIndex -= offsetDirection
            }
            
            ghost.centerOffset = CGPoint(x: CGFloat(xOffset), y: 0)
        }
        self.layer.layoutIfNeeded()
    }
    
    func ghostState(at point: CGPoint) -> ResolvedValues? {
        for ghost in activeGhosts where ghost.mainLayer.frame.contains(point) {
            return ghost.simulationContext
        }
        return nil
    }
}

class SquareLayer {
    var side: Double = 0 {
        didSet {
            update()
        }
    }
    var area: Double = 0 {
        didSet {
            update()
        }
    }
    var position: CGPoint = CGPoint.zero {
        didSet {
            self.mainLayer.position = position
        }
    }
    
    static let valueToPointScale: Double = UIDevice.current.userInterfaceIdiom == .pad ? 15 : 9
    
    var centerOffset = CGPoint.zero
    
    var simulationContext: ResolvedValues? = nil
    
    let darkSidesLayer: CAShapeLayer // Two lines, dark
    let lightSidesLayer: CAShapeLayer // Two lines, light
    let darkAreaLayer: CAShapeLayer // Two lines, dark
    let lightAreaLayer: CAShapeLayer // Filled in and transparent unless correct
    
    var mainLayer: CAShapeLayer {
        get {
            return darkSidesLayer
        }
    }
    
    let lineWidth: CGFloat = 4
    init() {
        let color = UIColor.adderInputColor()
        let transparentColor = color.withAlphaComponent(0.2)
        
        self.darkSidesLayer = CAShapeLayer()
        self.darkSidesLayer.lineWidth = lineWidth
        self.darkSidesLayer.strokeColor = color.cgColor
        self.darkSidesLayer.fillColor = nil
        self.darkSidesLayer.lineCap = "round"
        
        self.lightSidesLayer = CAShapeLayer()
        self.lightSidesLayer.lineWidth = lineWidth
        self.lightSidesLayer.strokeColor = transparentColor.cgColor
        self.lightSidesLayer.fillColor = nil
        self.lightSidesLayer.lineCap = "round"
        
        self.darkAreaLayer = CAShapeLayer()
        self.darkAreaLayer.lineWidth = lineWidth
        self.darkAreaLayer.strokeColor = color.cgColor
        self.darkAreaLayer.fillColor = nil
        self.darkAreaLayer.lineCap = "round"
        
        self.lightAreaLayer = CAShapeLayer()
        self.lightAreaLayer.fillColor = color.cgColor
        
        self.darkSidesLayer.addSublayer(self.lightSidesLayer)
        self.darkSidesLayer.addSublayer(self.darkAreaLayer)
        self.darkAreaLayer.addSublayer(self.lightAreaLayer)
        
        update()
    }
    
    func update() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer {CATransaction.commit()}
        
        func pathForSides(length: CGFloat, vertical: Bool) -> CGPath {
            // This draws a path with two lines on the sides of a square either on
            // the vertical or horizontal edges
            let segments = [
                CGPoint(x: 0, y: 0), // bottom-left
                (vertical
                    ? CGPoint(x: 0, y: length) // top-left
                    : CGPoint(x: length, y: 0) // bottom-right
                ),
                
                CGPoint(x: length, y: length), // top-right
                (vertical
                    ? CGPoint(x: length, y: 0) // bottom-right
                    : CGPoint(x: 0, y: length) // top-left
                ),
            ]
            let path = CGMutablePath()
            path.move(to: segments[0])
            path.addLine(to: segments[1])
            path.move(to: segments[2])
            path.addLine(to: segments[3])
            return path
        }
        
        let cgSide = CGFloat(self.side * SquareLayer.valueToPointScale)
        if !cgSide.isFinite {
            return
        }
        
        let targetRect = CGRect(x: 0, y: 0, width: cgSide, height: cgSide)
        self.darkSidesLayer.frame = targetRect
        self.darkSidesLayer.path = pathForSides(length: cgSide, vertical: true)
        
        self.lightSidesLayer.frame = targetRect
        self.lightSidesLayer.path = pathForSides(length: cgSide, vertical: false)
        
        let maxDifference = self.area * 0.1
        let targetArea = self.side * self.side
        let difference = abs(self.area - targetArea)
        let percentError = (difference / maxDifference).clamp(lower: 0, upper: 1.0)
        
        var cgAreaSide = CGFloat(sqrt(self.area) * SquareLayer.valueToPointScale)
        if !cgAreaSide.isFinite {
            cgAreaSide = 0
        }

        let areaRect = CGRect(x: 0, y: 0, width: cgAreaSide, height: cgAreaSide)
        
        self.darkAreaLayer.bounds = areaRect
        self.darkAreaLayer.position = targetRect.center()
        self.darkAreaLayer.path = pathForSides(length: cgAreaSide, vertical: false)
        
        self.lightAreaLayer.frame = areaRect
        self.lightAreaLayer.path = CGPath(rect: areaRect.insetBy(dx: -lineWidth/2, dy: -lineWidth/2), transform: nil)
        
        // We let it get lighter if you overshoot because the too-large square
        // starts bumping into other things
        let minOpacity: Double = self.area > targetArea ? 0.15 : 0.3
        self.lightAreaLayer.opacity = Float(percentError.lerp(lower: 1.0, upper: minOpacity))
    }
}

class SquaresToy : UIView, GhostableToy {
    let sideConnector: Connector
    let areaConnector: Connector
    
    let mainSquare: SquareLayer
    init(sideConnector: Connector, areaConnector: Connector) {
        self.sideConnector = sideConnector
        self.areaConnector = areaConnector
        self.mainSquare = SquareLayer()
        
        super.init(frame: CGRect.zero)
        
        self.layer.addSublayer(self.mainSquare.mainLayer)
        self.isUserInteractionEnabled = false
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func inputConnectors() -> [Connector] {
        return [sideConnector]
    }
    
    func outputConnectors() -> [Connector] {
        return [areaConnector]
    }
    
    override func layoutSublayers(of layer: CALayer) {
        let center = CGPoint(x: layer.bounds.size.width / 2, y: layer.bounds.size.height * 2 / 3)
        
        self.mainSquare.position = center
        for ghost in self.activeGhosts {
            ghost.position = center + ghost.centerOffset
        }
    }
    
    func update(values: [Connector : SimulationContext.ResolvedValue]) {
        if let side = values[self.sideConnector]?.DoubleValue, side.isFinite {
            self.mainSquare.side = side
        }
        if let area = values[self.areaConnector]?.DoubleValue, area.isFinite {
            self.mainSquare.area = area
        }
    }
    
    var activeGhosts: [SquareLayer] = []
    var reuseGhosts: [SquareLayer] = []
    
    func createNewGhost() -> SquareLayer {
        let ghost: SquareLayer
        if let oldGhost = reuseGhosts.popLast() {
            ghost = oldGhost
        } else {
            ghost = SquareLayer()
        }
        ghost.mainLayer.opacity = 0.35
        ghost.mainLayer.isHidden = ghostsHidden
        
        activeGhosts.append(ghost)
        self.layer.addSublayer(ghost.mainLayer)
        return ghost
    }
    
    func removeAllGhosts() {
        for ghost in activeGhosts.reversed() {
            ghost.mainLayer.removeFromSuperlayer()
            reuseGhosts.append(ghost)
        }
        activeGhosts = []
    }

    var ghostsHidden: Bool = false {
        didSet {
            for ghost in activeGhosts + reuseGhosts {
                ghost.mainLayer.isHidden = ghostsHidden
            }
        }
    }

    func updateGhosts(inputStates: [Connector : ConnectorState], resolver: GhostValueResolver) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        
        removeAllGhosts()
        
        let driverConnector = self.sideConnector
        guard let driverState = inputStates[driverConnector] else {
            return
        }
        let driverValue = driverState.Value.DoubleValue
        
        func side(at index: Int) -> Double {
            return pow(1.3, Double(index)) * driverValue
        }
        
        let range = 4
        for offsetIndex in -range...range {
            if offsetIndex == 0 {
                continue
            }
            
            let offsetDriverValue = side(at: offsetIndex)
            
            if offsetDriverValue <= 0 || !offsetDriverValue.isFinite {
                continue
            }
            
            let ghostValues = resolver([driverConnector: offsetDriverValue])
            
            guard let area = ghostValues[self.areaConnector]?.DoubleValue,
                area.isFinite else {
                    continue
            }
            
            let ghost = self.createNewGhost()
            ghost.simulationContext = ghostValues
            ghost.area = area
            ghost.side = offsetDriverValue
            
            // We need to space this out so it accounts for the main square's width, it's own width, and the
            // width of each ghost in between
            let spacing: Double = 15
            let offsetDirection: Int = offsetIndex > 0 ? 1 : -1
            let halfWidths = (driverValue + offsetDriverValue) / 2 * SquareLayer.valueToPointScale
            var xOffset = Double(offsetDirection) * (halfWidths + spacing)
            
            // Figure the size of each ghost between this ghost and the real square, and account for its size
            var inBetweenGhostIndex = offsetIndex - offsetDirection
            while inBetweenGhostIndex != 0 {
                xOffset += Double(offsetDirection) * (side(at: inBetweenGhostIndex) * SquareLayer.valueToPointScale + spacing)
                inBetweenGhostIndex -= offsetDirection
            }
            
            ghost.centerOffset = CGPoint(x: CGFloat(xOffset), y: 0)
        }
        self.layer.layoutIfNeeded()
    }
    
    func ghostState(at point: CGPoint) -> ResolvedValues? {
        for ghost in activeGhosts where ghost.mainLayer.frame.contains(point) {
            return ghost.simulationContext
        }
        return nil
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
        
        super.init(frame: CGRect.zero)
        
        self.isUserInteractionEnabled = false
        self.backgroundColor = UIColor.clear
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
    
    var a: Double = 0
    var b: Double = 0
    var c: Double = 0
    let valueToPointScale: Double = UIDevice.current.userInterfaceIdiom == .pad ? 12 : 5
    func update(values: [Connector : SimulationContext.ResolvedValue]) {
        if let a = values[self.aConnector]?.DoubleValue, let b = values[self.bConnector]?.DoubleValue, a.isFinite, b.isFinite {
            if self.a != a || self.b != b {
                self.a = max(a, 0)
                self.b = max(b, 0)
                self.setNeedsDisplay()
            }
        }
        if let c = values[self.cConnector]?.DoubleValue, c.isFinite {
            if self.c != c {
                self.c = max(c, 0)
                self.setNeedsDisplay()
            }
        }
    }
    
    var spacing: CGFloat = 25
    var topMargin: CGFloat = 80
    override func draw(_ rect: CGRect) {
        
        let a = CGFloat(self.a * valueToPointScale)
        let b = CGFloat(self.b * valueToPointScale)
        let c = CGFloat(self.c * valueToPointScale)
        
        let context = UIGraphicsGetCurrentContext()!
        context.clear(rect)
        let lineWidth: CGFloat = 4
        @discardableResult func drawLine(startPoint: CGPoint, delta: CGPoint, color: CGColor) -> CGPoint {
            let endPoint = CGPoint(x: startPoint.x + delta.x, y: startPoint.y + delta.y)
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setStrokeColor(color)
            context.strokePath()
            return endPoint
        }
        
        func fillSquare(corner: CGPoint, size: CGSize, color: CGColor) -> CGPoint {
            let rect = CGRect(x: corner.x, y:  corner.y, width:  size.width, height: size.height)
            
            context.setFillColor(color)
            context.fill(rect.insetBy(dx: -lineWidth/2, dy: -lineWidth/2))
            
            return CGPoint(x: corner.x + size.width, y: corner.y + size.height)
        }
        
        let lightness: CGFloat = 0.25
        let aColor = UIColor.multiplierInputColor().cgColor
        let aColorLight = aColor.copy(alpha: lightness)!
        let bColor = UIColor.adderInputColor().cgColor
        let bColorLight = bColor.copy(alpha: lightness)!
        let cColor = UIColor.exponentBaseColor().cgColor
        let cColorLight = cColor.copy(alpha: lightness)!
        
        let squareSide = a + b
        let totalWidth = squareSide * 2 + spacing
        let minX = (self.bounds.size.width - totalWidth) / 2
        
        
        /* --- Left square --- */
        var currentPoint = CGPoint(x: minX, y: topMargin + a)
        // Bottom-left square
        currentPoint = fillSquare(corner: currentPoint, size: CGSize(width: b, height: b), color: bColorLight)
        
        // Bottom-right triangles
        drawLine(startPoint: currentPoint, delta: CGPoint(x: a, y: -b), color: cColor)
        currentPoint = drawLine(startPoint: currentPoint, delta: CGPoint(x: a, y: 0), color: aColor)
        currentPoint = drawLine(startPoint: currentPoint, delta: CGPoint(x: 0, y: -b), color: bColor)
        
        // Top-right square
        currentPoint = fillSquare(corner: currentPoint, size: CGSize(width: -a, height: -a), color: aColorLight)
        
        // Top-left triangles
        drawLine(startPoint: currentPoint, delta: CGPoint(x: -b, y: a), color: cColor)
        drawLine(startPoint: currentPoint, delta: CGPoint(x: 0, y: a), color: aColor)
        currentPoint = drawLine(startPoint: currentPoint, delta: CGPoint(x: -b, y: 0), color: bColorLight)
        currentPoint = drawLine(startPoint: currentPoint, delta: CGPoint(x: 0, y: a), color: aColorLight)
        drawLine(startPoint: currentPoint, delta: CGPoint(x: b, y: 0), color: bColor)
        
        
        /* --- Right square --- */
        // Top-left
        currentPoint = CGPoint(x:  (self.bounds.size.width + spacing) / 2 + b, y: topMargin)
        currentPoint = drawLine(startPoint: currentPoint, delta: CGPoint(x: -b, y: 0), color: bColorLight)
        currentPoint = drawLine(startPoint: currentPoint, delta: CGPoint(x: 0, y: a), color: aColorLight)
        drawLine(startPoint: currentPoint, delta: CGPoint(x: b, y: -a), color: cColorLight)
        
        // Bottom-left
        currentPoint = drawLine(startPoint: currentPoint, delta: CGPoint(x: 0, y: b), color: bColor)
        currentPoint = drawLine(startPoint: currentPoint, delta: CGPoint(x: a, y: 0), color: aColor)
        drawLine(startPoint: currentPoint, delta: CGPoint(x: -a, y: -b), color: cColor)
        
        // Bottom-right
        currentPoint = drawLine(startPoint: currentPoint, delta: CGPoint(x: b, y: 0), color: bColorLight)
        currentPoint = drawLine(startPoint: currentPoint, delta: CGPoint(x: 0, y: -a), color: aColorLight)
        drawLine(startPoint: currentPoint, delta: CGPoint(x: -b, y: a), color: cColorLight)
        
        // Top-right
        currentPoint = drawLine(startPoint: currentPoint, delta: CGPoint(x: 0, y: -b), color: bColor)
        currentPoint = drawLine(startPoint: currentPoint, delta: CGPoint(x: -a, y: 0), color: aColor)
        drawLine(startPoint: currentPoint, delta: CGPoint(x: a, y: b), color: cColor)
        
        
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
        let cColorResult = cColor.copy(alpha: cOpacity)!
        
        context.saveGState()
        // Translate to the center of the right square, and rotate to match the hyp sides
        context.translateBy(x: (self.bounds.size.width + spacing + squareSide) / 2, y: topMargin + squareSide / 2)
        context.rotate(by: -atan2(a, b))
        
        context.setFillColor(cColorResult)
        let cRect = CGRect(x: -c/2, y:  -c/2, width:  c, height: c)
        context.fill(cRect.insetBy(dx: -lineWidth/2, dy: -lineWidth/2))
        
        let darkCSegments = [
            CGPoint(x: -c/2, y: c/2), CGPoint(x: c/2, y: c/2),
            CGPoint(x: -c/2, y: -c/2), CGPoint(x: c/2, y: -c/2)
        ]
        context.setStrokeColor(cColor)
        context.strokeLineSegments(between: darkCSegments)
        
        
        context.restoreGState()
    }
}

