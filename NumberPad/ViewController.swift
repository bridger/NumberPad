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
    
    var layerNeedsUpdate = false
    func addPoint(point: CGPoint)
    {
        points.append(point)
        layerNeedsUpdate = true
    }
    
    func updateLayer() {
        if layerNeedsUpdate {
            let path = CGPathCreateMutable()
            for (index, point) in points.enumerate() {
                if index == 0 {
                    CGPathMoveToPoint(path, nil, point.x, point.y)
                } else {
                    CGPathAddLineToPoint(path, nil, point.x, point.y)
                }
            }
            layer.path = path;
            
            layerNeedsUpdate = false
        }
    }
    
}

class ViewController: UIViewController, UIGestureRecognizerDelegate, NumberSlideViewDelegate, FTPenManagerDelegate, FTTouchClassificationsChangedDelegate {
    
    required init(coder aDecoder: NSCoder) {
        self.digitClassifier = DTWDigitClassifier()
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.multipleTouchEnabled = true
        self.view.userInteractionEnabled = true
        self.view.exclusiveTouch = true
        
        let pairingView = FTPenManager.sharedInstance().pairingButtonWithStyle(.Debug);
        self.view.addSubview(pairingView)
        FTPenManager.sharedInstance().delegate = self;
        FTPenManager.sharedInstance().classifier.delegate = self;
        
        self.scrollView = UIScrollView(frame: self.view.bounds)
        self.scrollView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.scrollView.userInteractionEnabled = false
        self.scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        self.view.addGestureRecognizer(self.scrollView.panGestureRecognizer)
        self.view.insertSubview(self.scrollView, atIndex: 0)
        
        let valuePickerHeight: CGFloat = 100.0
        valuePicker = NumberSlideView(frame: CGRectMake(0, self.view.bounds.size.height - valuePickerHeight, self.view.bounds.size.width, valuePickerHeight))
        valuePicker.delegate = self
        valuePicker.autoresizingMask = [.FlexibleWidth, .FlexibleTopMargin]
        self.view.addSubview(valuePicker)
        self.selectedConnectorLabel = nil
    }
    
    var scrollView: UIScrollView!
    var valuePicker: NumberSlideView!
    
    var strokeRecognizer: StrokeGestureRecognizer!
    var unprocessedStrokes: [Stroke] = []
    var digitClassifier: DTWDigitClassifier
    
    let connectorZPosition: CGFloat = -1
    let constraintZPosition: CGFloat = -2
    let connectionLayersZPosition: CGFloat = -3
    
