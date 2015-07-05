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
    var name: String?

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
    
    let borderWidth: CGFloat = 2
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
        print("Something went wrong! We couldn't get the size of the equation")
    }
    
    var isSelected: Bool = false {
        didSet {
            if self.isSelected {
                self.backgroundColor = UIColor.selectedBackgroundColor()
                self.valueLabel.textColor = UIColor.selectedTextColor()
            } else {
                self.backgroundColor = UIColor.backgroundColor()
                self.valueLabel.textColor = UIColor.textColor()
            }
        }
    }
    
    var hasError: Bool = false {
        didSet {
            if self.hasError {
                self.layer.borderColor = UIColor.redColor().CGColor
            } else {
                self.layer.borderColor = UIColor.textColor().CGColor
            }
        }
    }
    
    // Returns whether it changed size
    func displayValue(value: Double?) -> Bool {
        
        let namePrefix = self.name != nil ? self.name! + " : " : ""
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
            
            self.valueLabel.text = namePrefix + String(format: formatString, value) + (isPercent ? "%" : "")
        } else {
            self.valueLabel.text = namePrefix + "?"
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
        
        if let equationSize = self.equationViewSize where equationView != nil {
            newSize.width = max(newSize.width, equationSize.width)
            newSize.height += equationSpace + equationSize.height
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
    var color: UIColor = UIColor.whiteColor() {
        didSet {
            self.layer.backgroundColor = color.CGColor
        }
    }
    var connector: Connector?
    let layer: CALayer
    let isOutput: Bool
    var center: CGPoint { // In the constraintView's coordinate system
        get {
            return layer.position
        }
    }
    init(isOutput: Bool) {
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
    
    func idealAngleForNewConnectorLabel(connector: Connector, positions: [Connector: CGPoint]) -> CGFloat {
        fatalError("This method must be overriden")
    }
}

class MultiInputOutputConstraintView: ConstraintView {
    let innerConstraint: MultiInputOutputConstraint
    override var constraint: Constraint {
        get {
            return innerConstraint
        }
    }
    
    var inputColor: UIColor {
        get {
            return UIColor.adderInputColor()
        }
    }
    var outputColor: UIColor {
        get {
            return UIColor.adderOutputColor()
        }
    }
    
    let firstInput = InternalConnectorPort(isOutput: false)
    let secondInput = InternalConnectorPort(isOutput: false)
    let output = InternalConnectorPort(isOutput: true)
    
    override func connectorPorts() -> [ConnectorPort] {
        return [firstInput, secondInput, output]
    }
    
    func internalConnectorPorts() -> [InternalConnectorPort] {
        return [firstInput, secondInput, output]
    }
    func connectorPortIsMine(port: ConnectorPort) -> Bool {
        return port === firstInput || port === secondInput || port === output
    }
    
    func inputConnectorPorts() -> [ConnectorPort] {
        return [firstInput, secondInput]
    }
    func outputConnectorPorts() -> [ConnectorPort] {
        return [output]
    }
    
    override func connectorPortForDragAtLocation(location: CGPoint) -> ConnectorPort? {
        for internalPort in internalConnectorPorts() {
            if euclidianDistanceSquared(internalPort.layer.position, b: location) < 400 {
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
    let inputColoredLayer: CAShapeLayer = CAShapeLayer()
    let outputColoredLayer: CAShapeLayer = CAShapeLayer()
    init(constraint: MultiInputOutputConstraint) {
        self.innerConstraint = constraint
        super.init(frame: CGRectZero)
        
        self.firstInput.color = self.inputColor
        self.secondInput.color = self.inputColor
        self.output.color = self.outputColor
        
        self.layer.cornerRadius = 5
        addSentinelConnectorToPort(self.firstInput)
        addSentinelConnectorToPort(self.secondInput)
        addSentinelConnectorToPort(self.output)
        
        self.redLayer.backgroundColor = self.inputColor.CGColor
        self.blueLayer.backgroundColor = self.inputColor.CGColor
        self.purpleLayer.backgroundColor = self.outputColor.CGColor
        self.inputColoredLayer.fillColor = self.inputColor.CGColor
        self.outputColoredLayer.fillColor = self.outputColor.CGColor
        
        for layer in [self.redLayer, self.blueLayer, self.purpleLayer, self.firstInput.layer, self.secondInput.layer, self.output.layer, self.inputColoredLayer, self.outputColoredLayer] {
            self.layer.addSublayer(layer)
        }
    }
    
    override func idealAngleForNewConnectorLabel(connector: Connector, positions: [Connector: CGPoint]) -> CGFloat {
        // We want to maximize the distance from this angle to any other angle. First, we find all of the other
        // angles and put them in a sorted list.
        // We know the angle that is furthest from any of them will be a midpoint between two of them. So,
        // we go through each adjacent pair and find the midpoint, keeping the one that is furthest from its
        // neighbors
        var allAngles: [CGFloat] = []
        for connectorPort in self.connectorPorts() {
            if let connector = connectorPort.connector, let position = positions[connector] {
                let offset = position - self.center
                
                allAngles.append(atan2(offset.y, offset.x))
            }
        }
        allAngles.sortInPlace()
        
        var bestAngle: (angle: CGFloat, score: CGFloat) = (0, CGFloat.min)
        for index in 0..<allAngles.count {
            // We grab this angle and the next angle (looping around to the first angle, if necessary)
            let angle1 = allAngles[index]
            var angle2 = allAngles[(index + 1) % allAngles.count]
            if angle2 <= angle1 {
                // We are wrapping around, for example from the last positive angle to the first negative angle,
                // or if there is only one angle we might be wrapping around to itself
                angle2 += CGFloat(M_PI * 2)
            }
            let midAngle = (angle2 + angle1) / 2
            let score = angle2 - midAngle
            
            if score > bestAngle.score {
                bestAngle = (midAngle, score)
            }
        }
        
        return bestAngle.angle
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("Initializer not supported")
    }
}

class MultiplierView: MultiInputOutputConstraintView {
    let multiplier: Multiplier
    let label = UILabel()
    init(multiplier: Multiplier) {
        self.multiplier = multiplier
        super.init(constraint: multiplier)
        self.label.textColor = UIColor.textColor()
        self.label.text = "x"
        self.label.sizeToFit()
        self.addSubview(self.label)
    }
    
    override var inputColor: UIColor {
        get {
            return UIColor.multiplierInputColor()
        }
    }
    override var outputColor: UIColor {
        get {
            return UIColor.multiplierOutputColor()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let inputSize: CGFloat = 40.0
    let outputSize: CGFloat = 15.0
    let outputOverhang: CGFloat = 4.0
    override func layoutWithConnectorPositions(positions: [Connector: CGPoint]) {
        self.sizeToFit()
        
        self.inputColoredLayer.frame = CGRectMake(outputOverhang, outputOverhang, inputSize, inputSize)
        self.inputColoredLayer.path = CGPathCreateWithRect(CGRectMake(0, 0, inputSize, inputSize), nil)
        self.outputColoredLayer.frame = CGRectMake(0, 0, outputSize, outputSize)
        self.outputColoredLayer.path = CGPathCreateWithRect(CGRectMake(0, 0, outputSize, outputSize), nil)
        
        self.firstInput.layer.position = self.inputColoredLayer.frame.center()
        self.secondInput.layer.position = self.inputColoredLayer.frame.center()
        self.output.layer.position = self.outputColoredLayer.frame.center()

        var rotationAngle: CGFloat = 0
        if let connector = output.connector, let position = positions[connector] {
            let portAngle = (output.center - self.bounds.center()).angle
            let connectorAngle = (position - self.center).angle
            
            rotationAngle = connectorAngle - portAngle
        }
        
        self.transform = CGAffineTransformMakeRotation(rotationAngle)
        
        self.label.center = self.inputColoredLayer.frame.center()
        self.label.transform = CGAffineTransformMakeRotation(-rotationAngle)
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(inputSize + outputOverhang, inputSize + outputOverhang)
    }
}

class AdderView: MultiInputOutputConstraintView {
    let adder: Adder
    let label = UILabel()
    init(adder: Adder) {
        self.adder = adder
        super.init(constraint: adder)
        self.label.textColor = UIColor.textColor()
        self.label.text = "+"
        self.label.sizeToFit()
        self.addSubview(self.label)
    }
    
    override var inputColor: UIColor {
        get {
            return UIColor.adderInputColor()
        }
    }
    override var outputColor: UIColor {
        get {
            return UIColor.adderOutputColor()
        }
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let inputSize: CGFloat = 40.0
    let outputSize: CGFloat = 18.0
    let outputOverhang: CGFloat = 0.0
    override func layoutWithConnectorPositions(positions: [Connector: CGPoint]) {
        self.sizeToFit()
        
        self.inputColoredLayer.frame = CGRectMake(outputOverhang, outputOverhang, inputSize, inputSize)
        self.inputColoredLayer.path = CGPathCreateWithEllipseInRect(CGRectMake(0, 0, inputSize, inputSize), nil)
        self.outputColoredLayer.frame = CGRectMake(0, 0, outputSize, outputSize)
        self.outputColoredLayer.path = CGPathCreateWithEllipseInRect(CGRectMake(0, 0, outputSize, outputSize), nil)
        
        self.firstInput.layer.position = self.inputColoredLayer.frame.center()
        self.secondInput.layer.position = self.inputColoredLayer.frame.center()
        self.output.layer.position = self.outputColoredLayer.frame.center()
        
        var rotationAngle: CGFloat = 0
        if let connector = output.connector, let position = positions[connector] {
            let portAngle = (output.center - self.bounds.center()).angle
            let connectorAngle = (position - self.center).angle
            
            rotationAngle = connectorAngle - portAngle
        }
        
        self.transform = CGAffineTransformMakeRotation(rotationAngle)
        
        self.label.center = self.inputColoredLayer.frame.center()
        self.label.transform = CGAffineTransformMakeRotation(-rotationAngle)
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(inputSize + outputOverhang, inputSize + outputOverhang)
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
    
    let baseInput = InternalConnectorPort(isOutput: false)
    let exponentInput = InternalConnectorPort(isOutput: false)
    let resultOutput = InternalConnectorPort(isOutput: true)
    
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
            if euclidianDistanceSquared(internalPort.layer.position, b: location) < cutoffSquared {
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
    let label = UILabel()
    init(exponent: Exponent) {
        self.exponent = exponent
        super.init(frame: CGRectZero)
        addSentinelConnectorToPort(self.exponentInput)
        addSentinelConnectorToPort(self.baseInput)
        addSentinelConnectorToPort(self.resultOutput)
        self.baseInput.color = UIColor.exponentBaseColor()
        self.exponentInput.color = UIColor.exponentExponentColor()
        self.resultOutput.color = UIColor.exponentResultColor()
        
        self.resultLayer.strokeColor = UIColor.exponentResultColor().CGColor
        self.resultLayer.lineWidth = 4.0
        self.resultLayer.lineCap = kCALineCapRound
        self.resultLayer.fillColor = nil
        for layer in [self.resultLayer, self.exponentInput.layer, self.baseInput.layer, self.resultOutput.layer] {
            self.layer.addSublayer(layer)
        }
        
        self.label.textColor = UIColor.textColor()
        self.label.text = "^"
        self.label.sizeToFit()
        self.addSubview(self.label)
    }
    
    required init(coder aDecoder: NSCoder) {
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
        self.label.center = self.baseInput.center
    }
    
    override func idealAngleForNewConnectorLabel(connector: Connector, positions: [Connector: CGPoint]) -> CGFloat {
        var offset: CGPoint?
        var allCenters = CGPointZero
        
        // We find where this connector is in relation to the average center of all our ports. This way, if it
        // is visually in the top-right of the other connectors then the new connector will appear in the top-right
        for port in self.connectorPorts() {
            allCenters += port.center
            if port.connector == connector {
                offset = port.center
            }
        }
        allCenters /= CGFloat(self.connectorPorts().count)
        
        if let offset = offset {
            let averagedOffset = offset - allCenters
            return atan2(averagedOffset.y, averagedOffset.x)
        } else {
            print("Asked for an angle not corresponding to any connector port")
            return 0
        }
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(myWidth, myHeight)
    }
    
}
