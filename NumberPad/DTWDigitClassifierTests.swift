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
    
    func testParameters() {
        let digitClassifier = DTWDigitClassifier()
        let bundle = NSBundle(forClass: self.dynamicType)
        
        let trainingJsonData = DTWDigitClassifier.jsonLibraryFromFile(bundle.pathForResource("bridger_train", ofType: "json")!)
        digitClassifier.loadData(trainingJsonData!, loadNormalizedData: false)
        
        let testJsonData = DTWDigitClassifier.jsonLibraryFromFile(bundle.pathForResource("bridger_test", ofType: "json")!)
        let testData = DTWDigitClassifier.jsonToLibrary(testJsonData!["rawData"]!)
        
        
        for (votesCounted: Int, scoreCutoff: CGFloat) in [(5, 0.8), (10, 0.8)] {
            println("\n\n\nTesting votesCounted=\(votesCounted) scoreCutoff=\(scoreCutoff)")
            
            let startTime = NSDate()
            var aggregateCorrect = 0
            var aggregateTotal = 0
            
            for (label, testDigits) in testData {
                var labelCorrect = 0
                var labelTotal = 0
                var labelWrong = 0
                var labelUnclassified = 0
                let startDigitTime = NSDate()
                
                for testDigit in testDigits {
                    labelTotal++
                    
                    let classification = digitClassifier.classifyDigit(testDigit, votesCounted: votesCounted, scoreCutoff: scoreCutoff)
                    if classification == label {
                        labelCorrect += 1
                    } else if classification == nil {
                        labelUnclassified += 1
                    } else {
                        println("Misclassified \(label) as \(classification!)")
                        labelWrong += 1
                    }
                }
                
                let accuracy = Double(labelCorrect) / Double(labelTotal)
                let elapsedTime = NSDate().timeIntervalSinceDate(startDigitTime)
                println(String(format: "Accuracy score for %@ is %.3f%% (%d/%d). %d wrong. %d unknown. Took %d seconds", label, accuracy, labelCorrect, labelTotal, labelWrong, labelUnclassified, Int(elapsedTime)))
                
                aggregateCorrect += labelCorrect
                aggregateTotal += labelTotal
            }
            
            let accuracy = Double(aggregateCorrect) / Double(aggregateTotal)
            let elapsedTime = NSDate().timeIntervalSinceDate(startTime)
            println("Accuracy score for (\(votesCounted), \(scoreCutoff)) is \(accuracy)% (\(aggregateCorrect)/\(aggregateTotal)). All tests took \(elapsedTime) seconds.")
            
        }
        
        
    }
    
    func testPerformanceAndAccuracy() {
        let digitClassifier = DTWDigitClassifier()
        
        let bundle = NSBundle(forClass: self.dynamicType)
        let trainingJsonData = DTWDigitClassifier.jsonLibraryFromFile(bundle.pathForResource("bridger_train", ofType: "json")!)
        XCTAssertNotNil(trainingJsonData,  "Could not load training data")
        
        let testJsonData = DTWDigitClassifier.jsonLibraryFromFile(bundle.pathForResource("bridger_test", ofType: "json")!)
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
                var labelUnclassified = 0
                var labelWrong = 0
                
                let serviceGroup = dispatch_group_create()
                let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
                let serialResultsQueue = dispatch_queue_create("collect_results", nil)

                for testDigit in testDigits {
                    labelTotal++
                    
                    dispatch_group_async(serviceGroup, queue) {
                        let classification = digitClassifier.classifyDigit(testDigit)
                        
                        dispatch_group_async(serviceGroup, serialResultsQueue) {
                            if classification == label {
                                labelCorrect += 1
                            } else if classification == nil {
                                labelUnclassified += 1
                            } else {
                                labelWrong += 1
                            }
                        }
                    }
                }
                
                // Wait for all results
                dispatch_group_wait(serviceGroup, DISPATCH_TIME_FOREVER);
                
                let accuracy = Double(labelCorrect) / Double(labelTotal)
                println(String(format: "Accuracy score for %@ is %.3f%% (%d/%d). Wrong=%d Uknown=%d", label, accuracy, labelCorrect, labelTotal, labelWrong, labelUnclassified))
                
                aggregateCorrect += labelCorrect
                aggregateTotal += labelTotal
            }
            
            let accuracy = Double(aggregateCorrect) / Double(aggregateTotal)
            let elapsedTime = NSDate().timeIntervalSinceDate(startTime)
            println("Accuracy score for all training data is \(accuracy)% (\(aggregateCorrect)/\(aggregateTotal)). All tests took \(elapsedTime) seconds.")
        }
    }
}
