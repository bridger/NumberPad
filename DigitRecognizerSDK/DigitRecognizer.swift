//
//  DigitRecognizer.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 9/2/16.
//  Copyright © 2016 Bridger Maxwell. All rights reserved.
//

import Foundation

public struct ImageSize {
    public var width: UInt
    public var height: UInt

    public init(width: UInt, height: UInt) {
        self.width = width
        self.height = height
    }
}

public class DigitRecognizer {
    public typealias DigitStrokes = [[CGPoint]]
    public typealias DigitLabel = String

    public let imageSize = ImageSize(width: 28, height: 28)

    public let labelStringToByte: [DigitLabel : UInt8] = [
        "0" : 0,
        "1" : 1,
        "2" : 2,
        "3" : 3,
        "4" : 4,
        "5" : 5,
        "6" : 6,
        "7" : 7,
        "8" : 8,
        "9" : 9,
        "x" : 10,
        "/" : 11,
        "+" : 12,
        "-" : 13,
        "?" : 14,
        "^" : 15,
        "e" : 16,
        ]

    public lazy var byteToLabelString: [UInt8 : DigitLabel] = {
        var computedByteToLabelString: [UInt8 : DigitLabel] = [:]
        for (label, byte) in self.labelStringToByte {
            computedByteToLabelString[byte] = label
        }
        return computedByteToLabelString
    }()

    public typealias Classification = (Label: DigitLabel, Confidence: CGFloat)
    public func classifyDigit(digit: DigitStrokes) -> Classification? {
        guard let normalizedStroke = DigitRecognizer.normalizeDigit(inputDigit: digit) else {
            return nil
        }
        guard renderToContext(normalizedStrokes: normalizedStroke, size: imageSize, data: dataPointer2) != nil else {
            fatalError("Couldn't render image")
        }

        // Convert the int8 to floats
        let intPointer = dataPointer2.assumingMemoryBound(to: UInt8.self)
        let imageArray = Array<UInt8>(UnsafeBufferPointer(start: intPointer, count: Int(imageSize.width * imageSize.height)))
        for (index, pixel) in imageArray.enumerated() {
            dataBuffer1[index] = Float32(pixel) / 255.0
        }

        BNNSFilterApply(conv1, dataPointer1, dataPointer2)
        BNNSFilterApply(pool1, dataPointer2, dataPointer1)
        BNNSFilterApply(conv2, dataPointer1, dataPointer2)
        BNNSFilterApply(pool2, dataPointer2, dataPointer1)
        BNNSFilterApply(fullyConnected1, dataPointer1, dataPointer2)
        BNNSFilterApply(fullyConnected2, dataPointer2, dataPointer1)

        var highestScore: (Int, Float32)?
        for (index, score) in dataBuffer1[0..<labelStringToByte.count].enumerated() {
            if highestScore?.1 ?? -1 < score {
                highestScore = (index, score)
            }
        }
        if let highestScore = highestScore, let label = byteToLabelString[UInt8(highestScore.0)] {
            return (Label: label, Confidence: CGFloat(highestScore.1))
        } else {
            return nil
        }
    }

    struct StrokeToClassify {
        var stroke: [CGPoint]
        var min: CGFloat
        var max: CGFloat
    }

    var classificationQueue = [StrokeToClassify]()
    var singleStrokeClassifications = [Classification?]()
    var doubleStrokeClassifications = [(classification: Classification, overlap: CGFloat)?]()
    public func addStrokeToClassificationQueue(stroke: [CGPoint]) {
        guard stroke.count > 0 else {
            return
        }

        var minX = stroke[0].x
        var maxX = stroke[0].x
        for point in stroke {
            minX = min(point.x, minX)
            maxX = max(point.x, maxX)
        }

        classificationQueue.append(StrokeToClassify(stroke: stroke, min: minX, max: maxX))
        singleStrokeClassifications.append(self.classifyDigit(digit: [stroke]))

        if classificationQueue.count > 1 {
            var twoStrokeClassification: (Classification, CGFloat)?

            let lastStroke = classificationQueue[classificationQueue.count - 2]
            // Check to see if this stroke and the last stroke touched
            let overlapDistance = min(lastStroke.max, maxX) - max(lastStroke.min, minX)
            if overlapDistance >= 0 {
                let smallestWidth = min(lastStroke.max - lastStroke.min, maxX - minX)
                let overlapPercent = max(overlapDistance, 1) / max(smallestWidth, 1)

                if let classification = classifyDigit(digit: [lastStroke.stroke, stroke]) {
                    twoStrokeClassification = (classification, overlapPercent)
                }

            }
            doubleStrokeClassifications.append(twoStrokeClassification)
        }
    }

