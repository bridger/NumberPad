//
//  UITouch+EUMUITouch.m
//
//  Created by Shawn on 12/8/14.
//  Copyright (c) 2014 EUMLab. All rights reserved.
//

#import "UITouch+EUMUITouch.h"
#import <objc/runtime.h>

static void * keyPointerView;

@implementation UITouch (EUMUITouch)
- (UIView *)viewTouchPointer {
    return objc_getAssociatedObject(self, keyPointerView);
}

- (void)setViewTouchPointer:(UIView *)__viewTouchPointer {
    objc_setAssociatedObject(self, keyPointerView, __viewTouchPointer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end
