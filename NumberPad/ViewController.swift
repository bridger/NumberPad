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
    }

    func handleStroke(recognizer: StrokeGestureRecognizer) {
        if recognizer.state == UIGestureRecognizerState.Began {
            self.currentStroke = Stroke()
            self.scrollView.layer.addSublayer(self.currentStroke!.layer)
            
            let point = recognizer.locationInView(self.scrollView)
            self.currentStroke!.addPoint(point)
            
        } else if recognizer.state == UIGestureRecognizerState.Changed {
            if let currentStroke = self.currentStroke {
                let point = recognizer.locationInView(self.scrollView)
                currentStroke.addPoint(point)
            }
        } else if recognizer.state == UIGestureRecognizerState.Ended {
            if let currentStroke = self.currentStroke {
                
                // TODO: If this was far enough away from the last stroke, then all previous strokes should be saved
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
                            var currentDigit: DigitStrokes = []
                            if !wasFarAway {
                                for previousStroke in self.previousStrokes {
                                    currentDigit.append(previousStroke.points)
                                }
                            }
                            currentDigit.append(currentStroke.points)
                            
                            if let classification = self.digitClassifier.classifyDigit(currentDigit) {
                                self.resultLabel.text = classification
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
                                    self.resultLabel.text = classification
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
    
    
    @IBAction func clearStrokes(sender: AnyObject?) {
        for previousStroke in self.previousStrokes {
            previousStroke.layer.removeFromSuperlayer()
        }
        self.previousStrokes.removeAll(keepCapacity: false)
    }
}

