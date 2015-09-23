//
//  Constraints.swift
//  Numbers
//
//  Created by Bridger Maxwell on 10/17/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import Foundation

class SimulationContext {
    typealias ResolvedValue = (DoubleValue: Double, Expression: DDExpression, WasDependent: Bool, Informant: Constraint?)
    var connectorValues: [Connector: ResolvedValue] = [:]
    var rewriteExpressions = true
    
    let connectorResolvedCallback: (Connector, ResolvedValue) -> Void
    let connectorConflictCallback: (Connector, ResolvedValue) -> Void
    
    let mathEvaluator = DDMathEvaluator()
    
    func setConnectorValue(connector: Connector, value: ResolvedValue) {
        if let existingValue = connectorValues[connector] {
            if existingValue.DoubleValue != value.DoubleValue {
                print("Something went wrong. Value changed from \(existingValue.DoubleValue) not equal to outputs \(value.DoubleValue)")
                self.connectorConflictCallback(connector, value)
            }
        } else {
            var rewrittenValue = value
            if rewriteExpressions {
                if let rewrittenExpression = DDExpressionRewriter.defaultRewriter().expressionByRewritingExpression(value.Expression, withEvaluator: mathEvaluator) {
                    rewrittenValue = (value.DoubleValue, rewrittenExpression, value.WasDependent, value.Informant)
                } else {
                    print("Error rewriting expression \(value.Expression)")
                }
            }
            connectorValues[connector] = rewrittenValue
            connectorResolvedCallback(connector, rewrittenValue)
            for constraint in connector.constraints {
                if constraint != value.Informant {
                    if !constraint.processNewValues(self) {
                        self.connectorConflictCallback(connector, rewrittenValue)
                    }
                }
            }
        }
    }
    
    init(connectorResolvedCallback: (Connector, ResolvedValue) -> Void, connectorConflictCallback: (Connector, ResolvedValue) -> Void) {
        self.connectorResolvedCallback = connectorResolvedCallback
        self.connectorConflictCallback = connectorConflictCallback
    }
}

func functionExpression(functionName: String, arguments: [DDExpression]) -> DDExpression {
    do {
        return try DDExpression.functionExpressionWithFunction(functionName, arguments: arguments)
    } catch let error as NSError {
        fatalError("Unable to make function expression \(functionName). Error \(error)");
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
        if let index = inputs.indexOf(connector) {
            inputs.removeAtIndex(index)
            connector.disconnect(self)
        } else {
            print("Unable to remove input connector!")
        }
    }
    func addOutput(connector: Connector) {
        outputs.append(connector)
        connector.connect(self)
    }
    func removeOutput(connector: Connector) {
        if let index = outputs.indexOf(connector) {
            outputs.removeAtIndex(index)
            connector.disconnect(self)
        } else {
            print("Unable to remove output connector!")
        }
    }
}


class Connector {
    var constraints: [Constraint] = []
    
