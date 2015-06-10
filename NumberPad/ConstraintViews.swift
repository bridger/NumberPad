//
//  ConstraintViews.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 1/12/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import UIKit
import DigitRecognizerSDK
import WebKit

// Views that contain and draw Connector, Adder, or Multiplier. Their center stays the same, but otherwise they can rotate and resize to fit

class ConnectorLabel: UIView, WKScriptMessageHandler {
    let valueLabel: UILabel = UILabel()
    var scale: Int16 = -1
    let connector: Connector
    var isDependent: Bool = false
    var isPercent: Bool = false
    var equationView: WKWebView?
    var equationViewSize: CGSize?

    init(connector: Connector) {
        self.connector = connector
        super.init(frame: CGRectZero)
        connectorLabelInitialize()
    }
    
    required init(coder aDecoder: NSCoder) {
        self.connector = Connector()
        super.init(coder: aDecoder)
        connectorLabelInitialize()
    }
    
    let borderWidth: CGFloat = 3
    private func connectorLabelInitialize() {
        self.addSubview(self.valueLabel)
        self.valueLabel.font = UIFont.boldSystemFontOfSize(22)
        self.layer.borderWidth = borderWidth
        self.layer.cornerRadius = 12
        self.valueLabel.textAlignment = .Center
        self.layer.masksToBounds = true
        self.hasError = false
        
        //self.displayEquation("<msup><mi>e</mi><mrow><mi>x</mi><mo>+</mo><mn>2</mn><mo>-</mo><mn>3</mn></mrow></msup>")
    }
    
    func displayEquation(mathML: String) {
        if self.equationView == nil {
            let userContentController = WKUserContentController()
            userContentController.addScriptMessageHandler(self, name: "equationRendered")
            
            let source = "var rect = document.getElementById('math-element').getBoundingClientRect(); window.webkit.messageHandlers.equationRendered.postMessage([rect.right, rect.bottom]);"
            userContentController.addUserScript(WKUserScript(source: source, injectionTime: .AtDocumentEnd, forMainFrameOnly: true))
            
            let configuration = WKWebViewConfiguration()
            configuration.userContentController = userContentController
            let equationView = WKWebView(frame: CGRectMake(10, 20, 65, 25), configuration: configuration)
            
            self.addSubview(equationView)
            equationView.backgroundColor = UIColor.clearColor()
            equationView.opaque = false
            equationView.userInteractionEnabled = false
            self.equationView = equationView
        }
        
        if let equationView = self.equationView { // Should always succeed
            let htmlString = "<!DOCTYPE html><html lang='en'><head><meta name='viewport' content='initial-scale=1.0'/></head><body style='margin:0px'><math id='math-element'><mathstyle fontsize='12pt' mathcolor='rgb(127,127,127)'><mrow>\(mathML)</mrow></mathstyle></math></body></html>"
            equationView.loadHTMLString(htmlString, baseURL: nil)
        }
    }
    
