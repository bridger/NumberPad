//
//  CanvasViewController.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/13/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit
import DigitRecognizerSDK

class CanvasViewController: UIViewController, UIGestureRecognizerDelegate, NumberSlideViewDelegate, FTPenManagerDelegate, FTTouchClassificationsChangedDelegate, NameCanvasDelegate, UIViewControllerTransitioningDelegate {
    
    init(digitClassifier: DTWDigitClassifier) {
        self.digitClassifier = digitClassifier
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.digitClassifier = DTWDigitClassifier()
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.isMultipleTouchEnabled = true
        self.view.isUserInteractionEnabled = true
        self.view.isExclusiveTouch = true
        self.view.backgroundColor = UIColor.backgroundColor()
        
        FTPenManager.sharedInstance().delegate = self;
        FTPenManager.sharedInstance().classifier.delegate = self;
        
        self.scrollView = UIScrollView(frame: self.view.bounds)
        self.scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.scrollView.isUserInteractionEnabled = false
        self.scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        self.view.addGestureRecognizer(self.scrollView.panGestureRecognizer)
        self.view.insertSubview(self.scrollView, at: 0)
        
        let valuePickerHeight: CGFloat = 85.0
        valuePicker = NumberSlideView(frame: CGRect(x: 0, y:  self.view.bounds.size.height - valuePickerHeight, width:  self.view.bounds.size.width, height: valuePickerHeight))
        valuePicker.delegate = self
        valuePicker.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
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
            connectorLabels.insert(label, at: 0)
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
                    lastConstraint.connectPort(port: inputPort, connector: label.connector)
                    self.needsLayout = true
                    self.needsSolving = true
                }
                
