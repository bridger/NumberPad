//
//  SortedMinArrayTests.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/31/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit
import XCTest
import DigitRecognizerSDK

class SortedMinArrayTests: XCTestCase {
    func getElementsAndValues<D, T>(minArray: SortedMinArray<D, T>) -> (values: [D], elements: [T]) {
        var values: [D] = []
        var elements: [T] = []
        for (value, element) in minArray {
            elements.append(element)
            values.append(value)
        }
        return (values, elements)
    }
    
    func testInsertion() {
        var minArray = SortedMinArray<Double, Int>(capacity: 3)
        
        minArray.add(value: 4.2, element: 4)
        minArray.add(value: 7.2, element: 7)
        minArray.add(value: 3.14, element: 3)
        minArray.add(value: -3.5, element: -3)
        
        XCTAssert(minArray.count == 3, "Only 3 elements should be in array")
        
        minArray.add(value: 1.4, element: 1)
        minArray.add(value: 25.3, element: 25)
        
        XCTAssert(getElementsAndValues(minArray: minArray).elements == [-3, 1, 3], "Elements are wrong")
        
        minArray.add(value: 2.5, element: 2)
        
        let results = getElementsAndValues(minArray: minArray)
        XCTAssert(results.elements == [-3, 1, 2], "Elements are wrong")
        XCTAssert(results.values == [-3.5, 1.4, 2.5], "Values are wrong")
    }
    
    func testEmpty() {
        var noCapacity = SortedMinArray<Double, Int>(capacity: 0)
        noCapacity.add(value: 3.14, element: 3)
        XCTAssert(noCapacity.count == 0, "No element should be added")
        
        for (_, _) in noCapacity {
            XCTFail("No element should be here")
        }
        
        let hasCapacity = SortedMinArray<Double, Int>(capacity: 1)
        for (_, _) in hasCapacity {
            XCTFail("No element should be here")
        }
    }
    
}
