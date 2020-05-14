//
//  UnrecognizedSelectorHandler.m
//  DemoRequest
//
//  Created by Ericydong on 2020/5/13.
//  Copyright © 2020 EricyDong. All rights reserved.
//

#import "UnrecognizedSelectorHandler.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface ExceptionHandler : NSObject
+ (void)noSelector;
- (void)noSelector;
@end

@implementation ExceptionHandler
+ (void)noSelector {}
- (void)noSelector {}
@end




@implementation UnrecognizedSelectorHandler
NSMethodSignature * (*ori_meta_methodSignatureForSelector)(id self, SEL _cmd, SEL aSelector);
NSMethodSignature * (*ori_methodSignatureForSelector)(id self, SEL _cmd, SEL aSelector);
NSMethodSignature * methodSignatureForSelector(id self, SEL _cmd, SEL aSelector) {
    Class class = [self class];
    if (class_isMetaClass(class)) {
        //类方法
        NSMethodSignature *signature = ori_meta_methodSignatureForSelector(self, _cmd, aSelector);
        if (signature) {
            //若类方法已经实现则直接返回
            return signature;
        }
    } else {
        //实例方法
        NSMethodSignature *signature = ori_methodSignatureForSelector(self, _cmd, aSelector);
        if (signature) {
            //若实例方法已经实现则直接返回
            return signature;
        }
    }
    return [NSMethodSignature signatureWithObjCTypes:"v@:"];
}

//保存元类中的forwardInvocation实现
void (*ori_meta_forwardInvocation)(id self, SEL _cmd, NSInvocation * anInvocation);
//保存普通类中的forwardInvocation实现
void (*ori_forwardInvocation)(id self, SEL _cmd, NSInvocation * anInvocation);
void ds_forwardInvocation(id self, SEL _cmd, NSInvocation * anInvocation) {
    Class class = [anInvocation.target class];
    BOOL existImp = class_respondsToSelector(anInvocation.class, anInvocation.selector);
    if (class_isMetaClass(class)) {
        if (existImp && ori_meta_forwardInvocation) {
            ori_meta_forwardInvocation(self, _cmd, anInvocation);
        } else {
            //元类，类方法
            anInvocation.target = [ExceptionHandler class];
            anInvocation.selector = @selector(noSelector);
            [anInvocation invoke];
        }
    } else {
        if (existImp && ori_forwardInvocation) {
            ori_forwardInvocation(self, _cmd, anInvocation);
        } else {
            id obj = [[ExceptionHandler alloc] init];
            anInvocation.target = obj;
            anInvocation.selector = @selector(noSelector);
            [anInvocation invoke];
        }
    }
}


+ (void)start {
    
    //普通类
    Class class = [NSObject class];
    Method method = class_getInstanceMethod(class, @selector(methodSignatureForSelector:));
    ori_methodSignatureForSelector = (NSMethodSignature *(*)(id,SEL, SEL))method_setImplementation(method,(IMP)methodSignatureForSelector);
    
    method = class_getInstanceMethod(class, @selector(forwardInvocation:));
    ori_forwardInvocation = (void(*)(id,SEL,NSInvocation *))method_setImplementation(method, (IMP)ds_forwardInvocation);
    //元类
    class = object_getClass(class);
    Method method_meta = class_getInstanceMethod(class, @selector(methodSignatureForSelector:));
    ori_meta_methodSignatureForSelector = (NSMethodSignature *(*)(id,SEL, SEL))method_setImplementation(method_meta,(IMP)methodSignatureForSelector);
    method_meta = class_getInstanceMethod(class, @selector(forwardInvocation:));
    ori_meta_forwardInvocation = (void(*)(id,SEL,NSInvocation *))method_setImplementation(method_meta, (IMP)ds_forwardInvocation);

    
}
@end
