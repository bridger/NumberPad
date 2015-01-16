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
    
    public var normalizedPrototypeLibrary: PrototypeLibrary = [:]
    var rawPrototypeLibrary: PrototypeLibrary = [:]
    
    public init() {
        
    }
    
    public func learnDigit(label: DigitLabel, digit: DigitStrokes) {
        addToLibrary(&self.rawPrototypeLibrary, label: label, digit: digit)
        let normalizedDigit = normalizeDigit(digit)
        addToLibrary(&self.normalizedPrototypeLibrary, label: label, digit: normalizedDigit)
    }
    
    
    // If any one stroke can't be classified, this will return nil. It assumes the strokes go left-to-right and are in order
    public func classifyMultipleDigits(strokes: [[CGPoint]]) -> [DigitLabel]? {
        typealias MinAndMax = (min: CGFloat, max: CGFloat)
        func minAndMaxX(points: [CGPoint]) -> MinAndMax? {
            if points.count == 0 {
                return nil
            }
            var minX = points[0].x
            var maxX = points[0].x
            
            for point in points {
                minX = min(point.x, minX)
                maxX = max(point.x, maxX)
            }
            return (minX, maxX)
        }
        func isWithin(test: CGFloat, range: MinAndMax) -> Bool {
            return test >= range.min && test <= range.max
        }
        
        // TODO: This could be done in parallel
        let singleStrokeClassifications: [DTWDigitClassifier.Classification?] = strokes.map { singleStrokeDigit in
            return self.classifyDigit([singleStrokeDigit])
        }
        let strokeRanges: [MinAndMax?] = strokes.map(minAndMaxX)
        
        var labels: [DigitLabel] = []
        var index = 0
        while index < strokes.count {
            // For the stroke at this index, we either accept it, or make a stroke from it and the index+1 stroke
            let thisStrokeClassification = singleStrokeClassifications[index]
            
            if index + 1 < strokes.count {
                // Check to see if this stroke and the next stroke touched each other x-wise
                if let strokeRange = strokeRanges[index] {
                    if let nextStrokeRange = strokeRanges[index + 1] {
                        if isWithin(nextStrokeRange.min, strokeRange) || isWithin(nextStrokeRange.max, strokeRange) || isWithin(strokeRange.min, nextStrokeRange) {
                            
                            // These two strokes intersected x-wise, so we try to classify them as one digit
                            if let twoStrokeClassification = self.classifyDigit([strokes[index], strokes[index + 1]]) {
                                let nextStrokeClassification = singleStrokeClassifications[index + 1]
                                
                                var mustMatch = thisStrokeClassification == nil || nextStrokeClassification == nil;
                                if (mustMatch || twoStrokeClassification.Confidence < (thisStrokeClassification!.Confidence + nextStrokeClassification!.Confidence)) {
                                    
                                    // Sweet, the double stroke classification is the best one
                                    labels.append(twoStrokeClassification.Label)
                                    index += 2
                                    continue
                                }
                            }
                        }
                    }
                }
            }
            
            // If we made it this far, then the two stroke hypothesis didn't pan out. This stroke must be viable on its own, or we fail
            if let thisStrokeClassification = thisStrokeClassification {
                labels.append(thisStrokeClassification.Label)
            } else {
                println("Could not classify stroke \(index)")
                return nil
            }
            index += 1
        }
        
        return labels
    }
    
    
    // Returns the label, as well as a confidence in the label
    // Can be called from the background
    public typealias Classification = (Label: DigitLabel, Confidence: CGFloat, BestPrototypeIndex: Int)
    public func classifyDigit(digit: DigitStrokes, votesCounted: Int = 5, scoreCutoff: CGFloat = 0.8) -> Classification? {
        let normalizedDigit = normalizeDigit(digit)
        
        var bestMatches = SortedMinArray<CGFloat, (DigitLabel, Int)>(capacity: votesCounted)
        for (label, prototypes) in self.normalizedPrototypeLibrary {
            var localMinDistance: CGFloat?
            var localMinLabel: DigitLabel?
            var index = 0
            for prototype in prototypes {
                if prototype.count == digit.count {
                    let score = self.classificationScore(normalizedDigit, prototype: prototype)
                    //if score < scoreCutoff {
                        bestMatches.add(score, element: (label, index))
                    //}
                }
                index++
            }
        }
        
        var votes: [DigitLabel: Int] = [:]
        for (score, (label, index)) in bestMatches {
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
            for (score, (label, index)) in bestMatches {
                if label == maxVotedLabel {
                    return (maxVotedLabel, score, index)
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
                }.filter { (prototype: DigitStrokes) -> Bool in
                    for stroke in prototype {
                        if stroke.count < 5 {
                            return false // Sometimes a weird sample ends up in the database
                        }
                    }
                    return true
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
                for (index, prototype) in enumerate(prototypes) {
                    if label == "1" && index == 13 {
                        println("Normalizing a troubled digit")
                    }
                    let normalizedDigit = normalizeDigit(prototype)
                    let totalPoints = normalizedDigit.reduce(0) {(total, stroke) -> Int in
                        return total + stroke.count
                    }
                    println("Normalized digit \(label) to \(totalPoints) points")
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
    
    func hHalfMetricForPoints(indexA: Int, curveA: [CGPoint], indexB: Int, curveB: [CGPoint], neighborsRange: Int) -> CGFloat {
        var totalDistance: CGFloat = 0
        for neighbors in 1...neighborsRange {
            let aVector = curveA[indexA - neighbors] + curveA[indexA + neighbors]
            let bVector = curveB[indexB - neighbors] + curveB[indexB + neighbors]
            
            let difference = aVector - bVector
            let differenceDistance = difference.length()
            let windowScale = 1.0 / (CGFloat(neighbors * neighbors))
            totalDistance += differenceDistance * windowScale
        }
        
        return totalDistance
    }
    
    func greedyDynamicTimeWarp(sample: [CGPoint], prototype: [CGPoint]) -> CGFloat {
        let minNeighborSize = 3
        let maxNeighborSize = 5
        if sample.count < minNeighborSize * 4 || prototype.count < minNeighborSize * 4 {
            return CGFloat.max
        }
        
        let windowWidth: CGFloat = 0.5 * CGFloat(sample.count)
        let slope: CGFloat = CGFloat(sample.count) / CGFloat(prototype.count)
        
        var pathLength = 1
        var result: CGFloat = 0
        
        var sampleIndex: Int = minNeighborSize
        var prototypeIndex: Int = minNeighborSize
        // Imagine that sample is the vertical axis, and prototype is the horizontal axis
        while sampleIndex + 1 < sample.count - minNeighborSize && prototypeIndex + 1 < prototype.count - minNeighborSize {
            
            // We want to use the same window size to compare all options, so it must be safe for all cases
            let safeNeighborSize = min(sampleIndex, sample.count - 1 - (sampleIndex + 1),
                prototypeIndex, prototype.count - 1 - (prototypeIndex + 1),
                maxNeighborSize)
            
            // For a pairing (sampleIndex, prototypeIndex) to be made, it must meet the boundary condition:
            // sampleIndex < (slope * CGFloat(prototypeIndex) + windowWidth
            // sampleIndex < (slope * CGFloat(prototypeIndex) - windowWidth
            // You can think of slope * CGFloat(prototypeIndex) as being the perfectly diagonal pairing
            var up = CGFloat.max
//            if CGFloat(sampleIndex + 1) < slope * CGFloat(prototypeIndex) + windowWidth {
                up = hHalfMetricForPoints(sampleIndex + 1, curveA: sample,
                    indexB: prototypeIndex, curveB: prototype, neighborsRange: safeNeighborSize)
//            }
            var right = CGFloat.max
//            if CGFloat(sampleIndex) < slope * CGFloat(prototypeIndex + 1) + windowWidth {
                right = hHalfMetricForPoints(sampleIndex, curveA: sample,
                    indexB: prototypeIndex + 1, curveB: prototype, neighborsRange: safeNeighborSize)
//            }
            var diagonal = CGFloat.max
//            if (CGFloat(sampleIndex + 1) < slope * CGFloat(prototypeIndex + 1) + windowWidth &&
//                CGFloat(sampleIndex + 1) > slope * CGFloat(prototypeIndex + 1) - windowWidth) {
                    diagonal = hHalfMetricForPoints(sampleIndex + 1, curveA: sample,
                        indexB: prototypeIndex + 1, curveB: prototype, neighborsRange: safeNeighborSize)
//            }
            
            // TODO: The right is the least case is repeated twice. Any way to fix that?
            if up < diagonal {
                if up < right {
                    // up is the least
                    sampleIndex++
                    result += up
                } else {
                    // right is the least
                    prototypeIndex++
                    result += right
                }
            } else {
                // diagonal or right is the least
                if diagonal < right {
                    // diagonal is the least
                    sampleIndex++
                    prototypeIndex++
                    result += diagonal
                } else {
                    // right is the least
                    prototypeIndex++
                    result += right
                }
            }

            pathLength++;
        }
        
        // At most one of the following while loops will execute, finishing the path with a vertical or horizontal line along the boundary
        while sampleIndex + 1 < sample.count - minNeighborSize {
            sampleIndex++
            result += euclidianDistance(sample[sampleIndex], prototype[prototypeIndex])
            pathLength++;
        }
        while prototypeIndex + 1 < prototype.count - minNeighborSize {
            prototypeIndex++
            result += euclidianDistance(sample[sampleIndex], prototype[prototypeIndex])
            pathLength++;
        }
        
        return result / CGFloat(pathLength)
    }
    
    func normalizeDigit(inputDigit: DigitStrokes) -> DigitStrokes {
        let targetPointCount = 32
        let totalPoints = inputDigit.reduce(0) {(total, stroke) -> Int in
            return total + stroke.count
        }
        var dropEveryDistance: Double = 1000000.0
        if totalPoints > targetPointCount {
            dropEveryDistance = Double(totalPoints) / Double(totalPoints - targetPointCount)
        }
        
        var inputDigit = inputDigit
        if totalPoints < targetPointCount {
            // We need to insert points
            let newPointCount = targetPointCount - totalPoints
            let insertEveryDistance = CGFloat(totalPoints) / CGFloat(newPointCount)
            var pointIndex = 0
            var insertedToVirtualIndex: CGFloat = 0.0
            
            var newInputDigit: DigitStrokes = []
            for stroke in inputDigit {
                var lastPoint: CGPoint?
                var newStroke: [CGPoint] = []
                for point in stroke {
                    if let lastPoint = lastPoint {
                        while insertedToVirtualIndex + insertEveryDistance < CGFloat(pointIndex) {
                            let ratio = min(CGFloat(pointIndex) - insertedToVirtualIndex , 0.5)
                            let newPoint = CGPointMake(lastPoint.x * ratio + point.x * (1.0 - ratio),
                                lastPoint.y * ratio + point.y * (1.0 - ratio))
                            
                            newStroke.append(newPoint)
                            insertedToVirtualIndex += insertEveryDistance
                        }
                    }
                    newStroke.append(point)
                    lastPoint = point
                    pointIndex++
                }
                newInputDigit.append(newStroke)
            }
            inputDigit = newInputDigit
        }
        
        
        var topLeft: CGPoint?
        var bottomRight: CGPoint?
        for stroke in inputDigit {
            for point in stroke {
                if let capturedTopLeft = topLeft {
                    topLeft = CGPointMake(min(capturedTopLeft.x, point.x), min(capturedTopLeft.y, point.y));
                } else {
                    topLeft = point
                }
                if let capturedBottomRight = bottomRight {
                    bottomRight = CGPointMake(max(capturedBottomRight.x, point.x), max(capturedBottomRight.y, point.y));
                } else {
                    bottomRight = point
                }
            }
        }
        let xDistance = (bottomRight!.x - topLeft!.x)
        let yDistance = (bottomRight!.y - topLeft!.y)
        let xTranslate = topLeft!.x + xDistance / 2
        let yTranslate = topLeft!.y + yDistance / 2
        
        var xScale = 1.0 / xDistance;
        var yScale = 1.0 / yDistance;
        if !isfinite(xScale) {
            xScale = 1
        }
        if !isfinite(yScale) {
             yScale = 1
        }
        let scale = min(xScale, yScale)
        
        var pointIndex = 0
        var droppedDistance: Double = 0
        return inputDigit.map { subPath in
            return subPath.filter({ point in
                var drop = false
                if droppedDistance + dropEveryDistance < Double(pointIndex) {
                    drop = true
                    droppedDistance += dropEveryDistance
                }
                pointIndex++
                return !drop
            }).map({ point in
                let x = (point.x - xTranslate) * scale
                let y = (point.y - yTranslate) * scale
                return CGPointMake(x, y)
            })
        }
    }
}
