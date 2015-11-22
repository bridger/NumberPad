//
//  IntroViewController.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 11/21/15.
//  Copyright © 2015 Bridger Maxwell. All rights reserved.
//

import UIKit
import DigitRecognizerSDK

class IntroViewController: UIViewController {
    
    let digitClassifier = DTWDigitClassifier()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let path = NSBundle.mainBundle().pathForResource("bridger_normalized", ofType: "json") {
            loadData(path)
        }
        
        let pairingView = FTPenManager.sharedInstance().pairingButtonWithStyle(.Debug);
        self.view.addAutoLayoutSubview(pairingView)
        self.view.addVerticalConstraints(|-15-[pairingView])
        self.view.addHorizontalConstraints(|-15-[pairingView])
    }
    
    func loadData(path: String) {
        if let jsonLibrary = DTWDigitClassifier.jsonLibraryFromFile(path) {
            self.digitClassifier.loadData(jsonLibrary, loadNormalizedData: true)
        }
    }

    func configureNewCanvas() -> CanvasViewController {
        let canvas = CanvasViewController(digitClassifier: self.digitClassifier)
        
        let backButton = UIButton()
        backButton.setTitle("< Back", forState: .Normal)
        backButton.titleLabel?.font = UIFont.boldSystemFontOfSize(18)
        backButton.setTitleColor(UIColor.blueColor(), forState: .Normal)
        canvas.view.addAutoLayoutSubview(backButton)
        canvas.view.addHorizontalConstraints(|-6-[backButton])
        canvas.view.addVerticalConstraints(|-15-[backButton])
        backButton.addTarget(self, action: "backPressed", forControlEvents: .TouchUpInside)
        
        return canvas
    }
    
    func backPressed() {
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    @IBAction func startSandbox(sender: AnyObject) {
        let canvas = configureNewCanvas()
        
        self.navigationController?.pushViewController(canvas, animated: true)
    }

    @IBAction func startCircumferenceDemo(sender: AnyObject) {
        let canvas = configureNewCanvas()
        
        let diameterConnector = Connector()
        let diameterLabel = ConnectorLabel(connector: diameterConnector)
        diameterLabel.scale = 0
        diameterLabel.name = "diameter"
        diameterLabel.sizeToFit()
        diameterLabel.center = CGPointMake(200, self.view.frame.size.height - 300)
        
        let circumferenceConnector = Connector()
        let circumferenceLabel = ConnectorLabel(connector: circumferenceConnector)
        circumferenceLabel.scale = 0
        circumferenceLabel.name = "circumference"
        circumferenceLabel.sizeToFit()
        circumferenceLabel.center = CGPointMake(200, self.view.frame.size.height - 180)
        
        let initialDiameter: Double = 160
        
        canvas.addConnectorLabel(circumferenceLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(circumferenceLabel, value: initialDiameter * M_PI_4)
        
        let newToy = CirclesToy(diameterConnector: diameterConnector, circumferenceConnector: circumferenceConnector)
        canvas.view.addSubview(newToy)
        newToy.frame = self.view.bounds
        newToy.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        canvas.toys.append(newToy)
        
        canvas.addConnectorLabel(diameterLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(diameterLabel, value: initialDiameter)
        
        self.navigationController?.pushViewController(canvas, animated: true)
    }
    
    
    @IBAction func startFootballDemo(sender: AnyObject) {
        let canvas = configureNewCanvas()
        
        let xConnector = Connector()
        let xLabel = ConnectorLabel(connector: xConnector)
        xLabel.scale = 0
        xLabel.name = "X"
        xLabel.sizeToFit()
        xLabel.center = CGPointMake(60, 250)
        
        let yConnector = Connector()
        let yLabel = ConnectorLabel(connector: yConnector)
        yLabel.scale = 0
        yLabel.name = "Y"
        yLabel.sizeToFit()
        yLabel.center = CGPointMake(self.view.bounds.size.width - 60, 250)
        
        canvas.addConnectorLabel(yLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(yLabel, value: 350)
        
        canvas.addConnectorLabel(xLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(xLabel, value: 200)
        
        let timeConnector = Connector()
        let timeLabel = ConnectorLabel(connector: timeConnector)
        timeLabel.name = "time"
        timeLabel.sizeToFit()
        timeLabel.center = CGPointMake(self.view.bounds.size.width / 2, 40)
        
        let newToy = MotionToy(image: UIImage(named: "football")!, xConnector: xConnector, yConnector: yConnector, driverConnector: timeConnector)
        canvas.scrollView.addSubview(newToy)
        canvas.toys.append(newToy)
        
        canvas.addConnectorLabel(timeLabel, topPriority: true, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(timeLabel, value: 5)
        
        self.navigationController?.pushViewController(canvas, animated: true)
    }

}
