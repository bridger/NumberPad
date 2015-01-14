//
//  Constraints.swift
//  Numbers
//
//  Created by Bridger Maxwell on 10/17/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import Foundation

class Constraint {
    func processNewValues() {}
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


typealias ValueObserverBlock = Double? -> Void;

class ValueObserver : Constraint {
    
    var input: Connector
    
    let observeBlock: ValueObserverBlock;
    
    init(input: Connector, observeBlock: ValueObserverBlock) {
        self.observeBlock = observeBlock
        self.input = input
        super.init()
        input.connect(self)
    }
    
    override func processNewValues() {
        observeBlock(input.value)
    }
}

class Connector {
    var value: Double?
    
    var constraints: [Constraint] = []
    
    init() {
    }
    
    init(constant: Double) {
        let constantConstraint = Constant(value: constant, outputs: [self])
    }
    
    func addObserver(observer: ValueObserverBlock) -> ValueObserver {
        let internalObserver = ValueObserver(input: self, observeBlock: observer)
        return internalObserver
    }
    
    func addProbe(name: String) -> Probe {
        let internalProbe = Probe(input: self, name: name)
        return internalProbe
    }
    
    func connect(constraint: Constraint) {
        constraints.append(constraint)
        constraint.processNewValues()
    }
    func disconnect(constraint: Constraint) {
        if let index = find(constraints, constraint) {
            constraints.removeAtIndex(index)
        } else {
            println("Unable to remove constraint")
        }
    }
    
    func setValue(newValue: Double, informant: Constraint?) {
        if let value = self.value {
            if value != newValue {
                println("Something went wrong. Value changed from \(value) not equal to outputs \(newValue)");
            }
        } else {
            self.value = newValue
            for constraint in constraints {
                if constraint !== informant {
                    constraint.processNewValues()
                }
            }
        }
    }
    
    func forgetValue() {
        self.value = nil
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
    
    override func processNewValues() {
        var noValueInputs: [Connector] = []
        var noValueOutputs: [Connector] = []
        var inputsAdded: Double = 0
        var outputsAdded: Double = 0
        
        for connector in inputs {
            if let value = connector.value {
                inputsAdded += value;
            } else {
                noValueInputs.append(connector)
            }
        }
        for connector in outputs {
            if let value = connector.value {
                outputsAdded += value;
            } else {
                noValueOutputs.append(connector)
            }
        }
        
        if noValueOutputs.count == 1 && noValueInputs.count == 0 {
            // A + B + C = D + E + F. We know all except D
            // D = (A + B + C) - (E + F)
            noValueOutputs[0].setValue(inputsAdded - outputsAdded, informant: self);
        } else if noValueOutputs.count == 0 && noValueInputs.count == 1 {
            // A + B + C = D + E + F. We know all except A
            // A = (D + E + F) - (B + C)
            
            noValueInputs[0].setValue(outputsAdded - inputsAdded, informant: self);
        } else if noValueInputs.count == 0 && noValueOutputs.count == 0 {
            
            if outputsAdded != inputsAdded {
                println("Something went wrong in adder. Inputs \(inputsAdded) not equal to outputs \(outputsAdded)");
            }
        }
    }
}

class Multiplier : MultiInputOutputConstraint {
    
