//
//  ViewController.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/13/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit
import DigitRecognizerSDK

class Stroke {
    var points: [CGPoint] = []
    var layer: CAShapeLayer
    
    init(){
        layer = CAShapeLayer()
        layer.strokeColor = UIColor.black().cgColor
        layer.lineWidth = 2
        layer.fillColor = nil
    }
    
    func append( CGPoint)
    {
        points.append(point)
        
        let path = CGMutablePath()
        for (index, point) in points.enumerated() {
            if index == 0 {
                path.moveTo(nil, x: point.x, y: point.y)
            } else {
                path.addLineTo(nil, x: point.x, y: point.y)
            }
        }
        layer.path = path;
    }
}

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    var scrollView: UIScrollView!
    var currentStroke: Stroke?
    var previousStrokes: [Stroke] = []
    var digitClassifier: DTWDigitClassifier!
    @IBOutlet weak var labelSelector: UISegmentedControl!
    @IBOutlet weak var resultLabel: UILabel!
    
    required init(coder aDecoder: NSCoder) {
        self.digitClassifier = DTWDigitClassifier()
        super.init(coder: aDecoder)!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.digitClassifier = AppDelegate.sharedAppDelegate().digitClassifier
        self.scrollView = UIScrollView(frame: self.view.bounds)
        self.scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        self.view.insertSubview(self.scrollView, at: 0)
        
        let strokeRecognizer = StrokeGestureRecognizer()
        self.scrollView.addGestureRecognizer(strokeRecognizer)
        strokeRecognizer.addTarget(self, action: Selector("handleStroke:"))
        
        for index in 0..<self.labelSelector.numberOfSegments {
            if self.labelSelector.titleForSegment(at: index) == "Test" {
                self.labelSelector.selectedSegmentIndex = index
                break;
            }
        }
    }
    
    func handleStroke(recognizer: StrokeGestureRecognizer) {
        if recognizer.state == UIGestureRecognizerState.began {
            let currentStroke = Stroke()
            self.currentStroke = currentStroke
            self.scrollView.layer.addSublayer(self.currentStroke!.layer)
            
            let point = recognizer.location(in: self.scrollView)
            currentStroke.append( point)
            self.resultLabel.text = ""
            
        } else if recognizer.state == UIGestureRecognizerState.changed {
            if let currentStroke = self.currentStroke {
                let point = recognizer.location(in: self.scrollView)
                currentStroke.append( point)
            }
        } else if recognizer.state == UIGestureRecognizerState.ended {
            if let currentStroke = self.currentStroke {
                
                var wasFarAway = false
                if let lastStroke = self.previousStrokes.last {
                    if let lastStrokeLastPoint = lastStroke.points.last {
                        let point = recognizer.location(in: self.scrollView)
                        if euclidianDistance(a: lastStrokeLastPoint, b: point) > 150 {
                            wasFarAway = true
                        }
                    }
                }
                
                let selectedSegment = self.labelSelector.selectedSegmentIndex
                if selectedSegment != UISegmentedControlNoSegment {
                    if let currentLabel = self.labelSelector.titleForSegment(at: selectedSegment) {
                        
                        if currentLabel == "Test" {
                            var allStrokes: DTWDigitClassifier.DigitStrokes = []
                            if !wasFarAway {
                                for previousStroke in self.previousStrokes {
                                    allStrokes.append(previousStroke.points)
                                }
                            }
                            allStrokes.append(currentStroke.points)
                            
                            if let writtenNumber = self.readStringFromStrokes(strokes: allStrokes) {
                                self.resultLabel.text = writtenNumber
                            } else {
                                self.resultLabel.text = "Unknown"
                            }
                            if wasFarAway {
                                self.clearStrokes(sender: nil)
                            }
                            
                        } else {
                            if previousStrokes.count > 0 && wasFarAway {
                                var lastDigit: DTWDigitClassifier.DigitStrokes = []
                                for previousStroke in self.previousStrokes {
                                    lastDigit.append(previousStroke.points)
                                }
                                self.clearStrokes(sender: nil)
                                
                                self.digitClassifier.learnDigit(label: currentLabel, digit: lastDigit)
                                if let classification = self.digitClassifier.classifyDigit(digit: lastDigit) {
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
    func readStringFromStrokes(strokes: [[CGPoint]]) -> String? {
        if let classifiedLabels = self.digitClassifier.classifyMultipleDigits(strokes: strokes) {
            return classifiedLabels.reduce("", combine: +)
        } else {
            return nil
        }
    }
    
    
    @IBAction func clearStrokes(sender: AnyObject?) {
        for previousStroke in self.previousStrokes {
            previousStroke.layer.removeFromSuperlayer()
        }
        self.previousStrokes.removeAll(keepingCapacity: false)
    }
}

