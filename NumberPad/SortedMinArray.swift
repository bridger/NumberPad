//
//  SortedMinArray.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 12/30/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit

func insertionIndexOf<T>(array: [T], elem: T, isOrderedBefore: (T, T) -> Bool) -> Int {
    var lo = 0
    var hi = array.count - 1
    while lo <= hi {
        let mid = (lo + hi)/2
        let midValue = array[mid]
        if isOrderedBefore(midValue, elem) {
            lo = mid + 1
        } else if isOrderedBefore(elem, midValue) {
            hi = mid - 1
        } else {
            return mid // found at position mid
        }
    }
    return lo // not found, would be inserted at position lo
}

struct SortedMinArray<D: Comparable, T> {
    typealias Value = D
    typealias Element = T
    typealias ValueTuple = (value: Value, element: Element)
    
    private var contents: [ValueTuple] = []
    let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
    }
    
    var count: Int { return contents.count }
    
    var isEmpty: Bool { return contents.isEmpty }
    
    var first: ValueTuple? {
        get {
            return contents.first
        }
    }
    
    var last: ValueTuple? {
        get {
            return contents.last
        }
    }
    
    mutating func add(value: D, element: Element) {
        let hasRoom = contents.count < self.capacity
        
        if (hasRoom || (self.capacity > 0 && value < contents.last!.value)) {
            if !hasRoom {
                contents.removeAtIndex(contents.count - 1)
            }
            
            let generater = contents.generate()
            
            // Insert the element
            let insertedTuple = (value, element)
            let index = insertionIndexOf(contents, insertedTuple) { tuple1, tuple2 in
                return tuple1.value < tuple2.value
            }
            contents.insert((value, element), atIndex: index)
        }
    }
}

extension SortedMinArray : SequenceType {
    typealias Generator = IndexingGenerator<[ValueTuple]>
    func generate() -> Generator {
        return contents.generate()
    }
}