    func hideEquation() {
        if let equationView = self.equationView {
            equationView.removeFromSuperview()
            self.equationView = nil
            self.equationViewSize = nil
            
            resizeAndLayout()
        }
    }
    
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        if let rectValues = message.body as? [CGFloat] {
            if rectValues.count == 2 {
                
                let widthDelta: CGFloat = 8.0
                let heightDelta: CGFloat = 3.0
                // Here we "smooth" out the equationViewSize. We choose a size delta points bigger, and we only change the size if it goes above that size or below size - delta
                let latestWidth = rectValues[0]
                let latestHeight = rectValues[1]
                
                let newSize = CGSizeMake(latestWidth + widthDelta, latestHeight + heightDelta)
                if let oldSize = self.equationViewSize {
                    // It was at 5, so we chose 8. Now we only pick a new size if the latest width is > 8 or < 2
                    let maxDelta = max(abs(latestWidth - oldSize.width), abs(latestHeight - oldSize.height))
                    let minWidth = oldSize.width - widthDelta * 2
                    let minHeight = oldSize.height - heightDelta * 2
                    if latestWidth > oldSize.width || latestWidth < minWidth || latestHeight > oldSize.height || latestHeight < minHeight {
                        
                        self.equationViewSize = newSize
                    } else {
                        // No change. Keep the oldSize
                    }
                } else {
                    self.equationViewSize = newSize
                }
                
                if let equationView = self.equationView {
                    equationView.frame.size = CGSizeMake(latestWidth, latestHeight)
                }
                resizeAndLayout()
                return
            }
        }
        println("Something went wrong! We couldn't get the size of the equation")
    }
    
    var isSelected: Bool = false {
        didSet {
            if self.isSelected {
                self.backgroundColor = UIColor(white: 0.45, alpha: 1.0)
                self.valueLabel.textColor = UIColor.whiteColor()
            } else {
                self.backgroundColor = UIColor.whiteColor()
                self.valueLabel.textColor = UIColor.grayColor()
            }
        }
    }
    
    var hasError: Bool = false {
        didSet {
            if self.hasError {
                self.layer.borderColor = UIColor.redColor().CGColor
            } else {
                self.layer.borderColor = UIColor.lightGrayColor().CGColor
            }
        }
    }
    
    // Returns whether it changed size
    func displayValue(value: Double?) -> Bool {
        if var value = value {
            var scale = self.scale
            if isPercent {
                value *= 100
                scale += 2
            }
            
            let formatString: String
            switch scale {
            case let minScale where minScale <= -4: // 0.0001
                formatString = "%.4f"
            case -3: // 0.001
                formatString = "%.3f"
            case -2: // 0.01
                formatString = "%.2f"
            case -1: // 0.1
                formatString = "%.1f"
            case 1: // 10
                formatString = "%.f"
            case let maxScale where maxScale >= 2: // 100
                formatString = "%.f"
            default: // Also, case 0
                formatString = "%.f"
            }
            
            self.valueLabel.text = String(format: formatString, value) + (isPercent ? "%" : "")
        } else {
            self.valueLabel.text = "?"
        }
        
        return resizeAndLayout()
    }
    
    func resizeAndLayout() -> Bool {
        let center = self.center
        let size = self.bounds.size
        sizeToFit()
        if !CGSizeEqualToSize(size, self.bounds.size) {
            self.center = center
            return true
        }
        return false
    }
    
    override func sizeToFit() {
        self.valueLabel.sizeToFit()
        let valueLabelSize = self.valueLabel.frame.size
        var newSize = valueLabelSize
        
        let verticalMargin: CGFloat = 7.0 + borderWidth
        let horizontalMargin: CGFloat = 7.0 + borderWidth
        let equationSpace: CGFloat = 2.0
        
        if let equationView = self.equationView {
            if let equationSize = self.equationViewSize {
                newSize.width = max(newSize.width, equationSize.width)
                newSize.height += equationSpace + equationSize.height
            }
        }

        newSize.width += horizontalMargin * 2
        newSize.height += verticalMargin * 2
        
        self.valueLabel.center = CGPointMake(newSize.width / 2, verticalMargin + valueLabelSize.height / 2)
        if let equationView = self.equationView {
            equationView.center = CGPointMake(newSize.width / 2,
                verticalMargin + valueLabelSize.height + equationSpace + equationView.frame.size.height / 2)
        }
        
        self.frame.size = newSize
    }
}

protocol ConnectorPort: NSObjectProtocol {
    var color: UIColor {
        get
    }
    var connector: Connector? {
        get
    }
    var center: CGPoint {
        get
    }
    var isSelected: Bool {
        get
        set
    }
}

class InternalConnectorPort: NSObject, ConnectorPort {
    let color: UIColor
    var connector: Connector?
    let layer: CALayer
    let isOutput: Bool
    var center: CGPoint { // In the constraintView's coordinate system
        get {
            return layer.position
        }
    }
    init(color: UIColor, isOutput: Bool) {
        self.color = color
        self.isOutput = isOutput
        self.layer = CALayer()
        self.layer.backgroundColor = color.CGColor
        let connectorSize: CGFloat = 16
        self.layer.frame = CGRectMake(0, 0, connectorSize, connectorSize)
        self.layer.cornerRadius = connectorSize / 2.0
    }
    var isSelectedInternal: Bool = false
    var isSelected: Bool {
        get {
            return isSelectedInternal
        }
        set {
            isSelectedInternal = newValue
            if isSelectedInternal {
                if let saturated = self.color.colorWithSaturationComponent(0.2) {
                    self.layer.backgroundColor = saturated.CGColor
                    self.layer.borderColor = self.color.CGColor
                    self.layer.borderWidth = 2.0
                }
            } else {
                self.layer.backgroundColor = self.color.CGColor
                self.layer.borderWidth = 0.0
            }
        }
    }
}

