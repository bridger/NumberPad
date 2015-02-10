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

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var rootViewController: ViewController!


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        self.rootViewController = window?.rootViewController as! ViewController
        
        if let path = NSBundle.mainBundle().pathForResource("bridger_normalized", ofType: "json") {
            loadData(path)
        }
        
        // Set up a few more rewrite rules
        let expressionRewriter = DDExpressionRewriter.defaultRewriter()
        
        // A + A*B = A(1 + B)
        expressionRewriter.addRewriteRule("__exp1 * (1 - __exp2)", forExpressionsMatchingTemplate:"__exp1 - __exp1 * __exp2", condition:nil)
        expressionRewriter.addRewriteRule("__exp1 * (1 - __exp2)", forExpressionsMatchingTemplate:"__exp1 - __exp2 * __exp1", condition:nil)
        
        expressionRewriter.addRewriteRule("__exp1 * (1 + __exp2)", forExpressionsMatchingTemplate:"__exp1 + __exp1 * __exp2", condition:nil)
        expressionRewriter.addRewriteRule("__exp1 * (1 + __exp2)", forExpressionsMatchingTemplate:"__exp1 + __exp2 * __exp1", condition:nil)
        
        // A*B + A*C = A(B + C)
        expressionRewriter.addRewriteRule("__exp1 * (__exp2 + __exp3)", forExpressionsMatchingTemplate:"__exp1 * __exp2 + __exp1 * __exp3", condition:nil)
        expressionRewriter.addRewriteRule("__exp1 * (__exp2 + __exp3)", forExpressionsMatchingTemplate:"__exp2 * __exp1 + __exp3 * __exp1", condition:nil)
        expressionRewriter.addRewriteRule("__exp1 * (__exp2 + __exp3)", forExpressionsMatchingTemplate:"__exp1 * __exp2 + __exp3 * __exp1", condition:nil)
        expressionRewriter.addRewriteRule("__exp1 * (__exp2 + __exp3)", forExpressionsMatchingTemplate:"__exp2 * __exp1 + __exp1 * __exp3", condition:nil)
        
        expressionRewriter.addRewriteRule("__exp1 * (__exp2 - __exp3)", forExpressionsMatchingTemplate:"__exp1 * __exp2 - __exp1 * __exp3", condition:nil)
        expressionRewriter.addRewriteRule("__exp1 * (__exp2 - __exp3)", forExpressionsMatchingTemplate:"__exp2 * __exp1 - __exp3 * __exp1", condition:nil)
        expressionRewriter.addRewriteRule("__exp1 * (__exp2 - __exp3)", forExpressionsMatchingTemplate:"__exp1 * __exp2 - __exp3 * __exp1", condition:nil)
        expressionRewriter.addRewriteRule("__exp1 * (__exp2 - __exp3)", forExpressionsMatchingTemplate:"__exp2 * __exp1 - __exp1 * __exp3", condition:nil)
        
        return true
    }
    
    func documentsDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0] as! String
    }
    
    func loadData(path: String) {
        if let jsonLibrary = DTWDigitClassifier.jsonLibraryFromFile(path) {
            self.rootViewController.digitClassifier.loadData(jsonLibrary, loadNormalizedData: true)
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

