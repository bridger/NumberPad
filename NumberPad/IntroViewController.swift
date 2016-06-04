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
        
        if let path = NSBundle.main().pathForResource("bridger_normalized", ofType: "json") {
            loadData(path: path)
        }
        
        // TODO: Fix in swift3
//        let pairingView = FTPenManager.sharedInstance().pairingButton(with: .debug);
//        self.view.addAutoLayoutSubview(subview: pairingView!)
//        self.view.addVerticalConstraints(|-15-[pairingView])
//        self.view.addHorizontalConstraints(|-15-[pairingView])
    }
    
    func loadData(path: String) {
        if let jsonLibrary = DTWDigitClassifier.jsonLibraryFromFile(path: path) {
            self.digitClassifier.loadData(jsonData: jsonLibrary, loadNormalizedData: true)
        }
    }

    func configureNewCanvas() -> CanvasViewController {
        let canvas = CanvasViewController(digitClassifier: self.digitClassifier)
        
        let backButton = UIButton()
        backButton.setTitle("< Back", for: [])
        backButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        backButton.setTitleColor(UIColor.blue(), for: [])
        canvas.view.addAutoLayoutSubview(subview: backButton)
        canvas.view.addHorizontalConstraints(|-6-[backButton])
        canvas.view.addVerticalConstraints(|-15-[backButton])
        backButton.addTarget(self, action: #selector(IntroViewController.backPressed), for: .touchUpInside)
        
        return canvas
    }
    
    func backPressed() {
        _ = self.navigationController?.popViewController(animated: true)
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
        diameterLabel.center = CGPoint(x: 200, y: self.view.frame.size.height - 300)
        
        let circumferenceConnector = Connector()
        let circumferenceLabel = ConnectorLabel(connector: circumferenceConnector)
        circumferenceLabel.scale = 0
        circumferenceLabel.name = "circumference"
        circumferenceLabel.sizeToFit()
        circumferenceLabel.center = CGPoint(x: 200, y: self.view.frame.size.height - 180)
        
        let initialDiameter: Double = 160
        
        canvas.addConnectorLabel(label: circumferenceLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: circumferenceLabel, value: initialDiameter * M_PI_4)
        
        let newToy = CirclesToy(diameterConnector: diameterConnector, circumferenceConnector: circumferenceConnector)
        canvas.view.addSubview(newToy)
        newToy.frame = self.view.bounds
        newToy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.toys.append(newToy)
        
        canvas.addConnectorLabel(label: diameterLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: diameterLabel, value: initialDiameter)
        
        self.navigationController?.pushViewController(canvas, animated: true)
    }
    
    @IBAction func startPythagoreanDemo(sender: AnyObject) {
        
        let canvas = configureNewCanvas()
        
        let aConnector = Connector()
        let aLabel = ConnectorLabel(connector: aConnector)
        aLabel.scale = 0
        aLabel.name = "📗"
        aLabel.sizeToFit()
        aLabel.center = CGPoint(x: 60, y: 250)
        
        let bConnector = Connector()
        let bLabel = ConnectorLabel(connector: bConnector)
        bLabel.scale = 0
        bLabel.name = "🔷"
        bLabel.sizeToFit()
        bLabel.center = CGPoint(x: self.view.bounds.size.width - 60, y: 250)
        
        canvas.addConnectorLabel(label: bLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: bLabel, value: 150)
        
        canvas.addConnectorLabel(label: aLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: aLabel, value: 50)
        
        let cConnector = Connector()
        let cLabel = ConnectorLabel(connector: cConnector)
        cLabel.scale = 0
        cLabel.name = "🔶"
        cLabel.sizeToFit()
        cLabel.center = CGPoint(x: self.view.bounds.size.width / 2, y: self.view.bounds.size.height - 300)
        
        let newToy = PythagorasToy(aConnector: aConnector, bConnector: bConnector, cConnector: cConnector)
        canvas.view.addSubview(newToy)
        newToy.frame = self.view.bounds
        newToy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.toys.append(newToy)
        
        canvas.addConnectorLabel(label: cLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: cLabel, value: 120)
        
        self.navigationController?.pushViewController(canvas, animated: true)
    }
    
    @IBAction func startFootballDemo(sender: AnyObject) {
        let canvas = configureNewCanvas()
        
        let xConnector = Connector()
        let xLabel = ConnectorLabel(connector: xConnector)
        xLabel.scale = 0
        xLabel.name = "X"
        xLabel.sizeToFit()
        xLabel.center = CGPoint(x: 60, y: 250)
        
        let yConnector = Connector()
        let yLabel = ConnectorLabel(connector: yConnector)
        yLabel.scale = 0
        yLabel.name = "Y"
        yLabel.sizeToFit()
        yLabel.center = CGPoint(x: self.view.bounds.size.width - 60, y: 250)
        
        canvas.addConnectorLabel(label: yLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: yLabel, value: 350)
        
        canvas.addConnectorLabel(label: xLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: xLabel, value: 200)
        
        let timeConnector = Connector()
        let timeLabel = ConnectorLabel(connector: timeConnector)
        timeLabel.name = "time"
        timeLabel.sizeToFit()
        timeLabel.center = CGPoint(x: self.view.bounds.size.width / 2, y: 40)
        
        let newToy = MotionToy(image: UIImage(named: "football")!, xConnector: xConnector, yConnector: yConnector, driverConnector: timeConnector)
        canvas.scrollView.addSubview(newToy)
        canvas.toys.append(newToy)
        
        canvas.addConnectorLabel(label: timeLabel, topPriority: true, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: timeLabel, value: 5)
        
        self.navigationController?.pushViewController(canvas, animated: true)
    }

}
