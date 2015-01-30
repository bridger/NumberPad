//
//  Constraints.swift
//  Numbers
//
//  Created by Bridger Maxwell on 10/17/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import Foundation

class SimulationContext {
    typealias ResolvedValue = (DoubleValue: Double, WasDependent: Bool)
    var connectorValues: [Connector: ResolvedValue] = [:]
    
    let connectorResolvedCallback: (Connector, ResolvedValue, Constraint?) -> Void
    let connectorConflictCallback: (Connector, ResolvedValue, Constraint?) -> Void
    
    func setConnectorValue(connector: Connector, value: ResolvedValue, informant: Constraint?) {
        if let existingValue = connectorValues[connector] {
            if existingValue.DoubleValue != value.DoubleValue {
                println("Something went wrong. Value changed from \(existingValue.DoubleValue) not equal to outputs \(value.DoubleValue)")
                self.connectorConflictCallback(connector, value, informant)
            }
        } else {
            connectorValues[connector] = value
            connectorResolvedCallback(connector, value, informant)
            for constraint in connector.constraints {
                if constraint != informant {
                    constraint.processNewValues(self)
                }
            }
        }
    }
    
    init(connectorResolvedCallback: (Connector, ResolvedValue, Constraint?) -> Void, connectorConflictCallback: (Connector, ResolvedValue, Constraint?) -> Void) {
        self.connectorResolvedCallback = connectorResolvedCallback
        self.connectorConflictCallback = connectorConflictCallback
    }
}


class Constraint {
    func processNewValues(context: SimulationContext) {}
}

extension Constraint: Hashable {
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}
// Equatable
func ==(lhs: Constraint, rhs: Constraint) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}

class MultiInputOutputConstraint : Constraint {
    var inputs: [Connector] = []
    var outputs: [Connector] = []
    
    init(inputs: [Connector], outputs: [Connector]) {
        super.init()
        
        for input in inputs {
            addInput(input)
        }
        for output in outputs {
            addOutput(output)
        }
    }
    
    convenience override init() {
        self.init(inputs: [], outputs: [])
    }
    
    func addInput(connector: Connector) {
        inputs.append(connector)
        connector.connect(self)
    }
    func removeInput(connector: Connector) {
        if let index = find(inputs, connector) {
            inputs.removeAtIndex(index)
            connector.disconnect(self)
        } else {
            println("Unable to remove connector!")
        }
    }
    func addOutput(connector: Connector) {
        outputs.append(connector)
        connector.connect(self)
    }
    func removeOutput(connector: Connector) {
        if let index = find(outputs, connector) {
            outputs.removeAtIndex(index)
            connector.disconnect(self)
        } else {
            println("Unable to remove connector!")
        }
    }
}


class Connector {
    var constraints: [Constraint] = []
    
    func connect(constraint: Constraint) {
        constraints.append(constraint)
    }
    func disconnect(constraint: Constraint) {
        if let index = find(constraints, constraint) {
            constraints.removeAtIndex(index)
        } else {
            println("Unable to remove constraint")
        }
    }
}

extension Connector: Hashable {
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}
// Equatable
func ==(lhs: Connector, rhs: Connector) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}


class Adder : MultiInputOutputConstraint {
    
    override func processNewValues(context: SimulationContext) {
        var noValueInputs: [Connector] = []
        var noValueOutputs: [Connector] = []
        var inputsAdded: Double = 0
        var outputsAdded: Double = 0
        var anyValueWasDependent = false
        
        for connector in inputs {
            if let value = context.connectorValues[connector] {
                inputsAdded += value.DoubleValue;
                anyValueWasDependent = anyValueWasDependent || value.WasDependent
            } else {
                noValueInputs.append(connector)
            }
        }
        for connector in outputs {
            if let value = context.connectorValues[connector] {
                outputsAdded += value.DoubleValue;
                anyValueWasDependent = anyValueWasDependent || value.WasDependent
            } else {
                noValueOutputs.append(connector)
            }
        }
        
        if noValueOutputs.count == 1 && noValueInputs.count == 0 {
            // A + B + C = D + E + F. We know all except D
            // D = (A + B + C) - (E + F)
            if inputs.count > 0 {
                let value = (inputsAdded - outputsAdded, anyValueWasDependent)
                context.setConnectorValue(noValueOutputs[0], value: value, informant: self)
            }
        } else if noValueOutputs.count == 0 && noValueInputs.count == 1 {
            // A + B + C = D + E + F. We know all except A
            // A = (D + E + F) - (B + C)
            if outputs.count > 0 {
                let value = (outputsAdded - inputsAdded, anyValueWasDependent)
                context.setConnectorValue(noValueInputs[0], value: value, informant: self)
            }
        } else if noValueInputs.count == 0 && noValueOutputs.count == 0 {
            
            if outputsAdded != inputsAdded {
                println("Something went wrong in adder. Inputs \(inputsAdded) not equal to outputs \(outputsAdded)");
            }
        }
    }
}

class Multiplier : MultiInputOutputConstraint {
    
