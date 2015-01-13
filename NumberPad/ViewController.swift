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
    
    var currentStroke: Stroke?
    var unprocessedStrokes: [Stroke] = []
    var digitClassifier: DTWDigitClassifier
    
    var connectorLabels: [ConnectorLabel] = []
    var connectorToLabel: [Connector: ConnectorLabel] = [:]
    func addConnectorLabel(label: ConnectorLabel) {
        connectorLabels.append(label)
        connectorToLabel[label.connector] = label
        self.scrollView.addSubview(label)
    }
    
    var constraintViews: [ConstraintView] = []
    func addConstraintView(constraintView: ConstraintView) {
        constraintViews.append(constraintView)
        constraintView.delegate = self
        self.scrollView.addSubview(constraintView)
    }
    
    var makeConnectionDragStart: ConnectorLabel?
    var currentDragLine: CAShapeLayer?
    var connectionLayers: [CAShapeLayer] = []
    
    required init(coder aDecoder: NSCoder) {
        self.digitClassifier = DTWDigitClassifier()
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.scrollView = UIScrollView(frame: self.view.bounds)
        self.scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        self.view.insertSubview(self.scrollView, atIndex: 0)
        
        let strokeRecognizer = StrokeGestureRecognizer()
        self.scrollView.addGestureRecognizer(strokeRecognizer)
        strokeRecognizer.addTarget(self, action: "handleStroke:")
        //self.scrollView.layer.delegate = self
    }

    var processStrokesCounter: Int = 0
    func handleStroke(recognizer: StrokeGestureRecognizer) {
        let point = recognizer.locationInView(self.scrollView)

        if recognizer.state == UIGestureRecognizerState.Began {
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
            
        } else if recognizer.state == UIGestureRecognizerState.Changed {
            if let currentStroke = self.currentStroke {
                // We are drawing
                currentStroke.addPoint(point)
                
            } else if let dragStart = makeConnectionDragStart {
                // We are dragging between connectors
                let targetConnector = connectorPortForDragAtLocation(point)?.ConnectorPort
                
                if let oldDragLine = currentDragLine {
                    oldDragLine.removeFromSuperlayer()
                }
                let labelPoint = closestPointOnRectPerimeter(point, CGRectInset(dragStart.frame, 1, 1))
                let dragLine = createConnectionLayer(labelPoint, endPoint: point, color: targetConnector?.color)
                self.scrollView.layer.addSublayer(dragLine)
                self.currentDragLine = dragLine
            }
        } else if recognizer.state == UIGestureRecognizerState.Ended {
            if let currentStroke = self.currentStroke {
                let currentCounter = self.processStrokesCounter
                delay(0.8) { [weak self] in
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
                    constraintView.connectPort(connectorPort, connector: dragStart.connector)
                }
                
                if let dragLine = currentDragLine {
                    dragLine.removeFromSuperlayer()
                    self.currentDragLine = nil
                }
                makeConnectionDragStart = nil
                
                rebuildAllConnectionLayers()
            }
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
                    newConnector.setValue(Double(writtenNumber), informant: globalInformant)
                    let newLabel = ConnectorLabel(connector: newConnector)
                    newLabel.sizeToFit()
                    newLabel.center = centerPoint
                    addConnectorLabel(newLabel)
                    
                } else if combinedLabels == "x" || combinedLabels == "/" {
                    // We recognized a multiply or divide!
                    let newMultiplier = Multiplier()
                    let newView = MultiplierView(multiplier: newMultiplier)
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
            addConnectorLabel(newLabel)
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
    
    

}

