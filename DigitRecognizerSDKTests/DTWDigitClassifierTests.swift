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

struct MisclassifiedRecord: Printable {
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
        let bundle = NSBundle(forClass: self.dynamicType)
        
        var trainingJsonData = DTWDigitClassifier.jsonLibraryFromFile(bundle.pathForResource("bridger_train", ofType: "json")!)
        digitClassifier.loadData(trainingJsonData!, loadNormalizedData: false)
//        trainingJsonData = DTWDigitClassifier.jsonLibraryFromFile(bundle.pathForResource("ujipenchars2", ofType: "json")!)
//        digitClassifier.loadData(trainingJsonData!, loadNormalizedData: false)
        
        let testJsonData = DTWDigitClassifier.jsonLibraryFromFile(bundle.pathForResource("bridger_test", ofType: "json")!)
        let testData = DTWDigitClassifier.jsonToLibrary(testJsonData!["rawData"]!)
        
        
        for (votesCounted: Int, scoreCutoff: CGFloat) in [(5, 0.8)] {
            println("\n\n\nTesting votesCounted=\(votesCounted) scoreCutoff=\(scoreCutoff)")
            
            let startTime = NSDate()
            var aggregateCorrect = 0
            var aggregateTotal = 0
            
            var misclassifieds: [MisclassifiedRecord] = []
            
            for (label, testDigits) in testData {
                var labelCorrect = 0
                var labelTotal = 0
                var labelWrong = 0
                var labelUnclassified = 0
                let startDigitTime = NSDate()
                
                var index = 0
                for testDigit in testDigits {
                    labelTotal++
                    
                    let classification = digitClassifier.classifyDigit(testDigit, votesCounted: votesCounted, scoreCutoff: scoreCutoff)
                    if classification?.Label == label {
                        labelCorrect += 1
                    } else if classification == nil {
                        labelUnclassified += 1
                    } else {
                        misclassifieds.append(MisclassifiedRecord(testLabel: label, trainLabel: classification!.Label, testIndex: index, trainIndex: classification!.BestPrototypeIndex) )
                        println("! Misclassified \(label) as \(classification!.Label). Strokes \(testDigit.count) Indexes \(index) \(classification!.BestPrototypeIndex)")
                        labelWrong += 1
                    }
                    index++
                }
                
                let accuracy = Double(labelCorrect) / Double(labelTotal)
                let elapsedTime = NSDate().timeIntervalSinceDate(startDigitTime)
                println(String(format: "Accuracy score for %@ is %.3f%% (%d/%d). %d wrong. %d unknown. Took %d seconds", label, accuracy, labelCorrect, labelTotal, labelWrong, labelUnclassified, Int(elapsedTime)))
                
                
                aggregateCorrect += labelCorrect
                aggregateTotal += labelTotal
            }
            
            
            print("All misclassified: ")
            for misclassified in misclassifieds {
                print(misclassified.description + ", ")
            }
            println("")
            
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

                for testDigit in testDigits {
                    labelTotal++
                    
                    let classification = digitClassifier.classifyDigit(testDigit)?.Label
                    if classification == label {
                        labelCorrect += 1
                    } else if classification == nil {
                        labelUnclassified += 1
                    } else {
                        labelWrong += 1
                    }
                }
                
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
