//
//  do_FingerPrintRecognition_SM.m
//  DoExt_API
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_FingerPrintRecognition_SM.h"
#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doInvokeResult.h"
#import "doJsonHelper.h"
#import "doServiceContainer.h"
#import "doLogEngine.h"
#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>

#ifdef DEBUG
#ifndef ZJLog
#define ZJLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#endif
#else
#ifndef ZJLog
#define ZJLog(...)
#endif
#endif

@interface do_FingerPrintRecognition_SM()
//@property (nonatomic, strong) id<doIScriptEngine> scritEngine;
//@property (nonatomic, strong) NSString *callbackName;
@property (nonatomic, strong) LAContext * touchIDContext;

@end

@implementation do_FingerPrintRecognition_SM
#pragma mark - 方法
#pragma mark - 同步异步方法的实现
//同步
- (void)startRecognize:(NSArray *)parms
{
    NSDictionary *_dictParas = [parms objectAtIndex:0];
//    id<doIScriptEngine> scritEngine = [parms objectAtIndex:1];
    doInvokeResult *_invokeResult = [parms objectAtIndex:2];
    
    NSString *localizedReason = [doJsonHelper GetOneText:_dictParas :@"localizedReason" :@"通过Home键验证已有手机指纹"];
    NSString *localizedCancelTitle = [doJsonHelper GetOneText:_dictParas :@"localizedCancelTitle" :@"取消"];
    NSString *localizedFallbackTitle = [doJsonHelper GetOneText:_dictParas :@"localizedFallbackTitle" :@"前往自定义验证"];
    
    if (localizedReason == nil) {
        [self logErrorInfoWithStr:@"localizedReason参数必填"];
        return;
    }else {
        if ([localizedReason isEqualToString:@""]) {
            localizedReason = @"通过Home键验证已有手机指纹";
        }
    }
    if ([localizedCancelTitle isEqualToString:@""]) {
        localizedCancelTitle = @"取消";
    }
    if ([localizedFallbackTitle isEqualToString:@""]) {
        localizedFallbackTitle = @"前往自定义验证";
    }

    if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
        NSError *error;
        _touchIDContext = [[LAContext alloc] init];
        _touchIDContext.localizedFallbackTitle = localizedFallbackTitle;
        _touchIDContext.localizedCancelTitle = localizedCancelTitle;
        __weak typeof(self) weakSelf = self;
        if ([_touchIDContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) { // 指纹识别5次，不成功则调起密码输入
            [_invokeResult SetResultBoolean:true];
            [_touchIDContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:localizedReason reply:^(BOOL success, NSError * _Nullable error) {
                doInvokeResult *result = [[doInvokeResult alloc] init];
                if (success) {
                    [result SetResultBoolean:true];
                    
                    
                }else if (error) {
                    [result SetResultBoolean:false];
                    [weakSelf logErrorInfoWithErrorCode:error.code];
                }
                [weakSelf.EventCenter FireEvent:@"recognizeResult" :result];
                [weakSelf.touchIDContext invalidate];
                weakSelf.touchIDContext = nil;
            }];
            
        }else if ([_touchIDContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error]) { // 指纹识别可用，则先指纹验证，否则，密码验证6次
            [_invokeResult SetResultBoolean:true];
            [_touchIDContext evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:localizedReason reply:^(BOOL success, NSError * _Nullable error) {
                doInvokeResult *result = [[doInvokeResult alloc] init];
                if (success) {
                    [result SetResultBoolean:true];
                }else if (error) {
                    [result SetResultBoolean:false];
                    [weakSelf logErrorInfoWithErrorCode:error.code];
                }
                [weakSelf.EventCenter FireEvent:@"recognizeResult" :result];
                [weakSelf.touchIDContext invalidate];
                weakSelf.touchIDContext = nil;
            }];
        }
        if (error) {
            [_invokeResult SetResultBoolean:false];
            [[doServiceContainer Instance].LogEngine WriteError:nil :error.localizedDescription];
        }
        
    }else {
        [_invokeResult SetResultBoolean:false];
        [[doServiceContainer Instance].LogEngine WriteError:nil :@"设备系统低于iOS8.0,不支持touchID"];
    }
}

