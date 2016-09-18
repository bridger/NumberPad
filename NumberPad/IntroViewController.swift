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
    
    let digitRecognizer = DigitRecognizer()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set all buttons to be aspectFit. This is kind of a hack because
        // I couldn't find the property in IB
        for subview in self.view.subviews.flatMap({ $0.subviews} ) {
            if let button = subview as? UIButton {
                button.imageView?.contentMode = .scaleAspectFit
            }
        }
    }

    func configureNewCanvas() -> CanvasViewController {
        let canvas = CanvasViewController(digitRecognizer: self.digitRecognizer)
        canvas.view.clipsToBounds = true
        
        let backButton = UIButton()
        backButton.setTitle("< Back", for: [])
        backButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        backButton.setTitleColor(UIColor.backgroundColor(), for: [])
        canvas.view.addAutoLayoutSubview(subview: backButton)
        canvas.view.addHorizontalConstraints(|-9-[backButton])
        canvas.view.addVerticalConstraints(|-20-[backButton])
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
        diameterLabel.scale = -1
        diameterLabel.name = "diameter"
        diameterLabel.color = CircleLayer.diameterColor
        diameterLabel.sizeToFit()
        diameterLabel.center = CGPoint(x: self.view.frame.size.width / 2, y: 230)
        
        let circumferenceConnector = Connector()
        let circumferenceLabel = ConnectorLabel(connector: circumferenceConnector)
        circumferenceLabel.scale = -1
        circumferenceLabel.name = "circumference"
        circumferenceLabel.color = CircleLayer.circumferenceColor
        circumferenceLabel.sizeToFit()
        circumferenceLabel.center = CGPoint(x: self.view.frame.size.width / 2, y: 150)
        
        let initialDiameter: Double = 10
        
        let newToy = CirclesToy(diameterConnector: diameterConnector, circumferenceConnector: circumferenceConnector)
        canvas.view.addSubview(newToy)
        newToy.frame = self.view.bounds
        newToy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.toys.append(newToy)
        
        canvas.addConnectorLabel(label: diameterLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: diameterLabel, value: initialDiameter)
        
        canvas.addConnectorLabel(label: circumferenceLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: circumferenceLabel, value: initialDiameter * 3 * M_PI_4)
        
        self.navigationController?.pushViewController(canvas, animated: true)
    }
    
    @IBAction func startPythagoreanDemo(sender: AnyObject) {
        
        let canvas = configureNewCanvas()
        
        // Some pythagorean tripes:
        //  13  12  5
        //  15  12  9
        //  20  12  16
        //  17  15  8
        
        let aConnector = Connector()
        let aLabel = ConnectorLabel(connector: aConnector)
        aLabel.scale = -1
        aLabel.color = PythagorasToy.aColor
        aLabel.sizeToFit()
        aLabel.center = CGPoint(x: 60, y: 250)
        
        let bConnector = Connector()
        let bLabel = ConnectorLabel(connector: bConnector)
        bLabel.scale = -1
        bLabel.color = PythagorasToy.bColor
        bLabel.sizeToFit()
        bLabel.center = CGPoint(x: self.view.bounds.size.width - 60, y: 250)
        
        canvas.addConnectorLabel(label: bLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: bLabel, value: 12)
        
        canvas.addConnectorLabel(label: aLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: aLabel, value: 9)
        
        let cConnector = Connector()
        let cLabel = ConnectorLabel(connector: cConnector)
        cLabel.scale = -1
        cLabel.color = PythagorasToy.cColor
        cLabel.sizeToFit()
        cLabel.center = CGPoint(x: self.view.bounds.size.width / 2, y: self.view.bounds.size.height - 300)
        
        let newToy = PythagorasToy(aConnector: aConnector, bConnector: bConnector, cConnector: cConnector)
        canvas.view.addSubview(newToy)
        newToy.frame = self.view.bounds
        newToy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.toys.append(newToy)
        
        canvas.addConnectorLabel(label: cLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: cLabel, value: 13)
        
        self.navigationController?.pushViewController(canvas, animated: true)
    }
    
    @IBAction func startSquareDemo(sender: AnyObject) {
        
        let canvas = configureNewCanvas()
        
        let sideConnector = Connector()
        let sideLabel = ConnectorLabel(connector: sideConnector)
        sideLabel.scale = -1
        sideLabel.name = "side"
        sideLabel.color = SquareLayer.sideColor
        sideLabel.sizeToFit()
        sideLabel.center = CGPoint(x: 60, y: 150)
        
        let squareConnector = Connector()
        let squareLabel = ConnectorLabel(connector: squareConnector)
        squareLabel.scale = 0
        squareLabel.name = "area"
        squareLabel.color = SquareLayer.areaColor
        squareLabel.sizeToFit()
        squareLabel.center = CGPoint(x: self.view.bounds.size.width - 60, y: 150)
        
        canvas.addConnectorLabel(label: sideLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: sideLabel, value: 9)
        
        let newToy = SquaresToy(sideConnector: sideConnector, areaConnector: squareConnector)
        canvas.view.addSubview(newToy)
        newToy.frame = self.view.bounds
        newToy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.toys.append(newToy)
        
        canvas.addConnectorLabel(label: squareLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: squareLabel, value: 40)
        
        self.navigationController?.pushViewController(canvas, animated: true)
    }
    
    @IBAction func startFootballDemo(sender: AnyObject) {
        let canvas = configureNewCanvas()
        
        let fieldImage = UIImage(named: "field")!
        let fieldColor = UIColor(patternImage: fieldImage)
        let fieldView = UIView()
        let fieldHeight = fieldImage.size.height
        fieldView.heightAnchor.constraint(equalToConstant: fieldHeight).isActive = true
        fieldView.backgroundColor = fieldColor
        canvas.view.addAutoLayoutSubview(subview: fieldView)
        canvas.view.sendSubview(toBack: fieldView)
        canvas.view.addHorizontalConstraints(|[fieldView]|)
        canvas.view.addVerticalConstraints([fieldView]|)
        
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
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: yLabel, value: 300)
        
        canvas.addConnectorLabel(label: xLabel, topPriority: false, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: xLabel, value: 200)
        
        let timeConnector = Connector()
        let timeLabel = ConnectorLabel(connector: timeConnector)
        timeLabel.name = "time"
        timeLabel.sizeToFit()
        timeLabel.center = CGPoint(x: self.view.bounds.size.width / 2, y: 40)
        
        let newToy = MotionToy(image: UIImage(named: "football")!, xConnector: xConnector, yConnector: yConnector, driverConnector: timeConnector)
        newToy.yOffset = fieldHeight
        canvas.scrollView.addSubview(newToy)
        canvas.toys.append(newToy)
        
        canvas.addConnectorLabel(label: timeLabel, topPriority: true, automaticallyConnect: false)
        canvas.selectConnectorLabelAndSetToValue(connectorLabel: timeLabel, value: 5)
        
        self.navigationController?.pushViewController(canvas, animated: true)
    }

}