                self.selectedConnectorPort = nil
            }
        }
    }
    func moveConnectorToTopPriority(connectorLabel: ConnectorLabel) {
        if let index = connectorLabels.index(of: connectorLabel) {
            if index != 0 {
                connectorLabels.remove(at: index)
                connectorLabels.insert(connectorLabel, at: 0)
            }
        } else {
            print("Tried to move connector to top priority, but couldn't find it!")
        }
    }
    func moveConnectorToBottomPriority(connectorLabel: ConnectorLabel) {
        if let index = connectorLabels.index(of: connectorLabel) {
            if index != connectorLabels.count - 1 {
                connectorLabels.remove(at: index)
                connectorLabels.append(connectorLabel)
            }
        } else {
            print("Tried to move connector to bottom priority, but couldn't find it!")
        }
    }
    @discardableResult func removeConnectorLabel(label: ConnectorLabel) -> [(ConstraintView, ConnectorPort)] {
        var oldPorts: [(ConstraintView, ConnectorPort)] = []
        if let index = connectorLabels.index(of: label) {
            if label == selectedConnectorLabel {
                selectedConnectorLabel = nil
            }
            connectorLabels.remove(at: index)
            label.removeFromSuperview()
            connectorToLabel[label.connector] = nil
            
            let deleteConnector = label.connector
            for constraintView in self.constraintViews {
                for port in constraintView.connectorPorts() {
                    if port.connector === deleteConnector {
                        constraintView.removeConnectorAtPort(port: port)
                        oldPorts.append((constraintView, port))
                    }
                }
            }
            self.needsLayout = true
            self.needsSolving = true
        } else {
            print("Cannot remove that label!")
        }
        return oldPorts
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
                let selectedValue = selectedConnectorLabelValueOverride ?? self.lastValueForConnector(connector: connectorLabel.connector)
                var valueToDisplay = selectedValue ?? 0.0
                selectedConnectorLabelValueOverride = nil
                if !valueToDisplay.isFinite {
                    valueToDisplay = 0.0
                }
                valuePicker.resetToValue( value: NSDecimalNumber(value: Double(valueToDisplay)), scale: connectorLabel.scale)
                
                // If this is the input of a toy, make sure the outputs are low priority
                for toy in self.toys {
                    if toy.inputConnectors().contains(connectorLabel.connector)  {
                        for output in toy.outputConnectors() {
                            if let outputLabel = self.connectorToLabel[output] {
                                self.moveConnectorToBottomPriority(connectorLabel: outputLabel)
                            }
                        }
                    }
                }
                
                if let selectedValue = selectedValue {
                    updateDisplay(values: [connectorLabel.connector : selectedValue], needsSolving: true)
                } else {
                    updateDisplay(needsSolving: true)
                }
                
                valuePicker.isHidden = false
            } else {
                valuePicker.isHidden = true
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
            if connectorToLabel[inputPort.connector] == nil {
                self.connectConstraintViews(firstConstraintView: constraintView, firstConnectorPort: outputPort, secondConstraintView: lastConstraint, secondConnectorPort: inputPort)
            }
        }
        
        if let firstInputPort = firstInputPort, selectedConnector = self.selectedConnectorLabel {
            constraintView.connectPort(port: firstInputPort, connector: selectedConnector.connector)
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
                oldConstraintView.setConnectorPort(port: oldConnectorPort, isHighlighted: false)
            }
            
            if let (newConstraintView, newConnectorPort) = self.selectedConnectorPort {
                newConstraintView.setConnectorPort(port: newConnectorPort, isHighlighted: true)
                
                if self.selectedConnectorLabel != nil {
                    self.selectedConnectorLabel = nil
                }
            }
        }
    }
    // This is a conviencence for unhighlighting a connector port that was possibly part of a drag. We only
    // want to do this if it isn't the permanently selected connector. Also, this accepts the parameters as
    // optionals for convenience.
    func unhighlightConnectorPortIfNotSelected(constraintView: ConstraintView?, connectorPort: ConnectorPort?) {
        if let constraintView = constraintView, connectorPort = connectorPort {
            if selectedConnectorPort?.ConnectorPort !== connectorPort {
                constraintView.setConnectorPort(port: connectorPort, isHighlighted: false)
            }
        }
    }
    
    func removeConstraintView(constraintView: ConstraintView) {
        if let index = constraintViews.index(of: constraintView) {
            constraintViews.remove(at: index)
            constraintView.removeFromSuperview()
            for port in constraintView.connectorPorts() {
                constraintView.removeConnectorAtPort(port: port)
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
    var lastSimulationValues: [Connector: SimulationContext.ResolvedValue]?
    func lastValueForConnector(connector: Connector) -> Double? {
        return self.lastSimulationValues?[connector]?.DoubleValue
    }
    func lastInformantForConnector(connector: Connector) -> (WasDependent: Bool, Informant: Constraint?)? {
        if let lastValue = self.lastSimulationValues?[connector] {
            return (lastValue.WasDependent, lastValue.Informant)
        }
        return nil
    }
    
    // MARK: Pencil integration
    
    func penManagerStateDidChange(_ state: FTPenManagerState) {
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
        var classification = FTTouchClassification.unknown
        if FTPenManager.sharedInstance().classifier.classification(&classification, for: touch) {
            return classification
        } else {
            return nil
        }
    }
    
    func classificationsDidChange(forTouches touches: Set<NSObject>) {
        if usePenClassifications() {
            for object in touches {
                if let classificationInfo = object as? FTTouchClassificationInfo {
                    if let touchInfo = self.touches[classificationInfo.touchId] {
                        
                        let penClassification = classificationInfo.newValue
                        let gestureClassification = gestureClassificationForTouchAndPen(touchInfo: touchInfo, penClassification: penClassification)
                        changeTouchToClassification(touchInfo: touchInfo, classification: gestureClassification)
                    }
                }
            }
        }
    }
    
    func gestureClassificationForTouchAndPen(touchInfo: TouchInfo, penClassification: FTTouchClassification) -> GestureClassification? {
        if penClassification == .pen {
            // If there is a connectorPort or label, they are drawing a connection
            if touchInfo.connectorLabel != nil || touchInfo.constraintView?.ConnectorPort != nil {
                return .MakeConnection
            } else if touchInfo.constraintView == nil { // If there was a constraintView but no connectorPort, it was a miss and we ignore it
                return .Stroke
            }
        } else if penClassification == .finger {
            if touchInfo.pickedUpView() != nil {
                return .Drag
            }
            // TODO: Scroll the view, if there is no view to pick up
        } else if penClassification == .eraser {
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
        var highlightedConnectorPort: (ConstraintView: ConstraintView, ConnectorPort: ConnectorPort)?
        
        let currentStroke = Stroke()
        
        var phase: UITouchPhase = .began
        var classification: GestureClassification?
        
        let initialPoint: CGPoint
        let initialTime: NSTimeInterval
        init(initialPoint: CGPoint, initialTime: NSTimeInterval) {
            self.initialPoint = initialPoint
            self.initialTime = initialTime
            
            currentStroke.addPoint(point: initialPoint)
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
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self.scrollView)
            
            let touchInfo = TouchInfo(initialPoint: point, initialTime: touch.timestamp)
            
            if let connectorLabel = self.connectorLabelAtPoint(point: point) {
                touchInfo.connectorLabel = (connectorLabel, connectorLabel.center - point)
                
            } else if let (constraintView, connectorPort) = self.connectorPortAtLocation(location: point) {
                touchInfo.constraintView = (constraintView, constraintView.center - point, connectorPort)
                
            } else if let constraintView = self.constraintViewAtPoint(point: point) {
                touchInfo.constraintView = (constraintView, constraintView.center - point, nil)
                
            }
            
            let touchID = FTPenManager.sharedInstance().classifier.id(for: touch)
            self.touches[touchID] = touchInfo
            
            if (!usePenClassifications()) {
                // Test for a long press, to trigger a drag
                if (touchInfo.connectorLabel != nil || touchInfo.constraintView != nil) {
                    delay(delay: dragDelayTime) {
                        // If this still hasn't been classified as something else (like a connection draw), then it is a move
                        if touchInfo.classification == nil {
                            if touchInfo.phase == .began || touchInfo.phase == .moved {
                                self.changeTouchToClassification(touchInfo: touchInfo, classification: .Drag)
                            }
                        }
                    }
                }
            }
            
            let classification = penClassificationForTouch(touch: touch)
            if classification == nil || classification! != .palm {
                if let lastStroke = self.unprocessedStrokes.last, lastStrokeLastPoint = lastStroke.points.last {
                    if euclidianDistance(a: lastStrokeLastPoint, b: point) > 150 {
                        // This was far away from the last stroke, so we process that stroke
                        processStrokes()
                    }
                }
            }
        }
        
        // TODO: See if this was a double-tap, to delete
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchID = FTPenManager.sharedInstance().classifier.id(for: touch)
            if let touchInfo = self.touches[touchID] {
                let point = touch.location(in: self.scrollView)
                
                touchInfo.currentStroke.addPoint(point: point)
                touchInfo.phase = .moved
                
                if (usePenClassifications()) {
                    if touchInfo.classification == nil {
                        if let penClassification = penClassificationForTouch(touch: touch) {
                            if let gestureClassification = gestureClassificationForTouchAndPen(touchInfo: touchInfo, penClassification: penClassification) {
                                print("Used penClassification \(penClassification) in touchesMoved for touch \(touchID)")
                                changeTouchToClassification(touchInfo: touchInfo, classification: gestureClassification)
                            }
                        }
                    }
                    
                } else {
                    // Assign a classification, only if one doesn't exist
                    if touchInfo.classification == nil {
                        // If they weren't pointing at anything, then this is definitely a stroke
                        if touchInfo.connectorLabel == nil && touchInfo.constraintView == nil {
                            changeTouchToClassification(touchInfo: touchInfo, classification: .Stroke)
                        } else if touchInfo.connectorLabel != nil || touchInfo.constraintView?.ConnectorPort != nil {
                            // If we have moved significantly before the long press timer fired, then this is a connection draw
                            if touchInfo.initialPoint.distanceTo(point: point) > dragMaxDistance {
                                changeTouchToClassification(touchInfo: touchInfo, classification: .MakeConnection)
                            }
                            // TODO: Maybe it should be a failed gesture if there was no connectorPort?
                        }
                    }
                }
                
                if touchInfo.classification != nil {
                    updateGestureForTouch(touchInfo: touchInfo)
                }
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchID = FTPenManager.sharedInstance().classifier.id(for: touch)
            if let touchInfo = self.touches[touchID] {
                let point = touch.location(in: self.scrollView)
                
                touchInfo.currentStroke.addPoint(point: point)
                touchInfo.phase = .ended
                
                // See if this was a tap
                var wasTap = false
                if touch.timestamp - touchInfo.initialTime < dragDelayTime && touchInfo.initialPoint.distanceTo(point: point) <= dragMaxDistance {
                    wasTap = true
                    for point in touchInfo.currentStroke.points {
                        // Only if all points were within the threshold was it a tap
                        if touchInfo.initialPoint.distanceTo(point: point) > dragMaxDistance {
                            wasTap = false
                            break
                        }
                    }
                }
                if wasTap {
                    if touchInfo.classification != nil {
                        undoEffectsOfGestureInProgress(touchInfo: touchInfo)
                    }
                    
                    let isDeleteTap = usePenClassifications() ? touchInfo.classification == .Delete :  touch.tapCount == 2
                    if !isDeleteTap {
                        // This is a selection tap
                        if let (connectorLabel, _) = touchInfo.connectorLabel {
                            
                            if usePenClassifications() {
                                if self.selectedConnectorLabel != connectorLabel {
                                    self.selectedConnectorLabel = connectorLabel
                                } else {
                                    showNameCanvas()
                                }
                            } else {
                                // We delay this by a bit, so that the selection doesn't happen if a double-tap completes and the connector is deleted
                                delay(delay: dragDelayTime) {
                                    if let _ = self.connectorLabels.index(of: connectorLabel) { // It will be found unless it has been deleted
                                        if self.selectedConnectorLabel != connectorLabel {
                                            self.selectedConnectorLabel = connectorLabel
                                        } else {
                                            self.showNameCanvas()
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
                            
                        } else if let (connectorLabel, _, _) = self.connectionLineAtPoint(point: point) {
                            let lastInformant = self.lastInformantForConnector(connector: connectorLabel.connector)
                            
                            if (lastInformant != nil && lastInformant!.WasDependent) {
                                // Try to make this connector high priority, so it is constant instead of dependent
                                moveConnectorToTopPriority(connectorLabel: connectorLabel)
                            } else {
                                // Lower the priority of this connector, so it will be dependent
                                moveConnectorToBottomPriority(connectorLabel: connectorLabel)
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
                        if let (connectorLabel, _) = touchInfo.connectorLabel {
                            // Delete this connector!
                            if !self.connectorIsForToy(connector: connectorLabel.connector) {
                                removeConnectorLabel(label: connectorLabel)
                            }
                            deletedSomething = true
                        }
                        if deletedSomething == false {
                            if let (constraintView, _, _) = touchInfo.constraintView {
                                // Delete this constraint!
                                removeConstraintView(constraintView: constraintView)
                                deletedSomething = true
                            }
                        }
                        
                        if deletedSomething {
                            updateDisplay(needsSolving: true, needsLayout: true)
                        }
                    }
                    
                } else if touchInfo.classification != nil {
                    completeGestureForTouch(touchInfo: touchInfo)
                }
                
                self.touches[touchID] = nil
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        guard let touches = touches else { return }
        for touch in touches {
            let touchID = FTPenManager.sharedInstance().classifier.id(for: touch)
            if let touchInfo = self.touches[touchID] {
                undoEffectsOfGestureInProgress(touchInfo: touchInfo)
                touchInfo.phase = .cancelled
                
                self.touches[touchID] = nil
            }
        }
    }
    
    func changeTouchToClassification(touchInfo: TouchInfo, classification: GestureClassification?) {
        if touchInfo.classification != classification {
            if touchInfo.classification != nil {
                undoEffectsOfGestureInProgress(touchInfo: touchInfo)
            }
            
            touchInfo.classification = classification
            
            if let classification = classification {
                switch classification {
                case .Stroke:
                    self.processStrokesCounter += 1
                    touchInfo.currentStroke.updateLayer()
                    touchInfo.currentStroke.layer.strokeColor = UIColor.textColor().cgColor
                    self.scrollView.layer.addSublayer(touchInfo.currentStroke.layer)
                    
                case .MakeConnection:
                    updateDrawConnectionGesture(touchInfo: touchInfo)
                    
                case .Drag:
                    if let (pickedUpView, _) = touchInfo.pickedUpView() {
                        setViewPickedUp(view: pickedUpView, pickedUp: true)
                        updateDragGesture(touchInfo: touchInfo)
                        
                    } else {
                        fatalError("A touchInfo was classified as Drag, but didn't have a connectorLabel or constraintView.")
                    }
                    
                case .Delete:
                    touchInfo.currentStroke.updateLayer()
                    touchInfo.currentStroke.layer.strokeColor = UIColor.red().cgColor
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
                unhighlightConnectorPortIfNotSelected(constraintView: touchInfo.constraintView?.ConstraintView, connectorPort: touchInfo.constraintView?.ConnectorPort)
                unhighlightConnectorPortIfNotSelected(constraintView: touchInfo.highlightedConnectorPort?.ConstraintView, connectorPort: touchInfo.highlightedConnectorPort?.ConnectorPort)
            case .Drag:
                if let (pickedUpView, _) = touchInfo.pickedUpView() {
                    setViewPickedUp(view: pickedUpView, pickedUp: false)
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
                updateDrawConnectionGesture(touchInfo: touchInfo)
                
            case .Drag:
                updateDragGesture(touchInfo: touchInfo)
                
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
                delay(delay: delayTime) { [weak self] in
                    if let strongself = self {
                        // If we haven't begun a new stroke in the intervening time, then process the old strokes
                        if strongself.processStrokesCounter == currentCounter {
                            strongself.processStrokes()
                        }
                    }
                }
                unprocessedStrokes.append(touchInfo.currentStroke)
                
            case .MakeConnection:
                completeDrawConnectionGesture(touchInfo: touchInfo)
                
            case .Drag:
                if let (pickedUpView, _) = touchInfo.pickedUpView() {
                    updateDragGesture(touchInfo: touchInfo)
                    setViewPickedUp(view: pickedUpView, pickedUp: false)
                    updateScrollableSize()
                    
                } else {
                    fatalError("A touchInfo was classified as Drag, but didn't have a connectorLabel or constraintView.")
                }
                
            case .Delete:
                completeDeleteGesture(touchInfo: touchInfo)
                touchInfo.currentStroke.layer.removeFromSuperlayer()
            }
        } else {
            fatalError("A touchInfo must have a classification to complete the gesture.")
        }
    }
    
    func completeDeleteGesture(touchInfo: TouchInfo) {
        // Find all the connectors, constraintViews, and connections that fall under the stroke and remove them
        for point in touchInfo.currentStroke.points {
            if let connectorLabel = self.connectorLabelAtPoint(point: point) {
                if !self.connectorIsForToy(connector: connectorLabel.connector) {
                    self.removeConnectorLabel(label: connectorLabel)
                }
            } else if let constraintView = self.constraintViewAtPoint(point: point) {
                self.removeConstraintView(constraintView: constraintView)
            } else if let (_, constraintView, connectorPort) = self.connectionLineAtPoint(point: point, distanceCutoff: 2.0) {
                constraintView.removeConnectorAtPort(port: connectorPort)
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
        unhighlightConnectorPortIfNotSelected(constraintView: touchInfo.highlightedConnectorPort?.ConstraintView, connectorPort: touchInfo.highlightedConnectorPort?.ConnectorPort)
        
        var dragLine: CAShapeLayer!
        if let (connectorLabel, _) = touchInfo.connectorLabel {
            let targetConstraint = connectorPortAtLocation(location: point)
            let labelPoint = connectorLabel.center
            let dependent = lastInformantForConnector(connector: connectorLabel.connector)?.WasDependent ?? false
            dragLine = createConnectionLayer(startPoint: labelPoint, endPoint: point, color: targetConstraint?.ConnectorPort.color, isDependent: dependent, drawArrow: false)
            
            touchInfo.highlightedConnectorPort = targetConstraint
            if let (constraintView, connectorPort) = targetConstraint {
                constraintView.setConnectorPort(port: connectorPort, isHighlighted: true)
            }
            
        } else if let (constraintView, _, connectorPort) = touchInfo.constraintView {
            let startPoint = self.scrollView.convert(connectorPort!.center, from: constraintView)
            var endPoint = point
            var dependent = false
            if let targetConnector = connectorLabelAtPoint(point: point) {
                endPoint = targetConnector.center
                dependent = lastInformantForConnector(connector: targetConnector.connector)?.WasDependent ?? false
                touchInfo.highlightedConnectorPort = nil
            } else {
                let targetConstraint = connectorPortAtLocation(location: point)
                touchInfo.highlightedConnectorPort = targetConstraint
                if let (constraintView, connectorPort) = targetConstraint {
                    constraintView.setConnectorPort(port: connectorPort, isHighlighted: true)
                }
            }
            dragLine = createConnectionLayer(startPoint: startPoint, endPoint: endPoint, color: connectorPort!.color, isDependent: dependent, drawArrow: false)
            constraintView.setConnectorPort(port: connectorPort!, isHighlighted: true)
            
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
        unhighlightConnectorPortIfNotSelected(constraintView: touchInfo.constraintView?.ConstraintView, connectorPort: touchInfo.constraintView?.ConnectorPort)
        unhighlightConnectorPortIfNotSelected(constraintView: touchInfo.highlightedConnectorPort?.ConstraintView, connectorPort: touchInfo.highlightedConnectorPort?.ConnectorPort)
        
        var connectionMade = false
        
        if let (connectorLabel, _) = touchInfo.connectorLabel {
            if let (constraintView, connectorPort) = connectorPortAtLocation(location: point) {
                self.connect(connectorLabel: connectorLabel, constraintView: constraintView, connectorPort: connectorPort)
                connectionMade = true
            } else if let destinationConnectorLabel = connectorLabelAtPoint(point: point) where destinationConnectorLabel != connectorLabel {
                // Try to combine these connector labels
                if connectorIsForToy(connector: destinationConnectorLabel.connector) {
                    if connectorIsForToy(connector: connectorLabel.connector) {
                        // We can't combine these because they are both for toys
                    } else {
                        combineConnectors(bigConnectorLabel: destinationConnectorLabel, connectorLabelToDelete: connectorLabel)
                        connectionMade = true
                    }
                } else {
                    combineConnectors(bigConnectorLabel: connectorLabel, connectorLabelToDelete: destinationConnectorLabel)
                    connectionMade = true
                }
            }
            
        } else if let (constraintView, _, connectorPort) = touchInfo.constraintView {
            if let connectorLabel = connectorLabelAtPoint(point: point) {
                self.connect(connectorLabel: connectorLabel, constraintView: constraintView, connectorPort: connectorPort!)
                connectionMade = true
                
            } else if let (secondConstraintView, secondConnectorPort) = connectorPortAtLocation(location: point) {
                self.connectConstraintViews(firstConstraintView: constraintView, firstConnectorPort: connectorPort!, secondConstraintView: secondConstraintView, secondConnectorPort: secondConnectorPort)
                
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
            UIView.animate(withDuration: 0.2) {
                view.layer.shadowColor = UIColor.darkGray().cgColor
                view.layer.shadowOpacity = 0.4
                view.layer.shadowRadius = 10
                view.layer.shadowOffset = CGSize(width: 5, height: 5)
            }
        } else {
            // Remove the picked up styles
            UIView.animate(withDuration: 0.2) {
                view.layer.shadowColor = nil
                view.layer.shadowOpacity = 0
            }
        }
    }
    
    func combineConnectors(bigConnectorLabel: ConnectorLabel, connectorLabelToDelete: ConnectorLabel) {
        if bigConnectorLabel == connectorLabelToDelete {
            return
        }
        
        // We just delete connectorLabelToDelete, but wire up all connections to bigConnectorLabel
        
        let oldPorts = removeConnectorLabel(label: connectorLabelToDelete)
        for (constraintView, port) in oldPorts {
            connect(connectorLabel: bigConnectorLabel, constraintView: constraintView, connectorPort: port)
        }
    }
    
    func connect(connectorLabel: ConnectorLabel, constraintView: ConstraintView, connectorPort: ConnectorPort) {
        for connectorPort in constraintView.connectorPorts() {
            if connectorPort.connector === connectorLabel.connector {
                // This connector is already hooked up to this constraintView. The user is probably trying to change the connection, so we remove the old one
                constraintView.removeConnectorAtPort(port: connectorPort)
            }
        }
        
        constraintView.connectPort(port: connectorPort, connector: connectorLabel.connector)
        self.needsSolving = true
        self.needsLayout = true
    }
    
    @discardableResult func connectConstraintViews(firstConstraintView: ConstraintView, firstConnectorPort: ConnectorPort, secondConstraintView: ConstraintView, secondConnectorPort: ConnectorPort) -> ConnectorLabel {
        // We are dragging from one constraint directly to another constraint. To accomodate, we create a connector in-between and make two connections
        let midPoint = (firstConstraintView.center + secondConstraintView.center) / 2.0
        
        let newConnector = Connector()
        let newLabel = ConnectorLabel(connector: newConnector)
        newLabel.sizeToFit()
        newLabel.center = midPoint
        self.addConnectorLabel(label: newLabel, topPriority: false, automaticallyConnect: false)
        
        firstConstraintView.connectPort(port: firstConnectorPort, connector: newConnector)
        secondConstraintView.connectPort(port: secondConnectorPort, connector: newConnector)
        self.needsSolving = true
        self.needsLayout = true
        
        return newLabel
    }
    
    func connectorLabelAtPoint(point: CGPoint) -> ConnectorLabel? {
        for label in connectorLabels {
            if label.frame.contains(point) {
                return label
            }
        }
        return nil
    }
    
    func constraintViewAtPoint(point: CGPoint) -> ConstraintView? {
        for view in constraintViews {
            if view.frame.contains(point) {
                return view
            }
        }
        return nil
    }
    
    func connectorPortAtLocation(location: CGPoint) -> (ConstraintView: ConstraintView, ConnectorPort: ConnectorPort)? {
        for constraintView in constraintViews {
            let point = constraintView.convert(location, from: self.scrollView)
            if let port = constraintView.connectorPortForDragAtLocation(location: point, connectorIsVisible: { self.connectorToLabel[$0] != nil}) {
                return (constraintView, port)
            }
        }
        return nil
    }
    
    func connectionLineAtPoint(point: CGPoint, distanceCutoff: CGFloat = 12.0) -> (ConnectorLabel: ConnectorLabel, ConstraintView: ConstraintView, ConnectorPort: ConnectorPort)? {
        // This is a hit-test to see if the user has tapped on a line between a connector and a connectorPort.
        let squaredDistanceCutoff = distanceCutoff * distanceCutoff
        
        var minSquaredDistance: CGFloat?
        var minMatch: (ConnectorLabel, ConstraintView, ConnectorPort)?
        for constraintView in constraintViews {
            for connectorPort in constraintView.connectorPorts() {
                if let connectorLabel = connectorToLabel[connectorPort.connector] {
                    let connectorPoint = self.scrollView.convert(connectorPort.center, from: constraintView)
                    let labelPoint = connectorLabel.center
                    
                    let squaredDistance = shortestDistanceSquaredToLineSegmentFromPoint(segmentStart: connectorPoint, segmentEnd: labelPoint, testPoint: point)
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
        
        return minMatch
    }
    
    func processStrokes() {
        let unprocessedStrokesCopy = self.unprocessedStrokes
        self.unprocessedStrokes.removeAll(keepingCapacity: false)
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            var allStrokes: DTWDigitClassifier.DigitStrokes = []
            for previousStroke in unprocessedStrokesCopy {
                allStrokes.append(previousStroke.points)
            }
            let classifiedLabels = self.digitClassifier.classifyMultipleDigits(strokes: allStrokes)
            
            dispatch_async(dispatch_get_main_queue()) {
                if let classifiedLabels = classifiedLabels {
                    // Find the bounding rect of all of the strokes
                    var topLeft: CGPoint?
                    var bottomRight: CGPoint?
                    for stroke in allStrokes {
                        for point in stroke {
                            if let capturedTopLeft = topLeft {
                                topLeft = CGPoint(x: min(capturedTopLeft.x, point.x), y: min(capturedTopLeft.y, point.y));
                            } else {
                                topLeft = point
                            }
                            if let capturedBottomRight = bottomRight {
                                bottomRight = CGPoint(x: max(capturedBottomRight.x, point.x), y: max(capturedBottomRight.y, point.y));
                            } else {
                                bottomRight = point
                            }
                        }
                    }
                    // Figure out where to put the new component
                    var centerPoint = self.scrollView.convert(self.view.center, from: self.view)
                    if let topLeft = topLeft {
                        if let bottomRight = bottomRight {
                            centerPoint = CGPoint(x: (topLeft.x + bottomRight.x) / 2.0, y: (topLeft.y + bottomRight.y) / 2.0)
                        }
                    }
                    
                    var combinedLabels = classifiedLabels.reduce("", combine: +)
                    var isPercent = false
                    if classifiedLabels.count > 1 && combinedLabels.hasSuffix("/") {
                        combinedLabels = combinedLabels.substring(to: combinedLabels.index(before: combinedLabels.endIndex))
                        isPercent = true
                    }
                    var writtenValue: Double?
                    if let writtenNumber = Int(combinedLabels) {
                        writtenValue = Double(writtenNumber)
                    } else if combinedLabels == "e" {
                        writtenValue = Double(M_E)
                    }
                    if writtenValue != nil && isPercent {
                        writtenValue = writtenValue! / 100.0
                    }
                    
                    if combinedLabels == "?" {
                        let newConnector = Connector()
                        let newLabel = ConnectorLabel(connector: newConnector)
                        newLabel.sizeToFit()
                        newLabel.center = centerPoint
                        
                        self.addConnectorLabel(label: newLabel, topPriority: false)
                        self.selectedConnectorLabel = newLabel
                        
                    } else if combinedLabels == "x" || combinedLabels == "/" {
                        // We recognized a multiply or divide!
                        let newMultiplier = Multiplier()
                        let newView = MultiplierView(multiplier: newMultiplier)
                        newView.layoutWithConnectorPositions(positions: [:])
                        newView.center = centerPoint
                        let inputs = newView.inputConnectorPorts()
                        let outputs = newView.outputConnectorPorts()
                        if combinedLabels == "x" {
                            self.addConstraintView(constraintView: newView, firstInputPort: inputs[0], secondInputPort: inputs[1], outputPort: outputs[0])
                        } else if combinedLabels == "/" {
                            newView.showInverseOperator = true
                            self.addConstraintView(constraintView: newView, firstInputPort: outputs[0], secondInputPort: inputs[0], outputPort: inputs[1])
                        } else {
                            self.addConstraintView(constraintView: newView, firstInputPort: nil, secondInputPort: nil, outputPort: nil)
                        }
                        
                    } else if combinedLabels == "+" || combinedLabels == "-" || combinedLabels == "1-" || combinedLabels == "-1" { // The last is a hack for a common misclassification
                        // We recognized an add or subtract!
                        let newAdder = Adder()
                        let newView = AdderView(adder: newAdder)
                        newView.layoutWithConnectorPositions(positions: [:])
                        newView.center = centerPoint
                        let inputs = newView.inputConnectorPorts()
                        let outputs = newView.outputConnectorPorts()
                        if combinedLabels == "+" || combinedLabels == "1-" || combinedLabels == "-1" {
                            let inputs = newView.inputConnectorPorts()
                            self.addConstraintView(constraintView: newView, firstInputPort: inputs[0], secondInputPort: inputs[1], outputPort: outputs[0])
                        } else if combinedLabels == "-" {
                            newView.showInverseOperator = true
                            self.addConstraintView(constraintView: newView, firstInputPort: outputs[0], secondInputPort: inputs[0], outputPort: inputs[1])
                        } else {
                            self.addConstraintView(constraintView: newView, firstInputPort: nil, secondInputPort: nil, outputPort: nil)
                        }
                        
                    } else if combinedLabels == "^" {
                        let newExponent = Exponent()
                        let newView = ExponentView(exponent: newExponent)
                        newView.layoutWithConnectorPositions(positions: [:])
                        newView.center = centerPoint
                        
                        self.addConstraintView(constraintView: newView, firstInputPort: newView.basePort, secondInputPort: newView.exponentPort, outputPort: newView.resultPort)
                        
                    } else if let writtenValue = writtenValue {
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
                            scale = self.defaultScaleForNewValue(value: writtenValue)
                        }
                        newLabel.scale = scale
                        
                        self.addConnectorLabel(label: newLabel, topPriority: true)
                        self.selectConnectorLabelAndSetToValue(connectorLabel: newLabel, value: writtenValue)
                        
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
    
    func numberSlideView(numberSlideView _: NumberSlideView, didSelectNewValue newValue: NSDecimalNumber, scale: Int16) {
        if let selectedConnectorLabel = self.selectedConnectorLabel {
            selectedConnectorLabel.scale = scale
            self.updateDisplay(values: [selectedConnectorLabel.connector : newValue.doubleValue], needsSolving: true, selectNewConnectorLabel: false)
        }
    }
    
    func numberSlideView(numberSlideView _: NumberSlideView, didSelectNewScale scale: Int16) {
        if let selectedConnectorLabel = self.selectedConnectorLabel {
            selectedConnectorLabel.scale = scale
            selectedConnectorLabel.displayValue(value: lastValueForConnector(connector: selectedConnectorLabel.connector))
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
            self.connectionLayers.removeAll(keepingCapacity: true)
            
            for constraintView in self.constraintViews {
                for connectorPort in constraintView.connectorPorts() {
                    if let connectorLabel = self.connectorToLabel[connectorPort.connector] {
                        let constraintPoint = self.scrollView.convert(connectorPort.center, from: constraintView)
                        let labelPoint = connectorLabel.center
                        
                        let lastInformant = self.lastInformantForConnector(connector: connectorLabel.connector)
                        let dependent = lastInformant?.WasDependent ?? false
                        
                        let startPoint: CGPoint
                        let endPoint: CGPoint
                        // If this contraintView was the informant, then the arrow goes from the constraint
                        // to the connector. Otherwise, it goes from the connector to the constraint
                        if lastInformant?.Informant == constraintView.constraint {
                            startPoint = constraintPoint
                            endPoint = labelPoint
                        } else {
                            startPoint = labelPoint
                            endPoint = constraintPoint
                        }
                        
                        let connectionLayer = self.createConnectionLayer(startPoint: startPoint, endPoint: endPoint, color: connectorPort.color, isDependent: dependent, drawArrow: lastInformant != nil)
                        
                        self.connectionLayers.append(connectionLayer)
                        connectionLayer.zPosition = self.connectionLayersZPosition
                        self.scrollView.layer.addSublayer(connectionLayer)
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
                constraintView.layoutWithConnectorPositions(positions: connectorPositions)
            }
            self.needsLayout = false
            self.needsRebuildConnectionLayers = true
        }
        
        func runSolver() {
            let lastSimulationValues = self.lastSimulationValues
            
            var connectorToSelect: ConnectorLabel?
            let simulationContext = SimulationContext(connectorResolvedCallback: { (connector, resolvedValue) -> Void in
                if self.connectorToLabel[connector] == nil {
                    if let constraint = resolvedValue.Informant {
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
                        newLabel.scale = self.defaultScaleForNewValue(value: resolvedValue.DoubleValue)
                        newLabel.sizeToFit()
                        
                        // Find the positions of the existing connectorLabels on this constraint
                        var connectorPositions: [Connector: CGPoint] = [:]
                        for existingConnector in connectTo.constraintView.connectorPorts().map({$0.connector}) {
                             if let existingLabel = self.connectorToLabel[existingConnector] {
                                connectorPositions[existingConnector] = existingLabel.center
                            }
                        }
                        
                        let angle = connectTo.constraintView.idealAngleForNewConnectorLabel(connector: connector, positions: connectorPositions)
                        let distance: CGFloat = 70 + max(connectTo.constraintView.bounds.width, connectTo.constraintView.bounds.height)
                        let newDisplacement = CGPoint(x: cos(angle), y: sin(angle)) * distance
                        
                        // Make sure the new point is somewhat on the screen
                        var newPoint = connectTo.constraintView.frame.center() + newDisplacement
                        let minMargin: CGFloat = 10
                        newPoint.x = max(newPoint.x, minMargin)
                        newPoint.x = min(newPoint.x, self.scrollView.contentSize.width - minMargin)
                        newPoint.y = max(newPoint.y, minMargin)
                        
                        newLabel.center = newPoint
                        newLabel.alpha = 0
                        self.addConnectorLabel(label: newLabel, topPriority: false, automaticallyConnect: false)
                        UIView.animate(withDuration: 0.5) {
                            newLabel.alpha = 1.0
                        }
                        connectorToSelect = newLabel
                        self.needsLayout = true
                    }
                }
                
                if let label = self.connectorToLabel[connector] {
                    label.displayValue(value: resolvedValue.DoubleValue)
                }
                if let lastValue = lastSimulationValues?[connector] {
                    if (lastValue.WasDependent != resolvedValue.WasDependent || lastValue.Informant != resolvedValue.Informant) {
                        self.needsRebuildConnectionLayers = true
                    }
                } else {
                    self.needsRebuildConnectionLayers = true
                }
                }, connectorConflictCallback: { (connector, resolvedValue) -> Void in
                    if let label = self.connectorToLabel[connector] {
                        label.hasError = true
                    }
            })
            
            // Reset all error states
            for label in self.connectorLabels {
                label.hasError = false
            }
            
            // TODO: Take the values of the selected toy here
            
            // First, the selected connector
            if let selectedConnector = self.selectedConnectorLabel?.connector {
                if let value = (values[selectedConnector] ?? lastSimulationValues?[selectedConnector]?.DoubleValue) {
                    simulationContext.setConnectorValue(connector: selectedConnector, value: (DoubleValue: value, Expression: constantExpression(number: value), WasDependent: true, Informant: nil))
                }
            }
            
            // These are the first priority
            for (connector, value) in values {
                simulationContext.setConnectorValue(connector: connector, value: (DoubleValue: value, Expression: constantExpression(number: value), WasDependent: false, Informant: nil))
            }
            
            // We loop through connectorLabels like this, because it can mutate during the simulation, if a constraint "resolves a port"
            var index = 0
            while index < self.connectorLabels.count {
                let connector = self.connectorLabels[index].connector
                
                // If we haven't already resolved this connector, then set it as a non-dependent variable to the value from the last simulation
                if simulationContext.connectorValues[connector] == nil {
                    if let lastValue = lastSimulationValues?[connector]?.DoubleValue {
                        simulationContext.setConnectorValue(connector: connector, value: (DoubleValue: lastValue, Expression: constantExpression(number: lastValue), WasDependent: false, Informant: nil))
                    }
                }
                index += 1
            }
            
            // Update the labels that still don't have a value
            for label in self.connectorLabels {
                if simulationContext.connectorValues[label.connector] == nil {
                    label.displayValue(value: nil)
                }
            }
            
            constraintLoop: for constraintView in self.constraintViews {
                if let constraintView = constraintView as? MultiInputOutputConstraintView {
                    // Check to see if this constraint resolved one of its inputs or outputs and update it
                    // accordingly
                    let constraint = constraintView.innerConstraint
                    for connector in constraint.inputs {
                        if simulationContext.connectorValues[connector]?.Informant == constraint {
                            constraintView.showInverseOperator = true
                            continue constraintLoop
                        }
                    }
                    for connector in constraint.outputs {
                        if simulationContext.connectorValues[connector]?.Informant == constraint {
                            constraintView.showInverseOperator = false
                            continue constraintLoop
                        }
                    }
                }
            }
            
            self.lastSimulationValues = simulationContext.connectorValues
            self.needsSolving = false
            
            if let connectorToSelect = connectorToSelect {
                if selectNewConnectorLabel {
                    self.selectedConnectorLabel = connectorToSelect
                }
            }
        }
        
        func updateToyAndGhosts(toy: Toy, lastSimulationValues: [Connector: SimulationContext.ResolvedValue]) {
            toy.update(values: lastSimulationValues)
            
            // Now, get the state needed to update the ghosts
            
            var inputConnectorStates: [Connector: ConnectorState] = [:]
            for inputConnector in toy.inputConnectors() {
                guard let inputConnectorLabel = self.connectorToLabel[inputConnector],
                    let initialValue = lastSimulationValues[inputConnector] else {
                        // Somehow this input connector isn't in our context. We've got to bail
                    return
                }
                inputConnectorStates[inputConnector] = ConnectorState(Value: initialValue, Scale: inputConnectorLabel.scale)
            }
            
            // Construct a list of all connectors in order of priority. It is okay to have duplicates
            // First the selected connector
            var allConnectors = [self.selectedConnectorLabel?.connector].flatMap({$0})
            // Then the ones from the values map
            allConnectors += values.map{ (connector, value) in
                return connector
            }
            // Then the ones from the last context
            allConnectors += self.connectorLabels.map{ connectorLabel in
                return connectorLabel.connector
            }
            // Filter out any of the output connectors, to make sure they are last priority
            let outputConnectors = toy.outputConnectors()
            allConnectors = allConnectors.filter({ connector -> Bool in
                return !outputConnectors.contains(connector)
            })
            allConnectors = allConnectors + outputConnectors
            
            
            toy.updateGhosts(inputStates: inputConnectorStates) { (inputValues: [Connector: Double]) -> [Connector : SimulationContext.ResolvedValue] in
                // The toy calls this each time it wants to know what the outputs end up being for a given input
                
                // Set up the context
                let simulationContext = SimulationContext(connectorResolvedCallback: { (_, _) in },
                    connectorConflictCallback: { (_, _) in })
                simulationContext.rewriteExpressions = false
                
                // First the new values on the inputs
                for (inputConnector, inputValue) in inputValues {
                    simulationContext.setConnectorValue(connector: inputConnector, value: (DoubleValue: inputValue, Expression: constantExpression(number: inputValue), WasDependent: false, Informant: nil))
                }
                
                // Go through all the connectors in order and fill in previous values until they are all resolved
                for connector in allConnectors {
                    if simulationContext.connectorValues[connector] != nil {
                        // This connector has already been resolved
                        continue
                    }
                    if let value = (values[connector] ?? lastSimulationValues[connector]?.DoubleValue) {
                        simulationContext.setConnectorValue(connector: connector, value: (DoubleValue: value, Expression: constantExpression(number: value), WasDependent: true, Informant: nil))
                    }
                }
                
                return simulationContext.connectorValues
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
                runSolver()
                ranSolver = true
            }
        }
        
        if (self.needsRebuildConnectionLayers) {
            rebuildAllConnectionLayers()
        }
        

        if let lastSimulationValues = self.lastSimulationValues where ranSolver {
            for toy in self.toys {
                updateToyAndGhosts(toy: toy, lastSimulationValues: lastSimulationValues)
            }
            
            // We first make a map from value DDExpressions to the formatted value
            var formattedValues: [DDExpression : String] = [:]
            for label in self.connectorLabels {
                if let value = lastSimulationValues[label.connector] {
                    if value.Expression.expressionType() == .number {
                        formattedValues[value.Expression] = label.name ?? label.valueLabel.text
                    }
                }
            }
            
            for label in self.connectorLabels {
                var displayedEquation = false
                if let value = lastSimulationValues[label.connector] {
                    if value.Expression.expressionType() == .function {
                        if let mathML = mathMLForExpression(expression: value.Expression, formattedValues: formattedValues) {
                            label.displayEquation(mathML: mathML)
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
    
    func createConnectionLayer(startPoint: CGPoint, endPoint: CGPoint, color: UIColor?, isDependent: Bool, drawArrow: Bool) -> CAShapeLayer {
        let dragLine = CAShapeLayer()
        dragLine.lineWidth = 3
        dragLine.fillColor = nil
        dragLine.lineCap = kCALineCapRound
        dragLine.strokeColor = color?.cgColor ?? UIColor.textColor().cgColor
        
        dragLine.path = createPointingLine(startPoint: startPoint, endPoint: endPoint, dash: isDependent, arrowHead: drawArrow)
        return dragLine
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil, completion: { context in
            self.updateScrollableSize()
        })
    }
    
    func updateScrollableSize() {
        var maxY: CGFloat = 0
        var maxX: CGFloat = self.view.bounds.width
        for view in connectorLabels {
            maxY = max(maxY, view.frame.maxY)
            maxX = max(maxX, view.frame.maxX)
        }
        for view in constraintViews {
            maxY = max(maxY, view.frame.maxY)
            maxX = max(maxX, view.frame.maxX)
        }
        
        self.scrollView.contentSize = CGSize(width: maxX, height: maxY + self.view.bounds.height)
    }
    
    var toys: [Toy] = []
    
    func connectorIsForToy(connector: Connector) -> Bool {
        for toy in self.toys {
            if toy.outputConnectors().contains(connector) || toy.inputConnectors().contains(connector) {
                return true
            }
        }
        return false
    }
    
    var nameCanvas: NameCanvasViewController?
    
    func showNameCanvas() {
        let canvasViewController = NameCanvasViewController()
        self.nameCanvas = canvasViewController
        canvasViewController.delegate = self;
        
        canvasViewController.transitioningDelegate = self
        canvasViewController.modalPresentationStyle = .custom
        
        self.present(canvasViewController, animated: true, completion: nil)
    }
    
    func nameCanvasViewControllerDidFinish(nameCanvasViewController: NameCanvasViewController) {
        guard let canvasViewController = self.nameCanvas where canvasViewController == nameCanvasViewController else {
            return
        }
        
        if let selectedConnectorLabel = self.selectedConnectorLabel {
            let scale = UIScreen.main().scale
            let height = selectedConnectorLabel.valueLabel.frame.size.height
            
            if let nameImage = canvasViewController.renderedImage(pointHeight: height, scale: scale, color: UIColor.textColor().cgColor),
                let selectedNameImage = canvasViewController.renderedImage(pointHeight: height, scale: scale, color: UIColor.selectedTextColor().cgColor) {
                    
                    selectedConnectorLabel.nameImages = (image: nameImage, selectedImage: selectedNameImage)
            } else {
                selectedConnectorLabel.nameImages = nil
            }
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    
    func animationController(forPresentedController presented: UIViewController, presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        let animator = NameCanvasAnimator()
        animator.presenting = true
        return animator
    }
    
    func animationController(forDismissedController dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return NameCanvasAnimator()
    }
}

