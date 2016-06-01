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
    let nameAndValueView = UIView()
    var nameView: UIImageView?
    var scale: Int16 = -1
    let connector: Connector
    var isPercent: Bool = false
    var equationView: WKWebView?
    var equationViewSize: CGSize?
    var name: String?
    var nameImages: (image: UIImage, selectedImage: UIImage)? {
        didSet {
            updateNameView()
        }
    }

    init(connector: Connector) {
        self.connector = connector
        super.init(frame: CGRect.zero)
        connectorLabelInitialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.connector = Connector()
        super.init(coder: aDecoder)
        connectorLabelInitialize()
    }
    
    let borderWidth: CGFloat = 2
    private func connectorLabelInitialize() {
        self.addSubview(self.nameAndValueView)
        self.nameAndValueView.addSubview(self.valueLabel)
        self.valueLabel.font = UIFont.boldSystemFont(ofSize: 18)
        self.layer.borderWidth = borderWidth
        self.layer.cornerRadius = 12
        self.valueLabel.textAlignment = .center
        self.layer.masksToBounds = true
        self.hasError = false
        
        //self.displayEquation("<msup><mi>e</mi><mrow><mi>x</mi><mo>+</mo><mn>2</mn><mo>-</mo><mn>3</mn></mrow></msup>")
    }
    
    func displayEquation(mathML: String) {
        if self.equationView == nil {
            let userContentController = WKUserContentController()
            userContentController.add(self, name: "equationRendered")
            
            let source = "var rect = document.getElementById('math-element').getBoundingClientRect(); window.webkit.messageHandlers.equationRendered.postMessage([rect.right, rect.bottom]);"
            userContentController.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
            
            let configuration = WKWebViewConfiguration()
            configuration.userContentController = userContentController
            let equationView = WKWebView(frame: CGRect(x: 10, y:  20, width:  65, height: 25), configuration: configuration)
            
            self.addSubview(equationView)
            equationView.backgroundColor = UIColor.clear()
            equationView.isOpaque = false
            equationView.isUserInteractionEnabled = false
            self.equationView = equationView
        }
        
        if let equationView = self.equationView { // Should always succeed
            let htmlString = "<!DOCTYPE html><html lang='en'><head><meta name='viewport' content='initial-scale=1.0'/></head><body style='margin:0px'><math id='math-element'><mathstyle fontsize='10pt' mathcolor='rgb(43,66,81)'><mrow>\(mathML)</mrow></mathstyle></math></body></html>"
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
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let rectValues = message.body as? [CGFloat] {
            if rectValues.count == 2 {
                
                let widthDelta: CGFloat = 8.0
                let heightDelta: CGFloat = 3.0
                // Here we "smooth" out the equationViewSize. We choose a size delta points bigger, and we only change the size if it goes above that size or below size - delta
                let latestWidth = rectValues[0]
                let latestHeight = rectValues[1]
                
                let newSize = CGSize(width: latestWidth + widthDelta, height: latestHeight + heightDelta)
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
                    equationView.frame.size = CGSize(width: latestWidth, height: latestHeight)
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
            if oldValue != isSelected {
                updateNameView()
            }
        }
    }
    
    var hasError: Bool = false {
        didSet {
            if self.hasError {
                self.layer.borderColor = UIColor.red().cgColor
            } else {
                self.layer.borderColor = UIColor.textColor().cgColor
            }
        }
    }
    
    // Returns whether it changed size
    @discardableResult func displayValue(value: Double?) -> Bool {
        
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
    
    func updateNameView() {
        if self.nameView == nil && self.nameImages != nil {
            let imageView = UIImageView()
            self.nameView = imageView
            self.nameAndValueView.addSubview(imageView)
        }
        if let nameView = self.nameView where self.nameImages == nil {
            nameView.removeFromSuperview()
            self.nameView = nil
        }
        
        if let nameView = nameView, let (image, selectedImage) = self.nameImages {
            if self.isSelected {
                nameView.image = selectedImage
            } else {
                nameView.image = image
            }
        }
        resizeAndLayout()
    }
    
    @discardableResult func resizeAndLayout() -> Bool {
        let center = self.center
        let size = self.bounds.size
        sizeToFit()
        if !size.equalTo(self.bounds.size) {
            self.center = center
            return true
        }
        return false
    }
    
    override func sizeToFit() {
        self.valueLabel.sizeToFit()
        let nameAndValueSize: CGSize
        if let nameView = self.nameView {
            nameView.sizeToFit()
            
            let valueSize = self.valueLabel.frame.size
            let nameSize = nameView.frame.size
            nameAndValueSize = CGSize(width: valueSize.width + nameSize.width, height:
                max(valueSize.height, nameSize.height))
            
            // Lay out |[nameView][valueLabel]|
            self.nameAndValueView.frame.size = nameAndValueSize
            nameView.frame.origin = CGPoint.zero
            valueLabel.frame.origin = CGPoint(x: nameSize.width, y: 0)
        } else {
            nameAndValueSize = self.valueLabel.frame.size
            self.nameAndValueView.frame.size = nameAndValueSize
            self.valueLabel.frame.origin = CGPoint.zero
        }
        
        var newSize = nameAndValueSize
        
        let verticalMargin: CGFloat = 5.0 + borderWidth
        let horizontalMargin: CGFloat = 5.0 + borderWidth
        let equationSpace: CGFloat = 2.0
        
        if let equationSize = self.equationViewSize where equationView != nil {
            newSize.width = max(newSize.width, equationSize.width)
            newSize.height += equationSpace + equationSize.height
        }
        
        newSize.width += horizontalMargin * 2
        newSize.height += verticalMargin * 2
        
        self.nameAndValueView.center = CGPoint(x: newSize.width / 2, y: verticalMargin + nameAndValueSize.height / 2)
        if let equationView = self.equationView {
            equationView.center = CGPoint(x: newSize.width / 2, y:
                verticalMargin + nameAndValueSize.height + equationSpace + equationView.frame.size.height / 2)
        }
        
        self.frame.size = newSize
    }
}

protocol ConnectorPort: NSObjectProtocol {
    var color: UIColor {
        get
    }
    var connector: Connector {
        get
    }
    var center: CGPoint {
        get
    }
}

class InternalConnectorPort: NSObject, ConnectorPort {
    var color: UIColor = UIColor.white()
    var connector = Connector()
    let isOutput: Bool
    var center: CGPoint = CGPoint.zero
    init(isOutput: Bool) {
        self.isOutput = isOutput
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
    func connectorPortForDragAtLocation(location: CGPoint, connectorIsVisible: @noescape(Connector) -> Bool) -> ConnectorPort? {
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
        self.connectPort(port: connectorPort, connector: Connector())
    }
    
    func idealAngleForNewConnectorLabel(connector: Connector, positions: [Connector: CGPoint]) -> CGFloat {
        fatalError("This method must be overriden")
    }
    
    func setConnectorPort(port: ConnectorPort, isHighlighted: Bool) {
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
    
    var showInverseOperator: Bool = false
    
    var inputPorts = [InternalConnectorPort(isOutput: false), InternalConnectorPort(isOutput: false)]
    let outputPort = InternalConnectorPort(isOutput: true)
    
    override func connectorPorts() -> [ConnectorPort] {
        return inputConnectorPorts() + outputConnectorPorts()
    }
    
    func internalConnectorPorts() -> [InternalConnectorPort] {
        return inputPorts + [outputPort]
    }
    
    func inputConnectorPorts() -> [ConnectorPort] {
        return inputPorts.map {$0 as ConnectorPort}
    }
    func outputConnectorPorts() -> [ConnectorPort] {
        return [outputPort as ConnectorPort]
    }
    
    override func connectorPortForDragAtLocation(location: CGPoint, connectorIsVisible: @noescape(Connector) -> Bool) -> ConnectorPort? {
        if euclidianDistanceSquared(a: outputPort.center, b: location) < 18*18 {
            return outputPort
        } else if euclidianDistanceSquared(a: inputPorts[0].center, b: location) < 18*18 {
            // We should give back an input port. If we have less than two that are connected then we return
            // one of them. Otherwise, we make a new one
            for input in inputPorts {
                if !connectorIsVisible(input.connector) {
                    return input
                }
            }
            
            let newInput = InternalConnectorPort(isOutput: false)
            newInput.color = self.inputColor
            newInput.center = inputPorts[0].center
            
            return newInput
        }
        return nil
    }
    
    override func connectPort(port: ConnectorPort, connector: Connector) {
        guard let port = port as? InternalConnectorPort else {
            return
        }
        
        let oldConnector = port.connector
        if port.isOutput {
            innerConstraint.removeOutput(connector: oldConnector)
        } else {
            if inputPorts.index(of: port) != nil {
                innerConstraint.removeInput(connector: oldConnector)
            }
        }
        
        if port.isOutput {
            innerConstraint.addOutput(connector: connector)
        } else {
            innerConstraint.addInput(connector: connector)
            if inputPorts.index(of: port) == nil {
                inputPorts.append(port)
            }
        }
        port.connector = connector
    }
    
    override func removeConnectorAtPort(port: ConnectorPort) {
        guard let port = port as? InternalConnectorPort else {
            return
        }
        
        if !port.isOutput && inputPorts.count > 2 {
            // We kill this port forever
            guard let inputIndex = inputPorts.index(of: port) else {
                print("couldn't find a connectorPort. Maybe it was already removed?")
                return
            }
            inputPorts.remove(at: inputIndex)
            innerConstraint.removeInput(connector: port.connector)
        } else {
            addSentinelConnectorToPort(connectorPort: port) // This will remove the old connector
        }
        
        return
    }
    
    let inputColoredLayer: CAShapeLayer = CAShapeLayer()
    let outputColoredLayer: CAShapeLayer = CAShapeLayer()
    init(constraint: MultiInputOutputConstraint) {
        self.innerConstraint = constraint
        super.init(frame: CGRect.zero)
        
        for inputPort in self.inputPorts {
            inputPort.color = self.inputColor
            addSentinelConnectorToPort(connectorPort: inputPort)
        }
        self.outputPort.color = self.outputColor
        addSentinelConnectorToPort(connectorPort: self.outputPort)
        
        self.layer.cornerRadius = 5
        let borderWidth: CGFloat = 2.0
        self.inputColoredLayer.fillColor = self.inputColor.cgColor
        self.inputColoredLayer.strokeColor = self.inputColor.cgColor
        self.inputColoredLayer.lineWidth = borderWidth
        self.outputColoredLayer.fillColor = self.outputColor.cgColor
        self.outputColoredLayer.strokeColor = self.outputColor.cgColor
        self.outputColoredLayer.lineWidth = borderWidth
        
        for layer in [self.inputColoredLayer, self.outputColoredLayer] {
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
            if let position = positions[connectorPort.connector] {
                let offset = position - self.center
                
                allAngles.append(atan2(offset.y, offset.x))
            }
        }
        allAngles.sort()
        
        var bestAngle: (angle: CGFloat, score: CGFloat) = (0, CGFloat.leastNormalMagnitude)
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
    
    override func setConnectorPort(port: ConnectorPort, isHighlighted: Bool) {
        guard let port = port as? InternalConnectorPort else {
            return
        }
        let color: UIColor
        let layer: CAShapeLayer
        if port.isOutput {
            color = self.outputColor
            layer = self.outputColoredLayer
        } else {
            color = self.inputColor
            layer = self.inputColoredLayer
        }
        
        layer.fillColor = isHighlighted ? color.colorWithSaturationComponent(saturation: 0.25, brightness: 1.0).cgColor : color.cgColor
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
    
    override var showInverseOperator: Bool {
        didSet {
            let labelCenter = self.label.center
            if showInverseOperator {
                self.label.text = "÷"
            } else {
                self.label.text = "x"
            }
            self.label.sizeToFit()
            self.label.center = labelCenter
        }
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
    
    let inputSize: CGFloat = 32.0
    let outputSize: CGFloat = 16.0
    let outputOverhang: CGFloat = 7.0
    override func layoutWithConnectorPositions(positions: [Connector: CGPoint]) {
        self.sizeToFit()
        
        self.inputColoredLayer.frame = CGRect(x: outputOverhang, y:  outputOverhang, width:  inputSize, height: inputSize)
        self.inputColoredLayer.path = CGPath(rect: CGRect(x: 0, y:  0, width:  inputSize, height: inputSize), transform: nil)
        self.outputColoredLayer.frame = CGRect(x: 0, y:  0, width:  outputSize, height: outputSize)
        self.outputColoredLayer.path = CGPath(rect: CGRect(x: 0, y:  0, width:  outputSize, height: outputSize), transform: nil)
        
        for inputPort in self.inputPorts {
            inputPort.center = self.inputColoredLayer.frame.center()
        }
        self.outputPort.center = self.outputColoredLayer.frame.center()

        var rotationAngle: CGFloat = 0
        if let position = positions[outputPort.connector] {
            let portAngle = (outputPort.center - self.bounds.center()).angle
            let connectorAngle = (position - self.center).angle
            
            rotationAngle = connectorAngle - portAngle
        }
        
        self.transform = CGAffineTransform(rotationAngle: rotationAngle)
        
        self.label.center = self.inputColoredLayer.frame.center()
        self.label.transform = CGAffineTransform(rotationAngle: -rotationAngle)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: inputSize + outputOverhang, height: inputSize + outputOverhang)
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
    
    override var showInverseOperator: Bool {
        didSet {
            let labelCenter = self.label.center
            if showInverseOperator {
                self.label.text = "—"
            } else {
                self.label.text = "+"
            }
            self.label.sizeToFit()
            self.label.center = labelCenter
        }
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let inputSize: CGFloat = 35.0
    let outputSize: CGFloat = 18.0
    let outputOverhang: CGFloat = 3.0
    override func layoutWithConnectorPositions(positions: [Connector: CGPoint]) {
        self.sizeToFit()
        
        self.inputColoredLayer.frame = CGRect(x: outputOverhang, y:  outputOverhang, width:  inputSize, height: inputSize)
        self.inputColoredLayer.path = CGPath(ellipseIn: CGRect(x: 0, y:  0, width:  inputSize, height: inputSize), transform: nil)
        self.outputColoredLayer.frame = CGRect(x: 0, y:  0, width:  outputSize, height: outputSize)
        self.outputColoredLayer.path = CGPath(ellipseIn: CGRect(x: 0, y:  0, width:  outputSize, height: outputSize), transform: nil)
        
        for inputPort in self.inputPorts {
            inputPort.center = self.inputColoredLayer.frame.center()
        }
        self.outputPort.center = self.outputColoredLayer.frame.center()
        
        var rotationAngle: CGFloat = 0
        if let position = positions[outputPort.connector] {
            let portAngle = (outputPort.center - self.bounds.center()).angle
            let connectorAngle = (position - self.center).angle
            
            rotationAngle = connectorAngle - portAngle
        }
        
        self.transform = CGAffineTransform(rotationAngle: rotationAngle)
        
        self.label.center = self.inputColoredLayer.frame.center()
        self.label.transform = CGAffineTransform(rotationAngle: -rotationAngle)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: inputSize + outputOverhang, height: inputSize + outputOverhang)
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
    
    override func connectorPortForDragAtLocation(location: CGPoint, connectorIsVisible: @noescape(Connector) -> Bool) -> ConnectorPort? {
        for internalPort in internalConnectorPorts() {
            let cutoffSquared: CGFloat = (internalPort === basePort) ? 900 : 400
            if euclidianDistanceSquared(a: internalPort.center, b: location) < cutoffSquared {
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
                addSentinelConnectorToPort(connectorPort: internalPort) // This will remove the old connector
                return
            }
        }
    }
    
    let baseLayer = CALayer()
    let exponentLayer = CALayer()
    let resultLayer = CALayer()
    let label = UILabel()
    init(exponent: Exponent) {
        self.exponent = exponent
        super.init(frame: CGRect.zero)
        addSentinelConnectorToPort(connectorPort: self.exponentInput)
        addSentinelConnectorToPort(connectorPort: self.baseInput)
        addSentinelConnectorToPort(connectorPort: self.resultOutput)
        self.baseInput.color = UIColor.exponentBaseColor()
        self.exponentInput.color = UIColor.exponentExponentColor()
        self.resultOutput.color = UIColor.exponentResultColor()
        
        self.baseLayer.backgroundColor = self.baseInput.color.cgColor
        self.exponentLayer.backgroundColor = self.exponentInput.color.cgColor
        self.resultLayer.backgroundColor = self.resultOutput.color.cgColor
        
        let borderWidth: CGFloat = 2.0
        self.baseLayer.borderWidth = borderWidth
        self.baseLayer.borderColor = self.baseLayer.backgroundColor
        self.exponentLayer.borderWidth = borderWidth
        self.exponentLayer.borderColor = self.exponentLayer.backgroundColor
        self.resultLayer.borderWidth = borderWidth
        self.resultLayer.borderColor = self.resultLayer.backgroundColor
        
        for layer in [self.baseLayer, self.exponentLayer, self.resultLayer] {
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
    
    
    let spacing: CGFloat = 10.0
    let baseSize: CGFloat = 35
    let portSize: CGFloat = 18
    let portOverhang = CGPoint(x: 0, y: 0)
    override func layoutWithConnectorPositions(positions: [Connector: CGPoint]) {
        self.sizeToFit()
        
        self.baseLayer.frame = CGRect(x: 0, y:  0, width:  baseSize, height: baseSize)
        self.baseLayer.position = CGPoint(x: baseSize / 2, y: self.bounds.height / 2)
        self.baseLayer.cornerRadius = baseSize / 2
        self.baseInput.center = self.baseLayer.position
        
        self.exponentLayer.frame = CGRect(x: 0, y:  0, width:  portSize, height: portSize)
        self.exponentLayer.position = CGPoint(x: baseSize + portOverhang.x, y: self.baseLayer.frame.minY - portOverhang.y)
        self.exponentLayer.cornerRadius = portSize / 3
        self.exponentInput.center = self.exponentLayer.position
        
        self.resultLayer.frame = CGRect(x: 0, y:  0, width:  portSize, height: portSize)
        self.resultLayer.position = CGPoint(x: baseSize + portOverhang.x, y: self.baseLayer.frame.maxY + portOverhang.y)
        self.resultLayer.cornerRadius = portSize / 3
        self.resultOutput.center = self.resultLayer.position
        self.label.center = self.baseInput.center
    }
    
    override func idealAngleForNewConnectorLabel(connector: Connector, positions: [Connector: CGPoint]) -> CGFloat {
        var offset: CGPoint?
        var allCenters = CGPoint.zero
        
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
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: baseSize + portSize / 2 + portOverhang.x, height: baseSize + portSize / 2 + portOverhang.y)
    }
    
    override func setConnectorPort(port: ConnectorPort, isHighlighted: Bool) {
        let color: UIColor
        let layer: CALayer
        if port === baseInput {
            color = UIColor.exponentBaseColor()
            layer = self.baseLayer
        } else if port === exponentInput {
            color = UIColor.exponentExponentColor()
            layer = self.exponentLayer
        } else {
            color = UIColor.exponentResultColor()
            layer = self.resultLayer
        }
        
        layer.backgroundColor = isHighlighted ? color.colorWithSaturationComponent(saturation: 0.25, brightness: 1.0).cgColor : color.cgColor
    }
    
}
