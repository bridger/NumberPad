//
//  DTWDigitClassifier.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/26/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import CoreGraphics
import Foundation

public func euclidianDistance(a: CGPoint, b: CGPoint) -> CGFloat {
    return sqrt( euclidianDistanceSquared(a, b) )
}

public func euclidianDistanceSquared(a: CGPoint, b: CGPoint) -> CGFloat {
    let dx = a.x - b.x
    let dy = a.y - b.y
    return dx*dx + dy*dy
}

public class DTWDigitClassifier {
    public typealias DigitStrokes = [[CGPoint]]
    public typealias DigitLabel = String
    public typealias PrototypeLibrary = [DigitLabel: [DigitStrokes]]
    
    var normalizedPrototypeLibrary: PrototypeLibrary = [:]
    var rawPrototypeLibrary: PrototypeLibrary = [:]
    
    public init() {
        
    }
    
    public func learnDigit(label: DigitLabel, digit: DigitStrokes) {
        addToLibrary(&self.rawPrototypeLibrary, label: label, digit: digit)
        let normalizedDigit = normalizeDigit(digit)
        addToLibrary(&self.normalizedPrototypeLibrary, label: label, digit: normalizedDigit)
    }
    
    // Returns the label, as well as a confidence in the label
    // Can be called from the background
    public typealias Classification = (Label: DigitLabel, Confidence: CGFloat)
    public func classifyDigit(digit: DigitStrokes, votesCounted: Int = 5, scoreCutoff: CGFloat = 0.8) -> Classification? {
        let normalizedDigit = normalizeDigit(digit)
        
        var bestMatches = SortedMinArray<CGFloat, DigitLabel>(capacity: votesCounted)
        for (label, prototypes) in self.normalizedPrototypeLibrary {
            var localMinDistance: CGFloat?
            var localMinLabel: DigitLabel?
            for prototype in prototypes {
                if prototype.count == digit.count {
                    let score = self.classificationScore(normalizedDigit, prototype: prototype)
                    if score < scoreCutoff {
                        bestMatches.add(score, element: label)
                    }
                }
            }
        }
        
        var votes: [DigitLabel: Int] = [:]
        for (score, label) in bestMatches {
            votes[label] = (votes[label] ?? 0) + 1
        }
        
        var maxVotes: Int?
        var maxVotedLabel: DigitLabel?
        for (label, labelVotes) in votes {
            if maxVotes == nil || labelVotes > maxVotes! {
                maxVotedLabel = label
                maxVotes = labelVotes
            }
        }
        if let maxVotedLabel = maxVotedLabel {
            for (score, label) in bestMatches {
                if label == maxVotedLabel {
                    return (maxVotedLabel, score)
                }
            }
        }
        
        return nil
    }
    
    public typealias JSONCompatiblePoint = [CGFloat]
    public typealias JSONCompatibleLibrary = [DigitLabel: [[[JSONCompatiblePoint]]] ]
    public func dataToSave(saveRawData: Bool, saveNormalizedData: Bool) -> [String: JSONCompatibleLibrary] {
        func libraryToJson(library: PrototypeLibrary) -> JSONCompatibleLibrary {
            var jsonLibrary: JSONCompatibleLibrary = [:]
            for (label, prototypes) in library {
                
                // Maps the library to have [point.x, point.y] arrays at the leafs, instead of CGPoints
                jsonLibrary[label] = prototypes.map { (prototype: DigitStrokes) -> [[JSONCompatiblePoint]] in
                    return prototype.map { (points: [CGPoint]) -> [JSONCompatiblePoint] in
                        return points.map { (point: CGPoint) -> JSONCompatiblePoint in
                            return [point.x, point.y]
                        }
                    }
                }
            }
            
            return jsonLibrary
        }
        
        var dictionary: [String: JSONCompatibleLibrary] = [:]
        if (saveRawData) {
            dictionary["rawData"] = libraryToJson(self.rawPrototypeLibrary)
        }
        if (saveNormalizedData) {
            dictionary["normalizedData"] = libraryToJson(self.normalizedPrototypeLibrary)
        }
        
        return dictionary
    }
    