    public func clearClassificationQueue() {
        classificationQueue.removeAll()
        singleStrokeClassifications.removeAll()
        doubleStrokeClassifications.removeAll()
    }

    // This is pretty cheap to call, the work is done upfront in addStrokeToClassificationQueue
    public func recognizeStrokesInQueue() -> [DigitLabel]? {
        var labels = [DigitLabel]()
        // print("Classifying using \nSingle: \(singleStrokeClassifications) \nDouble: \(doubleStrokeClassifications)\n\n")

        var index = 0
        while index < singleStrokeClassifications.count {
            let singleClass = singleStrokeClassifications[index]

            var classifyAsDouble: Bool = false
            var doubleClass: (classification: Classification, overlap: CGFloat)?

            if index + 1 < singleStrokeClassifications.count {
                doubleClass = doubleStrokeClassifications[index]
                if let doubleClass = doubleClass {
                    // Decide if we should count both of these strokes as one digit or not
                    let nextSingle = singleStrokeClassifications[index + 1]

                    if let singleClass = singleClass, let nextSingle = nextSingle {
                        // Comparing the confidence score of the two single stroke classifications vs the double stroke
                        // classificaiton is tricky. I'm not sure the numbers are even on the same scale necessarily.
                        // The heuristic here is to favor the double stroke if the strokes overlap a lot on the x axis.
                        let overlapBonus = 0.7 + doubleClass.overlap
                        if min(singleClass.Confidence, nextSingle.Confidence) < doubleClass.classification.Confidence * overlapBonus {
                            classifyAsDouble = true
                        } else if doubleClass.overlap > 0.75
                            && ["-", "1"] == [singleClass.Label, nextSingle.Label].sorted() {
                            // Recognizing "+" as "1-" or "-1" is a common misclassification
                            classifyAsDouble = true
                        }
                    } else {
                        // Either this stroke or the next couldn't be classified by itself, so we must use the double
                        classifyAsDouble = true
                    }
                }
            }

            if classifyAsDouble, let doubleClass = doubleClass {
                labels.append(doubleClass.classification.Label)
                index += 2
            } else if let singleClass = singleClass {
                labels.append(singleClass.Label)
                index += 1
            } else {
                return nil
            }
        }

        return labels
    }

    public class func normalizeDigit(inputDigit: DigitStrokes) -> DigitStrokes? {
        let targetPointCount = 32

        var newInputDigit: DigitStrokes = []
        for stroke in inputDigit {
            // First, figure out the total arc length of this stroke
            var lastPoint: CGPoint?
            var totalDistance: CGFloat = 0
            for point in stroke {
                if let lastPoint = lastPoint {
                    totalDistance += lastPoint.distanceTo(point: point)
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
                    let nextDistance = lastPoint.distanceTo(point: point)
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

    let trainedData: UnsafeMutableRawPointer
    let conv1: BNNSFilter
    let pool1: BNNSFilter
    let conv2: BNNSFilter
    let pool2: BNNSFilter
    let fullyConnected1: BNNSFilter
    let fullyConnected2: BNNSFilter

    var dataBuffer1: Array<Float32>
    var dataBuffer2: Array<Float32>
    let dataPointer1: UnsafeMutableRawPointer
    let dataPointer2: UnsafeMutableRawPointer

    public init() {
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)

        var filterParams = createEmptyBNNSFilterParameters();

        let trainedDataPath = Bundle(for: DigitRecognizer.self).path(forResource: "trainedData", ofType: "dat")
        let trainedDataLength = 13127236

        // open file descriptors in read-only mode to parameter files
        let data_file = open(trainedDataPath!, O_RDONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)
        assert(data_file != -1, "Error: failed to open output file at \(trainedDataPath)  errno = \(errno)")

        // memory map the parameters
        trainedData = mmap(nil, trainedDataLength, PROT_READ, MAP_FILE | MAP_SHARED, data_file, 0);

        // ****** trained layer data ******** //

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

        let fullyConnected2Weights = BNNSLayerData(
            data: trainedData + 13057536,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0,
            data_table: nil
        )

        let fullyConnected2Bias = BNNSLayerData(
            data: trainedData + 13127168,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0,
            data_table: nil
        )

        // ****** conv 1 ******** //

        var input = BNNSImageStackDescriptor(
            width: width,
            height: height,
            channels: 1,
            row_stride: width,
            image_stride: width * height,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0)

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
            x_padding: 2,
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

        conv1 = BNNSFilterCreateConvolutionLayer(&input, &conv1_output, &conv1_params, &filterParams)!

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
            x_stride: 2,
            y_stride: 2,
            x_padding: 0,
            y_padding: 0,
            k_width: 2,
            k_height: 2,
            in_channels: 32,
            out_channels: 32,
            pooling_function: BNNSPoolingFunctionMax,
            bias: pool1Data,
            activation: BNNSActivation(
                function: BNNSActivationFunctionIdentity,
                alpha: 0,
                beta: 0
            )
        )

        pool1 = BNNSFilterCreatePoolingLayer(&conv1_output, &pool1_output, &pool1_parameters, &filterParams)!

        // ****** conv 2 ******** //

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
                alpha: 0,
                beta: 0
            )
        )

