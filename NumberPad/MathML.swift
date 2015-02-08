//
//  MathML.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 2/7/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import Foundation

func mathMLForExpression(expression: DDExpression) -> String? {
    switch expression.expressionType() {
    case .Function:
        if let functionName = expression.function {
            if let values = expression.arguments as? [DDExpression] {
                if values.count < 2 {
                    return nil
                }
                
                var firstSubExpression = mathMLForExpression(values[0])
                var secondSubExpression = mathMLForExpression(values[1])
                if firstSubExpression == nil {
                    return nil
                }
                if secondSubExpression == nil {
                    return nil
                }
                
                if functionName == DDMathOperatorAdd {
                    return "\(firstSubExpression!)<mo>+</mo>\(secondSubExpression!)"
                } else if functionName == DDMathOperatorMinus {
                    return "\(firstSubExpression!)<mo>-</mo>\(secondSubExpression!)"
                } else if functionName == DDMathOperatorMultiply {
                    return "\(firstSubExpression!)<mo>⋅</mo>\(secondSubExpression!)"
                } else if functionName == DDMathOperatorDivide {
                    return "<mfrac><mrow>\(firstSubExpression!)</mrow><mrow>\(secondSubExpression!)</mrow></mfrac>"
                }
            }
            
        }
        
    case .Variable:
        if let variableName = expression.variable {
            return "<mi>\(variableName)</mi>"
        }
        
    case .Number:
        if let numberValue = expression.number {
            return "<mn>\(numberValue)</mn>"
        }
    }
    
    return nil
}
