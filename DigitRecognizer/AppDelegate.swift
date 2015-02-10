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
    
    var window: UIWindow?
    var digitClassifier: DTWDigitClassifier = DTWDigitClassifier()
    
    class func sharedAppDelegate() -> AppDelegate {
        return UIApplication.sharedApplication().delegate as! AppDelegate
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        if let path = NSBundle.mainBundle().pathForResource("bridger_train", ofType: "json") {
            loadData(path)
        }
        //saveMisclassified()
        
        return true
    }
    
    func applicationWillResignActive(application: UIApplication) {
        saveData()
    }
    
    func documentsDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0] as! String
    }
    
    func saveData() {
        var dataToSave = self.digitClassifier.dataToSave(true, saveNormalizedData: true)
        
        let saveNumber: Int
        if let lastSave = newestSavedData(), let lastNumber = lastSave.substringFromIndex(filePrefix.endIndex).toInt()  {
            saveNumber = lastNumber + 1
        }
        else
        {
            saveNumber = 1
        }
        
        let documentName = self.documentsDirectory().stringByAppendingPathComponent( filePrefix + String(saveNumber))
        
        NSJSONSerialization.dataWithJSONObject(dataToSave, options: nil, error: nil)!.writeToFile(documentName, atomically: false)
    }
    
    func loadData(path: String) {
        if let jsonLibrary = DTWDigitClassifier.jsonLibraryFromFile(path) {
            self.digitClassifier.loadData(jsonLibrary, loadNormalizedData: false)
        }
    }
    
    
    func newestSavedData() -> String? {
        let contents = NSFileManager.defaultManager().contentsOfDirectoryAtPath(self.documentsDirectory(), error: nil)
        if contents != nil {
            if let contents = contents as? [String] {
                let contents = contents.filter({ string in
                    return string.hasPrefix(filePrefix)
                }).sorted({ (string1, string2) in
                    return string1.compare(string2) == NSComparisonResult.OrderedAscending
                })
                
                return contents.last
            }
        }
        
        return nil
    }
    
    
    func saveMisclassified() {
        
        let testDataPath = NSBundle.mainBundle().pathForResource("bridger_test", ofType: "json")!
        let testDataJson = DTWDigitClassifier.jsonLibraryFromFile(testDataPath)!["rawData"]!
        let testData = DTWDigitClassifier.jsonToLibrary(testDataJson)
        let randomNumber = arc4random() % 500
        let documentDirectory = documentsDirectory().stringByAppendingPathComponent("\(randomNumber)")
        NSFileManager.defaultManager().createDirectoryAtPath(documentDirectory, withIntermediateDirectories: true, attributes: nil, error: nil)

        let imageSize = CGSizeMake(200, 200)
        
        for (testLabel, trainLabel, testIndex, trainIndex) in [("3", "5", 17, 22), ("3", "5", 28, 12), ("7", "+", 8, 24), ("9", "4", 7, 29), ("9", "0", 13, 21), ("5", "1", 1, 3)] {
            
            let testStroke = testData[testLabel]![testIndex]
            let normalizedTestStroke = self.digitClassifier.normalizeDigit(testStroke)
            let trainStroke = self.digitClassifier.normalizedPrototypeLibrary[trainLabel]![trainIndex]
            
            let testStrokeImage = visualizeNormalizedStrokes(normalizedTestStroke!, imageSize)
            let trainStrokeImage = visualizeNormalizedStrokes(trainStroke, imageSize)
    
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
            let fileName = documentDirectory.stringByAppendingPathComponent("\(safeName(testLabel)) as \(safeName(trainLabel)) indexes \(testIndex) \(trainIndex)")
            let testFileName = fileName + " - Test.png"
            let trainFileName = fileName + " - Train.png"
            
            var error: NSError? = nil
            if !UIImagePNGRepresentation(testStrokeImage).writeToFile(testFileName, options: nil, error: &error) {
                println("Unable to write file \(testFileName) + \(error)")
            }
            if !UIImagePNGRepresentation(trainStrokeImage).writeToFile(trainFileName, options: nil, error: &error) {
                println("Unable to write file \(trainFileName) + \(error)")
            }
        }
        
        
        println("Finished writing to \(documentDirectory)")
    }
    
}

