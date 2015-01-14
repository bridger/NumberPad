//
//  ConstraintViews.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 1/12/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import UIKit

// Views that contain and draw Connector, Adder, or Multiplier. Their center stays the same, but otherwise they can rotate and resize to fit

class ConnectorLabel: UILabel {
    var scale: Double = 1
    let connector: Connector

    init(connector: Connector) {
        self.connector = connector
        super.init(frame: CGRectZero)
        connectorLabelInitialize()
    }
    
    required init(coder aDecoder: NSCoder) {
        self.connector = Connector(constant: 3)
        super.init(coder: aDecoder)
        connectorLabelInitialize()
    }
    
    private func connectorLabelInitialize() {
        self.font = UIFont.boldSystemFontOfSize(22)
        self.layer.borderWidth = 3
        self.textAlignment = .Center
        
        connector.addObserver { [unowned self] value in
            
            var color: UIColor = UIColor.blackColor()
            if let value = value {
                if abs(value) < 2 {
                    self.text = String(format: "%.3f", value)
                } else if abs(value) < 100 {
                    self.text = String(format: "%.1f", value)
                } else {
                    self.text = String(format: "%.f", value)
                }
            } else {
                self.text = "?"
                color = UIColor.redColor()
            }
            self.layer.borderColor = color.CGColor
            self.textColor = color
            
            self.sizeToFit()
        }
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        var newSize = super.sizeThatFits(size)
        newSize.width += 15.0
        newSize.height += 15.0
        return newSize
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
}

protocol ConstraintViewDelegate: NSObjectProtocol {
    func constraintView(constraintView: ConstraintView, didResolveConnectorPort connectorPort: ConnectorPort)
}

class ConstraintView: UIView {
    weak var delegate: ConstraintViewDelegate?
    
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
    
    private func addSentinelConnectorToPort(connectorPort: InternalConnectorPort) {
        let connector = Connector()
        var hasResolvedAtLeastOnce = false
        connector.addObserver { [weak self, weak connectorPort] value in
            if value != nil && !hasResolvedAtLeastOnce {
                if let delegate = self?.delegate {
                    if let connectorPort = connectorPort {
                        hasResolvedAtLeastOnce = true
                        delegate.constraintView(self!, didResolveConnectorPort: connectorPort)
                    }
                }
            }
        }
        self.connectPort(connectorPort, connector: connector)
    }
}

class MultiplierView: ConstraintView {
    let multiplier: Multiplier
    
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
                        multiplier.removeOutput(oldConnector)
                    } else {
                        multiplier.removeInput(oldConnector)
                    }
                }
                
                if internalPort.isOutput {
                    multiplier.addOutput(connector)
                } else {
                    multiplier.addInput(connector)
                }
                internalPort.connector = connector
                
                return
            }
        }
    }
    
    init(multiplier: Multiplier) {
        self.multiplier = multiplier
        super.init(frame: CGRectZero)
        multiplierViewInitialize()
    }

    required override init(coder aDecoder: NSCoder) {
        self.multiplier = Multiplier()
        super.init(coder: aDecoder)
        multiplierViewInitialize()
    }
    
    private func multiplierViewInitialize() {
        self.backgroundColor = UIColor.purpleColor().colorWithAlphaComponent(0.5)
        self.layer.cornerRadius = 5
        self.layer.addSublayer(self.redInput.layer)
        self.layer.addSublayer(self.blueInput.layer)
        self.layer.addSublayer(self.purpleOutput.layer)
        addSentinelConnectorToPort(self.redInput)
        addSentinelConnectorToPort(self.blueInput)
        addSentinelConnectorToPort(self.purpleOutput)
    }
    
    let mySize: CGFloat = 45.0
    override func layoutWithConnectorPositions(positions: [Connector: CGPoint]) {
        self.sizeToFit()
        self.redInput.layer.position = CGPointMake(0, mySize / 2.0)
        self.blueInput.layer.position = CGPointMake(mySize / 2.0, 0)
        self.purpleOutput.layer.position = CGPointMake(mySize, mySize)
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(mySize, mySize)
    }
}