    public class func jsonLibraryFromFile(path: String) -> [String: JSONCompatibleLibrary]? {
        let filename = path.lastPathComponent
        if let data = NSData(contentsOfFile: path) {
            if let json: AnyObject = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: nil) {
                if let jsonLibrary = json as? [String: JSONCompatibleLibrary] {
                    return jsonLibrary
                } else {
                    println("Unable to read file \(filename) as compatible json")
                }
            } else {
                println("Unable to read file \(filename) as json")
            }
        } else {
            println("Unable to read file \(filename)")
        }
        
        return nil
    }
    
    public class func jsonToLibrary(json: JSONCompatibleLibrary) -> PrototypeLibrary {
        var newLibrary: PrototypeLibrary = [:]
        for (label, prototypes) in json {
            newLibrary[label] = prototypes.map { (prototype: [[JSONCompatiblePoint]]) -> DigitStrokes in
                return prototype.map { (points: [JSONCompatiblePoint]) -> [CGPoint] in
                    return points.map { (point: JSONCompatiblePoint) -> CGPoint in
                        return CGPointMake(point[0], point[1])
                    }
                }
            }
        }
        
        return newLibrary
    }
    
    public func loadData(jsonData: [String: JSONCompatibleLibrary], loadNormalizedData: Bool) {
        // Clear the existing library
        self.normalizedPrototypeLibrary = [:]
        self.rawPrototypeLibrary = [:]
        var loadedNormalizedData = false
        
        if let jsonData = jsonData["rawData"] {
            self.rawPrototypeLibrary = DTWDigitClassifier.jsonToLibrary(jsonData)
        }
        if loadNormalizedData {
            if let jsonData = jsonData["normalizedData"] {
                self.normalizedPrototypeLibrary = DTWDigitClassifier.jsonToLibrary(jsonData)
                loadedNormalizedData = true
            }
        }
        
        if !loadedNormalizedData {
            for (label, prototypes) in self.rawPrototypeLibrary {
                for prototype in prototypes {
                    let normalizedDigit = normalizeDigit(prototype)
                    addToLibrary(&self.normalizedPrototypeLibrary, label: label, digit: normalizedDigit)
                }
            }
        }
    }
    
    
    public func addToLibrary(inout library: PrototypeLibrary, label: DigitLabel, digit: DigitStrokes) {
        if library[label] != nil {
            library[label]!.append(digit)
        } else {
            var newArray: [DigitStrokes] = [digit]
            library[label] = []
        }
    }

    
    func classificationScore(sample: DigitStrokes, prototype: DigitStrokes) -> CGFloat {
        assert(sample.count == prototype.count, "To compare two digits, they must have the same number of strokes")
        var result: CGFloat = 0
        for (index, stroke) in enumerate(sample) {
            result += self.greedyDynamicTimeWarp(stroke, prototype: prototype[index])
        }
        return result / CGFloat(sample.count)
    }
    
    func greedyDynamicTimeWarp(sample: [CGPoint], prototype: [CGPoint]) -> CGFloat {
        let windowWidth: CGFloat = 0.5 * CGFloat(sample.count)
        let slope: CGFloat = CGFloat(sample.count) / CGFloat(prototype.count)
        
        var pathLength = 1
        var result: CGFloat = euclidianDistance(sample[0], prototype[0])
        
        var sampleIndex: Int = 0
        var prototypeIndex: Int = 0
        // Imagine that sample is the vertical axis, and prototype is the horizontal axis
        while sampleIndex + 1 < sample.count && prototypeIndex + 1 < prototype.count {
            
            // For a pairing (sampleIndex, prototypeIndex) to be made, it must meet the boundary condition:
            // sampleIndex < (slope * CGFloat(prototypeIndex) + windowWidth
            // sampleIndex < (slope * CGFloat(prototypeIndex) - windowWidth
            // You can think of slope * CGFloat(prototypeIndex) as being the perfectly diagonal pairing
            var up = CGFloat.max
            if CGFloat(sampleIndex + 1) < slope * CGFloat(prototypeIndex) + windowWidth {
                up = euclidianDistanceSquared(sample[sampleIndex + 1], prototype[prototypeIndex])
            }
            var right = CGFloat.max
            if CGFloat(sampleIndex) < slope * CGFloat(prototypeIndex + 1) + windowWidth {
                right = euclidianDistanceSquared(sample[sampleIndex], prototype[prototypeIndex + 1])
            }
            var diagonal = CGFloat.max
            if (CGFloat(sampleIndex + 1) < slope * CGFloat(prototypeIndex + 1) + windowWidth &&
                CGFloat(sampleIndex + 1) > slope * CGFloat(prototypeIndex + 1) - windowWidth) {
                diagonal = euclidianDistanceSquared(sample[sampleIndex + 1], prototype[prototypeIndex + 1])
            }
            
            // TODO: The right is the least case is repeated twice. Any way to fix that?
            if up < diagonal {
                if up < right {
                    // up is the least
                    sampleIndex++
                    result += sqrt(up)
                } else {
                    // right is the least
                    prototypeIndex++
                    result += sqrt(right)
                }
            } else {
                // diagonal or right is the least
                if diagonal < right {
                    // diagonal is the least
                    sampleIndex++
                    prototypeIndex++
                    result += sqrt(diagonal)
                } else {
                    // right is the least
                    prototypeIndex++
                    result += sqrt(right)
                }
            }

            pathLength++;
        }
        
        // At most one of the following while loops will execute, finishing the path with a vertical or horizontal line along the boundary
        while sampleIndex + 1 < sample.count {
            sampleIndex++
            result += euclidianDistance(sample[sampleIndex], prototype[prototypeIndex])
            pathLength++;
        }
        while prototypeIndex + 1 < prototype.count {
            prototypeIndex++
            result += euclidianDistance(sample[sampleIndex], prototype[prototypeIndex])
            pathLength++;
        }
        
        return result / CGFloat(pathLength)
    }
    
    func normalizeDigit(inputDigit: DigitStrokes) -> DigitStrokes {
        // Resize the point list to have a center of mass at the origin and unit standard deviation on both axis
        //    scaled_x = (symbol.x - mean(symbol.x)) * (h/5)/std2(symbol.x) + h/2;
        //    scaled_y = (symbol.y - mean(symbol.y)) * (h/5)/std2(symbol.y) + h/2;
        var totalDistance: CGFloat = 0.0
        var xMean: CGFloat = 0.0
        var xDeviation: CGFloat = 0.0
        var yMean: CGFloat = 0.0
        var yDeviation: CGFloat = 0.0
        for subPath in inputDigit {
            var lastPoint: CGPoint?
            for point in subPath {
                if let lastPoint = lastPoint {
                    let midPoint = CGPointMake((point.x + lastPoint.x) / 2.0, (point.y + lastPoint.y) / 2.0)
                    var distanceScore = euclidianDistance(point, lastPoint)
                    if distanceScore == 0 {
                        distanceScore = 0.1 // Otherwise, we will get NaN because of the weighting
                    }
                    
                    let temp = distanceScore + totalDistance
                    
                    let xDelta = midPoint.x - xMean;
                    let xR = xDelta * distanceScore / temp;
                    xMean = xMean + xR;
                    xDeviation = xDeviation + totalDistance * xDelta * xR;
                    
                    let yDelta = midPoint.y - yMean;
                    let yR = yDelta * distanceScore / temp;
                    yMean = yMean + yR;
                    yDeviation = yDeviation + totalDistance * yDelta * yR;
                    
                    totalDistance = temp;
                    
                    assert(isfinite(xMean) && isfinite(yMean), "Found a nan!")
                } else {
                    lastPoint = point
                }
            }
        }
        
        
        xDeviation = sqrt(xDeviation / (totalDistance));
        yDeviation = sqrt(yDeviation / (totalDistance));
        
        var xScale = 1.0 / xDeviation;
        var yScale = 1.0 / yDeviation;
        if !isfinite(xScale) {
            xScale = 1
        }
        if !isfinite(yScale) {
             yScale = 1
        }
        let scale = min(xScale, yScale)
        
        return inputDigit.map { subPath in
            return subPath.map { point in
                let x = (point.x - xMean) * scale
                let y = (point.y - yMean) * scale
                return CGPointMake(x, y)
            }
        }
    }
}
