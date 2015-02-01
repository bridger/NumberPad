//
//  ViewController.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/13/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit
import DigitRecognizerSDK

class Stroke {
    var points: [CGPoint] = []
    var layer: CAShapeLayer
    
    init(){
        layer = CAShapeLayer()
        layer.strokeColor = UIColor.blackColor().CGColor
        layer.lineWidth = 2
        layer.fillColor = nil
    }
    
    func addPoint(point: CGPoint)
    {
        points.append(point)
        
        let path = CGPathCreateMutable()
        var x: CGFloat = 0
        for (index, point) in enumerate(points) {
            if index == 0 {
                CGPathMoveToPoint(path, nil, point.x, point.y)
            } else {
                CGPathAddLineToPoint(path, nil, point.x, point.y)
            }
        }
        layer.path = path;
    }
}

class ViewController: UIViewController, UIGestureRecognizerDelegate, NumberSlideViewDelegate {
    var scrollView: UIScrollView!
    var valuePicker: NumberSlideView!
    
    var strokeRecognizer: StrokeGestureRecognizer!
    var currentStroke: Stroke?
    var unprocessedStrokes: [Stroke] = []
    var digitClassifier: DTWDigitClassifier
    
    let connectorZPosition: CGFloat = -1
    let constraintZPosition: CGFloat = -2
    let connectionLayersZPosition: CGFloat = -3
    
    var connectorLabels: [ConnectorLabel] = []
    var connectorToLabel: [Connector: ConnectorLabel] = [:]
    func addConnectorLabel(label: ConnectorLabel, topPriority: Bool, automaticallyConnect: Bool = true) {
        if topPriority {
            connectorLabels.insert(label, atIndex: 0)
        } else {
            connectorLabels.append(label)
        }
        connectorToLabel[label.connector] = label
        label.isSelected = false
        self.scrollView.addSubview(label)
        label.layer.zPosition = connectorZPosition
        updateScrollableSize()
        
        if automaticallyConnect {
            self.lastDrawnConnector = label
            if let (lastConstraint, inputPort) = self.lastDrawnConstraint {
                if label.connector.constraints.count == 0 {
                    let connectorPortUsed = inputPort.connector != nil && connectorToLabel[inputPort.connector!] != nil
                    if !connectorPortUsed {
                        lastConstraint.connectPort(inputPort, connector: label.connector)
                        self.needsLayout = true
                        self.needsSolving = true
                    }
                }
                
                self.lastDrawnConstraint = nil
            }
        }
    }
    func moveConnectorToTopPriority(connectorLabel: ConnectorLabel) {
        if let index = find(connectorLabels, connectorLabel) {
            if index != 0 {
                connectorLabels.removeAtIndex(index)
                connectorLabels.insert(connectorLabel, atIndex: 0)
            }
        } else {
            println("Tried to move connector to top priority, but couldn't find it!")
        }
    }
    func moveConnectorToBottomPriority(connectorLabel: ConnectorLabel) {
        if let index = find(connectorLabels, connectorLabel) {
            if index != connectorLabels.count - 1 {
                connectorLabels.removeAtIndex(index)
                connectorLabels.append(connectorLabel)
            }
        } else {
            println("Tried to move connector to bottom priority, but couldn't find it!")
        }
    }
    func removeConnectorLabel(label: ConnectorLabel) {
        if let index = find(connectorLabels, label) {
            if label == selectedConnectorLabel {
                selectedConnectorLabel = nil
            }
            connectorLabels.removeAtIndex(index)
            label.removeFromSuperview()
            connectorToLabel[label.connector] = nil
            
            let deleteConnector = label.connector
            for constraintView in self.constraintViews {
                for port in constraintView.connectorPorts() {
                    if port.connector === deleteConnector {
                        constraintView.removeConnectorAtPort(port)
                    }
                }
            }
            if self.lastDrawnConnector == label {
                self.lastDrawnConnector = nil
            }
        } else {
            println("Cannot remove that label!")
        }
    }
    var selectedConnectorLabel: ConnectorLabel? {
        didSet {
            if let connectorLabel = selectedConnectorLabel {
                if let oldConnectorLabel = oldValue {
                    oldConnectorLabel.isSelected = false
                }
                connectorLabel.isSelected = true
                var value = self.lastValueForConnector(connectorLabel.connector) ?? 0.0
                if !isfinite(value) {
                    value = 0.0
                }
                var scale: Int16 = 0
                if abs(value) < 3 {
                    scale = -1
                } else if abs(value) >= 100 {
                    scale = 1
                }
                valuePicker.resetToValue( NSDecimalNumber(double: Double(value)) , scale: scale)
                
                updateDisplay(needsSolving: true)
                
                valuePicker.hidden = false
            } else {
                valuePicker.hidden = true
            }
        }
    }
    
