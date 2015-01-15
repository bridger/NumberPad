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
        
        weak var weakSelf = self
        connector.addObserver{ value in
            if let strongSelf = weakSelf {
                strongSelf.updateToValue()
            }
        }
        self.updateToValue()
    }
    
    func updateToValue() {
        let value = self.connector.value
        
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
    func removeConnectorAtPort(port: ConnectorPort) {
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
    
    override func removeConnectorAtPort(port: ConnectorPort) {
        for internalPort in internalConnectorPorts() {
            if internalPort === port {
                addSentinelConnectorToPort(internalPort) // This will remove the old connector
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
    
    let redLayer: CALayer = CALayer()
    let blueLayer: CALayer = CALayer()
    let purpleLayer: CALayer = CALayer()
    private func multiplierViewInitialize() {
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
        
        self.redInput.layer.position = CGPointMake(barSize / 2.0, purpleSquareSize / 2.0 + marginSpace)
        self.blueInput.layer.position = CGPointMake(purpleSquareSize / 2.0 + marginSpace, barSize / 2.0)
        self.purpleOutput.layer.position = CGPointMake(mySize, mySize)
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(mySize, mySize)
    }
}


class AdderView: ConstraintView {
    let adder: Adder
    
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
                        adder.removeOutput(oldConnector)
                    } else {
                        adder.removeInput(oldConnector)
                    }
                }
                
                if internalPort.isOutput {
                    adder.addOutput(connector)
                } else {
                    adder.addInput(connector)
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

    init(adder: Adder) {
        self.adder = adder
        super.init(frame: CGRectZero)
        multiplierViewInitialize()
    }
    
    required override init(coder aDecoder: NSCoder) {
        self.adder = Adder()
        super.init(coder: aDecoder)
        multiplierViewInitialize()
    }
    
    let redLayer: CALayer = CALayer()
    let blueLayer: CALayer = CALayer()
    let purpleLayer: CALayer = CALayer()
    private func multiplierViewInitialize() {
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
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(myWidth, barHeight * 2 + spacing)
    }
}