        conv2 = BNNSFilterCreateConvolutionLayer(&pool1_output, &conv2_output, &conv2_parameters, &filterParams)!

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
            x_stride: 2,
            y_stride: 2,
            x_padding: 0,
            y_padding: 0,
            k_width: 2,
            k_height: 2,
            in_channels: conv2_output.channels,
            out_channels: pool2_output.channels,
            pooling_function: BNNSPoolingFunctionMax,
            bias: pool2Data,
            activation: BNNSActivation(
                function: BNNSActivationFunctionIdentity,
                alpha: 0,
                beta: 0
            )
        )

        pool2 = BNNSFilterCreatePoolingLayer(&conv2_output, &pool2_output, &pool2_parameters, &filterParams)!

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

        fullyConnected1 = BNNSFilterCreateFullyConnectedLayer(&fullyConnected_in, &fullyConnected_out, &fullyConnected1_params, &filterParams)!

        // ****** fully connected 1 ******** //

        var output = BNNSVectorDescriptor(
            size: self.labelStringToByte.count,
            data_type: BNNSDataTypeFloat32,
            data_scale: 1,
            data_bias: 0)


        var fullyConnected2_params = BNNSFullyConnectedLayerParameters(
            in_size: fullyConnected_out.size,
            out_size: output.size,
            weights: fullyConnected2Weights,
            bias: fullyConnected2Bias,
            activation: BNNSActivation(
                function: BNNSActivationFunctionIdentity,
                alpha: 0,
                beta: 0
        ))

        fullyConnected2 = BNNSFilterCreateFullyConnectedLayer(&fullyConnected_out, &output, &fullyConnected2_params, &filterParams)!

        dataBuffer1 = Array<Float32>(repeating: 0, count: 6272)
        dataBuffer2 = Array<Float32>(repeating: 0, count: 25088)