    var constraintViews: [ConstraintView] = []
    func addConstraintView(constraintView: ConstraintView, firstInputPort: ConnectorPort?, secondInputPort: ConnectorPort?, outputPort: ConnectorPort?) {
        constraintViews.append(constraintView)
        self.scrollView.addSubview(constraintView)
        constraintView.layer.zPosition = constraintZPosition
        updateScrollableSize()
        
        if let outputPort = outputPort {
            if let (lastConstraint, inputPort) = self.lastDrawnConstraint {
                if connectorToLabel[inputPort.connector!] == nil {
                    self.connectConstraintViews(constraintView, firstConnectorPort: outputPort, secondConstraintView: lastConstraint, secondConnectorPort: inputPort)
                    
                    self.lastDrawnConnector = nil
                }
            }
        }
        
        if let secondInputPort = secondInputPort {
            self.lastDrawnConstraint = (constraintView, secondInputPort)
        } else {
            self.lastDrawnConstraint = nil
        }
        
        if let firstInputPort = firstInputPort {
            if let lastDrawnConnector = self.lastDrawnConnector {
                constraintView.connectPort(firstInputPort, connector: lastDrawnConnector.connector)
                self.needsLayout = true
                self.needsSolving = true
            }
        }
        self.lastDrawnConnector = nil
    }
    
    func removeConstraintView(constraintView: ConstraintView) {
        if let index = find(constraintViews, constraintView) {
            constraintViews.removeAtIndex(index)
            constraintView.removeFromSuperview()
            for port in constraintView.connectorPorts() {
                constraintView.removeConnectorAtPort(port)
            }
        } else {
            println("Cannot remove that constraint!")
        }
    }
    
    var connectionLayers: [CAShapeLayer] = []
    var lastSimulationContext: SimulationContext?
    func lastValueForConnector(connector: Connector) -> Double? {
        return self.lastSimulationContext?.connectorValues[connector]?.DoubleValue
    }
    func lastValueWasDependentForConnector(connector: Connector) -> Bool? {
        return self.lastSimulationContext?.connectorValues[connector]?.WasDependent
    }
    
    // For drawing connections
    enum DrawConnectionInfo {
        case FromConnector(ConnectorLabel)
        case FromConnectorPort(ConstraintView, ConnectorPort)
    }
    var currentDrawingConnection: DrawConnectionInfo?
    var currentDrawConnectionLine: CAShapeLayer?
    
    // For automatically hooking up drawn symbols
    var lastDrawnConnector: ConnectorLabel?
    var lastDrawnConstraint: (ConstraintView, ConnectorPort)?
    
    // For dragging views around
    enum DragViewInfo {
        case Connector(ConnectorLabel, CGPoint)
        case Constraint(ConstraintView, CGPoint)
    }
    var currentDrag: DragViewInfo?
    
    
    required init(coder aDecoder: NSCoder) {
        self.digitClassifier = DTWDigitClassifier()
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.scrollView = UIScrollView(frame: self.view.bounds)
        self.scrollView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        self.scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        self.view.insertSubview(self.scrollView, atIndex: 0)
        
        let strokeRecognizer = StrokeGestureRecognizer()
        self.scrollView.addGestureRecognizer(strokeRecognizer)
        strokeRecognizer.addTarget(self, action: "handleStroke:")
        self.strokeRecognizer = strokeRecognizer
        
        let moveRecognizer = UILongPressGestureRecognizer(target: self, action: "handleMove:")
        moveRecognizer.minimumPressDuration = 0.2
        self.scrollView.addGestureRecognizer(moveRecognizer)
        
        let deleteRecognizer = UITapGestureRecognizer(target: self, action: "handleDelete:")
        deleteRecognizer.numberOfTouchesRequired = 2
        self.scrollView.addGestureRecognizer(deleteRecognizer)
        
        let selectRecognizer = UITapGestureRecognizer(target: self, action: "handleSelect:")
        self.scrollView.addGestureRecognizer(selectRecognizer)
        
        let valuePickerHeight: CGFloat = 100.0
        valuePicker = NumberSlideView(frame: CGRectMake(0, self.view.bounds.size.height - valuePickerHeight, self.view.bounds.size.width, valuePickerHeight))
        valuePicker.delegate = self
        valuePicker.autoresizingMask = .FlexibleWidth | .FlexibleTopMargin
        self.view.addSubview(valuePicker)
        self.selectedConnectorLabel = nil
    }
    
