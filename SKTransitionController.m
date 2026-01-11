//
//  SKTransitionController.m
//  Skim
//
//  Created by Christiaan Hofman on 7/15/07.
/*
 This software is Copyright (c) 2007
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
 
/*
 This code is based partly on Apple's AnimatingTabView example code
 and Ankur Kothari's AnimatingTabsDemo application <http://dev.lipidity.com>
*/

#import "SKTransitionController.h"
#import "SKTransitionInfo.h"
#import "NSView_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import <Quartz/Quartz.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#define kCIInputBacksideImageKey @"inputBacksideImage"

#define TRANSITIONS_PLUGIN @"SkimTransitions.plugin"

@interface SKTransitionView : NSView <MTKViewDelegate> {
    MTKView *metalView;
    CIImage *image;
    CGRect extent;
    CIFilter *filter;
    id<MTLCommandQueue> commandQueue;
    CIContext *context;
    BOOL inUse;
}
@property (nonatomic) CGRect extent;
@property (nonatomic, strong) CIFilter *filter;
@property (nonatomic) CGFloat progress;
@property (nonatomic, getter=isInUse) BOOL inUse;
@end

#pragma mark -

@implementation SKTransitionController

@synthesize transition, pageTransitions, shouldScale;

static inline CGRect scaleRect(NSRect rect, CGFloat scale) {
    return CGRectMake(scale * NSMinX(rect), scale * NSMinY(rect), scale * NSWidth(rect), scale * NSHeight(rect));
}

// rect and extent are in pixels
static CIFilter *makeTransitionFilter(NSString *name, CGRect rect, CGRect extent, CGFloat scale, BOOL forward, CIImage *initialImage, CIImage *finalImage) {
    CIFilter *transitionFilter = [CIFilter filterWithName:name];
    BOOL scaled = fabs(scale - 1.0) > 0.0;
    
    [transitionFilter setDefaults];
    
    for (NSString *key in [transitionFilter inputKeys]) {
        id value = nil;
        NSDictionary *attrs = [[transitionFilter attributes] objectForKey:key];
        NSString *type = [attrs objectForKey:kCIAttributeType];
        if ([key isEqualToString:kCIInputExtentKey]) {
            value = [CIVector vectorWithCGRect:extent];
        } else if ([key isEqualToString:kCIInputAngleKey]) {
            CGFloat angle = forward ? 0.0 : M_PI;
            if ([name hasPrefix:@"CIPageCurl"])
                angle = forward ? -M_PI_4 : -3.0 * M_PI_4;
            value = [NSNumber numberWithDouble:angle];
        } else if ([key isEqualToString:kCIInputCenterKey]) {
            value = [CIVector vectorWithX:CGRectGetMidX(rect) Y:CGRectGetMidY(rect)];
        } else if ([key isEqualToString:kCIInputImageKey]) {
            value = initialImage;
        } else if ([key isEqualToString:kCIInputTargetImageKey]) {
            value = finalImage;
        } else if ([key isEqualToString:kCIInputShadingImageKey]) {
            static CIImage *inputShadingImage = nil;
            if (inputShadingImage == nil)
                inputShadingImage = [[CIImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"TransitionShading" withExtension:@"tiff"]];
            value = inputShadingImage;
        } else if ([key isEqualToString:kCIInputBacksideImageKey]) {
            value = initialImage;
        } else if ([type isEqualToString:kCIAttributeTypeBoolean]) {
            if ([[NSSet setWithObjects:@"inputBackward", @"inputRight", @"inputReversed", nil] containsObject:key])
                value = [NSNumber numberWithBool:forward == NO];
            else if ([[NSSet setWithObjects:@"inputForward", @"inputLeft", nil] containsObject:key])
                value = [NSNumber numberWithBool:forward];
            else
                continue;
        } else if (scaled && [type isEqualToString:kCIAttributeTypeDistance]) {
            if ([transitionFilter valueForKey:key] == nil) continue;
            CGFloat width = scale * [[transitionFilter valueForKey:key] doubleValue];
            NSNumber *limit;
            if ((limit = [attrs objectForKey:kCIAttributeMin]))
                width = fmax(width, [limit doubleValue]);
            if ((limit = [attrs objectForKey:kCIAttributeMax]))
                width = fmin(width, [limit doubleValue]);
            value = [NSNumber numberWithDouble:width];
        } else if (scaled && [type isEqualToString:kCIAttributeTypePosition]) {
            if ([transitionFilter valueForKey:key] == nil) continue;
            CGPoint point = [[transitionFilter valueForKey:key] CGPointValue];
            value = [CIVector vectorWithCGPoint:CGPointMake(scale * point.x, scale * point.y)];
        } else if (scaled && [type isEqualToString:kCIAttributeTypeRectangle]) {
            if ([transitionFilter valueForKey:key] == nil) continue;
            CGRect r = [[transitionFilter valueForKey:key] CGRectValue];
            value = [CIVector vectorWithCGRect:CGRectMake(scale * CGRectGetMinX(r), scale * CGRectGetMinY(r), scale * CGRectGetWidth(r), scale * CGRectGetHeight(r))];
        } else if ([[attrs objectForKey:kCIAttributeClass] isEqualToString:@"CIImage"]) {
            // Scale and translate our mask image to match the transition area size.
            static CIImage *inputMaskImage = nil;
            if (inputMaskImage == nil)
                inputMaskImage = [[CIImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"TransitionMask" withExtension:@"jpg"]];
            CGRect maskExtent = [inputMaskImage extent];
            CGAffineTransform transform;
            if ((CGRectGetWidth(maskExtent) < CGRectGetHeight(maskExtent)) != (CGRectGetWidth(rect) < CGRectGetHeight(rect))) {
                transform = CGAffineTransformMake(0.0, 1.0, 1.0, 0.0, 0.0, 0.0);
                transform = CGAffineTransformTranslate(transform, CGRectGetMinY(rect), CGRectGetMinX(rect));
                transform = CGAffineTransformScale(transform, CGRectGetHeight(rect) / CGRectGetWidth(maskExtent), CGRectGetWidth(rect) / CGRectGetHeight(maskExtent));
            } else {
                transform = CGAffineTransformMakeTranslation(CGRectGetMinX(rect), CGRectGetMinY(rect));
                transform = CGAffineTransformScale(transform, CGRectGetWidth(rect) / CGRectGetWidth(maskExtent), CGRectGetHeight(rect) / CGRectGetHeight(maskExtent));
            }
            value = [inputMaskImage imageByApplyingTransform:transform];
        } else continue;
        [transitionFilter setValue:value forKey:key];
    }
    
    return transitionFilter;
}

