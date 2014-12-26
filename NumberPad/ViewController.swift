//
//  ViewController.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/13/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit


class Stroke {
    var points: [CGFloat] = []
    var layer: CAShapeLayer
    
    init(){
        layer = CAShapeLayer()
        layer.strokeColor = UIColor.blackColor().CGColor
        layer.lineWidth = 2
        layer.fillColor = nil
    }
    
    func addPoint(point: CGPoint)
    {
        points.append(point.x)
        points.append(point.y)
        
        let path = CGPathCreateMutable()
        var x: CGFloat = 0
        for (index, y) in enumerate(points) {
            if index % 2 == 0 {
                x = y
                continue
            }
            if index == 1 {
                CGPathMoveToPoint(path, nil, x, y)
            } else {
                CGPathAddLineToPoint(path, nil, x, y)
            }
        }
        layer.path = path;
    }
}


class ViewController: UIViewController, UIGestureRecognizerDelegate {
    
    var scrollView: UIScrollView!
    var currentStroke: Stroke?
    var allStrokes: [Stroke] = []
    var digitClassifier: BitmapDigitClassifier!
    @IBOutlet weak var previewImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.scrollView = UIScrollView(frame: self.view.bounds)
        self.scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        self.view.addSubview(self.scrollView)
        
        let strokeRecognizer = StrokeGestureRecognizer()
        self.scrollView.addGestureRecognizer(strokeRecognizer)
        strokeRecognizer.addTarget(self, action: "handleStroke:")
        
        self.digitClassifier = BitmapDigitClassifier()
        
        self.previewImageView.layer
    }

    func handleStroke(recognizer: StrokeGestureRecognizer) {
        if recognizer.state == UIGestureRecognizerState.Began {
            self.currentStroke = Stroke()
            allStrokes.append(self.currentStroke!)
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
                let featureImage = self.digitClassifier.createFeatureImage(currentStroke.layer.path)
                self.previewImageView.image = featureImage
            }
        }
    }
}

