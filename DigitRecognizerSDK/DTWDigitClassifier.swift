//
//  DTWDigitClassifier.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/26/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import CoreGraphics
import Foundation
import Accelerate

public func euclidianDistance(a: CGPoint, b: CGPoint) -> CGFloat {
    return sqrt( euclidianDistanceSquared(a: a, b: b) )
}

public func euclidianDistanceSquared(a: CGPoint, b: CGPoint) -> CGFloat {
    let dx = a.x - b.x
    let dy = a.y - b.y
    return dx*dx + dy*dy
}

public struct ImageSize {
    public var width: UInt
    public var height: UInt
    
    public init(width: UInt, height: UInt) {
        self.width = width
        self.height = height
    }
}

public class DTWDigitClassifier {
    public typealias DigitStrokes = [[CGPoint]]
    public typealias DigitLabel = String
    public typealias PrototypeLibrary = [DigitLabel: [DigitStrokes]]
    
    public var normalizedPrototypeLibrary: PrototypeLibrary = [:]
    var rawPrototypeLibrary: PrototypeLibrary = [:]
    
    let imageSize = ImageSize(width: 28, height: 28)
    
    public init() {
        
    }
    
    public func learnDigit(label: DigitLabel, digit: DigitStrokes) {
        addToLibrary(library: &self.rawPrototypeLibrary, label: label, digit: digit)
        if let normalizedDigit = normalizeDigit(inputDigit: digit) {
            addToLibrary(library: &self.normalizedPrototypeLibrary, label: label, digit: normalizedDigit)
        }
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
            return self.classifyDigit(digit: [singleStrokeDigit])
        }
        let strokeRanges: [MinAndMax?] = strokes.map(minAndMaxX)
        
