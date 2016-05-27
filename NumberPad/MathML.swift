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
                func subExpressionInParenthesisIfNecessary(subExpression: DDExpression, subExpressionMathML: String, onlyForAddition: Bool = false) -> String {
                    if subExpression.expressionType() == .function {
                        if !onlyForAddition || (subExpression.function! == DDMathOperatorAdd || subExpression.function! == DDMathOperatorMinus) {
                            return "<mo>(</mo>\(subExpressionMathML)<mo>)</mo>"
                        }
                    }
                    return subExpressionMathML
                }
                
                if values.count < 2 {
                    return nil
                }
                
                if let firstSubMathML = mathMLForExpression(expression: values[0], formattedValues: formattedValues) {
                    // TODO: Add parenthesis as appropriate on negative numbers. 5 + (-6), or 5•(-6)
                    if let secondSubMathML = mathMLForExpression(expression: values[1], formattedValues: formattedValues) {
                        
                        if functionName == DDMathOperatorAdd {
                            return "\(firstSubMathML)<mo>+</mo>\(secondSubMathML)"
                            
                        } else if functionName == DDMathOperatorMinus {
                            return "\(firstSubMathML)<mo>-</mo>\(secondSubMathML)"
                            
                        } else if functionName == DDMathOperatorMultiply {
                            let leftExpression = subExpressionInParenthesisIfNecessary(subExpression: values[0], subExpressionMathML: firstSubMathML, onlyForAddition: true)
                            let rightExpression = subExpressionInParenthesisIfNecessary(subExpression: values[1], subExpressionMathML: secondSubMathML, onlyForAddition: true)
                            return "\(leftExpression)<mo>⋅</mo>\(rightExpression)"
                            
                        } else if functionName == DDMathOperatorDivide {
                            return "<mfrac><mrow>\(firstSubMathML)</mrow><mrow>\(secondSubMathML)</mrow></mfrac>"
                            
                        } else if functionName == DDMathOperatorPower {
                            let baseExpression = subExpressionInParenthesisIfNecessary(subExpression: values[0], subExpressionMathML: firstSubMathML)
                            return "<msup><mrow>\(baseExpression)</mrow><mrow>\(secondSubMathML)</mrow></msup>"
                            
                        } else if functionName == DDMathOperatorNthRoot {
                            return "<mroot><mrow>\(firstSubMathML)</mrow><mrow>\(secondSubMathML)</mrow></mroot>"
                            
                        } else if functionName == DDMathOperatorLogBase {
                            let subExpression = subExpressionInParenthesisIfNecessary(subExpression: values[1], subExpressionMathML: secondSubMathML)
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
