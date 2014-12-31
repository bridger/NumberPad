//
//  AppDelegate.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/13/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit

let filePrefix = "SavedLibraries-"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var rootViewController: ViewController!


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        self.rootViewController = window?.rootViewController as ViewController
        
        if let path = NSBundle.mainBundle().pathForResource("bridger_train", ofType: "json") {
            loadData(path)
        }
//        if let newestDataName = newestSavedData() {
//            loadData(documentsDirectory().stringByAppendingPathComponent(newestDataName))
//        }
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        saveData()
    }
    
    func documentsDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0] as String
    }
    
    func saveData() {
        let dataToSave = self.rootViewController.digitClassifier.dataToSave(true, saveNormalizedData: true)
        
        var saveNumber = 1
        if let lastSave = newestSavedData() {
            if let lastNumber = lastSave.substringFromIndex(filePrefix.endIndex).toInt() {
                saveNumber = lastNumber + 1
            }
        }
        
        let documentName = self.documentsDirectory().stringByAppendingPathComponent( filePrefix + String(saveNumber))
        
        NSJSONSerialization.dataWithJSONObject(dataToSave, options: nil, error: nil)!.writeToFile(documentName, atomically: false)
    }
    
    func loadData(path: String) {
        if let jsonLibrary = DTWDigitClassifier.jsonLibraryFromFile(path) {
            self.rootViewController.digitClassifier.loadData(jsonLibrary, loadNormalizedData: false)
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
}

