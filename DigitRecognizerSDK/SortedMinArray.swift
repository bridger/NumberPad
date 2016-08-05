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

public struct SortedMinArray<Value: Comparable, Element> {
    public typealias ValueTuple = (value: Value, element: Element)
    
    private var contents: [ValueTuple] = []
    let capacity: Int
    
    public init(capacity: Int) {
        self.capacity = capacity
    }
    
    public var count: Int { return contents.count }
    
    public var isEmpty: Bool { return contents.isEmpty }
    
    public var first: ValueTuple? {
        get {
            return contents.first
        }
    }
    
    public var last: ValueTuple? {
        get {
            return contents.last
        }
    }
    
    public mutating func add(value: Value, element: Element) {
        let hasRoom = contents.count < self.capacity

        if (hasRoom || (self.capacity > 0 && value < contents.last!.value)) {
            if !hasRoom {
                contents.remove(at: contents.count - 1)
            }

            // Insert the element
            let insertedTuple: ValueTuple = (value, element)
            let index = insertionIndexOf(array: contents, elem: insertedTuple) { tuple1, tuple2 in
                return tuple1.value < tuple2.value
            }
            contents.insert((value, element), at: index)
        }
    }
}

extension SortedMinArray : Sequence {
    public typealias Generator = IndexingIterator<[ValueTuple]>
    public func makeIterator() -> Generator {
        return contents.makeIterator()
    }
}

