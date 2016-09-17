//
//  EUMTouchPointView.m
//
//  Created by Shawn on 12/8/14.
//  Copyright (c) 2014 EUMLab. All rights reserved.
//

#import "EUMTouchPointView.h"

@implementation EUMTouchPointView

-(instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        
    }
    return self;
}

-(void)drawRect:(CGRect)rect{
    
    CGRect frm = self.frame;
    [self drawPointer:frm.size stockWidth:3];

}

- (void)drawPointer: (CGSize)pointSize stockWidth: (CGFloat)stockWidth
{
    
    //// General Declarations
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* color = [UIColor colorWithRed: 0 green: 0.734 blue: 1 alpha: 0.694];
    if (self.pointerColor) {
        color = self.pointerColor;
    }
    
    //// Shadow Declarations
    UIColor* shadow = [UIColor.blackColor colorWithAlphaComponent: 0.2];
    CGSize shadowOffset = CGSizeMake(0.1, -0.1);
    CGFloat shadowBlurRadius = 4;
    
    //// Oval Drawing
    UIBezierPath* ovalPath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(5, 5, pointSize.width - 10, pointSize.height -10)];
    [color setFill];
    [ovalPath fill];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, [shadow CGColor]);
    
    if (self.pointerStockColor) {
        [self.pointerStockColor setStroke];
    }else{
        [UIColor.whiteColor setStroke];
    }
    ovalPath.lineWidth = stockWidth;
    [ovalPath stroke];
    CGContextRestoreGState(context);
}


@end
