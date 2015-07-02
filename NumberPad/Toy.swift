//
//  Toy.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 6/28/15.
//  Copyright © 2015 Bridger Maxwell. All rights reserved.
//


class Toy : UIView {
    let xConnector: Connector
    let yConnector: Connector
    let angleConnector: Connector
    
    init(image: UIImage, xConnector: Connector, yConnector: Connector, angleConnector: Connector) {
        self.xConnector = xConnector
        self.yConnector = yConnector
        self.angleConnector = angleConnector
        
        super.init(frame: CGRectZero)
        
        let imageView = UIImageView(image: image)
        imageView.sizeToFit()
        self.frame.size = imageView.frame.size
        imageView.frame = self.bounds
        self.addSubview(imageView)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}