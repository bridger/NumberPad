//
//  Constraints.swift
//  Numbers
//
//  Created by Bridger Maxwell on 10/17/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import Foundation

class SimulationContext {
    typealias ResolvedValue = (DoubleValue: Double, Expression: DDExpression, WasDependent: Bool)
    var connectorValues: [Connector: ResolvedValue] = [:]
    
    let connectorResolvedCallback: (Connector, ResolvedValue, Constraint?) -> Void
    let connectorConflictCallback: (Connector, ResolvedValue, Constraint?) -> Void
    
    let mathEvaluator = DDMathEvaluator()
    
    func setConnectorValue(connector: Connector, value: ResolvedValue, informant: Constraint?) {
        if let existingValue = connectorValues[connector] {
            if existingValue.DoubleValue != value.DoubleValue {
                println("Something went wrong. Value changed from \(existingValue.DoubleValue) not equal to outputs \(value.DoubleValue)")
                self.connectorConflictCallback(connector, value, informant)
            }
        } else {
            var rewrittenValue = value
            if let rewrittenExpression = DDExpressionRewriter.defaultRewriter().expressionByRewritingExpression(value.Expression, withEvaluator: mathEvaluator) {
                rewrittenValue = (value.DoubleValue, rewrittenExpression, value.WasDependent)
            } else {
                println("Error rewriting expression \(value.Expression)")
            }
            connectorValues[connector] = rewrittenValue
            connectorResolvedCallback(connector, rewrittenValue, informant)
            for constraint in connector.constraints {
                if constraint != informant {
                    if !constraint.processNewValues(self) {
                        self.connectorConflictCallback(connector, rewrittenValue, informant)
                    }
                }
            }
        }
    }
    
    init(connectorResolvedCallback: (Connector, ResolvedValue, Constraint?) -> Void, connectorConflictCallback: (Connector, ResolvedValue, Constraint?) -> Void) {
        self.connectorResolvedCallback = connectorResolvedCallback
        self.connectorConflictCallback = connectorConflictCallback
    }
}

func functionExpression(functionName: String, arguments: [DDExpression]) -> DDExpression {
    var error: NSError? = nil
    let result = DDExpression.functionExpressionWithFunction(functionName, arguments: arguments, error: &error)
    if result == nil {
        fatalError("Unable to make function expression \(functionName). Error \(error)");
    } else {
        return result!
    }
}

func constantExpression(number: Double) -> DDExpression {
    return DDExpression.numberExpressionWithNumber(number)!
}

class Constraint {
    func processNewValues(context: SimulationContext) -> Bool { return true }
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
    
    override func processNewValues(context: SimulationContext) -> Bool {
        var noValueInputs: [Connector] = []
        var noValueOutputs: [Connector] = []
        var inputsAdded: Double = 0
        var outputsAdded: Double = 0
        var anyValueWasDependent = false
        
        var inputsExpression: DDExpression?
        var outputsExpression: DDExpression?
        
        for connector in inputs {
            if let value = context.connectorValues[connector] {
                inputsAdded += value.DoubleValue;
                anyValueWasDependent = anyValueWasDependent || value.WasDependent
                
                if inputsExpression != nil {
                    inputsExpression = functionExpression(DDMathOperatorAdd, [inputsExpression!, value.Expression])
                } else {
                    inputsExpression = value.Expression
                }
            } else {
                noValueInputs.append(connector)
            }
        }
        for connector in outputs {
            if let value = context.connectorValues[connector] {
                outputsAdded += value.DoubleValue;
                anyValueWasDependent = anyValueWasDependent || value.WasDependent
                
                if outputsExpression != nil {
                    outputsExpression = functionExpression(DDMathOperatorAdd, [outputsExpression!, value.Expression])
                } else {
                    outputsExpression = value.Expression
                }
            } else {
                noValueOutputs.append(connector)
            }
        }
        
        if noValueOutputs.count == 1 && noValueInputs.count == 0 {
            // A + B + C = D + E + F. We know all except D
            // D = (A + B + C) - (E + F)
            if inputs.count > 0 {
                let expression = (outputsExpression != nil
                    ? functionExpression(DDMathOperatorMinus, [inputsExpression!, outputsExpression!])
                    : inputsExpression!)
                let value = (inputsAdded - outputsAdded, expression, anyValueWasDependent)
                context.setConnectorValue(noValueOutputs[0], value: value, informant: self)
            }
        } else if noValueOutputs.count == 0 && noValueInputs.count == 1 {
            // A + B + C = D + E + F. We know all except A
            // A = (D + E + F) - (B + C)
            if outputs.count > 0 {
                let expression = (inputsExpression != nil
                    ? functionExpression(DDMathOperatorMinus, [outputsExpression!, inputsExpression!])
                    : outputsExpression!)
                let value = (outputsAdded - inputsAdded, expression, anyValueWasDependent)
                context.setConnectorValue(noValueInputs[0], value: value, informant: self)
            }
        } else if noValueInputs.count == 0 && noValueOutputs.count == 0 {
            
            if outputsAdded != inputsAdded {
                println("Something went wrong in adder. Inputs \(inputsAdded) not equal to outputs \(outputsAdded)");
                return false
            }
        }
        return true
    }
}

class Multiplier : MultiInputOutputConstraint {
    
