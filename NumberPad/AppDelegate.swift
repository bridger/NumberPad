//
//  AppDelegate.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/13/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        // Set up a few more rewrite rules
        let expressionRewriter = DDExpressionRewriter.default()!
        
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
}

