//
//  EUMShowTouchWindow.m
//
//  Created by Shawn on 12/8/14.
//  Copyright (c) 2014 EUMLab. All rights reserved.
//

#import "EUMShowTouchWindow.h"
#import "UITouch+EUMUITouch.h"
#import "EUMTouchPointView.h"

#define kAnimationDuration 0.1
#define kStartScale 2
#define kEndScale 1.2

@implementation EUMShowTouchWindow

-(instancetype)init{
    self = [super init];
    if (self) {
        self.pointerSize = CGSizeMake(50, 50);
    }
    return self;
}

-(CGSize)pointerSize{
    if (_pointerSize.height <= 10 ||
        _pointerSize.width <= 10) {
        _pointerSize = CGSizeMake(50, 50);
    }
    return _pointerSize;
}

- (void)sendEvent:(UIEvent *)event
{
    [super sendEvent:event];
    
    if (event.type == UIEventTypeTouches)
    {
        for (UITouch *touch in [event allTouches])
        {
            if (touch.phase == UITouchPhaseBegan)
            {
                CGPoint point = [touch locationInView:self];
                EUMTouchPointView *touchPointerView = [[EUMTouchPointView alloc] initWithFrame:CGRectMake(point.x-self.pointerSize.width/2 ,point.y-self.pointerSize.height/2, self.pointerSize.width, self.pointerSize.height)];
                touchPointerView.contentMode = UIViewContentModeRedraw;
                touchPointerView.pointerColor = self.pointerColor;
                touchPointerView.pointerStockColor = self.pointerStockColor;
                [self addSubview:touchPointerView];
                touch.viewTouchPointer = touchPointerView;
                touchPointerView.transform = CGAffineTransformMakeScale(kStartScale, kStartScale);
                touchPointerView.alpha = 0;
                [UIView animateWithDuration:kAnimationDuration animations:^{
                    touchPointerView.transform = CGAffineTransformIdentity;
                    touchPointerView.alpha = 1;
                }];
            }
            else if (touch.phase == UITouchPhaseCancelled || touch.phase == UITouchPhaseEnded)
            {
                
                [UIView animateWithDuration:kAnimationDuration animations:^{
                    touch.viewTouchPointer.transform = CGAffineTransformMakeScale(kEndScale, kEndScale);
                    touch.viewTouchPointer.alpha = 0;
                } completion:^(BOOL finished) {
                    [touch.viewTouchPointer removeFromSuperview];
                }];
            }
            else if (touch.phase == UITouchPhaseMoved)
            {
                CGPoint point = [touch locationInView:self];
                CGRect tFrame = touch.viewTouchPointer.frame;
                tFrame.origin.x = point.x-self.pointerSize.width/2;
                tFrame.origin.y = point.y-self.pointerSize.height/2;
                [UIView animateWithDuration:kAnimationDuration animations:^{
                    touch.viewTouchPointer.frame = tFrame;
                    
                }];
            }
        }
    }
}


@end