        var labels: [DigitLabel] = []
        var index = 0
        while index < strokes.count {
            // For the stroke at this index, we either accept it, or make a stroke from it and the index+1 stroke
            let thisStrokeClassification = singleStrokeClassifications[index]
            
            if index + 1 < strokes.count {
                // Check to see if this stroke and the next stroke touched each other x-wise
                if let strokeRange = strokeRanges[index], let nextStrokeRange = strokeRanges[index + 1] {
                    if isWithin(test: nextStrokeRange.min, range: strokeRange) || isWithin(test: nextStrokeRange.max, range: strokeRange) || isWithin(test: strokeRange.min, range: nextStrokeRange) {
                        
                        // These two strokes intersected x-wise, so we try to classify them as one digit
                        if let twoStrokeClassification = self.classifyDigit(digit: [strokes[index], strokes[index + 1]]) {
                            let nextStrokeClassification = singleStrokeClassifications[index + 1]
                            
                            let mustMatch = thisStrokeClassification == nil || nextStrokeClassification == nil;
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
            
            // If we made it this far, then the two stroke hypothesis didn't pan out. This stroke must be viable on its own, or we fail
            if let thisStrokeClassification = thisStrokeClassification {
                labels.append(thisStrokeClassification.Label)
            } else {
                print("Could not classify stroke \(index)")
                return nil
            }
            index += 1
        }
        
        return labels
    }
    
    public typealias Classification = (Label: DigitLabel, Confidence: CGFloat)

    
    public func classifyDigit(digit: DigitStrokes) -> Classification? {
        return nil
    }
    
    public func buildNetwork(digit: DigitStrokes) {
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)

        var filterParams = createEmptyBNNSFilterParameters();

        let trainedDataPath = Bundle(for: DTWDigitClassifier.self).path(forResource: "trainedData", ofType: "dat")
        let trainedDataLength = 13098536

        // open file descriptors in read-only mode to parameter files
        let data_file = open(trainedDataPath!, O_RDONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)
        assert(data_file != -1, "Error: failed to open output file at \(trainedDataPath)  errno = \(errno)")

        // memory map the parameters
        let trainedData: UnsafeMutableRawPointer = mmap(nil, trainedDataLength, PROT_READ, MAP_FILE | MAP_SHARED, data_file, 0);

        var input = BNNSImageStackDescriptor(
            width: width,
            height: height,
            channels: 1,
            row_stride: width,
            image_stride: width * height,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0)

        // ****** conv 1 ******** //

        let conv1Weights = BNNSLayerData(
            data: trainedData + 0,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0,
            data_table: nil
        )
        let conv1Bias = BNNSLayerData(
            data: trainedData + 3200,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0,
            data_table: nil
        )
        
        var conv1_output = BNNSImageStackDescriptor(
            width: width,
            height: height,
            channels: 32,
            row_stride: width,
            image_stride: width * height,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0)

        var conv1_params = BNNSConvolutionLayerParameters(
            x_stride: 1,
            y_stride: 1,
            x_padding: 2, // TODO: Match 'SAME' algorithm
            y_padding: 2,
            k_width: 5,
            k_height: 5,
            in_channels: input.channels,
            out_channels: conv1_output.channels,
            weights: conv1Weights,
            bias: conv1Bias,
            activation: BNNSActivation(
                function: BNNSActivationFunctionRectifiedLinear,
                alpha: 0,
                beta: 0
            )
        )

        let conv1 = BNNSFilterCreateConvolutionLayer(&input, &conv1_output, &conv1_params, &filterParams)!

        // ****** pool 1 ******** //
        
        let pool1Data = BNNSLayerData(
            data: nil,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0,
            data_table: nil
        )

        var pool1_output = BNNSImageStackDescriptor(
            width: width / 2,
            height: height / 2,
            channels: 32,
            row_stride: width / 2,
            image_stride: (width / 2) * (height / 2),
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0)

        var pool1_parameters = BNNSPoolingLayerParameters(
            x_stride: 1,
            y_stride: 1,
            x_padding: 0,
            y_padding: 0,
            k_width: 2,
            k_height: 2,
            in_channels: 32,
            out_channels: 32,
            pooling_function: BNNSPoolingFunctionMax,
            bias: pool1Data,
            activation: BNNSActivation( // TODO: Do pools have activation functions? ????
                function: BNNSActivationFunctionRectifiedLinear,
                alpha: 0,
                beta: 0
            )
        )

        let pool1 = BNNSFilterCreatePoolingLayer(&conv1_output, &pool1_output, &pool1_parameters, &filterParams)!

        // ****** conv 2 ******** //

        let conv2Weights = BNNSLayerData(
            data: trainedData + 3328,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0,
            data_table: nil
        )
        let conv2Bias = BNNSLayerData(
            data: trainedData + 208128,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0,
            data_table: nil
        )

        var conv2_output = BNNSImageStackDescriptor(
            width: width / 2,
            height: height / 2,
            channels: 64,
            row_stride: width / 2,
            image_stride: (width / 2) * (height / 2),
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0)

        var conv2_parameters = BNNSConvolutionLayerParameters(
            x_stride: 1,
            y_stride: 1,
            x_padding: 2,
            y_padding: 2,
            k_width: 5,
            k_height: 5,
            in_channels: pool1_output.channels,
            out_channels: conv2_output.channels,
            weights: conv2Weights,
            bias: conv2Bias,
            activation: BNNSActivation(
                function: BNNSActivationFunctionRectifiedLinear,
                alpha: 0, // TODO:
                beta: 0 // TODO:
            )
        )

        let conv2 = BNNSFilterCreateConvolutionLayer(&pool1_output, &conv2_output, &conv2_parameters, &filterParams)!

        // ****** pool 2 ******** //

        let pool2Data = BNNSLayerData(
            data: nil,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0,
            data_table: nil
        )

        var pool2_output = BNNSImageStackDescriptor(
            width: width / 4,
            height: height / 4,
            channels: 64,
            row_stride: width / 4,
            image_stride: (width / 4) * (height / 4),
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0)

        var pool2_parameters = BNNSPoolingLayerParameters(
            x_stride: 1,
            y_stride: 1,
            x_padding: 0,
            y_padding: 0,
            k_width: 2,
            k_height: 2,
            in_channels: conv2_output.channels,
            out_channels: pool2_output.channels,
            pooling_function: BNNSPoolingFunctionMax,
            bias: pool2Data,
            activation: BNNSActivation( // TODO: Do pools have activation functions?
                function: BNNSActivationFunctionRectifiedLinear,
                alpha: 0,
                beta: 0
            )
        )

        let pool2 = BNNSFilterCreatePoolingLayer(&conv2_output, &pool2_output, &pool2_parameters, &filterParams)!

        // ****** fully connected 1 ******** //

        var fullyConnected_in = BNNSVectorDescriptor(
            size: pool2_output.width * pool2_output.height * pool2_output.channels,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0)

        var fullyConnected_out = BNNSVectorDescriptor(
            size: 1024,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0)

        let fullyConnected1Weights = BNNSLayerData(
            data: trainedData + 208384,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0,
            data_table: nil
        )

        let fullyConnected1Bias = BNNSLayerData(
            data: trainedData + 13053440,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0,
            data_table: nil
        )

        var fullyConnected1_params = BNNSFullyConnectedLayerParameters(
            in_size: fullyConnected_in.size,
            out_size: fullyConnected_out.size,
            weights: fullyConnected1Weights,
            bias: fullyConnected1Bias,
            activation: BNNSActivation(
                function: BNNSActivationFunctionRectifiedLinear,
                alpha: 0,
                beta: 0
        ))

        let fullyConnected1 = BNNSFilterCreateFullyConnectedLayer(&fullyConnected_in, &fullyConnected_out, &fullyConnected1_params, &filterParams)!

        // ****** fully connected 1 ******** //

        var output = BNNSVectorDescriptor(
            size: 10,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0)

        let fullyConnected2Weights = BNNSLayerData(
            data: trainedData + 13057536,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0,
            data_table: nil
        )

        let fullyConnected2Bias = BNNSLayerData(
            data: trainedData + 13098496,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0,
            data_table: nil
        )

        var fullyConnected2_params = BNNSFullyConnectedLayerParameters(
            in_size: fullyConnected_out.size,
            out_size: output.size,
            weights: fullyConnected2Weights,
            bias: fullyConnected2Bias,
            activation: BNNSActivation(
                function: BNNSActivationFunctionRectifiedLinear,
                alpha: 0,
                beta: 0
        ))

        let fullyConnected2 = BNNSFilterCreateFullyConnectedLayer(&fullyConnected_out, &output, &fullyConnected2_params, &filterParams)!


        var dataBuffer1 = Array<Float32>(repeating: 0, count: 25088)
        dataBuffer1[0] = 0 // To silence "never mutated" warning
        var dataBuffer2 = Array<Float32>(repeating: 0, count: 6272)
        dataBuffer2[0] = 0 // To silence "never mutated" warning

        let dataPointer1 = UnsafeMutableRawPointer(mutating: dataBuffer1)
        let dataPointer2 = UnsafeMutableRawPointer(mutating: dataBuffer2)

        guard renderToContext(normalizedStrokes: digit, size: imageSize, data: dataPointer2) != nil else {
            fatalError("Couldn't render image")
        }

        // Convert the int8 to floats
        let intPointer = dataPointer2.assumingMemoryBound(to: UInt8.self)
        let imageArray = Array<UInt8>(UnsafeBufferPointer(start: intPointer, count: width * height))
        for (index, pixel) in imageArray.enumerated() {
            dataBuffer1[index] = Float32(pixel)
        }

        BNNSFilterApply(conv1, dataPointer1, dataPointer2)
        BNNSFilterApply(pool1, dataPointer2, dataPointer1)
        BNNSFilterApply(conv2, dataPointer1, dataPointer2)
        BNNSFilterApply(pool2, dataPointer2, dataPointer1)
        BNNSFilterApply(fullyConnected1, dataPointer1, dataPointer2)
        BNNSFilterApply(fullyConnected2, dataPointer2, dataPointer1)

        for (index, score) in dataBuffer1[0...9].enumerated() {
            print("Index \(index) got score \(score)")
        }
    }


    // Returns the label, as well as a confidence in the label
    // Can be called from the background
    public func classifyDigit(digit: DigitStrokes, votesCounted: Int = 5, scoreCutoff: CGFloat = 0.8) -> Classification? {
        if let normalizedDigit = normalizeDigit(inputDigit: digit) {
            let serviceGroup = DispatchGroup()
            let queue = DispatchQueue.global(qos: .userInitiated)
            let serialResultsQueue = DispatchQueue(label: "collect_results")
            
            var bestMatches = SortedMinArray<CGFloat, (DigitLabel, Int)>(capacity: votesCounted)
            for (label, prototypes) in self.normalizedPrototypeLibrary {
                
                queue.async(group: serviceGroup) {
                    var localBestMatches = SortedMinArray<CGFloat, (DigitLabel, Int)>(capacity: votesCounted)
                    var index = 0
                    for prototype in prototypes {
                        if prototype.count == digit.count {
                            let score = self.classificationScore(sample: normalizedDigit, prototype: prototype)
                            //if score < scoreCutoff {
                            localBestMatches.add(value: score, element: (label, index))
                            //}
                        }
                        index += 1
                    }
                    serialResultsQueue.async(group: serviceGroup) {
                        for (score, bestMatch) in localBestMatches {
                            bestMatches.add(value: score, element: bestMatch)
                        }
                    }
                }
            }
            
            // Wait for all results
            serviceGroup.wait()
            
            var votes: [DigitLabel: Int] = [:]
            for (_, (label, _)) in bestMatches {
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
                for (score, (label, _)) in bestMatches {
                    if label == maxVotedLabel {
                        return (maxVotedLabel, score)
                    }
                }
            }

        } else {
            print("Unable to normalize digit")
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
            dictionary["rawData"] = libraryToJson(library: self.rawPrototypeLibrary)
        }
        if (saveNormalizedData) {
            dictionary["normalizedData"] = libraryToJson(library: self.normalizedPrototypeLibrary)
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
    
    public class func jsonToLibrary(json: JSONCompatibleLibrary) -> PrototypeLibrary {
        var newLibrary: PrototypeLibrary = [:]
        for (label, prototypes) in json {
            newLibrary[label] = prototypes.map { (prototype: [[JSONCompatiblePoint]]) -> DigitStrokes in
                return prototype.map { (points: [JSONCompatiblePoint]) -> [CGPoint] in
                    return points.map { (point: JSONCompatiblePoint) -> CGPoint in
                        return CGPoint(x: point[0], y: point[1])
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
    
    public func loadData(jsonData: [String: JSONCompatibleLibrary], loadNormalizedData: Bool, clearExistingLibrary: Bool = true) {
        if (clearExistingLibrary) {
            self.normalizedPrototypeLibrary = [:]
            self.rawPrototypeLibrary = [:]
        }
        
        // TODO: Remove the saving / restoring of normalized data when we use
        if loadNormalizedData, let jsonData = jsonData["normalizedData"] {
            for (label, prototypes) in DTWDigitClassifier.jsonToLibrary(json: jsonData) {
                self.normalizedPrototypeLibrary[label] = (self.normalizedPrototypeLibrary[label] ?? []) + prototypes
            }
        } else if let jsonData = jsonData["rawData"] {
            let loadedData = DTWDigitClassifier.jsonToLibrary(json: jsonData)
            
            for (label, prototypes) in loadedData {
                self.rawPrototypeLibrary[label] = (self.rawPrototypeLibrary[label] ?? []) + prototypes
                
                for (_, prototype) in prototypes.enumerated() {
                    if let normalizedDigit = normalizeDigit(inputDigit: prototype) {
                        //                        let totalPoints = normalizedDigit.reduce(0) {(total, stroke) -> Int in
                        //                            return total + stroke.count
                        //                        }
                        //                        println("Normalized digit \(label) to \(totalPoints) points")
                        addToLibrary(library: &self.normalizedPrototypeLibrary, label: label, digit: normalizedDigit)
                    }
                }
            }
        }
    }
    
    public func addToLibrary(library: inout PrototypeLibrary, label: DigitLabel, digit: DigitStrokes) {
        if library[label] != nil {
            library[label]!.append(digit)
        } else {
            library[label] = []
        }
    }

    
    func classificationScore(sample: DigitStrokes, prototype: DigitStrokes) -> CGFloat {
        assert(sample.count == prototype.count, "To compare two digits, they must have the same number of strokes")
        var result: CGFloat = 0
        for (index, stroke) in sample.enumerated() {
            result += self.greedyDynamicTimeWarp(sample: stroke, prototype: prototype[index])
        }
        return result / CGFloat(sample.count)
    }
    
    func greedyDynamicTimeWarp(sample: [CGPoint], prototype: [CGPoint]) -> CGFloat {
        let minNeighborSize = 2
        let maxNeighborSize = 10
        if sample.count < minNeighborSize * 4 || prototype.count < minNeighborSize * 4 {
            return CGFloat.greatestFiniteMagnitude
        }
        
        let windowWidth: CGFloat = 6.0
        let slope: CGFloat = CGFloat(sample.count) / CGFloat(prototype.count)
        
        var pathLength = 1
        var result: CGFloat = 0
        
        var sampleIndex: Int = minNeighborSize
        var prototypeIndex: Int = minNeighborSize
        
        func calculateSafeNeighborSize(sampleIndex: Int, prototypeIndex: Int) -> Int {
            return min(sampleIndex, sample.count - 1 - (sampleIndex + 1),
                prototypeIndex, prototype.count - 1 - (prototypeIndex + 1),
                maxNeighborSize)
        }
        func hHalfMetricForPoints(sampleIndex: Int, prototypeIndex: Int, neighborsRange: Int) -> CGFloat {
            var totalDistance: CGFloat = 0
            for neighbors in 1...neighborsRange {
                let aVector = sample[sampleIndex - neighbors] + sample[sampleIndex + neighbors]
                let bVector = prototype[prototypeIndex - neighbors] + prototype[prototypeIndex + neighbors]
                
                let difference = aVector - bVector
                let differenceDistance = difference.length()
                let windowScale: CGFloat = 1.0
                totalDistance += differenceDistance * windowScale
            }
            //totalDistance += euclidianDistance(curveA[indexA], curveB[indexB])
            
            return totalDistance / CGFloat(neighborsRange)
        }
        
        
        // Imagine that sample is the vertical axis, and prototype is the horizontal axis
        while sampleIndex + 1 < sample.count - minNeighborSize && prototypeIndex + 1 < prototype.count - minNeighborSize {
            
            // We want to use the same window size to compare all options, so it must be safe for all cases
            let safeNeighborSize = calculateSafeNeighborSize(sampleIndex: sampleIndex, prototypeIndex: prototypeIndex)
            
            // For a pairing (sampleIndex, prototypeIndex) to be made, it must meet the boundary condition:
            // sampleIndex < (slope * CGFloat(prototypeIndex) + windowWidth
            // sampleIndex < (slope * CGFloat(prototypeIndex) - windowWidth
            // You can think of slope * CGFloat(prototypeIndex) as being the perfectly diagonal pairing
            var up = CGFloat.greatestFiniteMagnitude
            if CGFloat(sampleIndex + 1) < slope * CGFloat(prototypeIndex) + windowWidth {
                up = hHalfMetricForPoints(sampleIndex: sampleIndex + 1, prototypeIndex: prototypeIndex, neighborsRange: safeNeighborSize)
            }
            var right = CGFloat.greatestFiniteMagnitude
            if CGFloat(sampleIndex) < slope * CGFloat(prototypeIndex + 1) + windowWidth {
                right = hHalfMetricForPoints(sampleIndex: sampleIndex, prototypeIndex: prototypeIndex + 1, neighborsRange: safeNeighborSize)
            }
            var diagonal = CGFloat.greatestFiniteMagnitude
            if (CGFloat(sampleIndex + 1) < slope * CGFloat(prototypeIndex + 1) + windowWidth &&
                CGFloat(sampleIndex + 1) > slope * CGFloat(prototypeIndex + 1) - windowWidth) {
                    diagonal = hHalfMetricForPoints(sampleIndex: sampleIndex + 1, prototypeIndex: prototypeIndex + 1, neighborsRange: safeNeighborSize)
            }
            
            // TODO: The right is the least case is repeated twice. Any way to fix that?
            if up < diagonal {
                if up < right {
                    // up is the least
                    sampleIndex += 1
                    result += up
                } else {
                    // right is the least
                    prototypeIndex += 1
                    result += right
                }
            } else {
                // diagonal or right is the least
                if diagonal < right {
                    // diagonal is the least
                    sampleIndex += 1
                    prototypeIndex += 1
                    result += diagonal
                } else {
                    // right is the least
                    prototypeIndex += 1
                    result += right
                }
            }

            pathLength += 1
        }
        
        // At most one of the following while loops will execute, finishing the path with a vertical or horizontal line along the boundary
        while sampleIndex + 1 < sample.count - minNeighborSize {
            sampleIndex += 1
            pathLength += 1
            
            let safeNeighborSize = calculateSafeNeighborSize(sampleIndex: sampleIndex, prototypeIndex: prototypeIndex)
            result += hHalfMetricForPoints(sampleIndex: sampleIndex, prototypeIndex: prototypeIndex, neighborsRange: safeNeighborSize)
        }
        while prototypeIndex + 1 < prototype.count - minNeighborSize {
            prototypeIndex += 1
            pathLength += 1
            
            let safeNeighborSize = calculateSafeNeighborSize(sampleIndex: sampleIndex, prototypeIndex: prototypeIndex)
            result += hHalfMetricForPoints(sampleIndex: sampleIndex, prototypeIndex: prototypeIndex, neighborsRange: safeNeighborSize)
        }
        
        return result / CGFloat(pathLength)
    }
    
    public func normalizeDigit(inputDigit: DigitStrokes) -> DigitStrokes? {
        let targetPointCount = 32
        
        var newInputDigit: DigitStrokes = []
        for stroke in inputDigit {
            // First, figure out the total arc length of this stroke
            var lastPoint: CGPoint?
            var totalDistance: CGFloat = 0
            for point in stroke {
                if let lastPoint = lastPoint {
                    totalDistance += euclidianDistance(a: lastPoint, b: point)
                }
                lastPoint = point
            }
            if totalDistance < 1.0 {
                return nil
            }
            
            // Now, divide this arc length into 32 segments
            let distancePerPoint = totalDistance / CGFloat(targetPointCount)
            var newPoints: [CGPoint] = []
            
            lastPoint = nil
            var distanceCovered: CGFloat = 0
            totalDistance = 0
            for point in stroke {
                if let lastPoint = lastPoint {
                    let nextDistance = euclidianDistance(a: lastPoint, b: point)
                    let newTotalDistance = totalDistance + nextDistance
                    while distanceCovered + distancePerPoint < newTotalDistance {
                        distanceCovered += distancePerPoint
                        let ratio: CGFloat = (distanceCovered - totalDistance) / nextDistance
                        if ratio < 0.0 || ratio > 1.0 {
                            print("Uh oh! Something went wrong!")
                        }
                        let newPointX: CGFloat = point.x * ratio + lastPoint.x * (1.0 - ratio)
                        let newPointY: CGFloat = point.y * ratio + lastPoint.y * (1.0 - ratio)
                        newPoints.append(CGPoint(x: newPointX, y: newPointY))
                    }
                    totalDistance = newTotalDistance
                }
                lastPoint = point
            }
            if newPoints.count > 0 && newPoints.count > 29 {
                newInputDigit.append(newPoints)
            } else {
                print("What happened here????")
            }
        }
        let inputDigit = newInputDigit
        
        var topLeft: CGPoint?
        var bottomRight: CGPoint?
        for stroke in inputDigit {
            for point in stroke {
                if let capturedTopLeft = topLeft {
                    topLeft = CGPoint(x: min(capturedTopLeft.x, point.x), y: min(capturedTopLeft.y, point.y));
                } else {
                    topLeft = point
                }
                if let capturedBottomRight = bottomRight {
                    bottomRight = CGPoint(x: max(capturedBottomRight.x, point.x), y: max(capturedBottomRight.y, point.y));
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
        if !xScale.isFinite {
            xScale = 1
        }
        if !yScale.isFinite {
             yScale = 1
        }
        let scale = min(xScale, yScale)
        
        return inputDigit.map { subPath in
            return subPath.map({ point in
                let x = (point.x - xTranslate) * scale
                let y = (point.y - yTranslate) * scale
                return CGPoint(x: x, y: y)
            })
        }
    }
}
