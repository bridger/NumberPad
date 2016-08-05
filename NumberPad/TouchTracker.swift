//
//  TouchTracker.swift
//  NumberPad
//
//  Created by Bridger Maxwell on 7/10/16.
//  Copyright © 2016 Bridger Maxwell. All rights reserved.
//

import Foundation

typealias TouchID = Int

class TouchTracker {
    var currentTouchId: TouchID = 0
    var touchIds = NSMapTable<UITouch, NSNumber>(keyOptions: [.weakMemory], valueOptions: [])
    func id(for touch: UITouch) -> TouchID {
        if let touchId = touchIds.object(forKey: touch) {
            return touchId.intValue
        } else {
            currentTouchId += 1
            touchIds.setObject(NSNumber(value: currentTouchId), forKey: touch)
            return currentTouchId
        }
    }
}