    override func processNewValues(context: SimulationContext) {
        var noValueInputs: [Connector] = []
        var noValueOutputs: [Connector] = []
        var inputsMultiplied: Double = 1
        var outputsMultiplied: Double = 1
        // We keep track if we saw any zero input or output, and whether it was dependent
        var zeroInputWasDependent: Bool?
        var zeroOutputWasDependent: Bool?
        var anyValueWasDependent = false
        
        // A * B * C = D * E * F
        
        for connector in inputs {
            if let value = context.connectorValues[connector] {
                inputsMultiplied *= value.DoubleValue
                if value.DoubleValue == 0 {
                    zeroInputWasDependent = value.WasDependent
                }
                anyValueWasDependent = anyValueWasDependent || value.WasDependent
            } else {
                noValueInputs.append(connector)
            }
        }
        for connector in outputs {
            if let value = context.connectorValues[connector] {
                outputsMultiplied *= value.DoubleValue;
                if value.DoubleValue == 0 {
                    zeroOutputWasDependent = value.WasDependent
                }
                anyValueWasDependent = anyValueWasDependent || value.WasDependent
            } else {
                noValueOutputs.append(connector)
            }
        }
        
        if zeroInputWasDependent != nil && zeroOutputWasDependent == nil && noValueOutputs.count == 1 {
            // If one of the inputs was 0, and we know all of the outputs except 1 and none of them were zero, then the last output must be zero
            // A * B * 0 = D * E * F. We know all outputs except F, and they are nonzero
            // F = 0
            context.setConnectorValue(noValueOutputs[0], value: (0, zeroInputWasDependent!), informant: self)
            
        } else if zeroOutputWasDependent != nil && zeroOutputWasDependent == nil && noValueInputs.count == 1 {
            // If one of the outputs was 0, and we know all of the inputs except 1 and none of them were zero, then the last input must be zero
            // A * B * C = D * E * 0. We know all inputs except A, and they are nonzero
            // A = 0
            context.setConnectorValue(noValueInputs[0], value: (0, zeroOutputWasDependent!), informant: self)
            
        } else if noValueOutputs.count == 1 && noValueInputs.count == 0 {
            // A * B * C = D * E * F. We know all except D
            // D = (A * B * C) / (E * F)
            if inputs.count > 0 {
                let value = (inputsMultiplied / outputsMultiplied, anyValueWasDependent)
                context.setConnectorValue(noValueOutputs[0], value: value, informant: self)
            }
        } else if noValueOutputs.count == 0 && noValueInputs.count == 1 {
            // A * B * C = D * E * F. We know all except A
            // A = (D * E * F) / (B * C)
            if outputs.count > 0 {
                let value = (outputsMultiplied / inputsMultiplied, anyValueWasDependent)
                context.setConnectorValue(noValueInputs[0], value: value, informant: self)
            }
            
        } else if noValueInputs.count == 0 && noValueOutputs.count == 0 {
            
            if outputsMultiplied != inputsMultiplied {
                println("Something went wrong in multiplier. Inputs \(inputsMultiplied) not equal to outputs \(outputsMultiplied)");
            }
        }
    }
}

class Exponent : Constraint {
    // result = base ^ exponent
    // exponent = log_base(result) = ln(result) / ln(base)
    // base = result ^ (1/exponent)
    
    var base: Connector! {
        didSet {
            if let oldValue = oldValue {
                oldValue.disconnect(self)
            }
            self.base.connect(self)
        }
    }
    var exponent: Connector! {
        didSet {
            if let oldValue = oldValue {
                oldValue.disconnect(self)
            }
            self.exponent.connect(self)
        }
    }
    var result: Connector! {
        didSet {
            if let oldValue = oldValue {
                oldValue.disconnect(self)
            }
            self.result.connect(self)
        }
    }
    
    // Before this is called, we must have all three connectors present
    override func processNewValues(context: SimulationContext) {
        let resultValue = context.connectorValues[result]
        let exponentValue = context.connectorValues[exponent]
        let baseValue = context.connectorValues[base]
        
        
        if resultValue == nil {
            // result = base ^ exponent
            
            if exponentValue != nil && exponentValue!.DoubleValue == 0 {
                // If exponent is 0, then result is 1 (unless base is also zero)
                if baseValue != nil && baseValue!.DoubleValue == 0 {
                    print("Unable to determine result if exponent and base are 0")
                } else {
                    let value = (1.0, exponentValue!.WasDependent)
                    context.setConnectorValue(result, value: value, informant: self)
                }
                
            } else if baseValue != nil && baseValue!.DoubleValue == 0 {
                // If base is 0, then result is 0 (unless exponent is also zero)
                let value = (0.0, baseValue!.WasDependent)
                context.setConnectorValue(result, value: value, informant: self)
                
            } else if baseValue != nil && exponentValue != nil {
                //result = base ^ exponent
                let doubleValue = pow(baseValue!.DoubleValue, exponentValue!.DoubleValue)
                let isDependent = baseValue!.WasDependent || exponentValue!.WasDependent
                context.setConnectorValue(result, value: (doubleValue, isDependent), informant: self)
            }
            
        } else {
            
            // TODO: If result = 1 then exponent = 0, regardless of base
            
            if baseValue == nil && exponentValue != nil {
                // base = result ^ (1/exponent)
                let doubleValue = pow(resultValue!.DoubleValue, 1.0 / exponentValue!.DoubleValue)
                let isDependent = resultValue!.WasDependent || exponentValue!.WasDependent
                context.setConnectorValue(base, value: (doubleValue, isDependent), informant: self)
                
            } else if baseValue != nil && exponentValue == nil {
                // exponent = log_base(result) = ln(result) / ln(base)
                let doubleValue = log(resultValue!.DoubleValue) / log(baseValue!.DoubleValue)
                let isDependent = resultValue!.WasDependent || baseValue!.WasDependent
                context.setConnectorValue(exponent, value: (doubleValue, isDependent), informant: self)
                
            } else if baseValue != nil && exponentValue != nil {
                // Sanity check
                
                let predictedValue = pow(baseValue!.DoubleValue, exponentValue!.DoubleValue)
                let value = resultValue!.DoubleValue
                if predictedValue != value {
                    println("Something went wrong in exponent. Result \(value) is not equal to \(predictedValue)")
                }
            }
        }
    }
}
