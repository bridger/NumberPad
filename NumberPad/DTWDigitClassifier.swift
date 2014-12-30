//
//  DTWDigitClassifier.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/26/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit

typealias DigitStrokes = [[CGPoint]]
typealias DigitLabel = String
typealias PrototypeLibrary = [DigitLabel: [DigitStrokes]]

func euclidianDistance(a: CGPoint, b: CGPoint) -> CGFloat {
    return sqrt( pow(a.x - b.x, 2) + pow(a.y - b.y, 2) )
}

class DTWDigitClassifier {
    
    var normalizedPrototypeLibrary: PrototypeLibrary = [:]
    var rawPrototypeLibrary: PrototypeLibrary = [:]
    
    func learnDigit(label: DigitLabel, digit: DigitStrokes) {
        addToLibrary(&self.rawPrototypeLibrary, label: label, digit: digit)
        let normalizedDigit = normalizeDigit(digit)
        addToLibrary(&self.normalizedPrototypeLibrary, label: label, digit: normalizedDigit)
    }
    
    func classifyDigit(digit: DigitStrokes) -> DigitLabel? {
        let normalizedDigit = normalizeDigit(digit)
        var minDistance: CGFloat?
        var minLabel: DigitLabel?
        
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
        let serialResultsQueue = dispatch_queue_create("collect_results", nil)
        
        let serviceGroup = dispatch_group_create()
        
        for (label, prototypes) in self.normalizedPrototypeLibrary {
            dispatch_group_async(serviceGroup, queue) {
                var localMinDistance: CGFloat?
                var localMinLabel: DigitLabel?
                
                for prototype in prototypes {
                    if prototype.count == digit.count {
                        let score = self.classificationScore(normalizedDigit, prototype: prototype)
                        if localMinDistance == nil || score < localMinDistance! {
                            if score == 0 {
                                println("Found a suspiciously perfect match")
                            }
                            localMinDistance = score
                            localMinLabel = label
                        }
                    }
                }
                
                dispatch_group_async(serviceGroup, serialResultsQueue) {
                    if localMinDistance != nil && (minDistance == nil || localMinDistance! < minDistance) {
                        minDistance = localMinDistance
                        minLabel = localMinLabel
                    }
                }
            }
        }
        
        dispatch_group_wait(serviceGroup,DISPATCH_TIME_FOREVER);
        //println("Returning label \(minLabel) which has a distance of \(minDistance)")
        
        return minLabel
    }
    
    typealias JSONCompatiblePoint = [CGFloat]
    typealias JSONCompatibleLibrary = [DigitLabel: [[[JSONCompatiblePoint]]] ]
    func dataToSave(saveRawData: Bool, saveNormalizedData: Bool) -> [String: JSONCompatibleLibrary] {
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
    
    class func jsonLibraryFromFile(path: String) -> [String: JSONCompatibleLibrary]? {
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
    
    class func jsonToLibrary(json: JSONCompatibleLibrary) -> PrototypeLibrary {
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
    
    func loadData(jsonData: [String: JSONCompatibleLibrary], loadNormalizedData: Bool) {
        
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
    
    
    func addToLibrary(inout library: PrototypeLibrary, label: DigitLabel, digit: DigitStrokes) {
        if library[label] != nil {
            library[label]!.append(digit)
        } else {
            var newArray: [DigitStrokes] = [digit]
            library[label] = []
        }
    }

    
    func classificationScore(sample: DigitStrokes, prototype: DigitStrokes) -> CGFloat {
        // TODO: Assert that samples.count == prototype.count
        var result: CGFloat = 0
        for (index, stroke) in enumerate(sample) {
            result += self.greedyDynamicTimeWarp(stroke, prototype: prototype[index], cost: euclidianDistance)
        }
        return result / CGFloat(sample.count)
    }
    
    // TODO: Can we mark the inputs as constant in swift?
    func greedyDynamicTimeWarp(sample: [CGPoint], prototype: [CGPoint], cost: (CGPoint, CGPoint) -> CGFloat) -> CGFloat {
        
        let windowWidth: CGFloat = 0.5 * CGFloat(sample.count)
        let slope: CGFloat = CGFloat(sample.count) / CGFloat(prototype.count)
        
        var pathLength = 1
        var result: CGFloat = cost(sample[0], prototype[0])
        
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
                up = cost(sample[sampleIndex + 1], prototype[prototypeIndex])
            }
            var right = CGFloat.max
            if CGFloat(sampleIndex) < slope * CGFloat(prototypeIndex + 1) + windowWidth {
                right = cost(sample[sampleIndex], prototype[prototypeIndex + 1])
            }
            var diagonal = CGFloat.max
            if (CGFloat(sampleIndex + 1) < slope * CGFloat(prototypeIndex + 1) + windowWidth &&
                CGFloat(sampleIndex + 1) > slope * CGFloat(prototypeIndex + 1) - windowWidth) {
                diagonal = cost(sample[sampleIndex + 1], prototype[prototypeIndex + 1])
            }

            switch min(up, diagonal, right) {
            case up:
                sampleIndex++
                result += up
            case right:
                prototypeIndex++
                result += right
            default: // diagonal
                sampleIndex++
                prototypeIndex++
                result += diagonal
            }
            if !isfinite(result) {
                println("Uh oh. Found a nan")
            }
            pathLength++;
        }
        
        // At most one of the following while loops will execute, finishing the path with a vertical or horizontal line along the boundary
        while sampleIndex + 1 < sample.count {
            sampleIndex++
            result += cost(sample[sampleIndex], prototype[prototypeIndex])
            pathLength++;
        }
        while prototypeIndex + 1 < prototype.count {
            prototypeIndex++
            result += cost(sample[sampleIndex], prototype[prototypeIndex])
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
                    
                    if !isfinite(xMean) || !isfinite(yMean) {
                        println("Found a nan")
                    }
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
