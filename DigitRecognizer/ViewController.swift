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
        layer.strokeColor = UIColor.black.cgColor
        layer.lineWidth = 2
        layer.fillColor = nil
    }
    
    func append(_ point: CGPoint)
    {
        points.append(point)
        
        let path = CGMutablePath()
        for (index, point) in points.enumerated() {
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        layer.path = path;
    }
}

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    var scrollView: UIScrollView!
    var currentStroke: Stroke?
    var previousStrokes: [Stroke] = []
    var digitRecognizer: DigitRecognizer!
    @IBOutlet weak var labelSelector: UISegmentedControl!
    @IBOutlet weak var resultLabel: UILabel!
    
    required init(coder aDecoder: NSCoder) {
        self.digitRecognizer = DigitRecognizer()
        super.init(coder: aDecoder)!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.digitRecognizer = AppDelegate.sharedAppDelegate().digitRecognizer
        self.scrollView = UIScrollView(frame: self.view.bounds)
        self.scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        self.view.insertSubview(self.scrollView, at: 0)
        
        let strokeRecognizer = StrokeGestureRecognizer()
        self.scrollView.addGestureRecognizer(strokeRecognizer)
        strokeRecognizer.addTarget(self, action: #selector(ViewController.handleStroke(recognizer:)))
        
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
                        if lastStrokeLastPoint.distanceTo(point: point) > 150 {
                            wasFarAway = true
                        }
                    }
                }
                
                let selectedSegment = self.labelSelector.selectedSegmentIndex
                if selectedSegment != UISegmentedControlNoSegment {
                    if let currentLabel = self.labelSelector.titleForSegment(at: selectedSegment) {
                        
                        if currentLabel == "Test" {
                            if wasFarAway {
                                self.clearStrokes(sender: nil)
                            }

                            self.digitRecognizer.addStrokeToClassificationQueue(stroke: currentStroke.points)
                            
                            if let classifiedLabels = self.digitRecognizer.recognizeStrokesInQueue() {
                                let writtenNumber = classifiedLabels.reduce("", +)
                                self.resultLabel.text = writtenNumber
                            } else {
                                self.resultLabel.text = "Unknown"
                            }
                            
                        } else {
                            if previousStrokes.count > 0 && wasFarAway {
                                var lastDigit: DigitRecognizer.DigitStrokes = []
                                for previousStroke in self.previousStrokes {
                                    lastDigit.append(previousStroke.points)
                                }
                                self.clearStrokes(sender: nil)
                                
                                if let classification = self.digitRecognizer.classifyDigit(digit: lastDigit) {
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
    
    @IBAction func clearStrokes(sender: AnyObject?) {
        for previousStroke in self.previousStrokes {
            previousStroke.layer.removeFromSuperlayer()
        }
        self.previousStrokes.removeAll(keepingCapacity: false)
        self.digitRecognizer.clearClassificationQueue()
    }
}