#pragma mark - private method

- (void)logErrorInfoWithStr:(NSString*)errStr {
    [[doServiceContainer Instance].LogEngine WriteError:nil :errStr];
}

- (void)logErrorInfoWithErrorCode:(NSInteger)errorCode {
    switch (errorCode) {
        case kLAErrorAuthenticationFailed: {
            ZJLog(@"连续3次指纹识别失败");  // -1 连续三次指纹识别错误
            [self logErrorInfoWithStr:@"连续3次指纹识别失败"];
            break;
        }
        case kLAErrorUserCancel: {
            ZJLog(@"用户取消验证Touch ID"); // -2 在TouchID对话框中点击了取消按钮
            [self logErrorInfoWithStr:@"用户取消验证Touch ID(或当前设备被锁定已停用，此情况仅出现在连续3+2+6次验证失败后出现。)"];
            break;
        }
        case kLAErrorUserFallback: {
            __weak typeof(self) weakSelf = self;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                ZJLog(@"用户点击自定义按钮，切换主线程fireEvent"); // -3 在TouchID对话框中点击了自定义按钮
                [weakSelf.EventCenter FireEvent:@"localizedFallbackButtonClick" :[[doInvokeResult alloc] init]];
            }];
            break;
        }
        case kLAErrorSystemCancel: {
            ZJLog(@"系统终止了验证，例如按下Home或者电源键"); // -4 TouchID对话框被系统取消，例如按下Home或者电源键
            [self logErrorInfoWithStr:@"系统终止了验证，例如按下Home或者电源键"];
            break;
        }
        case kLAErrorPasscodeNotSet: {
            ZJLog(@"设备系统未设置密码"); // -5
            [self logErrorInfoWithStr:@"设备系统未设置密码"];
            break;
        }
        case kLAErrorTouchIDNotAvailable: {
            ZJLog(@"设备未设置Touch ID"); // -6
            [self logErrorInfoWithStr:@"设备未设置Touch ID"];
            break;
        }
        case kLAErrorTouchIDNotEnrolled: {
            ZJLog(@"用户未录入指纹"); // -7
            [self logErrorInfoWithStr:@"用户未录入指纹"];
            break;
        }
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
        case LAErrorTouchIDLockout: //Authentication was not successful, because there were too many failed Touch ID attempts and Touch ID is now locked. Passcode is required to unlock Touch ID, e.g. evaluating LAPolicyDeviceOwnerAuthenticationWithBiometrics will ask for passcode as a prerequisite 用户连续多次进行Touch ID验证失败，Touch ID被锁，需要用户输入密码解锁，先Touch ID验证密码
        {
            ZJLog(@"连续3+2次指纹识别错误，TouchID功能被锁定，下一次需要输入系统密码"); // -8 连续3+2次指纹识别错误，TouchID功能被锁定，下一次需要输入系统密码
            [self logErrorInfoWithStr:@"连续3+2次指纹识别错误，TouchID功能被锁定，下一次需要输入系统密码"];
        }
            break;
        case LAErrorAppCancel: // Authentication was canceled by application (e.g. invalidate was called while authentication was in progress) 如突然来了电话，电话应用进入前台，APP被挂起啦");
        {
            ZJLog(@"用户不能控制情况下APP被挂起"); // -9
            [self logErrorInfoWithStr:@"用户不能控制情况下APP被挂起"];
        }
            break;
        case LAErrorInvalidContext: // LAContext passed to this call has been previously invalidated.
        {
            ZJLog(@"LAContext传递给这个调用之前已经失效"); // -10
            [self logErrorInfoWithStr:@"LAContext传递给这个调用之前已经失效"];
        }
            break;
#else
#endif
        default:
        {
            ZJLog(@"未知错误");
            [self logErrorInfoWithStr:@"未知错误"];
            break;
        }
    }
}


@end