    func handleMove(recognizer: UILongPressGestureRecognizer) {
        let point = recognizer.locationInView(self.scrollView)
        
        let pickedUpScale: CGFloat = 1.3
        switch recognizer.state {
        case .Began:
            var pickedUpView: UIView?
            for connectorLabel in self.connectorLabels {
                if CGRectContainsPoint(connectorLabel.frame, point) {
                    let offset = connectorLabel.center - point
                    self.currentDrag = DragViewInfo.Connector(connectorLabel, offset)
                    pickedUpView = connectorLabel
                    break
                }
            }
            if pickedUpView == nil {
                for constraintView in self.constraintViews {
                    if CGRectContainsPoint(constraintView.frame, point) {
                        let offset = constraintView.center - point
                        self.currentDrag = DragViewInfo.Constraint(constraintView, offset)
                        pickedUpView = constraintView
                        break
                    }
                }
            }
            if let pickedUpView = pickedUpView {
                // Cancel the stroke
                self.strokeRecognizer.enabled = false
                self.strokeRecognizer.enabled = true
                
                // Add some styles to make it look picked up
                UIView.animateWithDuration(0.2) {
                    pickedUpView.layer.shadowColor = UIColor.blackColor().CGColor
                    pickedUpView.layer.shadowOpacity = 0.4
                    pickedUpView.layer.shadowRadius = 10
                    pickedUpView.layer.shadowOffset = CGSizeMake(5, 5)
                }
                updateDisplay(needsLayout: true)
            }
            
        case .Changed:
            if let currentDrag = self.currentDrag {
                switch currentDrag {
                case let .Connector(connectorLabel, offset):
                    connectorLabel.center = point + offset
                case let .Constraint(constraintView, offset):
                    constraintView.center = point + offset
                }
                updateDisplay(needsLayout: true)
            }
            
        case .Ended, .Cancelled, .Failed:
            if let currentDrag = self.currentDrag {
                var pickedUpView: UIView?
                switch currentDrag {
                case let .Connector(connectorLabel, offset):
                    connectorLabel.center = point + offset
                    pickedUpView = connectorLabel
                case let .Constraint(constraintView, offset):
                    constraintView.center = point + offset
                    pickedUpView = constraintView
                }
                
                if let pickedUpView = pickedUpView {
                    UIView.animateWithDuration(0.2) {
                        pickedUpView.layer.shadowColor = nil
                        pickedUpView.layer.shadowOpacity = 0
                    }
                }
                updateDisplay(needsLayout: true)
                updateScrollableSize()
                self.currentDrag = nil
            }
        case .Possible:
            break
        }
    }
    
    func handleDelete(recognizer: UITapGestureRecognizer) {
        let point = recognizer.locationInView(self.scrollView)
        var deletedSomething = false
        if let connectorLabel = self.connectorLabelAtPoint(point) {
            // Delete this connector!
            removeConnectorLabel(connectorLabel)
            deletedSomething = true
        }
        if deletedSomething == false {
            if let constraintView = self.constraintViewAtPoint(point) {
                // Delete this constraint!
                removeConstraintView(constraintView)
                deletedSomething = true
            }
        }
        
        if deletedSomething {
            updateDisplay(needsSolving: true, needsLayout: true)
        }
    }
    
    func handleSelect(recognizer: UITapGestureRecognizer) {
        let point = recognizer.locationInView(self.scrollView)
        if let connectorLabel = self.connectorLabelAtPoint(point) {
            self.selectedConnectorLabel = connectorLabel
        } else if let (connectorLabel, constraintView, connectorPort) = self.connectionLineAtPoint(point) {
            let lastValue = self.lastValueForConnector(connectorLabel.connector)
            let lastValueWasDependent = self.lastValueWasDependentForConnector(connectorLabel.connector)
            
            if (lastValueWasDependent != nil && lastValueWasDependent!) {
                // Try to make this connector high priority, so it is constant instead of dependent
                moveConnectorToTopPriority(connectorLabel)
            } else {
                // Lower the priority of this connector, so it will be dependent
                moveConnectorToBottomPriority(connectorLabel)
            }
            updateDisplay(needsSolving: true)
            
            println("Tapped connectorLabel \(lastValue) \(lastValueWasDependent)")
        }
    }
    