static CIImage *currentImageForView(NSView *view) {
    NSBitmapImageRep *contentBitmap = [view bitmapImageRepCachingDisplay];
    CIImage *image = [[CIImage alloc] initWithBitmapImageRep:contentBitmap];
    NSArray *colorFilters = SKColorEffectFilters();
    if ([colorFilters count] > 0) {
        for (CIFilter *filter in colorFilters) {
            [filter setValue:image forKey:kCIInputImageKey];
            image = [filter outputImage];
        }
    }
    return image;
}

- (SKTransitionAnimation)animationAtIndex:(NSUInteger)idx forView:(NSView *)view {
    if ([transitionView isInUse])
        return nil;
    
    SKTransitionInfo *currentTransition = transition;
    if (idx < [pageTransitions count])
        currentTransition = [[SKTransitionInfo alloc] initWithProperties:[pageTransitions objectAtIndex:idx]];
    
    if ([currentTransition style] == SKNoTransition)
        return nil;
    
    CIImage *initialImage = currentImageForView(view);
    
    NSRect bounds = [view bounds];
    CGFloat imageScale = CGRectGetWidth([initialImage extent]) / NSWidth(bounds);
    CGFloat scale = shouldScale ? imageScale * NSHeight(bounds) / NSHeight([[[view window] screen] frame]) : imageScale;
    
    if (transitionView == nil)
        transitionView = [[SKTransitionView alloc] initWithFrame:bounds];
    else
        [transitionView setFrame:bounds];
    [transitionView setInUse:YES];
    
    SKTransitionView *transView = transitionView;
    
    return ^(NSRect rect, BOOL forward, void (^completionHandler)(void)){
        
        CIImage *finalImage = currentImageForView(view);
        CGRect cgRect = CGRectIntegral(scaleRect(rect, imageScale));
        CGRect cgBounds = scaleRect(bounds, imageScale);
        CGRect extent = [currentTransition shouldRestrict] ? cgRect : cgBounds;
        NSString *filterName = [currentTransition styleName];
        CIFilter *transitionFilter = makeTransitionFilter(filterName, cgRect, extent, scale, forward, initialImage, finalImage);
        
        [transView setExtent:cgBounds];
        [transView setFilter:transitionFilter];
        [view addSubview:transView positioned:NSWindowAbove relativeTo:nil];

        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [context setDuration:[currentTransition duration]];
                [[transView animator] setProgress:1.0];
            } completionHandler:^{
                [transView removeFromSuperview];
                [transView setFilter:nil];
                [transView setInUse:NO];
                if (completionHandler)
                    completionHandler();
            }];
        
    };
}

