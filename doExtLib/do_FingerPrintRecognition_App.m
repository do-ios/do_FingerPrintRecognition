//
//  do_FingerPrintRecognition_App.m
//  DoExt_SM
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_FingerPrintRecognition_App.h"
static do_FingerPrintRecognition_App* instance;
@implementation do_FingerPrintRecognition_App
@synthesize OpenURLScheme;
+(id) Instance
{
    if(instance==nil)
        instance = [[do_FingerPrintRecognition_App alloc]init];
    return instance;
}
@end