    var processStrokesCounter: Int = 0
    func handleStroke(recognizer: StrokeGestureRecognizer) {
        let point = recognizer.locationInView(self.scrollView)
        
        switch recognizer.state {
        case .Began:
            if let connectorLabel  = connectorLabelAtPoint(point) {
                // We are dragging from a label
                currentDrawingConnection = DrawConnectionInfo.FromConnector(connectorLabel)
                return
            }
            if let (constraintView, connectorPort) = connectorPortAtLocation(point) {
                // We are dragging from a constraint view
                currentDrawingConnection = DrawConnectionInfo.FromConnectorPort(constraintView, connectorPort)
                return
            }
            
            self.processStrokesCounter += 1
            self.currentStroke = Stroke()
            self.scrollView.layer.addSublayer(self.currentStroke!.layer)
            self.currentStroke!.addPoint(point)
            
            var wasFarAway = false
            if let lastStroke = self.unprocessedStrokes.last {
                if let lastStrokeLastPoint = lastStroke.points.last {
                    let point = recognizer.locationInView(self.scrollView)
                    if euclidianDistance(lastStrokeLastPoint, point) > 150 {
                        wasFarAway = true
                    }
                }
            }
            if wasFarAway {
                processStrokes()
            }
            
        case .Changed:
            if let currentStroke = self.currentStroke {
                // We are drawing
                currentStroke.addPoint(point)
                
            } else if let drawConnectionInfo = currentDrawingConnection {
                // We are dragging between connectors
                
                if let oldDragLine = currentDrawConnectionLine {
                    oldDragLine.removeFromSuperlayer()
                }
                var dragLine: CAShapeLayer!
                switch drawConnectionInfo {
                case let .FromConnector(connectorLabel):
                    let targetPort = connectorPortAtLocation(point)?.ConnectorPort
                    let labelPoint = connectorLabel.center
                    var dependent = lastValueWasDependentForConnector(connectorLabel.connector) ?? false
                    dragLine = createConnectionLayer(labelPoint, endPoint: point, color: targetPort?.color, isDependent: dependent)
                case let .FromConnectorPort(constraintView, connectorPort):
                    let startPoint = self.scrollView.convertPoint(connectorPort.center, fromView: constraintView)
                    var endPoint = point
                    var dependent = false
                    if let targetConnector = connectorLabelAtPoint(point) {
                        endPoint = targetConnector.center
                        dependent = lastValueWasDependentForConnector(targetConnector.connector) ?? false
                    }
                    dragLine = createConnectionLayer(startPoint, endPoint: endPoint, color: connectorPort.color, isDependent: dependent)
                }
                
                dragLine.zPosition = connectionLayersZPosition
                self.scrollView.layer.addSublayer(dragLine)
                self.currentDrawConnectionLine = dragLine
            }
            
        case .Ended, .Cancelled, .Failed:
            if let currentStroke = self.currentStroke {
                
                let currentCounter = self.processStrokesCounter
                #if arch(i386) || arch(x86_64)
                    //simulator, give more time to draw stroke
                    let delayTime = 0.8
                    #else
                    //device
                    let delayTime = 0.4
                #endif
                delay(delayTime) { [weak self] in
                    if let strongself = self {
                        // If we haven't begun a new stroke in the intervening time, then process the old strokes
                        if strongself.processStrokesCounter == currentCounter {
                            strongself.processStrokes()
                        }
                    }
                }
                unprocessedStrokes.append(currentStroke)
                self.currentStroke = nil
                
            } else if let drawConnectionInfo = currentDrawingConnection {
                
                var connectionMade = false
                
                switch drawConnectionInfo {
                case let .FromConnector(connectorLabel):
                    if let (constraintView, connectorPort) = connectorPortAtLocation(point) {
                        self.connect(connectorLabel, constraintView: constraintView, connectorPort: connectorPort)
                        connectionMade = true
                    }
                case let .FromConnectorPort(constraintView, connectorPort):
                    if let connectorLabel = connectorLabelAtPoint(point) {
                        self.connect(connectorLabel, constraintView: constraintView, connectorPort: connectorPort)
                        connectionMade = true
                        
                    } else if let (secondConstraintView, secondConnectorPort) = connectorPortAtLocation(point) {
                        self.connectConstraintViews(constraintView, firstConnectorPort: connectorPort, secondConstraintView: secondConstraintView, secondConnectorPort: secondConnectorPort)
                        
                        connectionMade = true
                    }
                }
                
                if connectionMade {
                    // Clear any information about the last drawn constraint or connector
                    self.lastDrawnConstraint = nil
                    self.lastDrawnConnector = nil
                    
                    self.updateDisplay()
                }
                
                if let dragLine = currentDrawConnectionLine {
                    dragLine.removeFromSuperlayer()
                    self.currentDrawConnectionLine = nil
                }
                currentDrawingConnection = nil
            }
            
        case .Possible:
            break
        }
    }
    
