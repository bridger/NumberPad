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
    var digitClassifier: DTWDigitClassifier = DTWDigitClassifier()
    
    class func sharedAppDelegate() -> AppDelegate {
        return UIApplication.shared().delegate as! AppDelegate
    }
    
    func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        if let path = NSBundle.main().pathForResource("bridger_train", ofType: "json") {
            loadData(path: path)
        }
        //saveMisclassified()
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        saveData()
    }
    
    func documentsDirectory() -> NSURL {
        let path = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.documentDirectory, NSSearchPathDomainMask.userDomainMask, true)[0] as String
        return NSURL(fileURLWithPath: path)
    }
    
    func saveData() {
        let dataToSave = self.digitClassifier.dataToSave(saveRawData: !onlySaveNormalizedData, saveNormalizedData: true)
        
        let saveNumber: Int
        if let lastSave = newestSavedData(), let lastNumber = Int(lastSave.substring(from: filePrefix.endIndex))  {
            saveNumber = lastNumber + 1
        }
        else
        {
            saveNumber = 1
        }
        
        let documentName = self.documentsDirectory().appendingPathComponent(filePrefix + String(saveNumber))
        
        do {
            let jsonObject = try NSJSONSerialization.data(withJSONObject: dataToSave, options: [])
            jsonObject.write(to: documentName, atomically: false)
        } catch let error as NSError {
            print("Couldn't save data \(error)")
        }
    }
    
    func loadData(path: String) {
        if let jsonLibrary = DTWDigitClassifier.jsonLibraryFromFile(path: path) {
            self.digitClassifier.loadData(jsonData: jsonLibrary, loadNormalizedData: false)
        }
    }
    
    
    func newestSavedData() -> String? {
        let contents: [AnyObject]?
        do {
            contents = try NSFileManager.default().contentsOfDirectory(atPath: self.documentsDirectory().path!)
        } catch _ {
            contents = nil
        }
        if contents != nil {
            if let contents = contents as? [String] {
                let filtered = contents.filter({ string in
                    return string.hasPrefix(filePrefix)
                }).sorted(isOrderedBefore: { (string1, string2) in
                    return string1.compare(string2) == NSComparisonResult.orderedAscending
                })
                
                return filtered.last
            }
        }
        
        return nil
    }
    
    
    func saveMisclassified() {
        
        let testDataPath = NSBundle.main().pathForResource("bridger_test", ofType: "json")!
        let testDataJson = DTWDigitClassifier.jsonLibraryFromFile(path: testDataPath)!["rawData"]!
        let testData = DTWDigitClassifier.jsonToLibrary(json: testDataJson)
        let randomNumber = arc4random() % 500
        let documentDirectory = documentsDirectory().appendingPathComponent("\(randomNumber)")
        do {
            try NSFileManager.default().createDirectory(at: documentDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch _ {
        }

        let imageSize = CGSize(width: 200, height: 200)
        
        for (testLabel, trainLabel, testIndex, trainIndex) in [("3", "5", 17, 22), ("3", "5", 28, 12), ("7", "+", 8, 24), ("9", "4", 7, 29), ("9", "0", 13, 21), ("5", "1", 1, 3)] {
            
            let testStroke = testData[testLabel]![testIndex]
            let normalizedTestStroke = self.digitClassifier.normalizeDigit(inputDigit: testStroke)
            let trainStroke = self.digitClassifier.normalizedPrototypeLibrary[trainLabel]![trainIndex]
            
            let testStrokeImage = visualizeNormalizedStrokes(strokes: normalizedTestStroke!, imageSize: imageSize)
            let trainStrokeImage = visualizeNormalizedStrokes(strokes: trainStroke, imageSize: imageSize)
            
            func safeName(name: String) -> String {
                if name == "+" {
                    return "plus"
                } else if name == "/" {
                    return "slash"
                } else if name == "-" {
                    return "minus"
                }
                return name
            }
            
            let baseName = "\(safeName(name: testLabel)) as \(safeName(name: trainLabel)) indexes \(testIndex) \(trainIndex)"
            let testFileName = documentDirectory.appendingPathComponent(baseName + " - Test.png")
            let trainFileName = documentDirectory.appendingPathComponent(baseName + " - Train.png")
            
            do {
                try UIImagePNGRepresentation(testStrokeImage)!.write(to: testFileName, options: [])
            } catch let error as NSError {
                print("Unable to write file \(testFileName) + \(error)")
            }
            do {
                try UIImagePNGRepresentation(trainStrokeImage)!.write(to: trainFileName, options: [])
            } catch let error as NSError {
                print("Unable to write file \(trainFileName) + \(error)")
            }
        }
        
        print("Finished writing to \(documentDirectory)")
    }
    
}

