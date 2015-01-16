//
//  VisualizeCollectionViewController.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 1/15/15.
//  Copyright (c) 2015 Bridger Maxwell. All rights reserved.
//

import UIKit
import DigitRecognizerSDK

let reuseIdentifier = "ImageCell"

class ImageCell: UICollectionViewCell {
    let imageView: UIImageView
    
    override init(frame: CGRect) {
        imageView = UIImageView()
        super.init(frame: frame)
        imageView.frame = self.contentView.bounds
        self.contentView.addSubview(imageView)
        imageView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
    }
    
    required init(coder aDecoder: NSCoder) {
        imageView = UIImageView()
        super.init(coder: aDecoder)
        imageView.frame = self.contentView.bounds
        self.contentView.addSubview(imageView)
        imageView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
    
}


class VisualizeCollectionViewController: UICollectionViewController {
    
    var digitClassifier: DTWDigitClassifier!
    var digitLabels: [DTWDigitClassifier.DigitLabel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.digitClassifier = AppDelegate.sharedAppDelegate().digitClassifier
        self.digitLabels = Array(digitClassifier.normalizedPrototypeLibrary.keys)
        
        self.collectionView!.registerClass(ImageCell.self, forCellWithReuseIdentifier: reuseIdentifier)
    }
    
    let prototypeSize = CGSizeMake(280, 280)
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.digitLabels = Array(digitClassifier.normalizedPrototypeLibrary.keys)
        if let layout = self.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = prototypeSize
            layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
        }
        
        self.collectionView!.reloadData()
    }

    // MARK: UICollectionViewDataSource
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return digitClassifier.normalizedPrototypeLibrary.count
    }
    
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let label = self.digitLabels[section]
        return digitClassifier.normalizedPrototypeLibrary[label]?.count ?? 0
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as ImageCell
        
        let label = self.digitLabels[indexPath.section]
        let scale = UIScreen.mainScreen().scale
        let prototypeSize = self.prototypeSize
        if let prototype = digitClassifier.normalizedPrototypeLibrary[label]?[indexPath.row] {
            
            UIGraphicsBeginImageContextWithOptions(prototypeSize, true, scale)
            let ctx = UIGraphicsGetCurrentContext()
            
            let transformPointLambda: (CGPoint) -> CGPoint = { point -> CGPoint in
                return CGPointMake((point.x * 0.9 + 0.5) * prototypeSize.width,
                    (point.y * 0.9 + 0.5) * prototypeSize.height)
            }
            for stroke in prototype {
                var firstPoint = true
                for point in stroke {
                    let transformedPoint = transformPointLambda(point)
                    
                    if firstPoint {
                        firstPoint = false
                        CGContextMoveToPoint(ctx, transformedPoint.x, transformedPoint.y)
                    } else {
                        CGContextAddLineToPoint(ctx, transformedPoint.x, transformedPoint.y)
                    }
                }
                CGContextSetStrokeColorWithColor(ctx, UIColor.whiteColor().CGColor)
                CGContextSetLineWidth(ctx, 2)
                CGContextStrokePath(ctx)
                
                for point in stroke {
                    let transformedPoint = transformPointLambda(point)
                    CGContextSetFillColorWithColor(ctx, UIColor.redColor().CGColor)
                    CGContextFillEllipseInRect(ctx, CGRectMake(transformedPoint.x-2, transformedPoint.y-2, 4, 4))
                }
            }
            
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            cell.imageView.image = image
            cell.imageView.layer.borderWidth = 1
        }
        return cell
    }
    
    // MARK: UICollectionViewDelegate
    
    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(collectionView: UICollectionView, shouldHighlightItemAtIndexPath indexPath: NSIndexPath) -> Bool {
    return true
    }
    */
    
    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
    return true
    }
    */
    
    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(collectionView: UICollectionView, shouldShowMenuForItemAtIndexPath indexPath: NSIndexPath) -> Bool {
    return false
    }
    
    override func collectionView(collectionView: UICollectionView, canPerformAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) -> Bool {
    return false
    }
    
    override func collectionView(collectionView: UICollectionView, performAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) {
    
    }
    */
    
}
