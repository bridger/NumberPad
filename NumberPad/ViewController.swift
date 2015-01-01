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
        
        var labels: [DigitLabel] = []
        
        var lastStrokeClassification: DTWDigitClassifier.Classification? = nil
        var lastStrokeNeedClassifying = false
        for index in 0..<strokes.count {
            // We need to decide if we want classify this stroke by itself, or with the last stroke
            let singleStrokeDigit = strokes[index]
            let singleStrokeClassification = self.digitClassifier.classifyDigit([singleStrokeDigit])
            if singleStrokeClassification == nil {
                println("Could not classify stroke \(index) on its own")
            }
            
            if lastStrokeNeedClassifying {
                if let twoStrokeClassification = self.digitClassifier.classifyDigit([strokes[index-1], strokes[index]]) {
                    var mustMatch = lastStrokeClassification == nil || singleStrokeClassification == nil;
                    if (mustMatch || twoStrokeClassification.Confidence < lastStrokeClassification!.Confidence || twoStrokeClassification.Confidence < singleStrokeClassification!.Confidence) {
                        
                        // Sweet, the double stroke classification is the best one
                        lastStrokeClassification = nil
                        lastStrokeNeedClassifying = false
                        labels.append(twoStrokeClassification.Label)
                        continue
                    }
                }
                
                // If we made it to here, then trying to classify it together with the last stroke didn't work. That means we must commit the single-stroke classification for lastStroke, and wait until next iteration to get the final work on the current stroke
                if let lastStrokeClassification = lastStrokeClassification {
                    labels.append(lastStrokeClassification.Label)
                } else {
                    println("Could not classify stroke \(index - 1)")
                    // Uh oh, the last stroke couldn't be classified at all. Bail?
                    return nil
                }
            }
            
            lastStrokeClassification = singleStrokeClassification
            lastStrokeNeedClassifying = true
        }
        
        if lastStrokeNeedClassifying {
            if let lastStrokeClassification = lastStrokeClassification {
                labels.append(lastStrokeClassification.Label)
            } else {
                // Uh oh, the last stroke couldn't be classified at all. Bail?
                println("Could not classify the last stroke")
                return nil
            }
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

