//
//  BitmapDigitClassier.m
//  NumberPad
//
//  Created by Bridger Maxwell on 12/15/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import "BitmapDigitClassifier.h"

// Call CGPathApplyBlock to use a block to loop through the elements of a CGPath
typedef void(^CGPathApplyEnumerationHandler)(const CGPathElement *element);

void CGPathEnumerationCallback(void *info, const CGPathElement *element)
{
    CGPathApplyEnumerationHandler handler = (__bridge CGPathApplyEnumerationHandler)info;
    if (handler) {
        handler(element);
    }
    CFBridgingRelease(info);
}

void CGPathApplyBlock(CGPathRef path, CGPathApplyEnumerationHandler enumerationBlock ) {
    void CGPathEnumerationCallback(void *info, const CGPathElement *element);
    CGPathApply(path, (__bridge void *)enumerationBlock, CGPathEnumerationCallback);
}


@implementation BitmapDigitClassifier

- (id)init {
    self = [super init];
    if (self) {
        
        
        
    }
    return self;
}

- (UIImage *)createFeatureImage:(CGPathRef)path
{
    CGFloat windowSize = 16;
    
    // Resize the point list to have a center of mass at the origin and unit standard deviation on both axis
    //    scaled_x = (symbol.x - mean(symbol.x)) * (h/5)/std2(symbol.x) + h/2;
    //    scaled_y = (symbol.y - mean(symbol.y)) * (h/5)/std2(symbol.y) + h/2;
    __block CGPoint lastPoint;
    __block int pointCount = 0;
    __block CGFloat totalDistance = 0;
    __block CGFloat xMean = 0;
    __block CGFloat xDeviation = 0;
    __block CGFloat yMean = 0;
    __block CGFloat yDeviation = 0;
    CGPathApplyBlock(path, ^(const CGPathElement *element) {
        pointCount++;
        
        CGPoint point = element->points[0];
        if (element->type == kCGPathElementAddLineToPoint) {
            CGPoint midPoint = CGPointMake((point.x + lastPoint.x) / 2.f, (point.y + lastPoint.y) / 2.f);
            CGFloat distance = sqrt( pow(point.x - lastPoint.x, 2) + pow(point.y - lastPoint.y, 2) );
            
            CGFloat temp = distance + totalDistance;
            
            CGFloat xDelta = midPoint.x - xMean;
            CGFloat xR = xDelta * distance / temp;
            xMean = xMean + xR;
            xDeviation = xDeviation + totalDistance * xDelta * xR;
            
            CGFloat yDelta = midPoint.y - yMean;
            CGFloat yR = yDelta * distance / temp;
            yMean = yMean + yR;
            yDeviation = yDeviation + totalDistance * yDelta * yR;
            
            totalDistance = temp;
        }
        lastPoint = point;
    });
    xDeviation = sqrt(xDeviation / (totalDistance));
    yDeviation = sqrt(yDeviation / (totalDistance));
    
    CGFloat xScale = (windowSize / 5.f) / xDeviation;
    CGFloat yScale = (windowSize / 5.f) / yDeviation;
    if (!isfinite(xScale)) xScale = 1;
    if (!isfinite(yScale)) yScale = 1;
    
    // The color context is Gray 8 bpp, 8 bpc,kCGImageAlphaNone

    // The bitmap is laid out like this
    // |   0   | pi / 4 | pi / 2| 3pi/4 |  ends  |
    
    // To disable color management, set the kCIImageColorSpace key to null
    // You can control whether to allow anti-aliasing for a particular graphics context by using the function CGContextSetAllowsAntialiasing
    
    void *imageData = calloc((windowSize * 5) * windowSize, 1);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(imageData, windowSize * 5, windowSize, 8, windowSize * 5, colorSpace, kCGImageAlphaNone);
    
    // Flip the context
    CGContextTranslateCTM(context, 0, windowSize);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    CGContextSetAllowsAntialiasing(context, false); // We will be blurrying everything anyway
    
    __block CGPoint translatedLastPoint;
    CGPathApplyBlock(path, ^(const CGPathElement *element) {
        CGPoint point = element->points[0];
        CGPoint translatedPoint = CGPointMake((point.x - xMean) * xScale + windowSize / 2,
                                              (point.y - yMean) * yScale + windowSize / 2);
        
        if (element->type == kCGPathElementAddLineToPoint) {
            CGFloat tangent = atan2(point.y - lastPoint.y, point.x - lastPoint.x);
            //NSLog(@"Drawing line with tangent %f between %.1f,%.1f and %.1f,%.1f", tangent, point.x, point.y, lastPoint.x, lastPoint.y);
            
            CGColorRef color;
            CGFloat whiteValue;
            
            whiteValue = angleDistance(tangent, 0);
            color = CGColorCreate(colorSpace, (CGFloat[]){whiteValue, 1.0});
            drawLine(context, translatedLastPoint, translatedPoint, color, CGRectMake(0, 0, windowSize, windowSize));
            
            whiteValue = angleDistance(tangent, -M_PI_4);
            color = CGColorCreate(colorSpace, (CGFloat[]){whiteValue, 1.0});
            drawLine(context, translatedLastPoint, translatedPoint, color, CGRectMake(windowSize, 0, windowSize, windowSize));
            
            whiteValue = angleDistance(tangent, -M_PI_2);
            color = CGColorCreate(colorSpace, (CGFloat[]){whiteValue, 1.0});
            drawLine(context, translatedLastPoint, translatedPoint, color, CGRectMake(windowSize * 2, 0, windowSize, windowSize));
            
            whiteValue = angleDistance(tangent, -3 * M_PI_4);
            color = CGColorCreate(colorSpace, (CGFloat[]){whiteValue, 1.0});
            drawLine(context, translatedLastPoint, translatedPoint, color, CGRectMake(windowSize * 3, 0, windowSize, windowSize));
        }
        
        lastPoint = point;
        translatedLastPoint = translatedPoint;
    });
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage *uiimage = [UIImage imageWithCGImage:cgImage];

    return uiimage;
}


