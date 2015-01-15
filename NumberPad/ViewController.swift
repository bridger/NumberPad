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

class ViewController: UIViewController, UIGestureRecognizerDelegate, ConstraintViewDelegate {
    var scrollView: UIScrollView!
    
    var strokeRecognizer: StrokeGestureRecognizer!
    var currentStroke: Stroke?
    var unprocessedStrokes: [Stroke] = []
    var digitClassifier: DTWDigitClassifier
    
    var connectorLabels: [ConnectorLabel] = []
    var connectorToLabel: [Connector: ConnectorLabel] = [:]
    func addConnectorLabel(label: ConnectorLabel, topPriority: Bool) {
        if topPriority {
            connectorLabels.insert(label, atIndex: 0)
        } else {
            connectorLabels.append(label)
        }
        connectorToLabel[label.connector] = label
        self.scrollView.addSubview(label)
        updateScrollableSize()
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
    func removeConnectorLabel(label: ConnectorLabel) {
        if let index = find(connectorLabels, label) {
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
        } else {
            println("Cannot remove that label!")
        }
    }
    
    var constraintViews: [ConstraintView] = []
    func addConstraintView(constraintView: ConstraintView) {
        constraintViews.append(constraintView)
        constraintView.delegate = self
        self.scrollView.addSubview(constraintView)
        updateScrollableSize()
    }
    
    var connectionLayers: [CAShapeLayer] = []
    
    // For drawing connections
    enum DrawConnectionInfo {
        case FromConnector(ConnectorLabel)
        case FromConnectorPort(ConstraintView, ConnectorPort)
    }
    var currentDrawingConnection: DrawConnectionInfo?
    var makeConnectionDragStart: ConnectorLabel? // TODO: Get rid of this, replace with currentDrawingConnection
    var currentDrawConnectionLine: CAShapeLayer?
    
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
    }

    
    func handleMove(recognizer: UILongPressGestureRecognizer) {
        let point = recognizer.locationInView(self.scrollView)
        
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
                    pickedUpView.transform = CGAffineTransformMakeScale(1.3, 1.3)
                }
                self.rebuildAllConnectionLayers()
            }
            
        case .Changed:
            if let currentDrag = self.currentDrag {
                switch currentDrag {
                case let .Connector(connectorLabel, offset):
                    connectorLabel.center = point + offset
                case let .Constraint(constraintView, offset):
                    constraintView.center = point + offset
                }
                
                rebuildAllConnectionLayers()
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
                        pickedUpView.transform = CGAffineTransformIdentity
                    }
                }
                rebuildAllConnectionLayers()
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
        for connectorLabel in self.connectorLabels {
            if CGRectContainsPoint(connectorLabel.frame, point) {
                // Delete this connector!
                removeConnectorLabel(connectorLabel)
                deletedSomething = true
                break
            }
        }
