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
    let driverConnector: Connector
    let image: UIImage
    
    init(image: UIImage, xConnector: Connector, yConnector: Connector, angleConnector: Connector, driverConnector: Connector) {
        self.xConnector = xConnector
        self.yConnector = yConnector
        self.angleConnector = angleConnector
        self.driverConnector = driverConnector
        self.image = image
        
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
    
    var activeGhosts: [UIView] = []
    var reuseGhosts: [UIView] = []
    
    func createNewGhost(percent: Double) -> UIView {
        let ghost: UIView
        if let oldGhost = reuseGhosts.popLast() {
            ghost = oldGhost
        } else {
            ghost = UIImageView(image: self.image)
            ghost.sizeToFit()
        }
        let alpha = (1.0 - abs(percent)) * 0.35
        ghost.alpha = CGFloat(alpha)
        
        activeGhosts.append(ghost)
        return ghost
    }
    
    func removeAllGhosts() {
        for ghost in activeGhosts {
            ghost.removeFromSuperview()
            reuseGhosts.append(ghost)
        }
        activeGhosts = []
    }
}