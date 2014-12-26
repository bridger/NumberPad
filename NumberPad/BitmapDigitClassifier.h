//
//  BitmapDigitClassifier.h
//  NumberPad
//
//  Created by Bridger Maxwell on 12/15/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BitmapDigitClassifier : NSObject

- (UIImage *)createFeatureImage:(CGPathRef)path; // Array of CGFloats, x1, y1, x2, y2...

@end