//        if deletedSomething == false {
//            for constraintView in self.constraintViews {
//                if CGRectContainsPoint(constraintView.frame, point) {
//                    let offset = constraintView.center - point
//                    self.currentDrag = DragViewInfo.Constraint(constraintView, offset)
//                    deletedSomething = true
//                    break
//                }
//            }
//        }
//        
        if deletedSomething {
            runSolver([:])
            rebuildAllConnectionLayers()
        }
    }
    
    var processStrokesCounter: Int = 0
    func handleStroke(recognizer: StrokeGestureRecognizer) {
        let point = recognizer.locationInView(self.scrollView)
        
        switch recognizer.state {
        case .Began:
            for connectorLabel in self.connectorLabels {
                if CGRectContainsPoint(connectorLabel.frame, point) {
                    // We are dragging from a label
                    makeConnectionDragStart = connectorLabel
                    return
                }
            }
            
            self.processStrokesCounter += 1
            self.currentStroke = Stroke()
            self.scrollView.layer.addSublayer(self.currentStroke!.layer)
            self.currentStroke!.addPoint(point)
            
        case .Changed:
            if let currentStroke = self.currentStroke {
                // We are drawing
                currentStroke.addPoint(point)
                
            } else if let dragStart = makeConnectionDragStart {
                // We are dragging between connectors
                let targetConnector = connectorPortForDragAtLocation(point)?.ConnectorPort
                
                if let oldDragLine = currentDrawConnectionLine {
                    oldDragLine.removeFromSuperlayer()
                }
                let labelPoint = closestPointOnRectPerimeter(point, CGRectInset(dragStart.frame, 1, 1))
                let dragLine = createConnectionLayer(labelPoint, endPoint: point, color: targetConnector?.color)
                self.scrollView.layer.addSublayer(dragLine)
                self.currentDrawConnectionLine = dragLine
            }
            
        case .Ended, .Cancelled, .Failed:
            if let currentStroke = self.currentStroke {
                
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
                
            } else if let dragStart = makeConnectionDragStart {
                
                if let (constraintView, connectorPort) = connectorPortForDragAtLocation(point) {
                    let savedValue = dragStart.connector.value
                    dragStart.connector.forgetValue()
                    moveConnectorToTopPriority(dragStart) // Is this actually a good idea? When you drag a connector to a constraint, do you expect that connector to influence the constraint, or the other way around?
                    constraintView.connectPort(connectorPort, connector: dragStart.connector)
                    if let savedValue = savedValue {
                        runSolver([dragStart.connector : savedValue])
                    } else {
                        runSolver([:])
                    }
                }
                
                if let dragLine = currentDrawConnectionLine {
                    dragLine.removeFromSuperlayer()
                    self.currentDrawConnectionLine = nil
                }
                makeConnectionDragStart = nil
                
                rebuildAllConnectionLayers()
            }
            
        case .Possible:
            break
        }
    }
    
    @IBAction func clearStrokes(sender: AnyObject?) {
        for previousStroke in self.unprocessedStrokes {
            previousStroke.layer.removeFromSuperlayer()
        }
        self.unprocessedStrokes.removeAll(keepCapacity: false)
    }
    
    func connectorPortForDragAtLocation(location: CGPoint) -> (ConstraintView: ConstraintView, ConnectorPort: ConnectorPort)? {
        for constraintView in constraintViews {
            let point = constraintView.convertPoint(location, fromView: self.scrollView)
            if let port = constraintView.connectorPortForDragAtLocation(point) {
                return (constraintView, port)
            }
        }
        return nil
    }
    
    func processStrokes() {
        var allStrokes: DTWDigitClassifier.DigitStrokes = []
        for previousStroke in self.unprocessedStrokes {
            allStrokes.append(previousStroke.points)
        }
        
        if allStrokes.count > 0 {
            if let classifiedLabels = self.digitClassifier.classifyMultipleDigits(allStrokes) {
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
                var centerPoint = scrollView.convertPoint(self.view.center, fromView: self.view)
                if let topLeft = topLeft {
                    if let bottomRight = bottomRight {
                        centerPoint = CGPointMake((topLeft.x + bottomRight.x) / 2.0, (topLeft.y + bottomRight.y) / 2.0)
                    }
                }
                
                // TODO: Try to actually parse out an equation, instead of just one component
                let combinedLabels = classifiedLabels.reduce("", +)
                if let writtenNumber = combinedLabels.toInt() {
                    // We recognized a number!
                    let newConnector = Connector()
                    let newLabel = ConnectorLabel(connector: newConnector)
                    newLabel.sizeToFit()
                    newLabel.center = centerPoint
                    addConnectorLabel(newLabel, topPriority: true)
                    
                    runSolver([newConnector: Double(writtenNumber)])
                    
                } else if combinedLabels == "x" || combinedLabels == "/" {
                    // We recognized a multiply or divide!
                    let newMultiplier = Multiplier()
                    let newView = MultiplierView(multiplier: newMultiplier)
                    newView.layoutWithConnectorPositions([:])
                    newView.center = centerPoint
                    addConstraintView(newView)
                    
                } else if combinedLabels == "+" || combinedLabels == "-" || combinedLabels == "1-" { // The last is a hack for a common misclassification
                    // We recognized an add or subtract!
                    let newAdder = Adder()
                    let newView = AdderView(adder: newAdder)
                    newView.layoutWithConnectorPositions([:])
                    newView.center = centerPoint
                    addConstraintView(newView)
                    
                } else {
                    println("Unable to parse written text: \(combinedLabels)")
                }
            } else {
                println("Unable to recognize all \(allStrokes.count) strokes")
            }
        }
        
        self.clearStrokes(nil)
    }
    
    func constraintView(constraintView: ConstraintView, didResolveConnectorPort connectorPort: ConnectorPort) {
        // This is called when a constraint makes a connector on it's own. For example, if you set two inputs on a multiplier then it will resolve the output automatically. We need to add a view for it and display it
        // This is called during runSolver, so we need to be careful about what we mutate
        if let newConnector = connectorPort.connector {
            let newLabel = ConnectorLabel(connector: newConnector)
            newLabel.sizeToFit()
            
            let distance: CGFloat = 80 + max(constraintView.bounds.width, constraintView.bounds.height)
            // If the connectorPort is at the bottom-right, then we want to place it distance points off to the bottom-right
            let constraintMiddle = CGPointMake(CGRectGetMidX(constraintView.bounds), CGRectGetMidY(constraintView.bounds))
            let displacement = connectorPort.center - constraintMiddle
            let newDisplacement = displacement * (distance / displacement.length())
            
            let newPoint = self.scrollView.convertPoint(newDisplacement + constraintMiddle, fromView: constraintView)
            newLabel.center = newPoint
            addConnectorLabel(newLabel, topPriority: false)
        }
    }
    
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
                        let labelPoint = closestPointOnRectPerimeter(connectorPoint, CGRectInset(connectorLabel.frame, 1, 1))
                        
                        let connectionLayer = createConnectionLayer(labelPoint, endPoint: connectorPoint, color: connectorPort.color)
                        
                        self.connectionLayers.append(connectionLayer)
                        self.scrollView.layer.addSublayer(connectionLayer)
                    }
                }
            }
            
        }
    }
    
    func runSolver(values: [Connector: Double]) {
        // First we save all of the values for each connector. Then, we set them all again
        var savedValues = values
        
        for connectorLabel in self.connectorLabels {
            let connector = connectorLabel.connector
            if let value = connector.value {
                if savedValues[connector] == nil {
                    savedValues[connector] = value
                }
                connector.forgetValue()
            }
        }
        
        // We loop through connectorLabels like this, because it can mutate during the simulation, if a constraint "resolves a port"
        var index = 0
        while index < self.connectorLabels.count {
            let connector = self.connectorLabels[index].connector
            if connector.value == nil {
                if let value = savedValues[connector] {
                    connector.setValue(value, informant: nil)
                }
            }
            index += 1
        }
    }
    
    func createConnectionLayer(startPoint: CGPoint, endPoint: CGPoint, color: UIColor?) -> CAShapeLayer {
        let dragLine = CAShapeLayer()
        dragLine.lineWidth = 3
        dragLine.fillColor = nil
        dragLine.lineCap = kCALineCapRound
        dragLine.strokeColor = color?.CGColor ?? UIColor.blackColor().CGColor
        
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