@end

#pragma mark -

@implementation SKTransitionView

@synthesize extent, filter, inUse;
@dynamic progress;

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self && [MTKView class]) {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        metalView = [[MTKView alloc] initWithFrame:[self bounds] device:device];
        [metalView setFramebufferOnly:NO];
        [metalView setEnableSetNeedsDisplay:YES];
        [metalView setPaused:YES];
        [metalView setClearColor:MTLClearColorMake(0.0, 0.0, 0.0, 1.0)];
        [metalView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [metalView setDelegate:self];
        [self addSubview:metalView];
        commandQueue = [device newCommandQueue];
        context = [CIContext contextWithMTLDevice:device];
        [self setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        CAAnimation *animation = [CABasicAnimation animation];
        [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
        [self setAnimations:@{@"progress":animation}];
    }
    return self;
}

- (CGFloat)progress {
    NSNumber *number = [filter valueForKey:kCIInputTimeKey];
    return number ? [number doubleValue] : 0.0;
}

- (void)setProgress:(CGFloat)newProgress {
    if (filter) {
        [filter setValue:[NSNumber numberWithDouble:newProgress] forKey:kCIInputTimeKey];
        image = [filter outputImage];
        if ([metalView alphaValue] <= 0.0) {
            [self setNeedsDisplay:YES];
            [metalView setAlphaValue:1.0];
        }
        [metalView setNeedsDisplay:YES];
    }
}

- (void)setFilter:(CIFilter *)newFilter {
    if (newFilter != filter) {
        filter = newFilter;
        image = [filter valueForKey:kCIInputImageKey];
        [metalView setAlphaValue:0.0];
        [metalView setNeedsDisplay:YES];
        [self setNeedsDisplay:YES];
    }
}

- (void)drawInMTKView:(MTKView *)view {
    if (image == nil)
        return;
    
    id<CAMetalDrawable> drawable = [view currentDrawable];
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:[view currentRenderPassDescriptor]];
    
    [commandEncoder endEncoding];
    
    CGRect bounds = {CGPointZero, [view drawableSize]};
    CIImage *img = image;
    CGColorSpaceRef cs = CGColorSpaceRetain([image colorSpace]) ?: CGColorSpaceRetain([(CIImage *)[filter valueForKey:kCIInputImageKey] colorSpace]) ?: CGColorSpaceCreateDeviceRGB();
    
    if (CGRectEqualToRect(extent, bounds) == NO) {
        CGAffineTransform t = CGAffineTransformMakeScale(CGRectGetWidth(bounds) / CGRectGetWidth(extent), CGRectGetHeight(bounds) / CGRectGetHeight(extent));
        t = CGAffineTransformTranslate(t, -CGRectGetMinX(extent), -CGRectGetMinY(extent));
        img = [image imageByApplyingTransform:t];
    }
    
    [context render:img toMTLTexture:[drawable texture] commandBuffer:commandBuffer bounds:bounds colorSpace:cs];
    
    CGColorSpaceRelease(cs);
    
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}

- (void)drawRect:(NSRect)rect {
    if ([metalView alphaValue] <= 0.0) {
        [[NSColor blackColor] setFill];
        NSRectFill([self bounds]);
        [image drawInRect:[self bounds] fromRect:extent operation:NSCompositingOperationSourceOver fraction:1.0];
    }
}

@end