    func connect(connectorLabel: ConnectorLabel, constraintView: ConstraintView, connectorPort: ConnectorPort) {
        for connectorPort in constraintView.connectorPorts() {
            if connectorPort.connector === connectorLabel.connector {
                // This connector is already hooked up to this constraintView. The user is probably trying to change the connection, so we remove the old one
                constraintView.removeConnectorAtPort(connectorPort)
            }
        }
        
        constraintView.connectPort(connectorPort, connector: connectorLabel.connector)
        self.needsSolving = true
        self.needsLayout = true
    }
    
    func connectConstraintViews(firstConstraintView: ConstraintView, firstConnectorPort: ConnectorPort, secondConstraintView: ConstraintView, secondConnectorPort: ConnectorPort) -> ConnectorLabel {
        // We are dragging from one constraint directly to another constraint. To accomodate, we create a connector in-between and make two connections
        let midPoint = (firstConstraintView.center + secondConstraintView.center) / 2.0
        
        let newConnector = Connector()
        let newLabel = ConnectorLabel(connector: newConnector)
        newLabel.sizeToFit()
        newLabel.center = midPoint
        self.addConnectorLabel(newLabel, topPriority: false, automaticallyConnect: false)
        
        firstConstraintView.connectPort(firstConnectorPort, connector: newConnector)
        secondConstraintView.connectPort(secondConnectorPort, connector: newConnector)
        self.needsSolving = true
        self.needsLayout = true
        
        return newLabel
    }
    
    func connectorLabelAtPoint(point: CGPoint) -> ConnectorLabel? {
        for label in connectorLabels {
            if CGRectContainsPoint(label.frame, point) {
                return label
            }
        }
        return nil
    }
    
    func constraintViewAtPoint(point: CGPoint) -> ConstraintView? {
        for view in constraintViews {
            if CGRectContainsPoint(view.frame, point) {
                return view
            }
        }
        return nil
    }
    
    func connectorPortAtLocation(location: CGPoint) -> (ConstraintView: ConstraintView, ConnectorPort: ConnectorPort)? {
        for constraintView in constraintViews {
            let point = constraintView.convertPoint(location, fromView: self.scrollView)
            if let port = constraintView.connectorPortForDragAtLocation(point) {
                return (constraintView, port)
            }
        }
        return nil
    }
    
    func connectionLineAtPoint(point: CGPoint) -> (ConnectorLabel: ConnectorLabel, ConstraintView: ConstraintView, ConnectorPort: ConnectorPort)? {
        // This is a hit-test to see if the user has tapped on a line between a connector and a connectorPort.
        let distanceCutoff: CGFloat = 10
        let squaredDistanceCutoff = distanceCutoff * distanceCutoff
        
        var minSquaredDistance: CGFloat?
        var minMatch: (ConnectorLabel, ConstraintView, ConnectorPort)?
        for constraintView in constraintViews {
            for connectorPort in constraintView.connectorPorts() {
                if let connector = connectorPort.connector {
                    if let connectorLabel = connectorToLabel[connector] {
                        let connectorPoint = self.scrollView.convertPoint(connectorPort.center, fromView: constraintView)
                        let labelPoint = connectorLabel.center
                        
                        let squaredDistance = shortestDistanceSquaredToLineSegmentFromPoint(connectorPoint, labelPoint, point)
                        if squaredDistance < squaredDistanceCutoff {
                            if minSquaredDistance == nil || squaredDistance < minSquaredDistance! {
                                println("Found elligible distance of \(sqrt(squaredDistance))")
                                minMatch = (connectorLabel, constraintView, connectorPort)
                                minSquaredDistance = squaredDistance
                            }
                        }
                    }
                }
            }
        }
        
        return minMatch
    }
    