void drawLine(CGContextRef context, CGPoint startPoint, CGPoint endPoint, CGColorRef color, CGRect boundingRect) {
    CGContextSaveGState(context);
    CGContextClipToRect(context, boundingRect);
    
    startPoint.x += boundingRect.origin.x;
    startPoint.y += boundingRect.origin.y;
    endPoint.x += boundingRect.origin.x;
    endPoint.y += boundingRect.origin.y;
    
    CGContextMoveToPoint(context, startPoint.x, startPoint.y);
    CGContextAddLineToPoint(context, endPoint.x, endPoint.y);
    CGContextSetBlendMode(context, kCGBlendModeScreen);
    
    CGContextSetStrokeColorWithColor(context, color);
    CGContextSetLineWidth(context, 1);
    
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
}

// Given an omega, this returns the linear distance from target angle as a value from 0 to 1, where 1 is the closest
// If the angle is pi/4 radians away it is 0.5. If an angle is pi/2 radians away, it's value is 0. More than 90 degrees is 0
// both omega and targetAngle should be in the range -pi to pi
CGFloat angleDistance(CGFloat omega, CGFloat target) {
    CGFloat distance = ABS(omega - target);
    while (distance > M_PI) {
        distance -= M_PI;
    }
    while (distance < -M_PI) {
        distance += M_PI;
    }
    return ABS(1.0 - distance / M_PI_2);
}

//function [ distance ] = angleDistance( omega, target )
//% Given an omega, this returns the linear distance from target as a value
//% from 0 to 1, where 1 is the closest
//distance = abs(pi/2 - mod(omega - target + pi/2,  pi));
//distance = max(0, 1.0 - distance / (pi/4));
//end



@end
