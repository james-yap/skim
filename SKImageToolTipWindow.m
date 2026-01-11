//
//  SKImageToolTipWindow.m
//  Skim
//
//  Created by Christiaan Hofman on 2/16/07.
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

#import "SKImageToolTipWindow.h"
#import "NSGeometry_SKExtensions.h"
#import "NSScreen_SKExtensions.h"
#import "SKStringConstants.h"
#import "NSColor_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSWindow_SKExtensions.h"

#define WINDOW_OFFSET           18.0
#define ALPHA_VALUE             0.95
#define CRITICAL_ALPHA_VALUE    0.9
#define AUTO_HIDE_TIME_INTERVAL 10.0
#define DEFAULT_SHOW_DELAY      1.5
#define ALT_SHOW_DELAY          0.2
#define GENERATE_DELAY          0.1
#define WINDOW_LEVEL            ((NSWindowLevel)104)
#define DEFAULT_SCALE           -2.0

#define SKToolTipScaleKey @"SKToolTipScale"

@implementation SKImageToolTipWindow

@synthesize currentImageContext=context;

static SKImageToolTipWindow *sharedToolTipWindow = nil;

+ (SKImageToolTipWindow *)sharedToolTipWindow {
    if (sharedToolTipWindow == nil)
        sharedToolTipWindow = [[self alloc] init];
    return sharedToolTipWindow;
}

- (instancetype)initWithContentRect:(NSRect)contentRect {
    if (sharedToolTipWindow) NSLog(@"Attempt to allocate second instance of %@", self);
    self = [super initWithContentRect:contentRect];
    if (self) {
        [self setHidesOnDeactivate:NO];
        [self setIgnoresMouseEvents:YES];
        [self setBackgroundColor:[NSColor whiteColor]];
        [self setOpaque:YES];
        [self setHasShadow:YES];
        [self setLevel:WINDOW_LEVEL];
        [self setDefaultAlphaValue:ALPHA_VALUE];
        [self setAutoHideTimeInterval:AUTO_HIDE_TIME_INTERVAL];
        context = nil;
        point = NSZeroPoint;
        image = nil;
        shouldShow = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orderOut:) 
                                                     name:NSApplicationWillResignActiveNotification object:NSApp];
        if (@available(macOS 10.14, *)) {
            NSVisualEffectView *backgroundView = [[NSVisualEffectView alloc] init];
            [backgroundView setMaterial:NSVisualEffectMaterialToolTip];
            [backgroundView setState:NSVisualEffectStateActive];
            [backgroundView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
            [self setContentView:backgroundView];
        } else {
            [self setBackgroundColor:[NSColor colorWithGenericGamma22White:0.97 alpha:1.0]];
        }
        
        imageView = [self addImageViewWithImage:nil];
    }
    return self;
}

+ (dispatch_queue_t)imageQueue {
    static dispatch_queue_t imageQueue = nil;
    if (imageQueue == nil) {
        dispatch_queue_attr_t queuePriority = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_DEFAULT, 0);
        imageQueue = dispatch_queue_create("net.sourceforge.skim-app.skim.thumbnails.default", queuePriority);
    }
    return imageQueue;
}

- (void)orderOut:(id)sender {
    context = nil;
    point = NSZeroPoint;
    image = nil;
    shouldShow = NO;
    [super orderOut:sender];
}

- (void)fadeOut {
    // ignore any currently generating image
    context = nil;
    point = NSZeroPoint;
    image = nil;
    shouldShow = NO;
    [super fadeOut];
}

- (void)showDelayed {
    if (image) {
        [imageView setImage:image];
        
        BOOL isOpaque = [[[image representations] firstObject] isOpaque];
        [[self contentView] setContentFilters:isOpaque ? SKColorEffectFilters() : @[]];
        
        NSPoint thePoint = NSEqualPoints(point, NSZeroPoint) ? [NSEvent mouseLocation] : point;
        NSRect screenRect = [[NSScreen screenForPoint:thePoint] frame];
        NSRect contentRect = NSZeroRect;
        contentRect.size = [image size];
        contentRect.origin.x = fmin(thePoint.x, NSMaxX(screenRect) - NSWidth(contentRect));
        contentRect.origin.y = thePoint.y - WINDOW_OFFSET - NSHeight(contentRect);
        contentRect = [self frameRectForContentRect:contentRect];
        if (NSMinY(contentRect) < NSMinX(screenRect))
            contentRect.origin.y = thePoint.y + WINDOW_OFFSET;
        [self setFrame:contentRect display:NO];
        
        if ([self isVisible] && [self alphaValue] > CRITICAL_ALPHA_VALUE)
            [self orderFront:self];
        else
            [self fadeIn];
        
        image = nil;
        shouldShow = NO;
    } else {
        shouldShow = YES;
    }
}

- (void)generateImage {
    id <SKImageToolTipContext> aContext = context;
    CGFloat backingScale = [[NSScreen mainScreen] backingScaleFactor];
    NSNumber *usedScaleNumber = [[NSUserDefaults standardUserDefaults] objectForKey:SKToolTipScaleKey];
    CGFloat usedScale = [usedScaleNumber respondsToSelector:@selector(doubleValue)] ? [usedScaleNumber doubleValue] : DEFAULT_SCALE;
    if (usedScale <= 0.0)
        usedScale = usedScale < 0.0 ? fmin(scale, -usedScale) : scale;
    
    dispatch_async([[self class] imageQueue], ^{
        
        NSImage *anImage = [aContext toolTipImageWithScale:usedScale backingScale:backingScale];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // check if another image is enerated or we are fading out
            if (aContext == context) {
                image = anImage;
                if (image == nil)
                    [self fadeOut];
                else if (shouldShow)
                    [self showDelayed];
            }
            
        });
        
    });
}

- (void)stopAnimation {
    [super stopAnimation];
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(generateImage) object:nil];
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(showDelayed) object:nil];
}

- (void)showForImageContext:(id <SKImageToolTipContext>)aContext scale:(CGFloat)aScale atPoint:(NSPoint)aPoint {
    point = aPoint;
    
    if ([aContext isEqual:context] == NO) {
        [self stopAnimation];
        
        context = aContext;
        scale = aScale;
        image = nil;
        shouldShow = NO;
        
        [self performSelector:@selector(generateImage) withObject:nil afterDelay:GENERATE_DELAY];
        [self performSelector:@selector(showDelayed) withObject:nil afterDelay:[self isVisible] ? ALT_SHOW_DELAY : DEFAULT_SHOW_DELAY];
    }
}

@end