    // MARK: Managing connectors and constraints
    
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
            if let (lastConstraint, inputPort) = self.selectedConnectorPort {
                if label.connector.constraints.count == 0 {
                    lastConstraint.connectPort(inputPort, connector: label.connector)
                    self.needsLayout = true
                    self.needsSolving = true
                }
                
                self.selectedConnectorPort = nil
            }
        }
    }
    func moveConnectorToTopPriority(connectorLabel: ConnectorLabel) {
        if let index = connectorLabels.indexOf(connectorLabel) {
            if index != 0 {
                connectorLabels.removeAtIndex(index)
                connectorLabels.insert(connectorLabel, atIndex: 0)
            }
        } else {
            print("Tried to move connector to top priority, but couldn't find it!")
        }
    }
    func moveConnectorToBottomPriority(connectorLabel: ConnectorLabel) {
        if let index = connectorLabels.indexOf(connectorLabel) {
            if index != connectorLabels.count - 1 {
                connectorLabels.removeAtIndex(index)
                connectorLabels.append(connectorLabel)
            }
        } else {
            print("Tried to move connector to bottom priority, but couldn't find it!")
        }
    }
    func removeConnectorLabel(label: ConnectorLabel) {
        if let index = connectorLabels.indexOf(label) {
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
            self.needsLayout = true
            self.needsSolving = true
        } else {
            print("Cannot remove that label!")
        }
    }
    
    var selectedConnectorLabelValueOverride: Double?
    func selectConnectorLabelAndSetToValue(connectorLabel: ConnectorLabel?, value: Double)
    {
        selectedConnectorLabelValueOverride = value
        self.selectedConnectorLabel = connectorLabel
        selectedConnectorLabelValueOverride = nil
    }
    var selectedConnectorLabel: ConnectorLabel? {
        didSet {
            if let oldConnectorLabel = oldValue {
                oldConnectorLabel.isSelected = false
            }
            
            if let connectorLabel = selectedConnectorLabel {
                connectorLabel.isSelected = true
                if self.selectedConnectorPort != nil {
                    self.selectedConnectorPort = nil
                }
                
                // Here we are careful that if there isn't a value already selected (it was a ?), we don't assign a value. We just put 0 in the picker
                var selectedValue = selectedConnectorLabelValueOverride ?? self.lastValueForConnector(connectorLabel.connector)
                var valueToDisplay = selectedValue ?? 0.0
                selectedConnectorLabelValueOverride = nil
                if !isfinite(valueToDisplay) {
                    valueToDisplay = 0.0
                }
                valuePicker.resetToValue( NSDecimalNumber(double: Double(valueToDisplay)), scale: connectorLabel.scale)
                
                if let selectedValue = selectedValue {
                    updateDisplay([connectorLabel.connector : selectedValue], needsSolving: true)
                } else {
                    updateDisplay(needsSolving: true)
                }
                
                valuePicker.hidden = false
            } else {
                valuePicker.hidden = true
                if oldValue != nil {
                    // Solve again, to clear dependent connections
                    updateDisplay(needsSolving: true)
                }
            }
        }
    }
    
    var constraintViews: [ConstraintView] = []
    func addConstraintView(constraintView: ConstraintView, firstInputPort: ConnectorPort?, secondInputPort: ConnectorPort?, outputPort: ConnectorPort?) {
        constraintViews.append(constraintView)
        self.scrollView.addSubview(constraintView)
        constraintView.layer.zPosition = constraintZPosition
        updateScrollableSize()
        
        if let outputPort = outputPort, (lastConstraint, inputPort) = self.selectedConnectorPort {
                if connectorToLabel[inputPort.connector!] == nil {
                    self.connectConstraintViews(constraintView, firstConnectorPort: outputPort, secondConstraintView: lastConstraint, secondConnectorPort: inputPort)
                }
        }
        
        if let firstInputPort = firstInputPort, selectedConnector = self.selectedConnectorLabel {
            constraintView.connectPort(firstInputPort, connector: selectedConnector.connector)
            self.needsLayout = true
            self.needsSolving = true
        }
        if let secondInputPort = secondInputPort {
            self.selectedConnectorPort = (constraintView, secondInputPort)
        } else {
            self.selectedConnectorPort = nil
        }
    }
    var selectedConnectorPort: (ConstraintView: ConstraintView, ConnectorPort: ConnectorPort)? {
        didSet {
            if let (oldConstraintView, oldConnectorPort) = oldValue {
                oldConnectorPort.isSelected = false
            }
            
            if let (newConstraintView, newConnectorPort) = self.selectedConnectorPort {
                newConnectorPort.isSelected = true
                
                if self.selectedConnectorLabel != nil {
                    self.selectedConnectorLabel = nil
                }
            }
        }
    }
    
    func removeConstraintView(constraintView: ConstraintView) {
        if let index = constraintViews.indexOf(constraintView) {
            constraintViews.removeAtIndex(index)
            constraintView.removeFromSuperview()
            for port in constraintView.connectorPorts() {
                constraintView.removeConnectorAtPort(port)
            }
            if self.selectedConnectorPort?.ConstraintView == constraintView {
                self.selectedConnectorPort = nil
            }
            
            self.needsLayout = true
            self.needsSolving = true
        } else {
            print("Cannot remove that constraint!")
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
    
    
    // MARK: Pencil integration
    
    func penManagerStateDidChange(state: FTPenManagerState) {
        let connected = FTPenManagerStateIsConnected(state)
        // TODO: Switch between two-finger scroll and using finger to scroll by disabling UIScrollView's gesture recognizer
        if (connected)
        {
            print("Connected")
        }
        else
        {
            print("Disconnected")
        }
    }
    
    func penClassificationForTouch(touch: UITouch) -> FTTouchClassification? {
        var classification = FTTouchClassification.Unknown
        if FTPenManager.sharedInstance().classifier.classification(&classification, forTouch: touch) {
            return classification
        } else {
            return nil
        }
    }
    
    func classificationsDidChangeForTouches(touches: Set<NSObject>) {
        if usePenClassifications() {
            for object in touches {
                if let classificationInfo = object as? FTTouchClassificationInfo {
                    if let touchInfo = self.touches[classificationInfo.touchId] {
                        
                        let penClassification = classificationInfo.newValue
                        let gestureClassification = gestureClassificationForTouchAndPen(touchInfo, penClassification: penClassification)
                        changeTouchToClassification(touchInfo, classification: gestureClassification)
                    }
                }
            }
        }
    }
    
    func gestureClassificationForTouchAndPen(touchInfo: TouchInfo, penClassification: FTTouchClassification) -> GestureClassification? {
        if penClassification == .Pen {
            // If there is a connectorPort or label, they are drawing a connection
            if touchInfo.connectorLabel != nil || touchInfo.constraintView?.ConnectorPort != nil {
                return .MakeConnection
            } else if touchInfo.constraintView == nil { // If there was a constraintView but no connectorPort, it was a miss and we ignore it
                return .Stroke
            }
        } else if penClassification == .Finger {
            if touchInfo.pickedUpView() != nil {
                return .Drag
            }
            // TODO: Scroll the view, if there is no view to pick up
        } else if penClassification == .Eraser {
            return .Delete
        }
        return nil
    }
    
    func usePenClassifications() -> Bool {
        return FTPenManagerStateIsConnected(FTPenManager.sharedInstance().state)
    }
    
    // MARK: Gestures
    
    enum GestureClassification {
        case Stroke
        case MakeConnection
        case Drag
        case Delete
    }
    
    class TouchInfo {
        var connectorLabel: (ConnectorLabel: ConnectorLabel, Offset: CGPoint)?
        var constraintView: (ConstraintView: ConstraintView, Offset: CGPoint, ConnectorPort: ConnectorPort?)?
        var drawConnectionLine: CAShapeLayer?
        
        let currentStroke = Stroke()
        
        var phase: UITouchPhase = .Began
        var classification: GestureClassification?
        
        let initialPoint: CGPoint
        let initialTime: NSTimeInterval
        init(initialPoint: CGPoint, initialTime: NSTimeInterval) {
            self.initialPoint = initialPoint
            self.initialTime = initialTime
            
            currentStroke.addPoint(initialPoint)
        }
        
        func pickedUpView() -> (View: UIView, Offset: CGPoint)? {
            if let connectorLabel = self.connectorLabel {
                return (connectorLabel.ConnectorLabel, connectorLabel.Offset)
            } else if let constraintView =  self.constraintView {
                return (constraintView.ConstraintView, constraintView.Offset)
            } else {
                return nil
            }
        }
    }
    
    typealias TouchID = NSInteger
    var touches: [TouchID: TouchInfo] = [:]
    var processStrokesCounter: Int = 0
    
    let dragDelayTime = 0.2
    let dragMaxDistance: CGFloat = 10
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for object in touches {
            if let touch = object as? UITouch {
                let point = touch.locationInView(self.scrollView)
                
                var touchInfo = TouchInfo(initialPoint: point, initialTime: touch.timestamp)
                
                if let connectorLabel = self.connectorLabelAtPoint(point) {
                    touchInfo.connectorLabel = (connectorLabel, connectorLabel.center - point)
                    
                } else if let (constraintView, connectorPort) = self.connectorPortAtLocation(point) {
                    touchInfo.constraintView = (constraintView, constraintView.center - point, connectorPort)
                    
                } else if let constraintView = self.constraintViewAtPoint(point) {
                    touchInfo.constraintView = (constraintView, constraintView.center - point, nil)
                    
                }
                
                let touchID = FTPenManager.sharedInstance().classifier.idForTouch(touch)
                self.touches[touchID] = touchInfo
                
                if (!usePenClassifications()) {
                    // Test for a long press, to trigger a drag
                    if (touchInfo.connectorLabel != nil || touchInfo.constraintView != nil) {
                        delay(dragDelayTime) {
                            // If this still hasn't been classified as something else (like a connection draw), then it is a move
                            if touchInfo.classification == nil {
                                if touchInfo.phase == .Began || touchInfo.phase == .Moved {
                                    self.changeTouchToClassification(touchInfo, classification: .Drag)
                                }
                            }
                        }
                    }
                }
                
                let classification = penClassificationForTouch(touch)
                if classification == nil || classification! != .Palm {
                    if let lastStroke = self.unprocessedStrokes.last, lastStrokeLastPoint = lastStroke.points.last {
                        if euclidianDistance(lastStrokeLastPoint, b: point) > 150 {
                            // This was far away from the last stroke, so we process that stroke
                            processStrokes()
                        }
                    }
                }
            }
        }
        
        // TODO: See if this was a double-tap, to delete
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let touchID = FTPenManager.sharedInstance().classifier.idForTouch(touch)
            if let touchInfo = self.touches[touchID] {
                let point = touch.locationInView(self.scrollView)
                
                touchInfo.currentStroke.addPoint(point)
                touchInfo.phase = .Moved
                
                if (usePenClassifications()) {
                    if touchInfo.classification == nil {
                        if let penClassification = penClassificationForTouch(touch) {
                            if let gestureClassification = gestureClassificationForTouchAndPen(touchInfo, penClassification: penClassification) {
                                print("Used penClassification \(penClassification) in touchesMoved for touch \(touchID)")
                                changeTouchToClassification(touchInfo, classification: gestureClassification)
                            }
                        }
                    }
                    
                } else {
                    // Assign a classification, only if one doesn't exist
                    if touchInfo.classification == nil {
                        // If they weren't pointing at anything, then this is definitely a stroke
                        if touchInfo.connectorLabel == nil && touchInfo.constraintView == nil {
                            changeTouchToClassification(touchInfo, classification: .Stroke)
                        } else if touchInfo.connectorLabel != nil || touchInfo.constraintView?.ConnectorPort != nil {
                            // If we have moved significantly before the long press timer fired, then this is a connection draw
                            if touchInfo.initialPoint.distanceTo(point) > dragMaxDistance {
                                changeTouchToClassification(touchInfo, classification: .MakeConnection)
                            }
                            // TODO: Maybe it should be a failed gesture if there was no connectorPort?
                        }
                    }
                }
                
                if touchInfo.classification != nil {
                        updateGestureForTouch(touchInfo)
                }
                
            } else {
                print("Unable to find info for touchMoved ID \(touchID)")
            }
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for object in touches {
            if let touch = object as? UITouch {
                let touchID = FTPenManager.sharedInstance().classifier.idForTouch(touch)
                if let touchInfo = self.touches[touchID] {
                    let point = touch.locationInView(self.scrollView)
                    
                    touchInfo.currentStroke.addPoint(point)
                    touchInfo.phase = .Ended
                    
                    // See if this was a tap
                    var wasTap = false
                    if touch.timestamp - touchInfo.initialTime < dragDelayTime && touchInfo.initialPoint.distanceTo(point) <= dragMaxDistance {
                        wasTap = true
                        for point in touchInfo.currentStroke.points {
                            // Only if all points were within the threshold was it a tap
                            if touchInfo.initialPoint.distanceTo(point) > dragMaxDistance {
                                wasTap = false
                                break
                            }
                        }
                    }
                    if wasTap {
                        if touchInfo.classification != nil {
                            undoEffectsOfGestureInProgress(touchInfo)
                        }
                        
                        let isDeleteTap = usePenClassifications() ? touchInfo.classification == .Delete :  touch.tapCount == 2
                        if !isDeleteTap {
                            // This is a selection tap
                            if let (connectorLabel, offset) = touchInfo.connectorLabel {

                                if usePenClassifications() {
                                    if self.selectedConnectorLabel != connectorLabel {
                                        self.selectedConnectorLabel = connectorLabel
                                    } else {
                                        self.selectedConnectorLabel = nil
                                    }
                                } else {
                                    // We delay this by a bit, so that the selection doesn't happen if a double-tap completes and the connector is deleted
                                    delay(dragDelayTime) {
                                        if let _ = self.connectorLabels.indexOf(connectorLabel) { // It will be found unless it has been deleted
                                            if self.selectedConnectorLabel != connectorLabel {
                                                self.selectedConnectorLabel = connectorLabel
                                            } else {
                                                self.selectedConnectorLabel = nil
                                            }
                                        }
                                    }
                                }
                                
                            } else if let connectorPort = touchInfo.constraintView?.ConnectorPort {
                                if self.selectedConnectorPort?.ConnectorPort !== connectorPort {
                                    let constraintView = touchInfo.constraintView!.ConstraintView
                                    self.selectedConnectorPort = (constraintView, connectorPort)
                                } else {
                                    self.selectedConnectorPort = nil
                                }
                                
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
                                
                            } else {
                                // De-select everything
                                // TODO: What if they were just drawing a point?
                                self.selectedConnectorLabel = nil
                                self.selectedConnectorPort = nil
                            }
                            
                        } else {
                            // This is a delete tap
                            var deletedSomething = false
                            if let (connectorLabel, offset) = touchInfo.connectorLabel {
                                // Delete this connector!
                                removeConnectorLabel(connectorLabel)
                                deletedSomething = true
                            }
                            if deletedSomething == false {
                                if let (constraintView, offset, connectorPort) = touchInfo.constraintView {
                                    // Delete this constraint!
                                    removeConstraintView(constraintView)
                                    deletedSomething = true
                                }
                            }
                            
                            if deletedSomething {
                                updateDisplay(needsSolving: true, needsLayout: true)
                            }
                        }
                        
                    } else if touchInfo.classification != nil {
                        completeGestureForTouch(touchInfo)
                    }
                    
                    self.touches[touchID] = nil
                }
            }
        }
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        guard let touches = touches else { return }
        for touch in touches {
            let touchID = FTPenManager.sharedInstance().classifier.idForTouch(touch)
            if let touchInfo = self.touches[touchID] {
                undoEffectsOfGestureInProgress(touchInfo)
                touchInfo.phase = .Cancelled
                
                self.touches[touchID] = nil
            }
        }
    }
    
    func changeTouchToClassification(touchInfo: TouchInfo, classification: GestureClassification?) {
        if touchInfo.classification != classification {
            if touchInfo.classification != nil {
                undoEffectsOfGestureInProgress(touchInfo)
            }
            
            touchInfo.classification = classification
            
            if let classification = classification {
                switch classification {
                case .Stroke:
                    self.processStrokesCounter += 1
                    touchInfo.currentStroke.updateLayer()
                    touchInfo.currentStroke.layer.strokeColor = UIColor.blackColor().CGColor
                    self.scrollView.layer.addSublayer(touchInfo.currentStroke.layer)
                    
                case .MakeConnection:
                    updateDrawConnectionGesture(touchInfo)
                    
                case .Drag:
                    if let (pickedUpView, offset) = touchInfo.pickedUpView() {
                        setViewPickedUp(pickedUpView, pickedUp: true)
                        updateDragGesture(touchInfo)
                        
                    } else {
                        fatalError("A touchInfo was classified as Drag, but didn't have a connectorLabel or constraintView.")
                    }
                    
                case .Delete:
                    touchInfo.currentStroke.updateLayer()
                    touchInfo.currentStroke.layer.strokeColor = UIColor.redColor().CGColor
                    self.scrollView.layer.addSublayer(touchInfo.currentStroke.layer)
                }
            }
        }
    }
    
    func undoEffectsOfGestureInProgress(touchInfo: TouchInfo) {
        if let classification = touchInfo.classification {
            switch classification {
            case .Stroke:
                touchInfo.currentStroke.layer.removeFromSuperlayer()
            case .MakeConnection:
                if let dragLine = touchInfo.drawConnectionLine {
                    dragLine.removeFromSuperlayer()
                }
            case .Drag:
                if let (pickedUpView, offset) = touchInfo.pickedUpView() {
                    setViewPickedUp(pickedUpView, pickedUp: false)
                }
            case .Delete:
                touchInfo.currentStroke.layer.removeFromSuperlayer()
            }
        }
    }
    
    func updateGestureForTouch(touchInfo: TouchInfo) {
        if let classification = touchInfo.classification {
            
            switch classification {
            case .Stroke:
                touchInfo.currentStroke.updateLayer()
                
            case .MakeConnection:
                updateDrawConnectionGesture(touchInfo)
                
            case .Drag:
                updateDragGesture(touchInfo)
                
            case .Delete:
                touchInfo.currentStroke.updateLayer()
            }
            
        } else {
            fatalError("A touchInfo must have a classification to update the gesture.")
        }
    }
    
    func completeGestureForTouch(touchInfo: TouchInfo) {
        if let classification = touchInfo.classification {
            
            switch classification {
            case .Stroke:
                touchInfo.currentStroke.updateLayer()
                
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
                unprocessedStrokes.append(touchInfo.currentStroke)
                
            case .MakeConnection:
                completeDrawConnectionGesture(touchInfo)
                
            case .Drag:
                if let (pickedUpView, offset) = touchInfo.pickedUpView() {
                    updateDragGesture(touchInfo)
                    setViewPickedUp(pickedUpView, pickedUp: false)
                    updateScrollableSize()
                    
                } else {
                    fatalError("A touchInfo was classified as Drag, but didn't have a connectorLabel or constraintView.")
                }
                
            case .Delete:
                completeDeleteGesture(touchInfo)
                touchInfo.currentStroke.layer.removeFromSuperlayer()
            }
        } else {
            fatalError("A touchInfo must have a classification to complete the gesture.")
        }
    }
    
    func completeDeleteGesture(touchInfo: TouchInfo) {
        // Find all the connectors, constraintViews, and connections that fall under the stroke and remove them
        for point in touchInfo.currentStroke.points {
            if let connectorLabel = self.connectorLabelAtPoint(point) {
                self.removeConnectorLabel(connectorLabel)
            } else if let constraintView = self.constraintViewAtPoint(point) {
                self.removeConstraintView(constraintView)
            } else if let (connectorLabel, constraintView, connectorPort) = self.connectionLineAtPoint(point, distanceCutoff: 2.0) {
                constraintView.removeConnectorAtPort(connectorPort)
                self.needsSolving = true
                self.needsLayout = true
            }
        }
        self.updateDisplay()
    }
    
    func updateDragGesture(touchInfo: TouchInfo) {
        let point = touchInfo.currentStroke.points.last!
        if let (pickedUpView, offset) = touchInfo.pickedUpView() {
            
            let newPoint = point + offset
            pickedUpView.center = newPoint
            updateDisplay(needsLayout: true)
            
        } else {
            fatalError("A touchInfo was classified as Drag, but didn't have a connectorLabel or constraintView.")
        }
    }
    
    func updateDrawConnectionGesture(touchInfo: TouchInfo) {
        let point = touchInfo.currentStroke.points.last!
        
        if let oldDragLine = touchInfo.drawConnectionLine {
            oldDragLine.removeFromSuperlayer()
        }
        
        var dragLine: CAShapeLayer!
        if let (connectorLabel, offset) = touchInfo.connectorLabel {
            let targetPort = connectorPortAtLocation(point)?.ConnectorPort
            let labelPoint = connectorLabel.center
            let dependent = lastValueWasDependentForConnector(connectorLabel.connector) ?? false
            dragLine = createConnectionLayer(labelPoint, endPoint: point, color: targetPort?.color, isDependent: dependent)
            
        } else if let (constraintView, offset, connectorPort) = touchInfo.constraintView {
            let startPoint = self.scrollView.convertPoint(connectorPort!.center, fromView: constraintView)
            var endPoint = point
            var dependent = false
            if let targetConnector = connectorLabelAtPoint(point) {
                endPoint = targetConnector.center
                dependent = lastValueWasDependentForConnector(targetConnector.connector) ?? false
            }
            dragLine = createConnectionLayer(startPoint, endPoint: endPoint, color: connectorPort!.color, isDependent: dependent)
            
        } else {
            fatalError("A touchInfo was classified as MakeConnection, but didn't have a connectorLabel or connectorPort.")
        }
        
        dragLine.zPosition = connectionLayersZPosition
        self.scrollView.layer.addSublayer(dragLine)
        touchInfo.drawConnectionLine = dragLine
    }
    
    func completeDrawConnectionGesture(touchInfo: TouchInfo) {
        let point = touchInfo.currentStroke.points.last!
        
        if let oldDragLine = touchInfo.drawConnectionLine {
            oldDragLine.removeFromSuperlayer()
        }
        
        var connectionMade = false
        
        if let (connectorLabel, offset) = touchInfo.connectorLabel {
            if let (constraintView, connectorPort) = connectorPortAtLocation(point) {
                self.connect(connectorLabel, constraintView: constraintView, connectorPort: connectorPort)
                connectionMade = true
            }
            
        } else if let (constraintView, offset, connectorPort) = touchInfo.constraintView {
            if let connectorLabel = connectorLabelAtPoint(point) {
                self.connect(connectorLabel, constraintView: constraintView, connectorPort: connectorPort!)
                connectionMade = true
                
            } else if let (secondConstraintView, secondConnectorPort) = connectorPortAtLocation(point) {
                self.connectConstraintViews(constraintView, firstConnectorPort: connectorPort!, secondConstraintView: secondConstraintView, secondConnectorPort: secondConnectorPort)
                
                connectionMade = true
            }
            
        } else {
            fatalError("A touchInfo was classified as MakeConnection, but didn't have a connectorLabel or connectorPort.")
        }
        
        if connectionMade {
            self.updateDisplay()
        }
    }
    
    func setViewPickedUp(view: UIView, pickedUp: Bool) {
        if pickedUp {
            // Add some styles to make it look picked up
            UIView.animateWithDuration(0.2) {
                view.layer.shadowColor = UIColor.blackColor().CGColor
                view.layer.shadowOpacity = 0.4
                view.layer.shadowRadius = 10
                view.layer.shadowOffset = CGSizeMake(5, 5)
            }
        } else {
            // Remove the picked up styles
            UIView.animateWithDuration(0.2) {
                view.layer.shadowColor = nil
                view.layer.shadowOpacity = 0
            }
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
    
    func connectionLineAtPoint(point: CGPoint, distanceCutoff: CGFloat = 10.0) -> (ConnectorLabel: ConnectorLabel, ConstraintView: ConstraintView, ConnectorPort: ConnectorPort)? {
        // This is a hit-test to see if the user has tapped on a line between a connector and a connectorPort.
        let squaredDistanceCutoff = distanceCutoff * distanceCutoff
        
        var minSquaredDistance: CGFloat?
        var minMatch: (ConnectorLabel, ConstraintView, ConnectorPort)?
        for constraintView in constraintViews {
            for connectorPort in constraintView.connectorPorts() {
                if let connector = connectorPort.connector {
                    if let connectorLabel = connectorToLabel[connector] {
                        let connectorPoint = self.scrollView.convertPoint(connectorPort.center, fromView: constraintView)
                        let labelPoint = connectorLabel.center
                        
                        let squaredDistance = shortestDistanceSquaredToLineSegmentFromPoint(connectorPoint, segmentEnd: labelPoint, testPoint: point)
                        if squaredDistance < squaredDistanceCutoff {
                            if minSquaredDistance == nil || squaredDistance < minSquaredDistance! {
                                print("Found elligible distance of \(sqrt(squaredDistance))")
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
                    
                    var combinedLabels = classifiedLabels.reduce("", combine: +)
                    var isPercent = false
                    if classifiedLabels.count > 1 && combinedLabels.hasSuffix("/") {
                        combinedLabels = combinedLabels.substringToIndex(combinedLabels.endIndex.predecessor())
                        isPercent = true
                    }
                    var recognized = false
                    var writtenValue: Double?
                    if let writtenNumber = Int(combinedLabels) {
                        writtenValue = Double(writtenNumber)
                    } else if combinedLabels == "e" {
                        writtenValue = Double(M_E)
                    }
                    if writtenValue != nil && isPercent {
                        writtenValue = writtenValue! / 100.0
                    }
                    
                    if let writtenValue = writtenValue {
                        // We recognized a number!
                        let newConnector = Connector()
                        let newLabel = ConnectorLabel(connector: newConnector)
                        newLabel.sizeToFit()
                        newLabel.center = centerPoint
                        newLabel.isPercent = isPercent
                        
                        let scale: Int16
                        if isPercent {
                            scale = -3
                        } else if combinedLabels == "e" {
                            scale = -4
                        } else {
                            scale = self.defaultScaleForNewValue(writtenValue)
                        }
                        newLabel.scale = scale
                        
                        self.addConnectorLabel(newLabel, topPriority: true)
                        self.selectConnectorLabelAndSetToValue(newLabel, value: writtenValue)
                        
                        recognized = true
                        
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
                        print("Unable to parse written text: \(combinedLabels)")
                    }
                    self.updateDisplay();
                } else {
                    print("Unable to recognize all \(allStrokes.count) strokes")
                }
                
                for stroke in unprocessedStrokesCopy {
                    stroke.layer.removeFromSuperlayer()
                }
            }
        }
    }
    
    func defaultScaleForNewValue(value: Double) -> Int16 {
        if abs(value) < 3 {
            return -2
        } else if abs(value) >= 1000 {
            return 2
        } else if abs(value) >= 100 {
            return 1
        } else {
            return -1
        }
    }
    
    func numberSlideView(NumberSlideView, didSelectNewValue newValue: NSDecimalNumber, scale: Int16) {
        if let selectedConnectorLabel = self.selectedConnectorLabel {
            selectedConnectorLabel.scale = scale
            self.updateDisplay([selectedConnectorLabel.connector : newValue.doubleValue], needsSolving: true, selectNewConnectorLabel: false)
        }
    }
    
    func numberSlideView(NumberSlideView, didSelectNewScale scale: Int16) {
        if let selectedConnectorLabel = self.selectedConnectorLabel {
            selectedConnectorLabel.scale = scale
            selectedConnectorLabel.displayValue(lastValueForConnector(selectedConnectorLabel.connector))
        }
    }
    
    var needsLayout = false
    var needsRebuildConnectionLayers = false
    var needsSolving = false
    
    func updateDisplay(values: [Connector: Double] = [:], needsSolving: Bool = false, needsLayout: Bool = false, selectNewConnectorLabel: Bool = true)
    {
        // See how these variables are used at the end of this function, after the internal definitions
        self.needsLayout = self.needsLayout || needsLayout
        self.needsSolving = self.needsSolving || needsSolving || values.count > 0
        
        func rebuildAllConnectionLayers() {
            for oldLayer in self.connectionLayers {
                oldLayer.removeFromSuperlayer()
            }
            self.connectionLayers.removeAll(keepCapacity: true)
            
            for constraintView in self.constraintViews {
                for connectorPort in constraintView.connectorPorts() {
                    if let connector = connectorPort.connector {
                        if let connectorLabel = self.connectorToLabel[connector] {
                            let connectorPoint = self.scrollView.convertPoint(connectorPort.center, fromView: constraintView)
                            let labelPoint = connectorLabel.center
                            
                            let dependent = self.lastValueWasDependentForConnector(connectorLabel.connector) ?? false
                            let connectionLayer = self.createConnectionLayer(labelPoint, endPoint: connectorPoint, color: connectorPort.color, isDependent: dependent)
                            
                            self.connectionLayers.append(connectionLayer)
                            connectionLayer.zPosition = self.connectionLayersZPosition
                            self.scrollView.layer.addSublayer(connectionLayer)
                        }
                    }
                }
            }
            self.needsRebuildConnectionLayers = false
        }
        
        func layoutConstraintViews() {
            var connectorPositions: [Connector: CGPoint] = [:]
            for connectorLabel in self.connectorLabels {
                connectorPositions[connectorLabel.connector] = connectorLabel.center
            }
            for constraintView in self.constraintViews {
                constraintView.layoutWithConnectorPositions(connectorPositions)
            }
            self.needsLayout = false
            self.needsRebuildConnectionLayers = true
        }
        
        func runSolver(values: [Connector: Double]) {
            let lastSimulationContext = self.lastSimulationContext
            
            var connectorToSelect: ConnectorLabel?
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
                            print("Unable to find constraint view for newly resolved connector! \(connector), \(resolvedValue), \(constraint)")
                            return
                        }
                        
                        let newLabel = ConnectorLabel(connector: connector)
                        newLabel.scale = self.defaultScaleForNewValue(resolvedValue.DoubleValue)
                        newLabel.sizeToFit()
                        
                        let distance: CGFloat = 80 + max(connectTo.constraintView.bounds.width, connectTo.constraintView.bounds.height)
                        // If the connectorPort is at the bottom-right, then we want to place it distance points off to the bottom-right
                        let constraintMiddle = connectTo.constraintView.bounds.center()
                        let displacement = connectTo.connectorPort.center - connectTo.constraintView.bounds.center()
                        let newDisplacement = displacement * (distance / displacement.length())
                        
                        // Make sure the new point is somewhat on the screen
                        var newPoint = self.scrollView.convertPoint(newDisplacement + constraintMiddle, fromView: connectTo.constraintView)
                        let minMargin: CGFloat = 10
                        newPoint.x = max(newPoint.x, minMargin)
                        newPoint.x = min(newPoint.x, self.scrollView.contentSize.width - minMargin)
                        newPoint.y = max(newPoint.y, minMargin)
                        
                        newLabel.center = newPoint
                        newLabel.alpha = 0
                        self.addConnectorLabel(newLabel, topPriority: false, automaticallyConnect: false)
                        UIView.animateWithDuration(0.5) {
                            newLabel.alpha = 1.0
                        }
                        connectorToSelect = newLabel
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
                        label.hasError = true
                    }
            })
            
            // Reset all error states
            for label in self.connectorLabels {
                label.hasError = false
            }
            
            // First, the selected connector
            if let selectedConnector = self.selectedConnectorLabel?.connector {
                if let value = (values[selectedConnector] ?? lastSimulationContext?.connectorValues[selectedConnector]?.DoubleValue) {
                    simulationContext.setConnectorValue(selectedConnector, value: (DoubleValue: value, Expression: constantExpression(value), WasDependent: true), informant: nil)
                }
            }
            
            // These are the first priority
            for (connector, value) in values {
                simulationContext.setConnectorValue(connector, value: (DoubleValue: value, Expression: constantExpression(value), WasDependent: false), informant: nil)
            }
            
            // We loop through connectorLabels like this, because it can mutate during the simulation, if a constraint "resolves a port"
            var index = 0
            while index < self.connectorLabels.count {
                let connector = self.connectorLabels[index].connector
                
                // If we haven't already resolved this connector, then set it as a non-dependent variable to the value from the last simulation
                if simulationContext.connectorValues[connector] == nil {
                    if let lastValue = lastSimulationContext?.connectorValues[connector]?.DoubleValue {
                        simulationContext.setConnectorValue(connector, value: (DoubleValue: lastValue, Expression: constantExpression(lastValue), WasDependent: false), informant: nil)
                    }
                }
                index += 1
            }
            
            // Update the labels that still don't have a value
            for label in self.connectorLabels {
                if simulationContext.connectorValues[label.connector] == nil {
                    label.displayValue(nil)
                }
            }
            
            self.lastSimulationContext = simulationContext
            self.needsSolving = false
            
            if let connectorToSelect = connectorToSelect {
                if selectNewConnectorLabel {
                    self.selectedConnectorLabel = connectorToSelect
                }
            }
        }
        
        var ranSolver = false
        while (self.needsLayout || self.needsSolving) {
            // First, we layout. This way, if solving generates a new connector then it will be pointed in a sane direction
            // But, solving means we might need to layout, and so on...
            if (self.needsLayout) {
                layoutConstraintViews()
            }
            if (self.needsSolving) {
                runSolver(values)
                ranSolver = true
            }
        }
        
        if (self.needsRebuildConnectionLayers) {
            rebuildAllConnectionLayers()
        }

        if ranSolver {
            if let simulationContext = self.lastSimulationContext {
                
                // We first make a map from value DDExpressions to the formatted value
                var formattedValues: [DDExpression : String] = [:]
                for label in self.connectorLabels {
                    if let value = simulationContext.connectorValues[label.connector] {
                        if value.Expression.expressionType() == .Number {
                            formattedValues[value.Expression] = label.valueLabel.text
                        }
                    }
                }
                
                for label in self.connectorLabels {
                    var displayedEquation = false
                    if let value = simulationContext.connectorValues[label.connector] {
                        if value.Expression.expressionType() == .Function {
                            if let mathML = mathMLForExpression(value.Expression, formattedValues: formattedValues) {
                                label.displayEquation(mathML)
                                displayedEquation = true
                            }
                        }
                    }
                    if !displayedEquation {
                        label.hideEquation()
                    }
                }
            }
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