class ConstraintView: UIView {
    var constraint: Constraint {
        get {
            fatalError("This method must be overriden")
        }
    }
    
    func connectorPorts() -> [ConnectorPort] {
        fatalError("This method must be overriden")
    }
    func connectorPortForDragAtLocation(location: CGPoint) -> ConnectorPort? {
        fatalError("This method must be overriden")
    }
    func connectPort(port: ConnectorPort, connector: Connector) {
        fatalError("This method must be overriden")
    }
    func layoutWithConnectorPositions(positions: [Connector: CGPoint]) {
        fatalError("This method must be overriden")
    }
    func removeConnectorAtPort(port: ConnectorPort) {
        fatalError("This method must be overriden")
    }
    
    private func addSentinelConnectorToPort(connectorPort: InternalConnectorPort) {
        self.connectPort(connectorPort, connector: Connector())
    }
}

class MultiInputOutputConstraintView: ConstraintView {
    let innerConstraint: MultiInputOutputConstraint
    override var constraint: Constraint {
        get {
            return innerConstraint
        }
    }
    
    let redInput = InternalConnectorPort(color: UIColor.redColor(), isOutput: false)
    let blueInput = InternalConnectorPort(color: UIColor.blueColor(), isOutput: false)
    let purpleOutput = InternalConnectorPort(color: UIColor.purpleColor(), isOutput: true)
    
    override func connectorPorts() -> [ConnectorPort] {
        return [redInput, blueInput, purpleOutput]
    }
    
    func internalConnectorPorts() -> [InternalConnectorPort] {
        return [redInput, blueInput, purpleOutput]
    }
    func connectorPortIsMine(port: ConnectorPort) -> Bool {
        return port === redInput || port === blueInput || port === purpleOutput
    }
    
    func inputConnectorPorts() -> [ConnectorPort] {
        return [redInput, blueInput]
    }
    func outputConnectorPorts() -> [ConnectorPort] {
        return [purpleOutput]
    }
    
    override func connectorPortForDragAtLocation(location: CGPoint) -> ConnectorPort? {
        for internalPort in internalConnectorPorts() {
            if euclidianDistanceSquared(internalPort.layer.position, location) < 400 {
                return internalPort
            }
        }
        return nil
    }
    
    override func connectPort(port: ConnectorPort, connector: Connector) {
        for internalPort in internalConnectorPorts() {
            if internalPort === port {
                if let oldConnector = internalPort.connector {
                    if internalPort.isOutput {
                        innerConstraint.removeOutput(oldConnector)
                    } else {
                        innerConstraint.removeInput(oldConnector)
                    }
                }
                
                if internalPort.isOutput {
                    innerConstraint.addOutput(connector)
                } else {
                    innerConstraint.addInput(connector)
                }
                internalPort.connector = connector
                
                return
            }
        }
    }
    
    override func removeConnectorAtPort(port: ConnectorPort) {
        for internalPort in internalConnectorPorts() {
            if internalPort === port {
                addSentinelConnectorToPort(internalPort) // This will remove the old connector
                return
            }
        }
    }
    
    let redLayer: CALayer = CALayer()
    let blueLayer: CALayer = CALayer()
    let purpleLayer: CALayer = CALayer()
    init(constraint: MultiInputOutputConstraint) {
        self.innerConstraint = constraint
        super.init(frame: CGRectZero)
        self.layer.cornerRadius = 5
        addSentinelConnectorToPort(self.redInput)
        addSentinelConnectorToPort(self.blueInput)
        addSentinelConnectorToPort(self.purpleOutput)
        self.redLayer.backgroundColor = UIColor.redColor().CGColor
        self.blueLayer.backgroundColor = UIColor.blueColor().CGColor
        self.purpleLayer.backgroundColor = UIColor.purpleColor().CGColor
        for layer in [self.redLayer, self.blueLayer, self.purpleLayer, self.redInput.layer, self.blueInput.layer, self.purpleOutput.layer] {
            self.layer.addSublayer(layer)
        }
    }
    
    override init(coder aDecoder: NSCoder) {
        fatalError("Initializer not supported")
    }
    
    
    
