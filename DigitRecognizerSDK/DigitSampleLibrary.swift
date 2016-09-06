//
//  DigitSampleLibrary.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 9/2/16.
//  Copyright © 2016 Bridger Maxwell. All rights reserved.
//

import UIKit

public struct DigitSample {
    public typealias BatchID = String

    public var strokes: DigitRecognizer.DigitStrokes
    public var batchID: BatchID

    public init(strokes: DigitRecognizer.DigitStrokes, batchID: BatchID) {
        self.strokes = strokes
        self.batchID = batchID
    }
}

public class DigitSampleLibrary {

    public typealias DigitLabel = DigitRecognizer.DigitLabel
    public typealias DigitStrokes = DigitRecognizer.DigitStrokes
    public typealias BatchID = DigitSample.BatchID

    public typealias PrototypeLibrary = [DigitLabel: [DigitSample]]

    public var samples: PrototypeLibrary = [:]

    public init() {
        
    }

    public typealias JSONCompatiblePoint = [CGFloat]
    public typealias JSONCompatibleLibrary = [DigitLabel: [[[JSONCompatiblePoint]]] ]

    public func jsonDataToSave() -> [String: JSONCompatibleLibrary] {
        var dictionary: [DigitSampleLibrary.BatchID: JSONCompatibleLibrary] = [:]

        for (label, prototypes) in samples {
            for prototype in prototypes {
                var batchLibrary = dictionary[prototype.batchID] ?? [:]
                if batchLibrary[label] == nil {
                    batchLibrary[label] = []
                }
                // Add the stroke, but with the CGPoint converted to [CGFloat, CGFloat]
                batchLibrary[label]!.append( prototype.strokes.map { (points: [CGPoint]) -> [JSONCompatiblePoint] in
                    return points.map { (point: CGPoint) -> JSONCompatiblePoint in
                        return [point.x, point.y]
                    }
                })
                dictionary[prototype.batchID] = batchLibrary
            }
        }

        return dictionary
    }

    public class func jsonLibraryFromFile(path: String) -> [String: JSONCompatibleLibrary]? {
        let filename = NSURL(fileURLWithPath: path).lastPathComponent
        if let data = NSData(contentsOfFile: path) {
            do {
                let json = try JSONSerialization.jsonObject(with: data as Data, options: [])
                if let jsonLibrary = json as? [String: JSONCompatibleLibrary] {
                    return jsonLibrary
                } else {
                    print("Unable to read file \(filename) as compatible json")
                }
            } catch _ {
                print("Unable to read file \(filename) as json")
            }
        } else {
            print("Unable to read file \(filename)")
        }

        return nil
    }

    public class func jsonToLibrary(json: JSONCompatibleLibrary, batchID: BatchID) -> PrototypeLibrary {
        var newLibrary: PrototypeLibrary = [:]
        for (label, prototypes) in json {
            newLibrary[label] = prototypes.map { (prototype: [[JSONCompatiblePoint]]) -> DigitSample in
                return DigitSample(
                    strokes: prototype.map { (points: [JSONCompatiblePoint]) -> [CGPoint] in
                        return points.map { (point: JSONCompatiblePoint) -> CGPoint in
                            return CGPoint(x: point[0], y: point[1])
                        }
                    },
                    batchID: batchID)
            }
        }

        return newLibrary
    }

    public func loadData(jsonData: [String: JSONCompatibleLibrary], legacyBatchID: BatchID, clearExistingLibrary: Bool = false) {
        if (clearExistingLibrary) {
            self.samples = [:]
        }
        for (loadedID, library) in jsonData {
            if loadedID == "normalizedData" {
                // This was written out in a legacy version, but we don't read it in
                continue
            }
            let batchID = (loadedID == "rawData") ? legacyBatchID : loadedID

            let loadedData = DigitSampleLibrary.jsonToLibrary(json: library, batchID: batchID)
            for (label, prototypes) in loadedData {
                self.samples[label] = (self.samples[label] ?? []) + prototypes
            }
        }
    }

    /*
    public func addToLibrary(library: inout PrototypeLibrary, label: DigitLabel, digit: DigitStrokes) {
        if library[label] != nil {
            library[label]!.append(digit)
        } else {
            library[label] = []
        }
    }
    */

}
