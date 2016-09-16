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
    
    var description: String {
        return "(\"\(testLabel)\", \"\(trainLabel)\", \(testIndex))"
    }
}

class DigitRecognizerTests: XCTestCase {
    
    func testAccuracyAndPerformance() {
        let digitRecognizer = DigitRecognizer()
        let digitSampleLibrary = DigitSampleLibrary()
        let bundle = Bundle(for: DigitRecognizerTests.self)
        
        let jsonData = DigitSampleLibrary.jsonLibraryFromFile(path: bundle.path(forResource: "bridger_test", ofType: "json")!)
        digitSampleLibrary.loadData(jsonData: jsonData!, legacyBatchID: "bridger_test")

        self.measure {
            let startTime = Date()
            var aggregateCorrect = 0
            var aggregateTotal = 0

            for (label, samples) in digitSampleLibrary.samples {
                for sample in samples {
                    aggregateTotal += 1
                    digitRecognizer.clearClassificationQueue()

                    for stroke in sample.strokes {
                        digitRecognizer.addStrokeToClassificationQueue(stroke: stroke)
                    }
                    if let classification = digitRecognizer.recognizeStrokesInQueue() {
                        if classification.count == 1 && classification[0] == label {
                            aggregateCorrect += 1
                        }
                    }
                }
            }

            let accuracy = Double(aggregateCorrect) / Double(aggregateTotal)
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("Accuracy score is \(accuracy)% (\(aggregateCorrect)/\(aggregateTotal)). All tests took \(elapsedTime) seconds.")
        }
    }
}