    override func processNewValues(context: SimulationContext) -> Bool {
        var noValueInputs: [Connector] = []
        var noValueOutputs: [Connector] = []
        var inputsMultiplied: Double = 1
        var outputsMultiplied: Double = 1
        // We keep track if we saw any zero input or output, and whether it was dependent
        var zeroInputWasDependent: Bool?
        var zeroOutputWasDependent: Bool?
        var anyValueWasDependent = false
        
        var inputsExpression: DDExpression?
        var outputsExpression: DDExpression?
        
        // A * B * C = D * E * F
        
        for connector in inputs {
            if let value = context.connectorValues[connector] {
                inputsMultiplied *= value.DoubleValue
                if value.DoubleValue == 0 {
                    zeroInputWasDependent = value.WasDependent
                }
                anyValueWasDependent = anyValueWasDependent || value.WasDependent
                
                if inputsExpression != nil {
                    inputsExpression = functionExpression(DDMathOperatorMultiply, [inputsExpression!, value.Expression])
                } else {
                    inputsExpression = value.Expression
                }
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
                
                if outputsExpression != nil {
                    outputsExpression = functionExpression(DDMathOperatorMultiply, [outputsExpression!, value.Expression])
                } else {
                    outputsExpression = value.Expression
                }
            } else {
                noValueOutputs.append(connector)
            }
        }
        
        if zeroInputWasDependent != nil && zeroOutputWasDependent == nil && noValueOutputs.count == 1 {
            // If one of the inputs was 0, and we know all of the outputs except 1 and none of them were zero, then the last output must be zero
            // A * B * 0 = D * E * F. We know all outputs except F, and they are nonzero
            // F = 0
            context.setConnectorValue(noValueOutputs[0], value: (0, constantExpression(0), zeroInputWasDependent!), informant: self)
            
        } else if zeroOutputWasDependent != nil && zeroOutputWasDependent == nil && noValueInputs.count == 1 {
            // If one of the outputs was 0, and we know all of the inputs except 1 and none of them were zero, then the last input must be zero
            // A * B * C = D * E * 0. We know all inputs except A, and they are nonzero
            // A = 0
            context.setConnectorValue(noValueInputs[0], value: (0, constantExpression(0), zeroOutputWasDependent!), informant: self)
            
        } else if noValueOutputs.count == 1 && noValueInputs.count == 0 {
            // A * B * C = D * E * F. We know all except D
            // D = (A * B * C) / (E * F)
            if inputs.count > 0 && outputsMultiplied != 0 {
                let expression = (outputsExpression != nil
                    ? functionExpression(DDMathOperatorDivide, [inputsExpression!, outputsExpression!])
                    : inputsExpression!)
                let value = (inputsMultiplied / outputsMultiplied, expression, anyValueWasDependent)
                context.setConnectorValue(noValueOutputs[0], value: value, informant: self)
            }
        } else if noValueOutputs.count == 0 && noValueInputs.count == 1 {
            // A * B * C = D * E * F. We know all except A
            // A = (D * E * F) / (B * C)
            if outputs.count > 0 && inputsMultiplied != 0 {
                let expression = (inputsExpression != nil
                    ? functionExpression(DDMathOperatorDivide, [outputsExpression!, inputsExpression!])
                    : outputsExpression!)
                let value = (outputsMultiplied / inputsMultiplied, expression, anyValueWasDependent)
                context.setConnectorValue(noValueInputs[0], value: value, informant: self)
            }
            
        } else if noValueInputs.count == 0 && noValueOutputs.count == 0 {
            
            if outputsMultiplied != inputsMultiplied {
                println("Something went wrong in multiplier. Inputs \(inputsMultiplied) not equal to outputs \(outputsMultiplied)");
                return false
            }
        }
        return true
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
    override func processNewValues(context: SimulationContext) -> Bool {
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
                    let value = (1.0, constantExpression(1.0), exponentValue!.WasDependent)
                    context.setConnectorValue(result, value: value, informant: self)
                }
                
            } else if baseValue != nil && baseValue!.DoubleValue == 0 {
                // If base is 0, then result is 0 (unless exponent is also zero)
                let value = (0.0, constantExpression(0.0), baseValue!.WasDependent)
                context.setConnectorValue(result, value: value, informant: self)
                
            } else if baseValue != nil && exponentValue != nil {
                //result = base ^ exponent
                let doubleValue = pow(baseValue!.DoubleValue, exponentValue!.DoubleValue)
                let isDependent = baseValue!.WasDependent || exponentValue!.WasDependent
                let expression = functionExpression(DDMathOperatorPower, [baseValue!.Expression, exponentValue!.Expression])
                context.setConnectorValue(result, value: (doubleValue, expression, isDependent), informant: self)
            }
            
        } else {
            
            // TODO: If result = 1 then exponent = 0, regardless of base
            
            if baseValue == nil && exponentValue != nil {
                // base = result ^ (1/exponent)
                let doubleValue = pow(resultValue!.DoubleValue, 1.0 / exponentValue!.DoubleValue)
                let isDependent = resultValue!.WasDependent || exponentValue!.WasDependent
                let expression = functionExpression("nthroot", [resultValue!.Expression, exponentValue!.Expression])
                context.setConnectorValue(base, value: (doubleValue, expression, isDependent), informant: self)
                
            } else if baseValue != nil && exponentValue == nil {
                // exponent = log_base(result) = ln(result) / ln(base)
                let doubleValue = log(resultValue!.DoubleValue) / log(baseValue!.DoubleValue)
                let isDependent = resultValue!.WasDependent || baseValue!.WasDependent
                let expression = functionExpression(DDMathOperatorLogBase, [baseValue!.Expression, resultValue!.Expression])
                context.setConnectorValue(exponent, value: (doubleValue, expression, isDependent), informant: self)
                
            } else if baseValue != nil && exponentValue != nil {
                // Sanity check
                
                let predictedValue = pow(baseValue!.DoubleValue, exponentValue!.DoubleValue)
                let value = resultValue!.DoubleValue
                if predictedValue != value {
                    println("Something went wrong in exponent. Result \(value) is not equal to \(predictedValue)")
                    return false
                }
            }
        }
        return true
    }
}