    func connect(constraint: Constraint) {
        constraints.append(constraint)
    }
    func disconnect(constraint: Constraint) {
        if let index = constraints.indexOf(constraint) {
            constraints.removeAtIndex(index)
        } else {
            print("Unable to remove constraint")
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
                    inputsExpression = functionExpression(DDMathOperatorAdd, arguments: [inputsExpression!, value.Expression])
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
                    outputsExpression = functionExpression(DDMathOperatorAdd, arguments: [outputsExpression!, value.Expression])
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
                let expression = outputsExpression != nil
                    ? functionExpression(DDMathOperatorMinus, arguments: [inputsExpression!, outputsExpression!])
                    : inputsExpression!
                context.setConnectorValue(noValueOutputs[0], value: (inputsAdded - outputsAdded, expression, anyValueWasDependent, self))
            }
        } else if noValueOutputs.count == 0 && noValueInputs.count == 1 {
            // A + B + C = D + E + F. We know all except A
            // A = (D + E + F) - (B + C)
            if outputs.count > 0 {
                let expression = (inputsExpression != nil
                    ? functionExpression(DDMathOperatorMinus, arguments: [outputsExpression!, inputsExpression!])
                    : outputsExpression!)
                context.setConnectorValue(noValueInputs[0], value: (outputsAdded - inputsAdded, expression, anyValueWasDependent, self))
            }
        } else if noValueInputs.count == 0 && noValueOutputs.count == 0 {
            
            if outputsAdded != inputsAdded {
                print("Something went wrong in adder. Inputs \(inputsAdded) not equal to outputs \(outputsAdded)");
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
                    inputsExpression = functionExpression(DDMathOperatorMultiply, arguments: [inputsExpression!, value.Expression])
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
                    outputsExpression = functionExpression(DDMathOperatorMultiply, arguments: [outputsExpression!, value.Expression])
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
            context.setConnectorValue(noValueOutputs[0], value: (0, constantExpression(0), zeroInputWasDependent!, self))
            
        } else if zeroOutputWasDependent != nil && zeroOutputWasDependent == nil && noValueInputs.count == 1 {
            // If one of the outputs was 0, and we know all of the inputs except 1 and none of them were zero, then the last input must be zero
            // A * B * C = D * E * 0. We know all inputs except A, and they are nonzero
            // A = 0
            context.setConnectorValue(noValueInputs[0], value: (0, constantExpression(0), zeroOutputWasDependent!, self))
            
        } else if noValueOutputs.count == 1 && noValueInputs.count == 0 {
            // A * B * C = D * E * F. We know all except D
            // D = (A * B * C) / (E * F)
            if inputs.count > 0 && outputsMultiplied != 0 {
                let expression = (outputsExpression != nil
                    ? functionExpression(DDMathOperatorDivide, arguments: [inputsExpression!, outputsExpression!])
                    : inputsExpression!)
                let value: SimulationContext.ResolvedValue = (inputsMultiplied / outputsMultiplied, expression, anyValueWasDependent, self)
                context.setConnectorValue(noValueOutputs[0], value: value)
            }
        } else if noValueOutputs.count == 0 && noValueInputs.count == 1 {
            // A * B * C = D * E * F. We know all except A
            // A = (D * E * F) / (B * C)
            if outputs.count > 0 && inputsMultiplied != 0 {
                let expression = (inputsExpression != nil
                    ? functionExpression(DDMathOperatorDivide, arguments: [outputsExpression!, inputsExpression!])
                    : outputsExpression!)
                let value: SimulationContext.ResolvedValue = (outputsMultiplied / inputsMultiplied, expression, anyValueWasDependent, self)
                context.setConnectorValue(noValueInputs[0], value: value)
            }
            
        } else if noValueInputs.count == 0 && noValueOutputs.count == 0 {
            
            if outputsMultiplied != inputsMultiplied {
                print("Something went wrong in multiplier. Inputs \(inputsMultiplied) not equal to outputs \(outputsMultiplied)");
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
                    print("Unable to determine result if exponent and base are 0", terminator: "")
                } else {
                    context.setConnectorValue(result, value: (1.0, constantExpression(1.0), exponentValue!.WasDependent, self))
                }
                
            } else if baseValue != nil && baseValue!.DoubleValue == 0 {
                // If base is 0, then result is 0 (unless exponent is also zero)
                context.setConnectorValue(result, value: (0.0, constantExpression(0.0), baseValue!.WasDependent, self))
                
            } else if baseValue != nil && exponentValue != nil {
                //result = base ^ exponent
                let doubleValue = pow(baseValue!.DoubleValue, exponentValue!.DoubleValue)
                let isDependent = baseValue!.WasDependent || exponentValue!.WasDependent
                let expression = functionExpression(DDMathOperatorPower, arguments: [baseValue!.Expression, exponentValue!.Expression])
                context.setConnectorValue(result, value: (doubleValue, expression, isDependent, self))
            }
            
        } else {
            
            // TODO: If result = 1 then exponent = 0, regardless of base
            
            if baseValue == nil && exponentValue != nil {
                // base = result ^ (1/exponent)
                let doubleValue = pow(resultValue!.DoubleValue, 1.0 / exponentValue!.DoubleValue)
                let isDependent = resultValue!.WasDependent || exponentValue!.WasDependent
                let expression = functionExpression("nthroot", arguments: [resultValue!.Expression, exponentValue!.Expression])
                context.setConnectorValue(base, value: (doubleValue, expression, isDependent, self))
                
            } else if baseValue != nil && exponentValue == nil {
                // exponent = log_base(result) = ln(result) / ln(base)
                let doubleValue = log(resultValue!.DoubleValue) / log(baseValue!.DoubleValue)
                let isDependent = resultValue!.WasDependent || baseValue!.WasDependent
                let expression = functionExpression(DDMathOperatorLogBase, arguments: [baseValue!.Expression, resultValue!.Expression])
                context.setConnectorValue(exponent, value: (doubleValue, expression, isDependent, self))
                
            } else if baseValue != nil && exponentValue != nil {
                // Sanity check
                
                let predictedValue = pow(baseValue!.DoubleValue, exponentValue!.DoubleValue)
                let value = resultValue!.DoubleValue
                if predictedValue != value {
                    print("Something went wrong in exponent. Result \(value) is not equal to \(predictedValue)")
                    return false
                }
            }
        }
        return true
    }
}