    override func layoutWithConnectorPositions(positions: [Connector: CGPoint]) {
        // Subclasses should have overriden this method, layed out the connectors, then called super
        
        var angles: [(ChangeableAngle: CGFloat, TargetAngle: CGFloat)] = []
        var flippedPortAngles: [CGFloat] = []
        for internalConnector in self.internalConnectorPorts() {
            if let connector = internalConnector.connector, let position = positions[connector] {
                let portAngle = (internalConnector.center - self.bounds.center()).angle
                let connectorAngle = (position - self.center).angle
                
                angles.append((ChangeableAngle: portAngle, TargetAngle: connectorAngle))
            }
        }
        
        let (idealAngle, idealFlip) = optimizeAngles(angles)
        let baseTransform = idealFlip ? CGAffineTransformMakeScale(1, -1) : CGAffineTransformIdentity
        self.transform = CGAffineTransformRotate(baseTransform, idealAngle)
    }
    
}

class MultiplierView: MultiInputOutputConstraintView {
    let multiplier: Multiplier
    init(multiplier: Multiplier) {
        self.multiplier = multiplier
        super.init(constraint: multiplier)
    }
    
    let mySize: CGFloat = 50.0
    let spacing: CGFloat = 5.0
    let barSize: CGFloat = 6.0
    override func layoutWithConnectorPositions(positions: [Connector: CGPoint]) {
        self.sizeToFit()
        
        let marginSpace = spacing + barSize
        let purpleSquareSize = mySize - marginSpace
        
        self.redLayer.frame = CGRectMake(0, marginSpace, barSize, purpleSquareSize)
        self.blueLayer.frame = CGRectMake(marginSpace, 0, purpleSquareSize, barSize)
        self.purpleLayer.frame = CGRectMake(marginSpace, marginSpace, purpleSquareSize, purpleSquareSize)
        self.redLayer.cornerRadius = barSize / 2
        self.blueLayer.cornerRadius = barSize / 2
        self.purpleLayer.cornerRadius = barSize / 2
        
        self.redInput.layer.position = CGPointMake(barSize / 2.0, purpleSquareSize / 2.0 + marginSpace)
        self.blueInput.layer.position = CGPointMake(purpleSquareSize / 2.0 + marginSpace, barSize / 2.0)
        self.purpleOutput.layer.position = CGPointMake(mySize, mySize)
        
        super.layoutWithConnectorPositions(positions)
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(mySize, mySize)
    }
}

class AdderView: MultiInputOutputConstraintView {
    let adder: Adder
    init(adder: Adder) {
        self.adder = adder
        super.init(constraint: adder)
    }
    
    let myWidth: CGFloat = 60.0
    let spacing: CGFloat = 10.0
    let barHeight: CGFloat = 5.0
    override func layoutWithConnectorPositions(positions: [Connector: CGPoint]) {
        self.sizeToFit()
        self.redInput.layer.position = CGPointMake(0, barHeight / 2.0)
        self.blueInput.layer.position = CGPointMake(myWidth, barHeight / 2.0)
        self.purpleOutput.layer.position = CGPointMake(myWidth / 2.0, barHeight + spacing + barHeight / 2.0)
        
        self.redLayer.frame = CGRectMake(0, 0, myWidth / 2.0, barHeight)
        self.blueLayer.frame = CGRectMake(myWidth / 2.0, 0, myWidth / 2.0, barHeight)
        self.purpleLayer.frame = CGRectMake(0, barHeight + spacing, myWidth, barHeight)
        self.redLayer.cornerRadius = barHeight / 2
        self.blueLayer.cornerRadius = barHeight / 2
        self.purpleLayer.cornerRadius = barHeight / 2
        
        super.layoutWithConnectorPositions(positions)
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(myWidth, barHeight * 2 + spacing)
    }
}


class ExponentView: ConstraintView {
    let exponent: Exponent
    override var constraint: Constraint {
        get {
            return exponent
        }
    }
    var basePort: ConnectorPort {
        get {
            return baseInput
        }
    }
    var exponentPort: ConnectorPort {
        get {
            return exponentInput
        }
    }
    var resultPort: ConnectorPort {
        get {
            return resultOutput
        }
    }
    
    let baseInput = InternalConnectorPort(color: UIColor.redColor(), isOutput: false)
    let exponentInput = InternalConnectorPort(color: UIColor.blueColor(), isOutput: false)
    let resultOutput = InternalConnectorPort(color: UIColor.purpleColor(), isOutput: true)
    
    override func connectorPorts() -> [ConnectorPort] {
        return [baseInput, exponentInput, resultOutput]
    }
    
