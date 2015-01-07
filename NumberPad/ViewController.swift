//
//  ViewController.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/13/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit

class Stroke {
    var points: [CGPoint] = []
    var layer: CAShapeLayer
    
    init(){
        layer = CAShapeLayer()
        layer.strokeColor = UIColor.blackColor().CGColor
        layer.lineWidth = 2
        layer.fillColor = nil
    }
    
    func addPoint(point: CGPoint)
    {
        points.append(point)
        
        let path = CGPathCreateMutable()
        var x: CGFloat = 0
        for (index, point) in enumerate(points) {
            if index == 0 {
                CGPathMoveToPoint(path, nil, point.x, point.y)
            } else {
                CGPathAddLineToPoint(path, nil, point.x, point.y)
            }
        }
        layer.path = path;
    }
}

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    var scrollView: UIScrollView!
    var currentStroke: Stroke?
    var previousStrokes: [Stroke] = []
    var digitClassifier: DTWDigitClassifier
    @IBOutlet weak var labelSelector: UISegmentedControl!
    @IBOutlet weak var resultLabel: UILabel!

    required init(coder aDecoder: NSCoder) {
        self.digitClassifier = DTWDigitClassifier()
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.scrollView = UIScrollView(frame: self.view.bounds)
        self.scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        self.view.insertSubview(self.scrollView, atIndex: 0)
        
        let strokeRecognizer = StrokeGestureRecognizer()
        self.scrollView.addGestureRecognizer(strokeRecognizer)
        strokeRecognizer.addTarget(self, action: "handleStroke:")
        
        self.labelSelector.selectedSegmentIndex = 10
    }

    func handleStroke(recognizer: StrokeGestureRecognizer) {
        if recognizer.state == UIGestureRecognizerState.Began {
            self.currentStroke = Stroke()
            self.scrollView.layer.addSublayer(self.currentStroke!.layer)
            
            let point = recognizer.locationInView(self.scrollView)
            self.currentStroke!.addPoint(point)
            self.resultLabel.text = ""
            
        } else if recognizer.state == UIGestureRecognizerState.Changed {
            if let currentStroke = self.currentStroke {
                let point = recognizer.locationInView(self.scrollView)
                currentStroke.addPoint(point)
            }
        } else if recognizer.state == UIGestureRecognizerState.Ended {
            if let currentStroke = self.currentStroke {
                
                var wasFarAway = false
                if let lastStroke = self.previousStrokes.last {
                    if let lastStrokeLastPoint = lastStroke.points.last {
                        let point = recognizer.locationInView(self.scrollView)
                        if euclidianDistance(lastStrokeLastPoint, point) > 150 {
                            wasFarAway = true
                        }
                    }
                }
                
                let selectedSegment = self.labelSelector.selectedSegmentIndex
                if selectedSegment != UISegmentedControlNoSegment {
                    if let currentLabel = self.labelSelector.titleForSegmentAtIndex(selectedSegment) {
                        
                        if currentLabel == "Test" {
                            var allStrokes: DigitStrokes = []
                            if !wasFarAway {
                                for previousStroke in self.previousStrokes {
                                    allStrokes.append(previousStroke.points)
                                }
                            }
                            allStrokes.append(currentStroke.points)
                            
                            if let writtenNumber = self.readNumberFromStrokes(allStrokes) {
                                self.resultLabel.text = "\(writtenNumber)"
                            } else {
                                self.resultLabel.text = "Unknown"
                            }
                            if wasFarAway {
                                self.clearStrokes(nil)
                            }
                            
                        } else {
                            if previousStrokes.count > 0 && wasFarAway {
                                var lastDigit: DigitStrokes = []
                                for previousStroke in self.previousStrokes {
                                    lastDigit.append(previousStroke.points)
                                }
                                self.clearStrokes(nil)
                                
                                self.digitClassifier.learnDigit(currentLabel, digit: lastDigit)
                                if let classification = self.digitClassifier.classifyDigit(lastDigit) {
                                    self.resultLabel.text = classification.Label
                                } else {
                                    self.resultLabel.text = "Unknown"
                                }
                            }
                        }
                    }
                }
                
                previousStrokes.append(self.currentStroke!)
            }
        }
    }
    
    // If any one stroke can't be classified, this will return nil
    func readNumberFromStrokes(strokes: [[CGPoint]]) -> Int? {
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
            return self.digitClassifier.classifyDigit([singleStrokeDigit])
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
                            if let twoStrokeClassification = self.digitClassifier.classifyDigit([strokes[index], strokes[index + 1]]) {
                                let nextStrokeClassification = singleStrokeClassifications[index + 1]
                                
                                var mustMatch = thisStrokeClassification == nil || nextStrokeClassification == nil;
                                if (mustMatch || twoStrokeClassification.Confidence < thisStrokeClassification!.Confidence || twoStrokeClassification.Confidence < nextStrokeClassification!.Confidence) {
                                    
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
        
        // Translate from labels to an integer
        let combinedLabels = labels.reduce("", +)
        return combinedLabels.toInt()
    }
    
    
    @IBAction func clearStrokes(sender: AnyObject?) {
        for previousStroke in self.previousStrokes {
            previousStroke.layer.removeFromSuperlayer()
        }
        self.previousStrokes.removeAll(keepCapacity: false)
    }
}

