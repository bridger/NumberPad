//
//  AppDelegate.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/13/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit
import DigitRecognizerSDK

let filePrefix = "SavedLibraries-"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    /*
      To add another digit:
      Change the storyboard to have another character in the segmented control. Make sure onlySaveNormalizedData. Then, run the app and input a bunch of samples for the new digit. Once you are done, copy the resulting file from the Documents directory. It is the new "training" file. Replace the existing train file. Now, temporarily set onlySaveNormalizedData to true. Launch the app and then send it to the background to re-save the training data as a normalized set. Replace the normalized.json file with the resulting file.
    */
    let onlySaveNormalizedData = false
    
    var window: UIWindow?
    var library: DigitSampleLibrary = DigitSampleLibrary()
    var digitRecognizer: DigitRecognizer = DigitRecognizer()
    
    class func sharedAppDelegate() -> AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        if let lastSave = newestSavedData() {
            let path = self.documentsDirectory().appendingPathComponent(lastSave)!.path
            loadData(path: path, legacyBatchID: "unknown")
        } else {
            loadData(path: Bundle.main.path(forResource: "bridger_all", ofType: "json")!, legacyBatchID: "bridger")
            loadData(path: Bundle.main.path(forResource: "ujipenchars2", ofType: "json")!, legacyBatchID: "ujipen2")
        }
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        saveData()
    }
    
    func documentsDirectory() -> NSURL {
        let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0] as String
        return NSURL(fileURLWithPath: path)
    }
    
    func saveData() {
        let dataToSave = self.library.jsonDataToSave()
        
        let saveNumber: Int
        if let lastSave = newestSavedData(), let lastNumber = Int(lastSave.substring(from: filePrefix.endIndex))  {
            saveNumber = lastNumber + 1
        }
        else
        {
            saveNumber = 1
        }
        
        let documentName = self.documentsDirectory().appendingPathComponent(filePrefix + String(saveNumber))!
        
        do {
            let jsonObject = try JSONSerialization.data(withJSONObject: dataToSave, options: [])
            try jsonObject.write(to: documentName)
        } catch let error as NSError {
            print("Couldn't save data \(error)")
        }
    }
    
    func loadData(path: String, legacyBatchID: String) {
        if let jsonLibrary = DigitSampleLibrary.jsonLibraryFromFile(path: path) {
            self.library.loadData(jsonData: jsonLibrary, legacyBatchID: legacyBatchID)
        }
    }
    
    
    func newestSavedData() -> String? {
        let contents: [String]?
        do {
            contents = try FileManager.default.contentsOfDirectory(atPath: self.documentsDirectory().path!)
        } catch _ {
            contents = nil
        }
        if contents != nil {
            if let contents = contents {
                let filtered = contents.filter({ string in
                    return string.hasPrefix(filePrefix)
                }).sorted(by: { (string1, string2) in
                    return string1.compare(string2) == ComparisonResult.orderedAscending
                })
                
                return filtered.last
            }
        }
        
        return nil
    }
    
    func saveAsBinary(library: DigitSampleLibrary.PrototypeLibrary, filepath: String, testPercentage: CGFloat) {
        guard let trainImagesFile = OutputStream(toFileAtPath: filepath + "-images-train", append: false) else {
            fatalError("Couldn't open output file")
        }
        trainImagesFile.open()
        defer { trainImagesFile.close() }
        
        guard let trainLabelsFile = OutputStream(toFileAtPath: filepath + "-labels-train", append: false) else {
            fatalError("Couldn't open output file")
        }
        trainLabelsFile.open()
        defer { trainLabelsFile.close() }
        
        
        guard let testImagesFile = OutputStream(toFileAtPath: filepath + "-images-test", append: false) else {
            fatalError("Couldn't open output file")
        }
        testImagesFile.open()
        defer { testImagesFile.close() }
        
        guard let testLabelsFile = OutputStream(toFileAtPath: filepath + "-labels-test", append: false) else {
            fatalError("Couldn't open output file")
        }
        testLabelsFile.open()
        defer { testLabelsFile.close() }
        
        let imageSize = ImageSize(width: 28, height: 28)
        var bitmapData = Array<UInt8>(repeating: 0, count: Int(imageSize.width * imageSize.height))
        bitmapData[0] = 0 // To silence the "never mutated" warning
        let bitmapPointer = UnsafeMutableRawPointer(mutating: bitmapData)
        var labelToWrite = Array<UInt8>(repeating: 0, count: 1)
        
        var trainWriteCount = 0
        var testWriteCount = 0
        writeloop: for (label, samples) in library {
            guard let byteLabel = self.digitRecognizer.labelStringToByte[label] else {
                continue
            }
            
            labelToWrite[0] = byteLabel
            
            for digit in samples {
                guard renderToContext(normalizedStrokes: digit.strokes, size: imageSize, data: bitmapPointer) != nil else {
                    fatalError("Couldn't render image")
                }
                if (CGFloat(arc4random_uniform(1000)) / 1000.0 <= testPercentage) {
                    testLabelsFile.write(labelToWrite, maxLength: 1)
                    testImagesFile.write(bitmapData, maxLength: bitmapData.count)
                    testWriteCount += 1
                } else {
                    trainLabelsFile.write(labelToWrite, maxLength: 1)
                    trainImagesFile.write(bitmapData, maxLength: bitmapData.count)
                    trainWriteCount += 1
                }
            }
        }
        print("Wrote \(trainWriteCount) training and \(testWriteCount) testing binary images to \(filepath)")
    }
    
}