    func internalConnectorPorts() -> [InternalConnectorPort] {
        // The order here is the order they will be picked for connectorPortForDragAtLocation
        return [exponentInput, resultOutput, baseInput]
    }
    func connectorPortIsMine(port: ConnectorPort) -> Bool {
        return port === baseInput || port === exponentInput || port === resultOutput
    }
    
    override func connectorPortForDragAtLocation(location: CGPoint) -> ConnectorPort? {
        for internalPort in internalConnectorPorts() {
            let cutoffSquared: CGFloat = (internalPort === basePort) ? 900 : 400
            if euclidianDistanceSquared(internalPort.layer.position, location) < cutoffSquared {
                return internalPort
            }
        }
        return nil
    }
    
    override func connectPort(port: ConnectorPort, connector: Connector) {
        if port === baseInput {
            exponent.base = connector
            baseInput.connector = connector
        } else if port === exponentInput {
            exponent.exponent = connector
            exponentInput.connector = connector
        } else if port === resultOutput {
            exponent.result = connector
            resultOutput.connector = connector
        }
    }
    
    override func removeConnectorAtPort(port: ConnectorPort) {
        for internalPort in internalConnectorPorts() {
            if internalPort === port {
                addSentinelConnectorToPort(internalPort) // This will remove the old connector
                return
            }
        }
    }
    
    let resultLayer: CAShapeLayer = CAShapeLayer()
    init(exponent: Exponent) {
        self.exponent = exponent
        super.init(frame: CGRectZero)
        addSentinelConnectorToPort(self.exponentInput)
        addSentinelConnectorToPort(self.baseInput)
        addSentinelConnectorToPort(self.resultOutput)
        self.resultLayer.strokeColor = UIColor.purpleColor().CGColor
        self.resultLayer.lineWidth = 4.0
        self.resultLayer.lineCap = kCALineCapRound
        self.resultLayer.fillColor = nil
        for layer in [self.resultLayer, self.exponentInput.layer, self.baseInput.layer, self.resultOutput.layer] {
            self.layer.addSublayer(layer)
        }
    }
    
    override init(coder aDecoder: NSCoder) {
        fatalError("Initializer not supported")
    }
    
    
    let myWidth: CGFloat = 60.0
    let myHeight: CGFloat = 50.0
    let spacing: CGFloat = 10.0
    let barHeight: CGFloat = 5.0
    override func layoutWithConnectorPositions(positions: [Connector: CGPoint]) {
        self.sizeToFit()
        
        self.baseInput.layer.zPosition = 0
        self.exponentInput.layer.zPosition = 1
        self.resultLayer.zPosition = 2
        self.resultOutput.layer.zPosition = 3
        
        let exponentSize: CGFloat = 18
        self.exponentInput.layer.frame = CGRectMake(myWidth * 0.4, 0, exponentSize, exponentSize)
        self.exponentInput.layer.cornerRadius = exponentSize / 2
        
        let baseSize: CGFloat = 35
        let offsetFromExponent = baseSize / 2.0 * CGFloat(M_SQRT1_2) + 2
        let exponentCenter = self.exponentInput.layer.position
        self.baseInput.layer.frame = CGRectMake(0, 0, baseSize, baseSize)
        self.baseInput.layer.position = CGPointMake(exponentCenter.x - offsetFromExponent, exponentCenter.y + offsetFromExponent)
        self.baseInput.layer.cornerRadius = baseSize / 2
        
        let pathBase: CGFloat = 95
        let scale = myHeight / (pathBase - 1.0)
        func pointOnExponentAtX(x: CGFloat) -> CGPoint {
            let percentage = x / self.myWidth
            let y = pow(pathBase, percentage)
            
            let point = CGPointMake(x, self.myHeight - (y - 1.0) * scale)
            return point
        }
        
        let path = CGPathCreateMutable()
        for var i: CGFloat = 0; i < myWidth; i++ {
            // Here we draw an exponent curve from x = 0 to x = 1, which results in y=1 to y=base
            // Then we scale it so y goes from 0 to myHeight
            let point = pointOnExponentAtX(i)
            if i == 0 {
                CGPathMoveToPoint(path, nil, point.x, point.y)
            } else {
                CGPathAddLineToPoint(path, nil, point.x, point.y)
            }
        }
        
        self.resultLayer.path = path
        
        self.resultOutput.layer.position = pointOnExponentAtX(myWidth * 0.7)
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(myWidth, myHeight)
    }
    
}