    override func processNewValues() {
        var noValueInputs: [Connector] = []
        var noValueOutputs: [Connector] = []
        var inputsMultiplied: Double = 1
        var outputsMultiplied: Double = 1
        var inputWasZero = false
        var outputWasZero = false
        
        // A * B * C = D * E * F
        
        for connector in inputs {
            if let value = connector.value {
                inputsMultiplied *= value;
                if value == 0 {
                    inputWasZero = true
                }
            } else {
                noValueInputs.append(connector)
            }
        }
        for connector in outputs {
            if let value = connector.value {
                outputsMultiplied *= value;
                if value == 0 {
                    outputWasZero = true
                }
            } else {
                noValueOutputs.append(connector)
            }
        }
        
        if inputWasZero && !outputWasZero && noValueOutputs.count == 1 {
            // If one of the inputs was 0, and we know all of the outputs except 1 and none of them were zero, then the last output must be zero
            // A * B * 0 = D * E * F. We know all outputs except F, and they are nonzero
            // F = 0
            noValueOutputs[0].setValue(0, informant: self)
            
        } else if outputWasZero && !inputWasZero && noValueInputs.count == 1 {
            // If one of the outputs was 0, and we know all of the inputs except 1 and none of them were zero, then the last input must be zero
            // A * B * C = D * E * 0. We know all inputs except A, and they are nonzero
            // A = 0
            noValueInputs[0].setValue(0, informant: self)
            
        } else if noValueOutputs.count == 1 && noValueInputs.count == 0 {
            // A * B * C = D * E * F. We know all except D
            // D = (A * B * C) / (E * F)
            if inputs.count > 0 {
                noValueOutputs[0].setValue(inputsMultiplied / outputsMultiplied, informant: self)
            }
        } else if noValueOutputs.count == 0 && noValueInputs.count == 1 {
            // A * B * C = D * E * F. We know all except A
            // A = (D * E * F) / (B * C)
            if outputs.count > 0 {
                noValueInputs[0].setValue(outputsMultiplied / inputsMultiplied, informant: self)

            }
            
        } else if noValueInputs.count == 0 && noValueOutputs.count == 0 {
            
            if outputsMultiplied != inputsMultiplied {
                println("Something went wrong in multiplier. Inputs \(inputsMultiplied) not equal to outputs \(outputsMultiplied)");
            }
        }
    }
}

class Exponent : Constraint {
    
    var base: Connector
    var exponent: Connector
    var result: Connector
    
    
    // result = base ^ exponent
    // exponent = log_base(result) = ln(result) / ln(base)
    // base = result ^ (1/exponent)
    init(base: Connector, exponent: Connector, result: Connector) {
        self.base = base
        self.exponent = exponent
        self.result = result
        
        super.init()
        
        self.base.connect(self)
        self.exponent.connect(self)
        self.result.connect(self)
    }
    
    
    override func processNewValues() {
        
        if result.value == nil {
            // result = base ^ exponent
            
            if exponent.value != nil && exponent.value! == 0 {
                // If exponent is 0, then result is 1 (unless base is also zero)
                if base.value != nil && base.value! == 0 {
                    print("Unable to determine result if exponent and base are 0")
                } else {
                    result.setValue(1, informant: self)
                }
                
            } else if base.value != nil && base.value! == 0 {
                // If base is 0, then result is 0 (unless exponent is also zero)
                result.setValue(0, informant: self)
                
            } else if base.value != nil && exponent.value != nil {
                //result = base ^ exponent
                result.setValue(pow(base.value!, exponent.value!), informant: self)
            }
            
        } else {
            
            // TODO: If result = 1 then exponent = 0, regardless of base
            
            if base.value == nil && exponent.value != nil {
                // base = result ^ (1/exponent)
                base.setValue( pow(result.value!, 1.0 / exponent.value!), informant: self)
                
            } else if base.value != nil && exponent.value == nil {
                // exponent = log_base(result) = ln(result) / ln(base)
                exponent.setValue( log(result.value!) / log(base.value!) , informant: self)
                
            } else if base.value != nil && exponent.value != nil {
                // Sanity check
                
                let predictedValue = pow(base.value!, exponent.value!)
                let value = result.value!
                if predictedValue != value {
                    println("Something went wrong in exponent. Result \(value) is not equal to \(predictedValue)")
                }
            }
        }
    }
}

class Constant : Constraint {
    let value: Double
    
    var outputs: [Connector] = []
    
    init(value: Double, outputs: [Connector]) {
        self.value = value
        super.init()
        
        for output in outputs {
            addOutput(output)
        }
    }
    
    func addOutput(connector: Connector) {
        outputs.append(connector)
        connector.connect(self)
        connector.setValue(self.value, informant: self)
    }
    
    override func processNewValues() {
        println("A constant cannot process new values")
    }
}

class Probe : ValueObserver {
    let name: String
    
    init(input: Connector, name: String) {
        self.name = name
        super.init(input: input, observeBlock: { value in
            if let value = value {
                println("Probe \(name) is now \(value)")
            } else {
                println("Probe \(name) has forgotten its value")
            }
            
        })
    }
}

