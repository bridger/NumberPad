//
//  BNNSHelpers.m
//  NumberPad
//
//  Created by Bridger Maxwell on 9/1/16.
//  Copyright © 2016 Bridger Maxwell. All rights reserved.
//

#include "BNNSHelpers.h"
#include <string.h>

BNNSFilterParameters createEmptyBNNSFilterParameters()
{
    BNNSFilterParameters filter_params;
    bzero(&filter_params, sizeof(filter_params));
    filter_params.flags = BNNSFlagsUseClientPtr;
    return filter_params;
}
