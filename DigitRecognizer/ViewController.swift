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
    var currentStroke: Stroke?
    var previousStrokes: [Stroke] = []
    var digitRecognizer: DigitRecognizer!
    var digitSampleLibrary: DigitSampleLibrary!
    var batchID: String = "unknown"
    @IBOutlet weak var labelSelector: UISegmentedControl!
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var sampleCountLabel: UILabel?
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.isMultipleTouchEnabled = false
        self.view.isUserInteractionEnabled = true
        self.view.isExclusiveTouch = true

        self.digitRecognizer = AppDelegate.sharedAppDelegate().digitRecognizer
        self.digitSampleLibrary = AppDelegate.sharedAppDelegate().library
        
        for index in 0..<self.labelSelector.numberOfSegments {
            if self.labelSelector.titleForSegment(at: index) == "Test" {
                self.labelSelector.selectedSegmentIndex = index
                break;
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        batchID = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        self.clearStrokes(sender: nil)
        self.updateSampleCountLabel(sender: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }

        let currentStroke = Stroke()
        self.currentStroke = currentStroke
        self.view.layer.addSublayer(self.currentStroke!.layer)

        for coalesced in event?.coalescedTouches(for: touch) ?? [] {
            let point = coalesced.preciseLocation(in: self.view)
            currentStroke.append( point)
        }
        self.resultLabel.text = ""
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let currentStroke = self.currentStroke else {
            return
        }

        for coalesced in event?.coalescedTouches(for: touch) ?? [] {
            let point = coalesced.preciseLocation(in: self.view)
            currentStroke.append( point)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let currentStroke = self.currentStroke {
            currentStroke.layer.removeFromSuperlayer()
            self.currentStroke = nil
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let currentStroke = self.currentStroke else {
            return
        }

        var wasFarAway = false
        if let lastStroke = self.previousStrokes.last {
            if let lastStrokeLastPoint = lastStroke.points.last {
                let point = touch.location(in: self.view)
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
                } else {
                    if previousStrokes.count > 0 && wasFarAway {
                        // Add the previous digit to the library
                        let strokes = previousStrokes.map({ return $0.points })
                        self.digitSampleLibrary.addToLibrary(label: currentLabel, digit: strokes, batchID: batchID)
                        self.clearStrokes(sender: nil)
                        self.updateSampleCountLabel(sender: nil)
                    }
                }

                self.digitRecognizer.addStrokeToClassificationQueue(stroke: currentStroke.points)

                if let classifiedLabels = self.digitRecognizer.recognizeStrokesInQueue() {
                    let writtenNumber = classifiedLabels.reduce("", +)
                    self.resultLabel.text = writtenNumber
                } else {
                    self.resultLabel.text = "Unknown"
                }
            }
        }

        previousStrokes.append(self.currentStroke!)
    }

    @IBAction func updateSampleCountLabel(sender: AnyObject?) {
        var label = ""

        let selectedSegment = self.labelSelector.selectedSegmentIndex
        if selectedSegment != UISegmentedControlNoSegment {
            if let currentLabel = self.labelSelector.titleForSegment(at: selectedSegment) {
                if currentLabel != "Test" {
                    let count = self.digitSampleLibrary.samples[currentLabel]?.count ?? 0
                    label = "\(count) samples"
                }
            }
        }
        self.sampleCountLabel?.text = label
    }

    @IBAction func clearStrokes(sender: AnyObject?) {
        for previousStroke in self.previousStrokes {
            previousStroke.layer.removeFromSuperlayer()
        }
        self.previousStrokes.removeAll(keepingCapacity: false)
        self.digitRecognizer.clearClassificationQueue()
    }
}

