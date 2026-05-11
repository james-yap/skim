//
//  SKPresentationView.m
//  Skim
//
//  Created by Christiaan Hofman on 14/09/2024.
/*
 This software is Copyright (c) 2024
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

#import "SKPresentationView.h"
#import <Quartz/Quartz.h>
#import "SKApplication.h"
#import "SKNavigationWindow.h"
#import "SKTransitionController.h"
#import "SKTransitionInfo.h"
#import "SKStringConstants.h"
#import "SKMainWindowController_Actions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSEvent_SKExtensions.h"
#import "NSObject_SKExtensions.h"
#import "NSCursor_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "PDFAnnotation_SKExtensions.h"
#import "NSBezierPath_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "PDFDocument_SKExtensions.h"
#import "PDFAnnotation_SKExtensions.h"

#define NAVIGATION_BOTTOM_EDGE_HEIGHT 5.0

#define AUTO_HIDE_DELAY 3.0
#define SHOW_NAV_DELAY  0.25

#define SKUseArrowCursorInPresentationKey @"SKUseArrowCursorInPresentation"
#define SKLaserPointerColorKey @"SKLaserPointerColor"
#define SKRemoveLaserPointerShadowKey @"SKRemoveLaserPointerShadows"
#define SKDisableDrawingInPresentationKey @"SKDisableDrawingInPresentation"

NSNotificationName const SKPresentationViewPageChangedNotification = @"SKPresentationViewPageChangedNotification";
NSNotificationName const SKPresentationViewAutoScalesChangedNotification = @"SKPresentationViewAutoScalesChangedNotification";

static char SKPresentationViewDefaultsObservationContext;

enum {
    SKNavigationNone,
    SKNavigationBottom,
    SKNavigationEverywhere,
};

static NSInteger navigationMode = SKNavigationBottom;

@interface SKPDFPageView ()
- (void)displayCurrentPage:(void (^)(void))completionHandler;
- (void)redisplayAtCurrentScaleFactorIfNeeded;
@end

@implementation SKPDFPageView

@synthesize page, transitionController;
@dynamic canGoToNextPage, canGoToPreviousPage, canGoToFirstPage, canGoToLastPage;

static inline NSArray *defaultKeysToObserve() {
    if (@available(macOS 10.14, *))
        return @[SKInvertColorsInDarkModeKey, SKSepiaToneKey, SKWhitePointKey];
    else
        return @[SKSepiaToneKey, SKWhitePointKey];
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        page = nil;
        
        [self setWantsLayer:YES];
        
        pageLayer = [CALayer layer];
        [pageLayer setMasksToBounds:YES];
        [pageLayer setFrame:NSRectToCGRect([self bounds])];
        [pageLayer setAutoresizingMask:kCALayerWidthSizable | kCALayerHeightSizable];
        [pageLayer setActions:@{@"contents": [NSNull null]}];
        [pageLayer setFilters:SKColorEffectFilters()];
        [pageLayer setContentsScale:[[self layer] contentsScale]];
        [[self layer] addSublayer:pageLayer];
        
        [self setTranslatesAutoresizingMaskIntoConstraints:NO];
        
        NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
        for (NSString *key in defaultKeysToObserve())
            [sud addObserver:self forKeyPath:key options:0 context:&SKPresentationViewDefaultsObservationContext];
    }
    return self;
}

- (void)dealloc {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    for (NSString *key in defaultKeysToObserve()) {
        @try { [sud removeObserver:self forKeyPath:key context:&SKPresentationViewDefaultsObservationContext]; }
        @catch (id e) {}
    }
}

- (void)viewDidChangeEffectiveAppearance {
    if (@available(macOS 10.14, *))
        [super viewDidChangeEffectiveAppearance];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
        [pageLayer setFilters:SKColorEffectFilters()];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKPresentationViewDefaultsObservationContext)
        [pageLayer setFilters:SKColorEffectFilters()];
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];
    if ([self window] == nil)
        return;
    CGFloat scale = [[self window] backingScaleFactor];
    if (fabs([pageLayer contentsScale] - scale) > 0.0) {
        [pageLayer setContentsScale:scale];
        [self redisplayAtCurrentScaleFactorIfNeeded];
        [self removePredrawnImageAtIndex:NSNotFound];
        [self displayCurrentPage:nil];
    }
}

#pragma mark Transitions

- (void)displayPage:(PDFPage *)newPage completionHandler:(void (^)(void))completionHandler {
    page = newPage;
    [self displayCurrentPage:completionHandler];
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPresentationViewPageChangedNotification object:self];
}

- (NSRect)pageRect:(PDFPage *)aPage {
    NSRect bounds = [self bounds];
    NSRect pageRect = [aPage boundsForBox:kPDFDisplayBoxCropBox];
    if (([aPage rotation] % 180) != 0)
        pageRect = NSMakeRect(0.0, 0.0, NSHeight(pageRect), NSWidth(pageRect));
    CGFloat scale = [self autoScales] ? fmin(NSHeight(bounds) / NSHeight(pageRect), NSWidth(bounds) / NSWidth(pageRect)) : 1.0;
    return NSInsetRect(bounds, 0.5 * fmax(0.0, NSWidth(bounds) - scale * NSWidth(pageRect)), 0.5 * fmax(0.0, NSHeight(bounds) - scale * NSHeight(pageRect)));
}

static inline BOOL equalStrings(NSString *s1, NSString *s2) {
    return s1 == nil || s2 == nil || [s1 isEqualToString:s2];
}

- (BOOL)animateTransitionAtIndex:(NSUInteger)idx forward:(BOOL)forward toPage:(PDFPage *)toPage {
    if ([self window] &&
        ([transitionController pageTransitions] ||
         ([[transitionController transition] style] != SKNoTransition && equalStrings([page label], [toPage label]) == NO))) {
        SKTransitionAnimation animation = [transitionController animationAtIndex:idx forView:self];
        if (animation) {
            NSRect rect = NSUnionRect([self pageRect:page], [self pageRect:toPage]);
            [self displayPage:toPage completionHandler:^{ animation(rect, forward, nil); }];
            return YES;
        }
    }
    return NO;
}

- (void)animateToNextPage:(void (^)(void))completionHandler {
    PDFDocument *pdfDoc = [page document];
    NSUInteger idx = [page pageIndex];
    if (idx + 1 < [pdfDoc pageCount]) {
        PDFPage *toPage = [pdfDoc pageAtIndex:idx + 1];
        SKTransitionAnimation animation = [transitionController animationAtIndex:idx forView:self];
        if (animation) {
            NSRect rect = NSUnionRect([self pageRect:page], [self pageRect:toPage]);
            [self displayPage:toPage completionHandler:^{ animation(rect, YES, completionHandler); }];
        } else {
            [self displayPage:toPage completionHandler:completionHandler];
        }
    } else {
        completionHandler();
    }
}

#pragma mark Accessors

- (void)setPage:(PDFPage *)newPage {
    if (newPage != page) {
        if (newPage) {
            [self displayPage:newPage completionHandler:nil];
        } else {
            page = nil;
            [self removePredrawnImageAtIndex:NSNotFound];
            [pageLayer setContents:nil];
            // nothing needs the notification when set to nil
        }
    }
}

- (BOOL)autoScales { return YES; }

- (BOOL)canGoToNextPage {
    return [page pageIndex] + 1 < [[page document] pageCount];
}

- (BOOL)canGoToPreviousPage {
    return [page pageIndex] > 0;
}

- (BOOL)canGoToFirstPage {
    return [page pageIndex] > 0;
}

- (BOOL)canGoToLastPage {
    return [page pageIndex] + 1 < [[page document] pageCount];
}

#pragma mark Action

- (void)goToNextPage:(id)sender {
    PDFDocument *pdfDoc = [page document];
    NSUInteger idx = [page pageIndex];
    if (idx + 1 < [pdfDoc pageCount]) {
        PDFPage *toPage = [pdfDoc pageAtIndex:idx + 1];
        if (NO == [self animateTransitionAtIndex:idx forward:YES toPage:toPage])
            [self setPage:toPage];
    }
}

- (void)goToPreviousPage:(id)sender {
    PDFDocument *pdfDoc = [page document];
    NSUInteger idx = [page pageIndex];
    if (idx > 0) {
        PDFPage *toPage = [pdfDoc pageAtIndex:idx - 1];
        if (NO == [self animateTransitionAtIndex:idx - 1 forward:NO toPage:toPage])
            [self setPage:toPage];
    }
}

- (void)goToFirstPage:(id)sender {
    PDFDocument *pdfDoc = [page document];
    NSUInteger idx = [page pageIndex];
    if (idx > 0)
        [self setPage:[pdfDoc pageAtIndex:0]];
}

- (void)goToLastPage:(id)sender {
    PDFDocument *pdfDoc = [page document];
    NSUInteger idx = [page pageIndex];
    if (idx + 1 < [pdfDoc pageCount])
        [self setPage:[pdfDoc pageAtIndex:[pdfDoc pageCount] - 1]];
}

#pragma mark Drawing

- (NSImage *)predrawnImageAtIndex:(NSUInteger)pageIndex { return nil; }

- (void)removePredrawnImageAtIndex:(NSUInteger)pageIndex {}

- (dispatch_block_t)imageGeneratorForPage:(PDFPage *)aPage handler:(void (^)(NSImage *))handler {
    NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:[self bounds]];
    
    if (imageRep == nil)
        return nil;
    
    BOOL autoScales = [self autoScales];
    
    return dispatch_block_create(0, ^{
        
        NSSize size = [imageRep size];
        NSRect pageRect = [aPage boundsForBox:kPDFDisplayBoxCropBox];
        if (([aPage rotation] % 180) != 0)
            pageRect = NSMakeRect(0.0, 0.0, NSHeight(pageRect), NSWidth(pageRect));
        CGFloat scale = 1.0;
        if (autoScales) {
            scale = fmin(size.height / NSHeight(pageRect), size.width / NSWidth(pageRect));
            pageRect.size.width *= scale;
            pageRect.size.height *= scale;
        }
        pageRect.origin.x = 0.5 * (size.width - NSWidth(pageRect));
        pageRect.origin.y = 0.5 * (size.height - NSHeight(pageRect));
        
        CGContextRef context = [[NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep] CGContext];
        
        CGContextSaveGState(context);
        CGContextSetFillColorWithColor(context, CGColorGetConstantColor(kCGColorWhite));
        CGContextFillRect(context, SKPixelAlignedRect(NSRectToCGRect(pageRect), context));
        CGContextRestoreGState(context);
        CGContextSaveGState(context);
        CGContextClipToRect(context, pageRect);
        CGContextSetInterpolationQuality(context, [[NSUserDefaults standardUserDefaults] integerForKey:SKInterpolationQualityKey] + 1);
        CGContextTranslateCTM(context, NSMinX(pageRect), NSMinY(pageRect));
        CGContextScaleCTM(context, scale, scale);
        [aPage drawWithBox:kPDFDisplayBoxCropBox toContext:context];
        CGContextRestoreGState(context);
        
        NSImage *image = [[NSImage alloc] initWithSize:size];
        [image addRepresentation:imageRep];
        
        dispatch_async(dispatch_get_main_queue(), ^{ handler(image); });
    });
}

- (void)displayCurrentPage:(void (^)(void))completionHandler {
    if (page) {
        NSUInteger pageIndex = [page pageIndex];
        NSImage *predrawnImage = [self predrawnImageAtIndex:pageIndex];
        
        if (predrawnImage) {
            [pageLayer setContents:predrawnImage];
            [self removePredrawnImageAtIndex:pageIndex];
        } else {
            
            dispatch_block_t imageGenerator = [self imageGeneratorForPage:page handler:^(NSImage *image){
                if (page && pageIndex == [page pageIndex])
                    [pageLayer setContents:image];
                if (completionHandler)
                    completionHandler();
            }];
            
            if (imageGenerator) {
                
                static dispatch_queue_t drawingQueue = nil;
                if (drawingQueue == nil) {
                    dispatch_queue_attr_t queuePriority = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_UTILITY, 0);
                    drawingQueue = dispatch_queue_create("net.sourceforge.skim-app.skim.pageview.drawing", queuePriority);
                }
                
                dispatch_async(drawingQueue, imageGenerator);
                return;
            }
        }
    }
    
    if (completionHandler)
        completionHandler();
}

- (void)redisplayAtCurrentScaleFactorIfNeeded {
    CALayerContentsGravity gravity = [pageLayer contentsGravity];
    if (gravity != kCAGravityResize && gravity != kCAGravityResizeAspect && gravity != kCAGravityResizeAspectFill) {
        NSImage *image = [pageLayer contents];
        if ([image isKindOfClass:[NSImage class]]) {
            NSRect bounds = [self bounds];
            NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:bounds];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep]];
            [image drawInRect:bounds];
            [NSGraphicsContext restoreGraphicsState];
            image = [[NSImage alloc] initWithSize:bounds.size];
            [image removeRepresentation:[[image representations] firstObject]];
            [pageLayer setContents:image];
        }
    }
}

- (NSBitmapImageRep *)bitmapImageRepCachingDisplay {
    NSImage *image = [pageLayer contents];
    if ([image isKindOfClass:[NSImage class]]) {
        NSImageRep *imageRep = [[image representations] firstObject];
        if ([imageRep isKindOfClass:[NSBitmapImageRep class]])
            return (NSBitmapImageRep *)imageRep;
    }
    return [super bitmapImageRepCachingDisplay];
}

@end

#pragma mark -

@interface SKPresentationView ()

- (void)setCursorForMouse:(NSEvent *)theEvent;
- (void)setCursorAndAutoHide;
- (void)autoHideCursor;
- (void)autoHide;
- (void)showNavWindow;

- (void)dragWindowWithEvent:(NSEvent *)theEvent;
- (void)drawFreehandNoteWithEvent:(NSEvent *)theEvent;
- (void)showHelpMenu;

- (PDFAnnotation *)linkAnnotationForMouse:(NSEvent *)theEvent;

@end

@implementation SKPresentationView

@dynamic autoScales, cursorStyle, hasBlackout, removeCursorShadow, drawInPresentation;

+ (void)initialize {
    SKINITIALIZE;
    navigationMode = [[NSUserDefaults standardUserDefaults] integerForKey:SKPresentationNavigationOptionKey];
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        pvFlags.autoScales = YES;
        pvFlags.cursorHidden = NO;
        pvFlags.useArrowCursor = [[NSUserDefaults standardUserDefaults] boolForKey:SKUseArrowCursorInPresentationKey];
        pvFlags.removeLaserPointerShadow = [[NSUserDefaults standardUserDefaults] boolForKey:SKRemoveLaserPointerShadowKey];
        pvFlags.enableDrawing = NO == [[NSUserDefaults standardUserDefaults] boolForKey:SKDisableDrawingInPresentationKey];
        
        [pageLayer setContentsGravity:kCAGravityResizeAspectFill];
        
        [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
    }
    return self;
}

#pragma mark Drawing

- (NSImage *)predrawnImageAtIndex:(NSUInteger)pageIndex {
    if (predrawnImages == nil)
        return nil;
    NSImage *image = (__bridge id)NSMapGet(predrawnImages, (void *)pageIndex);
    if ([image isKindOfClass:[NSImage class]])
        return image;
    return nil;
}

static inline void cancelIfBlock(id imageOrBlock) {
    if (imageOrBlock && [imageOrBlock isKindOfClass:[NSImage class]] == NO)
        dispatch_block_cancel((dispatch_block_t)imageOrBlock);
}

- (void)removePredrawnImageAtIndex:(NSUInteger)pageIndex {
    if (predrawnImages) {
        if (pageIndex == NSNotFound) {
            for (id imageOrBlock in NSAllMapTableValues(predrawnImages))
                cancelIfBlock(imageOrBlock);
            predrawnImages = nil;
        } else {
            cancelIfBlock((__bridge id)NSMapGet(predrawnImages, (void *)pageIndex));
            NSMapRemove(predrawnImages, (void *)pageIndex);
        }
    }
}

- (void)predrawNextPage {
    if (page) {
        // generate an image for the next page in the background, which is usually needed next for a presentation
        
        NSUInteger pageIndex = [page pageIndex] + 1;
        
        if (pageIndex < [[page document] pageCount]) {
            
            if (predrawnImages == nil)
                predrawnImages = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsIntegerPersonality valueOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality capacity:2];
            else if (NSMapGet(predrawnImages, (void *)pageIndex))
                return;
            
            __block void *block = NULL;
            dispatch_block_t imageGenerator = [self imageGeneratorForPage:[[page document] pageAtIndex:pageIndex] handler:^(NSImage *image){
                if (predrawnImages && block == NSMapGet(predrawnImages, (void *)pageIndex)) {
                    NSMapRemove(predrawnImages, (void *)pageIndex);
                    NSUInteger currentIndex = [page pageIndex];
                    if (pageIndex > currentIndex)
                        NSMapInsert(predrawnImages, (void *)pageIndex, (__bridge void *)image);
                    else if (pageIndex == currentIndex)
                        [pageLayer setContents:image];
                }
            }];
            
            if (imageGenerator) {
                
                // set this block so we can cancel it
                block = (__bridge void *)imageGenerator;
                NSMapInsert(predrawnImages, (void *)pageIndex, block);
                
                static dispatch_queue_t predrawingQueue = nil;
                if (predrawingQueue == nil) {
                    dispatch_queue_attr_t queuePriority = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_BACKGROUND, 0);
                    predrawingQueue = dispatch_queue_create("net.sourceforge.skim-app.skim.pageview.predrawing", queuePriority);
                }
                
                dispatch_async(predrawingQueue, imageGenerator);
            }
        }
    }
}

- (void)displayCurrentPage:(void (^)(void))completionHandler {
    [super displayCurrentPage:completionHandler];
    [self predrawNextPage];
}

- (void)viewWillStartLiveResize {
    [super viewWillStartLiveResize];
    [self removePredrawnImageAtIndex:NSNotFound];
}

- (void)viewDidEndLiveResize {
    [super viewDidEndLiveResize];
    [self removePredrawnImageAtIndex:NSNotFound];
    [self displayCurrentPage:nil];
}

- (void)setNeedsDisplayForPage:(PDFPage *)aPage {
    if (page == nil)
        return;
    if (aPage) {
        [self removePredrawnImageAtIndex:[aPage pageIndex]];
        if (page == aPage) {
            [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(displayCurrentPage:) object:nil];
            [self performSelector:@selector(displayCurrentPage:) withObject:nil afterDelay:0.0];
        } else if ([page pageIndex] + 1 == [aPage pageIndex]) {
            [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(predrawNextPage) object:nil];
            [self performSelector:@selector(predrawNextPage) withObject:nil afterDelay:0.0];
        }
    } else {
        [self removePredrawnImageAtIndex:NSNotFound];
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(displayCurrentPage:) object:nil];
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(predrawNextPage) object:nil];
        [self performSelector:@selector(displayCurrentPage:) withObject:nil afterDelay:0.0];
    }
}

#pragma mark Transforms

- (NSPoint)convertPointToPage:(NSPoint)point {
    if (page == nil)
        return point;
    
    NSRect bounds = [self bounds];
    NSRect pageBounds = [page boundsForBox:kPDFDisplayBoxCropBox];
    CGFloat scale;
    if (pvFlags.autoScales == NO)
        scale = 1.0;
    else if (([page rotation] % 180))
        scale = fmin(NSHeight(bounds) / NSWidth(pageBounds), NSWidth(bounds) / NSHeight(pageBounds));
    else
        scale = fmin(NSHeight(bounds) / NSHeight(pageBounds), NSWidth(bounds) / NSWidth(pageBounds));
    
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:NSMidX(pageBounds) yBy:NSMidY(pageBounds)];
    [transform rotateByDegrees:[page rotation]];
    [transform scaleBy:1.0 / scale];
    [transform translateXBy:-NSMidX(bounds) yBy:-NSMidY(bounds)];

    return [transform transformPoint:point];
}

- (NSPoint)convertPointFromPage:(NSPoint)point {
    if (page == nil)
        return point;
    
    NSRect bounds = [self bounds];
    NSRect pageBounds = [page boundsForBox:kPDFDisplayBoxCropBox];
    CGFloat scale;
    if (pvFlags.autoScales == NO)
        scale = 1.0;
    else if (([page rotation] % 180))
        scale = fmin(NSHeight(bounds) / NSWidth(pageBounds), NSWidth(bounds) / NSHeight(pageBounds));
    else
        scale = fmin(NSHeight(bounds) / NSHeight(pageBounds), NSWidth(bounds) / NSWidth(pageBounds));
    
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:NSMidX(bounds) yBy:NSMidY(bounds)];
    [transform scaleBy:scale];
    [transform rotateByDegrees:-[page rotation]];
    [transform translateXBy:-NSMidX(pageBounds) yBy:-NSMidY(pageBounds)];
    
    return [transform transformPoint:point];
}

#pragma mark Accessors

- (BOOL)canBecomeKeyView {
    return YES;
}

- (BOOL)autoScales {
    return pvFlags.autoScales;
}

- (void)setAutoScales:(BOOL)flag {
    if (flag != pvFlags.autoScales) {
        pvFlags.autoScales = flag;
        [pageLayer setContentsGravity:flag ? kCAGravityResizeAspectFill : kCAGravityCenter];
        [self removePredrawnImageAtIndex:NSNotFound];
        [self displayCurrentPage:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPresentationViewAutoScalesChangedNotification object:self];
    }
}

- (BOOL)hasBlackout {
    return [pageLayer opacity] <= 0.0;
}

- (NSInteger)cursorStyle {
    return pvFlags.useArrowCursor ? -1 : laserPointerColor;
}

- (BOOL)removeCursorShadow {
    return pvFlags.removeLaserPointerShadow;
}

- (BOOL)drawInPresentation {
    return pvFlags.enableDrawing;
}

#pragma mark Actions

- (void)toggleAutoActualSize:(id)sender {
    [self setAutoScales:[self autoScales] == NO];
}

- (void)toggleBlackout:(id)sender {
    [pageLayer setOpacity:1.0 - [pageLayer opacity]];
}

- (void)exitPresentation:(id)sender {
    [self tryToPerform:@selector(togglePresentation:) with:self];
}

- (void)toggleLaserPointer:(id)sender {
    pvFlags.useArrowCursor = pvFlags.useArrowCursor == NO;
    [self setCursorAndAutoHide];
    [[NSUserDefaults standardUserDefaults] setBool:pvFlags.useArrowCursor forKey:SKUseArrowCursorInPresentationKey];
    [cursorWindow selectCursorStyle:[self cursorStyle]];
}

- (void)nextLaserPointerColor:(id)sender {
    laserPointerColor = (laserPointerColor + 1) % 7;
    [self setCursorAndAutoHide];
    [[NSUserDefaults standardUserDefaults] setInteger:laserPointerColor forKey:SKLaserPointerColorKey];
    [cursorWindow selectCursorStyle:[self cursorStyle]];
}

- (void)previousLaserPointerColor:(id)sender {
    laserPointerColor = (laserPointerColor + 6) % 7;
    [self setCursorAndAutoHide];
    [[NSUserDefaults standardUserDefaults] setInteger:laserPointerColor forKey:SKLaserPointerColorKey];
    [cursorWindow selectCursorStyle:[self cursorStyle]];
}

- (void)closeCursorStyleWindow:(id)sender {
    [cursorWindow fadeOut];
}

- (void)changeCursorStyle:(id)sender {
    NSInteger style = [sender selectedTag];
    if (style < 0) {
        pvFlags.useArrowCursor = YES;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SKUseArrowCursorInPresentationKey];
    } else {
        pvFlags.useArrowCursor = NO;
        laserPointerColor = style % 7;
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:SKUseArrowCursorInPresentationKey];
        [[NSUserDefaults standardUserDefaults] setInteger:laserPointerColor forKey:SKLaserPointerColorKey];
    }
}

- (void)toggleRemoveCursorShadow:(id)sender {
    pvFlags.removeLaserPointerShadow = pvFlags.removeLaserPointerShadow == NO;
    [[NSUserDefaults standardUserDefaults] setBool:pvFlags.removeLaserPointerShadow forKey:SKRemoveLaserPointerShadowKey];
}

- (void)toggleDrawInPresentation:(id)sender {
    pvFlags.enableDrawing = pvFlags.enableDrawing == NO;
    [[NSUserDefaults standardUserDefaults] setBool:NO == pvFlags.enableDrawing forKey:SKDisableDrawingInPresentationKey];
}

- (void)cancelOperation:(id)sender {
    for (NSWindow *window in [[self window] childWindows]) {
        if (window != navWindow && window != cursorWindow) {
            [self tryToPerform:@selector(toggleLeftSidePane:) with:sender];
            return;
        }
    }
    if ([self hasBlackout])
        [self toggleBlackout:sender];
    else if ([cursorWindow isVisible])
        [self closeCursorStyleWindow:sender];
    else
        [[self window] tryToPerform:_cmd with:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(goToNextPage:))
        return [self canGoToNextPage];
    else if ([menuItem action] == @selector(goToPreviousPage:))
        return [self canGoToPreviousPage];
    else if ([menuItem action] == @selector(goToFirstPage:))
        return [self canGoToFirstPage];
    else if ([menuItem action] == @selector(goToLastPage:))
        return [self canGoToLastPage];
    else if ([menuItem action] == @selector(nextLaserPointerColor:) || [menuItem action] == @selector(previousLaserPointerColor:))
        return pvFlags.useArrowCursor == NO;
    else if ([NSView instancesRespondToSelector:_cmd])
        return [super validateMenuItem:menuItem];
    else
        return YES;
}

#pragma mark Event handlers

- (void)keyDown:(NSEvent *)theEvent {
    unichar eventChar = [theEvent firstCharacter];
    NSEventModifierFlags modifiers = [theEvent deviceIndependentModifierFlags] & ~NSEventModifierFlagCapsLock;
    NSEventModifierFlags standardModifiers = modifiers & ~NSEventModifierFlagNumericPad & ~NSEventModifierFlagFunction;
    
    if (((eventChar == NSDownArrowFunctionKey) && ((standardModifiers & ~NSEventModifierFlagOption) == 0)) ||
        ((eventChar == NSRightArrowFunctionKey) && ((standardModifiers & ~NSEventModifierFlagCommand) == 0)) ||
        ((eventChar == NSPageDownFunctionKey) && (standardModifiers == 0))) {
        [self goToNextPage:self];
    } else if (((eventChar == NSUpArrowFunctionKey) && ((standardModifiers & ~NSEventModifierFlagOption) == 0)) ||
               ((eventChar == NSLeftArrowFunctionKey) && ((standardModifiers & ~NSEventModifierFlagCommand) == 0)) ||
               ((eventChar == NSPageUpFunctionKey) && (standardModifiers == 0))) {
        [self goToPreviousPage:self];
    } else if (((eventChar == NSLeftArrowFunctionKey) && (standardModifiers == NSEventModifierFlagOption)) ||
               ((eventChar == NSUpArrowFunctionKey) && (standardModifiers  == NSEventModifierFlagCommand)) ||
               ((eventChar == NSHomeFunctionKey) && (standardModifiers == 0))) {
        [self goToFirstPage:self];
    } else if (((eventChar == NSRightArrowFunctionKey) && (standardModifiers == NSEventModifierFlagOption)) ||
               ((eventChar == NSDownArrowFunctionKey) && (standardModifiers  == NSEventModifierFlagCommand)) ||
               ((eventChar == NSEndFunctionKey && standardModifiers == 0))) {
        [self goToLastPage:self];
    } else if ((eventChar == 'p') && (modifiers == 0)) {
        [self tryToPerform:@selector(toggleOverview:) with:self];
    } else if ((eventChar == 't') && (modifiers == 0)) {
        [self tryToPerform:@selector(toggleLeftSidePane:) with:self];
    } else if ((eventChar == 'a') && (modifiers == 0)) {
        [self toggleAutoActualSize:self];
    } else if ((eventChar == 'b') && (modifiers == 0)) {
        [self toggleBlackout:self];
    } else if ((eventChar == 'l') && (modifiers == 0)) {
        [self toggleLaserPointer:nil];
    } else if (pvFlags.useArrowCursor == NO && (eventChar == 'c') && (modifiers == 0)) {
        [self nextLaserPointerColor:nil];
    } else if (pvFlags.useArrowCursor == NO && (eventChar == 'C') && ((modifiers & ~NSEventModifierFlagShift) == 0)) {
        [self previousLaserPointerColor:nil];
    } else if (pvFlags.useArrowCursor == NO && (eventChar == ',') && (modifiers == 0)) {
        if ([cursorWindow isVisible])
            [self closeCursorStyleWindow:nil];
        else
            [self showCursorStyleWindow:nil];
    } else if ((eventChar == '?') && ((modifiers & ~NSEventModifierFlagShift) == 0)) {
        [self showHelpMenu];
    } else {
        [super keyDown:theEvent];
    }
}

#define IS_TABLET_EVENT(theEvent, deviceType) (([theEvent subtype] == NSEventSubtypeTabletProximity || [theEvent subtype] == NSEventSubtypeTabletPoint) && [NSEvent currentPointingDeviceType] == deviceType)

- (BOOL)shouldDragWindowWithEvent:(NSEvent *)theEvent {
    if (IS_TABLET_EVENT(theEvent, NSPointingDeviceTypePen))
        return NO;
    if (pvFlags.enableDrawing && ([theEvent modifierFlags] & NSEventModifierFlagShift))
        return NO;
    NSWindow *window = [self window];
    return ([window styleMask] & NSWindowStyleMaskResizable) != 0 && NSEqualRects([window frame], [[window screen] frame]) == NO;
}

- (void)mouseDown:(NSEvent *)theEvent {
    BOOL didHideMouse = pvFlags.cursorHidden;
    if ([pageLayer opacity] <= 0.0) {
        [pageLayer setOpacity:1.0];
    } else if ([NSApp willDragMouse] == NO) {
        PDFDestination *link = [[self linkAnnotationForMouse:theEvent] destination];
        if (link)
            [self setPage:[link page]];
        else
            [self goToNextPage:self];
    } else if ([self shouldDragWindowWithEvent:theEvent]) {
        pvFlags.cursorHidden = NO;
        [[NSCursor closedHandCursor] set];
        [self dragWindowWithEvent:theEvent];
    } else if (pvFlags.enableDrawing || IS_TABLET_EVENT(theEvent, NSPointingDeviceTypePen)) {
        pvFlags.cursorHidden = NO;
        [[NSCursor arrowCursor] set];
        [self drawFreehandNoteWithEvent:theEvent];
    } else {
        [super mouseDown:theEvent];
    }
    if (didHideMouse) {
        [self autoHideCursor];
    } else {
        [self setCursorAndAutoHide];
    }
}

- (void)rightMouseDown:(NSEvent *)theEvent {
    [self goToPreviousPage:nil];
}

- (void)mouseMoved:(NSEvent *)theEvent {
    pvFlags.cursorHidden = NO;
    [self setCursorForMouse:theEvent];
    [self performSelectorOnce:@selector(autoHide) afterDelay:AUTO_HIDE_DELAY];
    
    if (navigationMode != SKNavigationNone && [navWindow isVisible] == NO) {
        if (navigationMode == SKNavigationEverywhere && [cursorWindow isVisible] == NO && NSPointInRect([theEvent locationInWindow], [[[self window] contentView] frame])) {
            if (navWindow == nil)
                navWindow = [[SKNavigationWindow alloc] initWithView:self];
            [navWindow showForWindow:[self window]];
            NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor(self), NSAccessibilityLayoutChangedNotification, [NSDictionary dictionaryWithObjectsAndKeys:NSAccessibilityUnignoredChildrenForOnlyChild(navWindow), NSAccessibilityUIElementsKey, nil]);
        } else if (navigationMode == SKNavigationBottom && NSPointInRect([theEvent locationInWindow], SKSliceRect([[[self window] contentView] frame], NAVIGATION_BOTTOM_EDGE_HEIGHT, NSRectEdgeMinY))) {
            [self performSelectorOnce:@selector(showNavWindow) afterDelay:SHOW_NAV_DELAY];
        }
    }
    
    [super mouseMoved:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent {
    if (pvFlags.cursorHidden || (pvFlags.useArrowCursor == NO && pvFlags.removeLaserPointerShadow && pvFlags.cursorHidden == NO)) {
        pvFlags.cursorHidden = NO;
        [self setCursorForMouse:theEvent];
    }
    [self performSelectorOnce:@selector(autoHide) afterDelay:AUTO_HIDE_DELAY];
    [super mouseDragged:theEvent];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    [super mouseEntered:theEvent];
}
 
- (void)mouseExited:(NSEvent *)theEvent {
    NSTrackingArea *eventArea = [theEvent trackingArea];
    if (([eventArea options] & NSTrackingInVisibleRect)) {
        [[NSCursor arrowCursor] set];
    } else {
        [super mouseExited:theEvent];
    }
}

- (void)swipeWithEvent:(NSEvent *)theEvent {
    if ([theEvent deltaX] < 0.0 || [theEvent deltaX] + [theEvent deltaY] < 0.0) {
        if ([self canGoToNextPage])
            [self goToNextPage:nil];
    } else if ([theEvent deltaX] > 0.0 || [theEvent deltaX] + [theEvent deltaY] > 0.0) {
        if ([self canGoToPreviousPage])
            [self goToPreviousPage:nil];
    } else {
        [super swipeWithEvent:theEvent];
    }
}

- (void)scrollWheel:(NSEvent *)theEvent {
    switch ([theEvent phase]) {
        case NSEventPhaseBegan:
            pvFlags.handleScroll = YES;
            pvFlags.didScrollNext = NO;
            pvFlags.didScrollPrevious = NO;
            scrollDelta = [theEvent scrollingDeltaX] + [theEvent scrollingDeltaY];
            break;
        case NSEventPhaseChanged:
            if (pvFlags.handleScroll) {
                CGFloat scrollingDelta = [theEvent scrollingDeltaX] + [theEvent scrollingDeltaY];
                if (fabs(scrollingDelta) <= 0.0)
                    break;
                if ((scrollingDelta > 0.0) != (scrollDelta > 0.0)) {
                    scrollDelta = scrollingDelta;
                } else {
                    scrollDelta += scrollingDelta;
                    if (scrollDelta < -50.0 && pvFlags.didScrollNext == NO) {
                        pvFlags.didScrollNext = YES;
                        if ([self canGoToNextPage])
                            [self goToNextPage:nil];
                        return;
                    } else if (scrollDelta > 50.0 && pvFlags.didScrollPrevious == NO) {
                        pvFlags.didScrollPrevious = YES;
                        if ([self canGoToPreviousPage])
                            [self goToPreviousPage:nil];
                        return;
                    }
                }
            }
            break;
        case NSEventPhaseEnded:
        case NSEventPhaseCancelled:
        case NSEventPhaseMayBegin:
            pvFlags.handleScroll = NO;
            break;
        default:
            break;
    }
    [super scrollWheel:theEvent];
}

- (void)dragWindowWithEvent:(NSEvent *)theEvent {
    NSWindow *window = [self window];
    NSRect frame = [window frame];
    NSPoint offset = SKSubstractPoints(frame.origin, [[theEvent window] convertPointToScreen:[theEvent locationInWindow]]);
    while (YES) {
        theEvent = [window nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged];
        if ([theEvent type] == NSEventTypeLeftMouseUp)
             break;
        frame.origin = SKAddPoints([[theEvent window] convertPointToScreen:[theEvent locationInWindow]], offset);
        [window setFrame:SKConstrainRect(frame, [[window screen] frame]) display:YES];
    }
}

static NSArray *scaledDashPattern(NSArray *dashPattern, CGFloat scale) {
    if ([dashPattern count] == 0)
        return nil;
    NSMutableArray *array = [NSMutableArray array];
    for (NSNumber *dash in dashPattern)
        [array addObject:[NSNumber numberWithDouble:scale * [dash doubleValue]]];
    return array;
}

- (void)drawFreehandNoteWithEvent:(NSEvent *)theEvent {
    NSRect bounds = [self bounds];
    NSRect pageBounds = [page boundsForBox:kPDFDisplayBoxCropBox];
    CGFloat scale;
    if (pvFlags.autoScales == NO)
        scale = 1.0;
    else if (([page rotation] % 180))
        scale = fmin(NSHeight(bounds) / NSWidth(pageBounds), NSWidth(bounds) / NSHeight(pageBounds));
    else
        scale = fmin(NSHeight(bounds) / NSHeight(pageBounds), NSWidth(bounds) / NSWidth(pageBounds));
    
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:NSMidX(pageBounds) yBy:NSMidY(pageBounds)];
    [transform rotateByDegrees:[page rotation]];
    [transform scaleBy:1.0 / scale];
    [transform translateXBy:-NSMidX(bounds) yBy:-NSMidY(bounds)];
    
    NSPoint point = [transform transformPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
    NSWindow *window = [self window];
    BOOL wasMouseCoalescingEnabled = [NSEvent isMouseCoalescingEnabled];
    BOOL isOption = ([theEvent modifierFlags] & NSEventModifierFlagOption) != 0;
    BOOL wasOption = NO;
    BOOL wantsBreak = isOption;
    NSBezierPath *bezierPath = nil;
    CGMutablePathRef cgPath = NULL;
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    CAShapeLayer *layer = nil;
    NSRect boxBounds = pvFlags.autoScales ? pageBounds : NSIntersectionRect(pageBounds, SKTransformRect(transform, bounds));
    CGAffineTransform t = CGAffineTransformMakeRotation(-M_PI_2 * [page rotation] / 90.0);
    NSColor *tmpColor = [sud colorForKey:SKPresentationInkNoteColorKey];
    layer = [CAShapeLayer layer];
    // transform and place so that the path is in scaled page coordinates
    [layer setBounds:CGRectMake(scale * NSMinX(boxBounds), scale * NSMinY(boxBounds), scale * NSWidth(boxBounds), scale * NSHeight(boxBounds))];
    [layer setAnchorPoint:CGPointMake(0.5, 0.5)];
    [layer setPosition:CGPointMake(NSMidX(bounds), NSMidY(bounds))];
    [layer setAffineTransform:t];
    [layer setMasksToBounds:YES];
    [layer setFillColor:NULL];
    [layer setLineJoin:kCALineJoinRound];
    [layer setLineCap:kCALineCapRound];
    [layer setStrokeColor:[tmpColor ?: [sud colorForKey:SKInkNoteColorKey] CGColor]];
    [layer setLineWidth:[sud floatForKey:SKInkNoteLineWidthKey] * scale];
    if ((PDFBorderStyle)[sud integerForKey:SKInkNoteLineStyleKey] == kPDFBorderStyleDashed) {
        [layer setLineDashPattern:scaledDashPattern([sud arrayForKey:SKInkNoteDashPatternKey], scale)];
        [layer setLineCap:kCALineCapButt];
    }
    
    [layer setContentsScale:[[self layer] contentsScale]];
    [pageLayer addSublayer:layer];
    
    t = CGAffineTransformMakeScale(scale, scale);
    
    // don't coalesce mouse event from mouse while drawing,
    // but not from tablets because those fire very rapidly and lead to serious delays
    if ([NSEvent currentPointingDeviceType] == NSPointingDeviceTypeUnknown)
        [NSEvent setMouseCoalescingEnabled:NO];
    
    while (YES) {
        theEvent = [window nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged | NSEventMaskFlagsChanged];
        
        if ([theEvent type] == NSEventTypeLeftMouseUp) {
            
            break;
            
        } else if ([theEvent type] == NSEventTypeLeftMouseDragged) {
            
            if (bezierPath == nil) {
                bezierPath = [NSBezierPath bezierPath];
                [bezierPath moveToPoint:point];
            } else if (wantsBreak && NO == NSEqualPoints(point, [bezierPath associatedPointForElementAtIndex:[bezierPath elementCount] - 2])) {
                [PDFAnnotation addPoint:point toSkimNotesPath:bezierPath];
            }
            
            point = [transform transformPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
            
            if (isOption && wantsBreak == NO) {
                NSInteger eltCount = [bezierPath elementCount];
                NSPoint points[3] = {point, point, point};
                if (NSCurveToBezierPathElement == [bezierPath elementAtIndex:eltCount - 1]) {
                    points[0] = [bezierPath associatedPointForElementAtIndex:eltCount - 2];
                    points[0].x += ( point.x - points[0].x ) / 3.0;
                    points[0].y += ( point.y - points[0].y ) / 3.0;
                }
                [bezierPath setAssociatedPoints:points atIndex:eltCount - 1];
            } else {
                [PDFAnnotation addPoint:point toSkimNotesPath:bezierPath];
            }
            
            wasOption = isOption;
            wantsBreak = NO;
            
            cgPath = CGPathCreateMutable();
            [bezierPath addToCGPath:cgPath transform:&t];
            [layer setPath:cgPath];
            CGPathRelease(cgPath);
            
        } else if ((([theEvent modifierFlags] & NSEventModifierFlagOption) != 0) != isOption) {
            
            isOption = isOption == NO;
            wantsBreak = isOption || wasOption;
            
        }
    }
    
    [NSEvent setMouseCoalescingEnabled:wasMouseCoalescingEnabled];
    
    if (bezierPath) {
        NSMutableArray *paths = [[NSMutableArray alloc] init];
        [paths addObject:bezierPath];
        
        PDFAnnotation *annotation = [PDFAnnotation newSkimNoteWithPaths:paths];
        if (tmpColor)
            [annotation setColor:tmpColor];
        [[page document] addAnnotation:annotation toPage:page];
        
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(displayCurrentPage:) object:nil];
        [self displayCurrentPage:^{
            [layer removeFromSuperlayer];
        }];
    } else {
        [layer removeFromSuperlayer];
    }
}

- (void)showHelpMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *item;
    item = [menu addItemWithTitle:NSLocalizedString(@"Go To Next Page", @"Menu item title") action:@selector(goToNextPage:) keyEquivalent:@"\uF703"];
    [item setKeyEquivalentModifierMask:0];
    item = [menu addItemWithTitle:NSLocalizedString(@"Go To Previous Page", @"Menu item title") action:@selector(goToPreviousPage:) keyEquivalent:@"\uF702"];
    [item setKeyEquivalentModifierMask:0];
    item = [menu addItemWithTitle:NSLocalizedString(@"Show Overview", @"Menu item title") action:@selector(toggleOverview:) keyEquivalent:@"p"];
    [item setKeyEquivalentModifierMask:0];
    item = [menu addItemWithTitle:NSLocalizedString(@"Show Contents Pane", @"Menu item title") action:@selector(toggleLeftSidePane:) keyEquivalent:@"t"];
    [item setKeyEquivalentModifierMask:0];
    item = [menu addItemWithTitle:[NSString stringWithFormat:@"%@ / %@", NSLocalizedString(@"Actual Size", @"Menu item title"), NSLocalizedString(@"Fit to Screen", @"Menu item title")] action:@selector(toggleAutoActualSize:) keyEquivalent:@"a"];
    [item setKeyEquivalentModifierMask:0];
    item = [menu addItemWithTitle:NSLocalizedString(@"Blackout", @"Menu item title") action:@selector(toggleBlackout:) keyEquivalent:@"b"];
    [item setKeyEquivalentModifierMask:0];
    item = [menu addItemWithTitle:NSLocalizedString(@"Laser Pointer", @"Menu item title") action:@selector(toggleLaserPointer:) keyEquivalent:@"l"];
    [item setKeyEquivalentModifierMask:0];
    item = [menu addItemWithTitle:NSLocalizedString(@"Laser Pointer Color", @"Menu item title") action:@selector(nextLaserPointerColor:) keyEquivalent:@"c"];
    [item setKeyEquivalentModifierMask:0];
    item = [menu addItemWithTitle:NSLocalizedString(@"Pointers", @"Menu item title") action:@selector(showCursorStyleWindow:) keyEquivalent:@","];
    [item setKeyEquivalentModifierMask:0];
    item = [menu addItemWithTitle:NSLocalizedString(@"End", @"Menu item title") action:@selector(cancelOperation:) keyEquivalent:@"\e"];
    [item setKeyEquivalentModifierMask:0];
    [[NSCursor arrowCursor] set];
    NSPoint point = SKTopLeftPoint(SKRectFromCenterAndSize(SKCenterPoint([self bounds]), [menu size]));
    [menu popUpMenuPositioningItem:nil atLocation:point inView:self];
}

- (PDFAnnotation *)linkAnnotationForMouse:(NSEvent *)theEvent {
    if ([[page annotations] count] == 0)
        return nil;
    
    NSPoint point = [self convertPointToPage:[self convertPoint:(theEvent ? [theEvent locationInWindow] : [[self window] convertPointFromScreen:[NSEvent mouseLocation]]) fromView:nil]];
    
    for (PDFAnnotation *annotation in [[page annotations] reverseObjectEnumerator]) {
        if ([annotation isLink] && NSPointInRect(point, [annotation bounds]))
            return annotation;
    }
    
    return nil;
}

#pragma mark Cursors and HUD windows

- (void)cancelDelayedRequests {
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(showNavWindow) object:nil];
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(autoHide) object:nil];
}

- (void)didOpen {
    [self setAutoScales:YES];
    [self performSelectorOnce:@selector(setCursorForMouse:) afterDelay:0.0];
    [self performSelectorOnce:@selector(autoHide) afterDelay:AUTO_HIDE_DELAY];
}

- (void)willClose {
    pvFlags.cursorHidden = NO;
    [NSCursor setHiddenUntilMouseMoves:NO];
    [self cancelDelayedRequests];
    if (navWindow) {
        [navWindow remove];
        navWindow = nil;
    }
    if (cursorWindow) {
        [cursorWindow remove];
        cursorWindow = nil;
    }
}

- (void)setCursorForMouse:(NSEvent *)theEvent {
    if (pvFlags.cursorHidden)
        [[NSCursor emptyCursor] set];
    else if ([[self linkAnnotationForMouse:theEvent] destination])
        [[NSCursor pointingHandCursor] set];
    else if (pvFlags.useArrowCursor)
        [[NSCursor arrowCursor] set];
    else if (pvFlags.removeLaserPointerShadow)
        [[NSCursor safeLaserPointerCursorWithColor:laserPointerColor] set];
    else
        [[NSCursor laserPointerCursorWithColor:laserPointerColor] set];
}

- (void)setCursorAndAutoHide {
    pvFlags.cursorHidden = NO;
    [self setCursorForMouse:nil];
    [self performSelectorOnce:@selector(autoHide) afterDelay:AUTO_HIDE_DELAY];
}

- (void)autoHideCursor {
    if ([NSWindow windowNumberAtPoint:[NSEvent mouseLocation] belowWindowWithWindowNumber:0] == [[self window] windowNumber]) {
        [[NSCursor emptyCursor] set];
        pvFlags.cursorHidden = YES;
        [NSCursor setHiddenUntilMouseMoves:YES];
    }
}

- (void)autoHide {
    if (([navWindow isVisible] == NO || NSPointInRect([NSEvent mouseLocation], [navWindow frame]) == NO)) {
        [self autoHideCursor];
        if ([navWindow isVisible]) {
            [navWindow fadeOut];
            NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor(self), NSAccessibilityLayoutChangedNotification, nil);
        }
    }
}

- (void)showNavWindow {
    if ([navWindow isVisible] == NO && NSPointInRect([[self window] mouseLocationOutsideOfEventStream], SKSliceRect([[[self window] contentView] frame], NAVIGATION_BOTTOM_EDGE_HEIGHT, NSRectEdgeMinY))) {
        if (navWindow == nil)
            navWindow = [[SKNavigationWindow alloc] initWithView:self];
        [navWindow showForWindow:[self window]];
        NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor(self), NSAccessibilityLayoutChangedNotification, [NSDictionary dictionaryWithObjectsAndKeys:NSAccessibilityUnignoredChildrenForOnlyChild(navWindow), NSAccessibilityUIElementsKey, nil]);
    }
}

- (void)showCursorStyleWindow:(id)sender {
    [navWindow fadeOut];
    if ([cursorWindow isVisible] == NO) {
        if (cursorWindow == nil)
            cursorWindow = [[SKCursorStyleWindow alloc] initWithView:self];
        [cursorWindow showForWindow:[self window]];
        NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor(self), NSAccessibilityLayoutChangedNotification, [NSDictionary dictionaryWithObjectsAndKeys:NSAccessibilityUnignoredChildrenForOnlyChild(cursorWindow), NSAccessibilityUIElementsKey, nil]);
    }
}

- (void)handleWindowDidResignKeyNotification:(NSNotification *)notification {
    if ([self isHiddenOrHasHiddenAncestor] == NO) {
        [self cancelDelayedRequests];
        pvFlags.cursorHidden = NO;
        [[NSCursor arrowCursor] set];
    }
}

- (void)handleWindowDidBecomeKeyNotification:(NSNotification *)notification {
    if (pvFlags.cursorHidden == NO && [self isHiddenOrHasHiddenAncestor] == NO) {
        [self performSelectorOnce:@selector(setCursorForMouse:) afterDelay:0.0];
        [self performSelectorOnce:@selector(autoHide) afterDelay:AUTO_HIDE_DELAY];
    }
}

- (void)willCloseOrHide {
    if ([pageLayer opacity] < 1.0) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [pageLayer setOpacity:1.0];
        [CATransaction commit];
    }
    [self willClose];
    [[NSCursor arrowCursor] set];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSWindow *oldWindow = [self window];
    if (oldWindow) {
        [nc removeObserver:self name:NSWindowDidBecomeKeyNotification object:oldWindow];
        [nc removeObserver:self name:NSWindowDidResignKeyNotification object:oldWindow];
    }
    if (newWindow) {
        [nc addObserver:self selector:@selector(handleWindowDidBecomeKeyNotification:) name:NSWindowDidBecomeKeyNotification object:newWindow];
        [nc addObserver:self selector:@selector(handleWindowDidResignKeyNotification:) name:NSWindowDidResignKeyNotification object:newWindow];
    } else {
        [self willCloseOrHide];
    }
    
    [super viewWillMoveToWindow:newWindow];
}

- (void)viewDidMoveToWindow {
    if ([[self window] isKeyWindow])
        [self handleWindowDidBecomeKeyNotification:nil];
    
    [super viewDidMoveToWindow];
}

- (void)viewDidHide {
    [self willCloseOrHide];
    
    [super viewDidHide];
}

- (void)viewDidUnhide {
    [super viewDidUnhide];
    
    if ([[self window] isKeyWindow])
        [self handleWindowDidBecomeKeyNotification:nil];
}

@end
