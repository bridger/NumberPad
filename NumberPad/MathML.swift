//
//  MathML.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 2/7/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import Foundation

let DDMathOperatorNthRoot = "nthroot"
let DDMathOperatorLogBase = "logbase"

func mathMLForExpression(expression: DDExpression, formattedValues: [DDExpression : String]) -> String? {
    switch expression.expressionType() {
    case .Function:
        if let functionName = expression.function {
            if let values = expression.arguments as? [DDExpression] {
                func subExpressionInParenthesisIfNecessary(subExpression: DDExpression, subExpressionMathML: String) -> String {
                    if subExpression.expressionType() == .Function {
                        return "<mo>(</mo>\(subExpressionMathML)<mo>)</mo>"
                    }
                    return subExpressionMathML
                }
                
                if values.count < 2 {
                    return nil
                }
                
                if let firstSubMathML = mathMLForExpression(values[0], formattedValues) {
                    if let secondSubMathML = mathMLForExpression(values[1], formattedValues) {
                        
                        if functionName == DDMathOperatorAdd {
                            return "\(firstSubMathML)<mo>+</mo>\(secondSubMathML)"
                            
                        } else if functionName == DDMathOperatorMinus {
                            return "\(firstSubMathML)<mo>-</mo>\(secondSubMathML)"
                            
                        } else if functionName == DDMathOperatorMultiply {
                            return "\(firstSubMathML)<mo>⋅</mo>\(secondSubMathML)"
                            
                        } else if functionName == DDMathOperatorDivide {
                            return "<mfrac><mrow>\(firstSubMathML)</mrow><mrow>\(secondSubMathML)</mrow></mfrac>"
                            
                        } else if functionName == DDMathOperatorPower {
                            let baseExpression = subExpressionInParenthesisIfNecessary(values[0], firstSubMathML)
                            return "<msup><mrow>\(baseExpression)</mrow><mrow>\(secondSubMathML)</mrow></msup>"
                            
                        } else if functionName == DDMathOperatorNthRoot {
                            return "<mroot><mrow>\(firstSubMathML)</mrow><mrow>\(secondSubMathML)</mrow></mroot>"
                            
                        } else if functionName == DDMathOperatorLogBase {
                            let subExpression = subExpressionInParenthesisIfNecessary(values[1], secondSubMathML)
                            return "<mrow><msub><mi>log</mi><mrow>\(firstSubMathML)</mrow></msub>\(subExpression)</mrow>"
                        }
                    } else {
                        return nil // No second subexpression
                    }
                } else {
                    return nil // No first subexpression
                }
            }
        }
        
    case .Variable:
        if let variableName = expression.variable {
            return "<mi>\(variableName)</mi>"
        }
        
    case .Number:
        if let formattedValues = formattedValues[expression] {
            return "<mn>\(formattedValues)</mn>"
        } else if let numberValue = expression.number {
            return "<mn>\(numberValue)</mn>"
        }
    }
    
    return nil
}
