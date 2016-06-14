//
//  DTWDigitClassifierTests.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/29/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit
import XCTest
import DigitRecognizerSDK

struct MisclassifiedRecord: CustomStringConvertible {
    var testLabel: String
    var trainLabel: String
    var testIndex: Int
    var trainIndex: Int
    
    var description: String {
        return "(\"\(testLabel)\", \"\(trainLabel)\", \(testIndex), \(trainIndex))"
    }
}

class DTWDigitClassifierTests: XCTestCase {
    
    func testParameters() {
        let digitClassifier = DTWDigitClassifier()
        let bundle = Bundle(for: self.dynamicType)
        
        let trainingJsonData = DTWDigitClassifier.jsonLibraryFromFile(path: bundle.pathForResource("bridger_train", ofType: "json")!)
        digitClassifier.loadData(jsonData: trainingJsonData!, loadNormalizedData: false)
//        trainingJsonData = DTWDigitClassifier.jsonLibraryFromFile(bundle.pathForResource("ujipenchars2", ofType: "json")!)
//        digitClassifier.loadData(trainingJsonData!, loadNormalizedData: false)
        
        let testJsonData = DTWDigitClassifier.jsonLibraryFromFile(path: bundle.pathForResource("bridger_test", ofType: "json")!)
        let testData = DTWDigitClassifier.jsonToLibrary(json: testJsonData!["rawData"]!)
        
        
        for (votesCounted, scoreCutoff): (Int, CGFloat) in [(5, 0.8)] {
            print("\n\n\nTesting votesCounted=\(votesCounted) scoreCutoff=\(scoreCutoff)")
            
            let startTime = Date()
            var aggregateCorrect = 0
            var aggregateTotal = 0
            
            var misclassifieds: [MisclassifiedRecord] = []
            
            for (label, testDigits) in testData {
                var labelCorrect = 0
                var labelTotal = 0
                var labelWrong = 0
                var labelUnclassified = 0
                let startDigitTime = Date()
                
                var index = 0
                for testDigit in testDigits {
                    labelTotal += 1
                    
                    let classification = digitClassifier.classifyDigit(digit: testDigit, votesCounted: votesCounted, scoreCutoff: scoreCutoff)
                    if classification?.Label == label {
                        labelCorrect += 1
                    } else if classification == nil {
                        labelUnclassified += 1
                    } else {
                        misclassifieds.append(MisclassifiedRecord(testLabel: label, trainLabel: classification!.Label, testIndex: index, trainIndex: classification!.BestPrototypeIndex) )
                        print("! Misclassified \(label) as \(classification!.Label). Strokes \(testDigit.count) Indexes \(index) \(classification!.BestPrototypeIndex)")
                        labelWrong += 1
                    }
                    index += 1
                }
                
                let accuracy = Double(labelCorrect) / Double(labelTotal)
                let elapsedTime = Date().timeIntervalSince(startDigitTime)
                print(String(format: "Accuracy score for %@ is %.3f%% (%d/%d). %d wrong. %d unknown. Took %d seconds", label, accuracy, labelCorrect, labelTotal, labelWrong, labelUnclassified, Int(elapsedTime)))
                
                
                aggregateCorrect += labelCorrect
                aggregateTotal += labelTotal
            }
            
            
            print("All misclassified: ", terminator: "")
            for misclassified in misclassifieds {
                print(misclassified.description + ", ", terminator: "")
            }
            print("")
            
            let accuracy = Double(aggregateCorrect) / Double(aggregateTotal)
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("Accuracy score for (\(votesCounted), \(scoreCutoff)) is \(accuracy)% (\(aggregateCorrect)/\(aggregateTotal)). All tests took \(elapsedTime) seconds.")
        }
    }
    
    func testPerformanceAndAccuracy() {
        let digitClassifier = DTWDigitClassifier()
        
        let bundle = Bundle(for: self.dynamicType)
        let trainingJsonData = DTWDigitClassifier.jsonLibraryFromFile(path: bundle.pathForResource("bridger_train", ofType: "json")!)
        XCTAssertNotNil(trainingJsonData,  "Could not load training data")
        
        let testJsonData = DTWDigitClassifier.jsonLibraryFromFile(path: bundle.pathForResource("bridger_test", ofType: "json")!)
        XCTAssertNotNil(testJsonData,  "Could not load test data")
        let testData = DTWDigitClassifier.jsonToLibrary(json: testJsonData!["rawData"]!)
        
        digitClassifier.loadData(jsonData: trainingJsonData!, loadNormalizedData: false)
        self.measure {
            let startTime = Date()
            var aggregateCorrect = 0
            var aggregateTotal = 0
            
            for (label, testDigits) in testData {
                var labelCorrect = 0
                var labelTotal = 0
                var labelUnclassified = 0
                var labelWrong = 0

                for testDigit in testDigits {
                    labelTotal += 1
                    
                    let classification = digitClassifier.classifyDigit(digit: testDigit)?.Label
                    if classification == label {
                        labelCorrect += 1
                    } else if classification == nil {
                        labelUnclassified += 1
                    } else {
                        labelWrong += 1
                    }
                }
                
                let accuracy = Double(labelCorrect) / Double(labelTotal)
                print(String(format: "Accuracy score for %@ is %.3f%% (%d/%d). Wrong=%d Uknown=%d", label, accuracy, labelCorrect, labelTotal, labelWrong, labelUnclassified))
                
                aggregateCorrect += labelCorrect
                aggregateTotal += labelTotal
            }
            
            let accuracy = Double(aggregateCorrect) / Double(aggregateTotal)
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("Accuracy score for all training data is \(accuracy)% (\(aggregateCorrect)/\(aggregateTotal)). All tests took \(elapsedTime) seconds.")
        }
    }
}