    func processStrokes() {
        let unprocessedStrokesCopy = self.unprocessedStrokes
        self.unprocessedStrokes.removeAll(keepCapacity: false)
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            var allStrokes: DTWDigitClassifier.DigitStrokes = []
            for previousStroke in unprocessedStrokesCopy {
                allStrokes.append(previousStroke.points)
            }
            let classifiedLabels = self.digitClassifier.classifyMultipleDigits(allStrokes)
            
            dispatch_async(dispatch_get_main_queue()) {
                if let classifiedLabels = classifiedLabels {
                    // Find the bounding rect of all of the strokes
                    var topLeft: CGPoint?
                    var bottomRight: CGPoint?
                    for stroke in allStrokes {
                        for point in stroke {
                            if let capturedTopLeft = topLeft {
                                topLeft = CGPointMake(min(capturedTopLeft.x, point.x), min(capturedTopLeft.y, point.y));
                            } else {
                                topLeft = point
                            }
                            if let capturedBottomRight = bottomRight {
                                bottomRight = CGPointMake(max(capturedBottomRight.x, point.x), max(capturedBottomRight.y, point.y));
                            } else {
                                bottomRight = point
                            }
                        }
                    }
                    // Figure out where to put the new component
                    var centerPoint = self.scrollView.convertPoint(self.view.center, fromView: self.view)
                    if let topLeft = topLeft {
                        if let bottomRight = bottomRight {
                            centerPoint = CGPointMake((topLeft.x + bottomRight.x) / 2.0, (topLeft.y + bottomRight.y) / 2.0)
                        }
                    }
                    
                    // TODO: Try to actually parse out an equation, instead of just one component
                    let combinedLabels = classifiedLabels.reduce("", +)
                    var recognized = false
                    var writtenValue: Double?
                    if let writtenNumber = combinedLabels.toInt() {
                        writtenValue = Double(writtenNumber)
                    } else if combinedLabels == "e" {
                        writtenValue = Double(M_E)
                    }
                    
                    if let writtenValue = writtenValue {
                        // We recognized a number!
                        let newConnector = Connector()
                        let newLabel = ConnectorLabel(connector: newConnector)
                        newLabel.sizeToFit()
                        newLabel.center = centerPoint
                        self.addConnectorLabel(newLabel, topPriority: true)
                        
                        recognized = true
                        self.updateDisplay(values: [newConnector: Double(writtenValue)], needsSolving: true)
                        
                    } else if combinedLabels == "x" || combinedLabels == "/" {
                        // We recognized a multiply or divide!
                        let newMultiplier = Multiplier()
                        let newView = MultiplierView(multiplier: newMultiplier)
                        newView.layoutWithConnectorPositions([:])
                        newView.center = centerPoint
                        let inputs = newView.inputConnectorPorts()
                        let outputs = newView.outputConnectorPorts()
                        if combinedLabels == "x" {
                            self.addConstraintView(newView, firstInputPort: inputs[0], secondInputPort: inputs[1], outputPort: outputs[0])
                        } else if combinedLabels == "/" {
                            self.addConstraintView(newView, firstInputPort: outputs[0], secondInputPort: inputs[0], outputPort: inputs[1])
                        } else {
                            self.addConstraintView(newView, firstInputPort: nil, secondInputPort: nil, outputPort: nil)
                        }
                        recognized = true
                        
                    } else if combinedLabels == "+" || combinedLabels == "-" || combinedLabels == "1-" { // The last is a hack for a common misclassification
                        // We recognized an add or subtract!
                        let newAdder = Adder()
                        let newView = AdderView(adder: newAdder)
                        newView.layoutWithConnectorPositions([:])
                        newView.center = centerPoint
                        let inputs = newView.inputConnectorPorts()
                        let outputs = newView.outputConnectorPorts()
                        if combinedLabels == "+" || combinedLabels == "1-" {
                            let inputs = newView.inputConnectorPorts()
                            self.addConstraintView(newView, firstInputPort: inputs[0], secondInputPort: inputs[1], outputPort: outputs[0])
                        } else if combinedLabels == "-" {
                            self.addConstraintView(newView, firstInputPort: outputs[0], secondInputPort: inputs[0], outputPort: inputs[1])
                        } else {
                            self.addConstraintView(newView, firstInputPort: nil, secondInputPort: nil, outputPort: nil)
                        }
                        recognized = true
                        
                    } else if combinedLabels == "^" {
                        let newExponent = Exponent()
                        let newView = ExponentView(exponent: newExponent)
                        newView.layoutWithConnectorPositions([:])
                        newView.center = centerPoint
                        
                        self.addConstraintView(newView, firstInputPort: newView.basePort, secondInputPort: newView.exponentPort, outputPort: newView.resultPort)
                        recognized = true
                        
                    } else {
                        println("Unable to parse written text: \(combinedLabels)")
                    }
                    self.updateDisplay();
                } else {
                    println("Unable to recognize all \(allStrokes.count) strokes")
                }
                
                for stroke in unprocessedStrokesCopy {
                    stroke.layer.removeFromSuperlayer()
                }
            }
        }
    }
    
    func numberSlideView(NumberSlideView, didSelectNewValue newValue: NSDecimalNumber) {
        if let selectedConnectorLabel = self.selectedConnectorLabel {
            self.updateDisplay(values: [selectedConnectorLabel.connector : newValue.doubleValue], needsSolving: true)
        }
    }
    
    var needsLayout = false
    var needsRebuildConnectionLayers = false
    var needsSolving = false
    
    func updateDisplay(values: [Connector: Double] = [:], needsSolving: Bool = false, needsLayout: Bool = false)
    {
        // See how these variables are used at the end of this function, after the internal definitions
        self.needsLayout |= needsLayout
        self.needsSolving |= needsSolving || values.count > 0
        
        func rebuildAllConnectionLayers() {
            for oldLayer in self.connectionLayers {
                oldLayer.removeFromSuperlayer()
            }
            self.connectionLayers.removeAll(keepCapacity: true)
            
            for constraintView in constraintViews {
                for connectorPort in constraintView.connectorPorts() {
                    if let connector = connectorPort.connector {
                        if let connectorLabel = connectorToLabel[connector] {
                            let connectorPoint = self.scrollView.convertPoint(connectorPort.center, fromView: constraintView)
                            let labelPoint = connectorLabel.center
                            
                            let dependent = lastValueWasDependentForConnector(connectorLabel.connector) ?? false
                            let connectionLayer = createConnectionLayer(labelPoint, endPoint: connectorPoint, color: connectorPort.color, isDependent: dependent)
                            
                            self.connectionLayers.append(connectionLayer)
                            connectionLayer.zPosition = connectionLayersZPosition
                            self.scrollView.layer.addSublayer(connectionLayer)
                        }
                    }
                }
            }
            self.needsRebuildConnectionLayers = false
        }
        
        func layoutConstraintViews() {
            var connectorPositions: [Connector: CGPoint] = [:]
            for connectorLabel in connectorLabels {
                connectorPositions[connectorLabel.connector] = connectorLabel.center
            }
            for constraintView in constraintViews {
                constraintView.layoutWithConnectorPositions(connectorPositions)
            }
            self.needsLayout = false
            self.needsRebuildConnectionLayers = true
        }
        
        func runSolver(values: [Connector: Double]) {
            let lastSimulationContext = self.lastSimulationContext
            
            let simulationContext = SimulationContext(connectorResolvedCallback: { (connector, resolvedValue, informant) -> Void in
                if self.connectorToLabel[connector] == nil {
                    if let constraint = informant {
                        // This happens when a constraint makes a connector on it's own. For example, if you set two inputs on a multiplier then it will resolve the output automatically. We need to add a view for it and display it
                        
                        // We need to find the constraintView and the connectorPort this belongs to
                        var connectTo: (constraintView: ConstraintView, connectorPort: ConnectorPort)!
                        for possibleView in self.constraintViews {
                            if possibleView.constraint == constraint {
                                for possiblePort in possibleView.connectorPorts() {
                                    if possiblePort.connector == connector {
                                        connectTo = (possibleView, possiblePort)
                                        break
                                    }
                                }
                                break
                            }
                        }
                        if connectTo == nil {
                            println("Unable to find constraint view for newly resolved connector! \(connector), \(resolvedValue), \(constraint)")
                            return
                        }
                        
                        let newLabel = ConnectorLabel(connector: connector)
                        newLabel.sizeToFit()
                        
                        let distance: CGFloat = 80 + max(connectTo.constraintView.bounds.width, connectTo.constraintView.bounds.height)
                        // If the connectorPort is at the bottom-right, then we want to place it distance points off to the bottom-right
                        let constraintMiddle = connectTo.constraintView.bounds.center()
                        let displacement = connectTo.connectorPort.center - connectTo.constraintView.bounds.center()
                        let newDisplacement = displacement * (distance / displacement.length())
                        
                        let newPoint = self.scrollView.convertPoint(newDisplacement + constraintMiddle, fromView: connectTo.constraintView)
                        newLabel.center = newPoint
                        self.addConnectorLabel(newLabel, topPriority: false)
                        self.needsLayout = true
                    }
                }
                
                if let label = self.connectorToLabel[connector] {
                    label.displayValue(resolvedValue.DoubleValue)
                    if label.isDependent != resolvedValue.WasDependent {
                        self.needsRebuildConnectionLayers = true
                        label.isDependent = resolvedValue.WasDependent
                    }
                }
                }, connectorConflictCallback: { (connector, resolvedValue, informant) -> Void in
                    if let label = self.connectorToLabel[connector] {
                        label.layer.borderColor = UIColor.redColor().CGColor
                    }
            })
            
            // First, the selected connector
            if let selectedConnector = selectedConnectorLabel?.connector {
                if let value = (values[selectedConnector] ?? lastSimulationContext?.connectorValues[selectedConnector]?.DoubleValue) {
                    simulationContext.setConnectorValue(selectedConnector, value: (DoubleValue: value, WasDependent: true), informant: nil)
                }
            }
            
            // These are the first priority
            for (connector, value) in values {
                simulationContext.setConnectorValue(connector, value: (DoubleValue: value, WasDependent: false), informant: nil)
            }
            
            // We loop through connectorLabels like this, because it can mutate during the simulation, if a constraint "resolves a port"
            var index = 0
            while index < self.connectorLabels.count {
                let connector = self.connectorLabels[index].connector
                
                // If we haven't already resolved this connector, then set it as a non-dependent variable to the value from the last simulation
                if simulationContext.connectorValues[connector] == nil {
                    if let lastValue = lastSimulationContext?.connectorValues[connector]?.DoubleValue {
                        simulationContext.setConnectorValue(connector, value: (DoubleValue: lastValue, WasDependent: false), informant: nil)
                    }
                }
                index += 1
            }
            
            // Update the labels that still don't have a value
            for label in self.connectorLabels {
                if simulationContext.connectorValues[label.connector] == nil {
                    label.displayValue(nil)
                    label.layer.backgroundColor = UIColor.blackColor().CGColor
                }
            }
            
            self.lastSimulationContext = simulationContext
            self.needsSolving = false
        }
        
        
        while (self.needsLayout || self.needsSolving) {
            // First, we layout. This way, if solving generates a new connector then it will be pointed in a sane direction
            // But, solving means we might need to layout, and so on...
            if (self.needsLayout) {
                layoutConstraintViews()
            }
            if (self.needsSolving) {
                runSolver(values)
            }
        }
        
        if (self.needsRebuildConnectionLayers) {
            rebuildAllConnectionLayers()
        }
    }
    
    func createConnectionLayer(startPoint: CGPoint, endPoint: CGPoint, color: UIColor?, isDependent: Bool) -> CAShapeLayer {
        let dragLine = CAShapeLayer()
        dragLine.lineWidth = 3
        dragLine.fillColor = nil
        dragLine.lineCap = kCALineCapRound
        dragLine.strokeColor = color?.CGColor ?? UIColor.blackColor().CGColor
        if isDependent {
            dragLine.lineDashPattern = [4, 6]
        }
        
        let path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, startPoint.x, startPoint.y)
        CGPathAddLineToPoint(path, nil, endPoint.x, endPoint.y)
        dragLine.path = path
        return dragLine
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        coordinator.animateAlongsideTransition(nil, completion: { context in
            self.updateScrollableSize()
        })
    }
    
    func updateScrollableSize() {
        var maxY: CGFloat = 0
        var maxX: CGFloat = self.view.bounds.width
        for view in connectorLabels {
            maxY = max(maxY, CGRectGetMaxY(view.frame))
            maxX = max(maxX, CGRectGetMaxX(view.frame))
        }
        for view in constraintViews {
            maxY = max(maxY, CGRectGetMaxY(view.frame))
            maxX = max(maxX, CGRectGetMaxX(view.frame))
        }
        
        self.scrollView.contentSize = CGSizeMake(maxX, maxY + self.view.bounds.height)
    }
}