        dataPointer1 = UnsafeMutableRawPointer(mutating: dataBuffer1)
        dataPointer2 = UnsafeMutableRawPointer(mutating: dataBuffer2)
    }
    
    
    public func strokeIsScribble(_ stroke: [CGPoint]) -> Bool {
        guard stroke.count > 1 else {
            return false
        }
        
        // Here are magic values I found by scatter plotting a few samples. This method could
        // be improved...
        let intersectionThreshold = 32
        let lengthToAreaThreshold: CGFloat = 0.055
        
        var lengths = Array<CGFloat>(repeating: 0, count: stroke.count - 1)
        var totalLength: CGFloat = 0
        var totalArea: CGFloat = 0
        
        func doubleTriangleArea(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
            return abs(a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
        }
        
        let firstPoint = stroke.first!
        var lastPoint: CGPoint?
        for (index, point) in stroke.enumerated() {
            if let lastPoint = lastPoint {
                let distance = lastPoint.distanceTo(point: point)
                totalLength += distance
                lengths[index - 1] = totalLength
                
                totalArea += doubleTriangleArea(firstPoint, lastPoint, point)
            }
            lastPoint = point
        }
        totalArea /= 2
        
        if (totalLength / totalArea) <= lengthToAreaThreshold {
            // A scribble should have a relatively large length compared to its area
            return false
        }
        
        // A, B, C, D, E, F
        //   2, 4, 6, 8, 10
        
        struct Arc {
            let stroke: ArraySlice<CGPoint>
            let lengths: ArraySlice<CGFloat>
            let startingLength: CGFloat
        }
        
        func split(arc: Arc, midLengthIndex: Int) -> (Arc, Arc) {
            let arc1 = Arc(stroke: arc.stroke.prefix(through: midLengthIndex),
                           lengths: arc.lengths.prefix(upTo: midLengthIndex),
                           startingLength: arc.startingLength)
            
            let arc1EndLength = arc.lengths[midLengthIndex - 1]
            let arc2 = Arc(stroke: arc.stroke.suffix(from: midLengthIndex),
                           lengths: arc.lengths.suffix(from: midLengthIndex),
                           startingLength: arc1EndLength)
            
            return (arc1, arc2)
        }
        
        func midIndex(_ arc: Arc) -> Int? {
            guard arc.stroke.count > 2 else {
                return nil
            }
            
            // Returns nil if the midpoint is the first point
            let arcLength = arc.lengths.last!
            let midDistance = (arcLength - arc.startingLength) / 2
            let midDistancePlusStarting = midDistance + arc.startingLength
            guard let midLengthIndex = arc.lengths.index(where: { $0 > midDistancePlusStarting}),
                midLengthIndex > arc.stroke.startIndex else {
                    return nil
            }
            return midLengthIndex
        }
        
        func averageMidpoint(arc: Arc) -> CGPoint {
            let pointSum = arc.stroke.reduce(CGPoint.zero, +)
            return pointSum / CGFloat(arc.stroke.count)
        }
        /* This is based on an intersection-finding algorithm:
         1. Chop the curve in half, so you've got two arcs.
         2. Draw a circle around the midpoint of each arc.  The radius of the circle is L/2, where L is the length of the arc.  (So the arc must lie entirely inside the circle).
         3. If the circles don't overlap, it is impossible for the two arcs to intersect.  Do nothing.
         4. If the circles do overlap, it is possible that the arcs intersect.  Chop each arc into two pieces, and recurse: for each of the 4 possible pairs, go back to step 1.
         In this case, we don't need the actual intersections but how many times the recursion
         happens, which is an approximation for how intersection-ey a curve is.
         */
        func findRecursiveIntersections(arc1: Arc, midIndex1: Int?, arc2: Arc, midIndex2: Int?) -> Int {
            let point1 = midIndex1 != nil ? arc1.stroke[midIndex1!] : averageMidpoint(arc: arc1)
            let point2 = midIndex2 != nil ? arc2.stroke[midIndex2!] : averageMidpoint(arc: arc2)
            
            
            let arc1Length = arc1.lengths.last! - arc1.startingLength
            let arc2Length = arc2.lengths.last! - arc2.startingLength
            
            // We imagine that a circle of radius arcLength/2 was drawn around each circle. If those
            // circles intersect, then the two arcs might intersect. We divide each up into two more
            // arcs and recurse on each combo.
            if point1.distanceTo(point: point2) >= (arc1Length + arc2Length) / 2 {
                // No intersection
                return 0
            }
            
            if let midIndex1 = midIndex1, let midIndex2 = midIndex2 {
                let (arc1Left, arc1Right) = split(arc: arc1, midLengthIndex: midIndex1)
                let arc1LeftMid = midIndex(arc1Left)
                let arc1RightMid = midIndex(arc1Right)
                let (arc2Left, arc2Right) = split(arc: arc2, midLengthIndex: midIndex2)
                let arc2LeftMid = midIndex(arc2Left)
                let arc2RightMid = midIndex(arc2Right)
                
                return (1 +
                    findRecursiveIntersections(arc1: arc1Left, midIndex1: arc1LeftMid, arc2: arc2Left, midIndex2: arc2LeftMid) +
                    findRecursiveIntersections(arc1: arc1Left, midIndex1: arc1LeftMid, arc2: arc2Right, midIndex2: arc2RightMid) +
                    findRecursiveIntersections(arc1: arc1Right, midIndex1: arc1RightMid, arc2: arc2Left, midIndex2: arc2LeftMid) +
                    findRecursiveIntersections(arc1: arc1Right, midIndex1: arc1RightMid, arc2: arc2Right, midIndex2: arc2RightMid)
                )
            } else {
                // If neither can be split we stop recursing
                return 1
            }
        }
        
        let fullArc = Arc(stroke: stroke.suffix(from: 0), lengths: lengths.suffix(from: 0), startingLength: 0)
        if let fullArcMiddle = midIndex(fullArc) {
            let (fullArcLeft, fullArcRight) = split(arc: fullArc, midLengthIndex: fullArcMiddle)
            let intersectionCount = findRecursiveIntersections(arc1: fullArcLeft, midIndex1: midIndex(fullArcLeft), arc2: fullArcRight, midIndex2: midIndex(fullArcRight))
            
            return intersectionCount > intersectionThreshold
        }
        
        return false
    }
}
