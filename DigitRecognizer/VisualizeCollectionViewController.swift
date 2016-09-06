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
    let imageView: UIImageView = UIImageView()
    let indexLabel: UILabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageCellSetup()
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        imageCellSetup()
    }
    
    func imageCellSetup() {
        imageView.frame = self.contentView.bounds
        self.contentView.addSubview(imageView)
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        indexLabel.text = "Mj"
        indexLabel.sizeToFit()
        indexLabel.frame = CGRect(x: 0, y:  self.contentView.bounds.height  - indexLabel.frame.size.height, width:  self.contentView.bounds.width, height: indexLabel.frame.height)
        self.contentView.addSubview(indexLabel)
        indexLabel.textColor = UIColor.gray
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        indexLabel.text = ""
    }
    
}


class VisualizeCollectionViewController: UICollectionViewController {
    
    var digitLibrary: DigitSampleLibrary!
    var digitRecognizer: DigitRecognizer!
    var digitLabels: [DigitSampleLibrary.DigitLabel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.digitLibrary = AppDelegate.sharedAppDelegate().library
        self.digitLabels = Array(digitLibrary.samples.keys)
        self.digitRecognizer = AppDelegate.sharedAppDelegate().digitRecognizer
        
        self.collectionView!.register(ImageCell.self, forCellWithReuseIdentifier: reuseIdentifier)
    }
    
    let prototypeSize = CGSize(width: 56, height: 56)
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let layout = self.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = prototypeSize
            layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
        }
        
        self.collectionView!.reloadData()
    }

    // MARK: UICollectionViewDataSource
    
    override func numberOfSections(in: UICollectionView) -> Int {
        self.digitLabels = Array(digitLibrary.samples.keys)
        return self.digitLabels.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let label = self.digitLabels[section]
        return digitLibrary.samples[label]?.count ?? 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ImageCell
        
        let label = self.digitLabels[indexPath.section]
        if let prototype = digitLibrary.samples[label]?[indexPath.row] {
            let strokes = DigitRecognizer.normalizeDigit(inputDigit: prototype.strokes) ?? []
            let image = renderToImage(normalizedStrokes: strokes, size: ImageSize(width: 28, height: 28))
            cell.imageView.image = image
            cell.imageView.layer.borderWidth = 1

            digitRecognizer.clearClassificationQueue()
            for stroke in prototype.strokes {
                digitRecognizer.addStrokeToClassificationQueue(stroke: stroke)
            }
            var displayLabel = "unknown"
            var correct = false

            if let recognized = digitRecognizer.recognizeStrokesInQueue() {
                displayLabel = recognized.reduce("", +)
                correct = displayLabel == label
            }
            
            cell.indexLabel.text = displayLabel
            cell.imageView.layer.borderColor = correct ? UIColor.darkGray.cgColor : UIColor.red.cgColor
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
