//
//  DTWDigitClassifierTests.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/29/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit
import XCTest

class DTWDigitClassifierTests: XCTestCase {
    
    let digitClassifier = DTWDigitClassifier()
    
    func testUjiPenDataClassification() {
        let digitClassifier = DTWDigitClassifier()
        
        let bundle = NSBundle(forClass: self.dynamicType)
        let trainingJsonData = DTWDigitClassifier.jsonLibraryFromFile(bundle.pathForResource("ujipenchars2_train", ofType: "json")!)
        XCTAssertNotNil(trainingJsonData,  "Could not load training data")
        
        let testJsonData = DTWDigitClassifier.jsonLibraryFromFile(bundle.pathForResource("ujipenchars2_test", ofType: "json")!)
        XCTAssertNotNil(testJsonData,  "Could not load test data")
        let testData = DTWDigitClassifier.jsonToLibrary(testJsonData!["rawData"]!)
        
        digitClassifier.loadData(trainingJsonData!, loadNormalizedData: false)
        self.measureBlock {
            let startTime = NSDate()
            var aggregateCorrect = 0
            var aggregateTotal = 0
            for (label, testDigits) in testData {
                var labelCorrect = 0
                var labelTotal = 0
                let startDigitTime = NSDate()
                
                for testDigit in testDigits {
                    labelTotal++
                    
                    let classification = digitClassifier.classifyDigit(testDigit)
                    if classification == label {
                        labelCorrect++
                    }
                }
                
                let accuracy = Double(labelCorrect) / Double(labelTotal)
                let elapsedTime = NSDate().timeIntervalSinceDate(startDigitTime)
                println(String(format: "Accuracy score for %@ is %.3f%% (%d/%d). Took %d seconds", label, accuracy, labelCorrect, labelTotal, Int(elapsedTime)))
                
                aggregateCorrect += labelCorrect
                aggregateTotal += labelTotal
            }
            
            let accuracy = Double(aggregateCorrect) / Double(aggregateTotal)
            let elapsedTime = NSDate().timeIntervalSinceDate(startTime)
            println("Accuracy score for all training data is \(accuracy)% (\(aggregateCorrect)/\(aggregateTotal)). All tests took \(elapsedTime) seconds.")
        }
    }
}
