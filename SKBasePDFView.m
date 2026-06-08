//
//  SKBasePDFView.m
//  Skim
//
//  Created by Christiaan Hofman on 03/10/2021.
/*
 This software is Copyright (c) 2021
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

#import "SKBasePDFView.h"
#import "SKStringConstants.h"
#import "NSGeometry_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSEvent_SKExtensions.h"
#import "PDFAnnotation_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "PDFDestination_SKExtensions.h"
#import "NSScroller_SKExtensions.h"

#define SKNeverChangeZoomFromLinksKey @"SKNeverChangeZoomFromLinks"

static char SKBasePDFViewDefaultsObservationContext;

#if SDK_BEFORE_10_14
@interface PDFView (SKMojaveDeclarations)
@property (nonatomic, setter=enablePageShadows:) BOOL pageShadowsEnabled;
@end
#endif

@interface PDFView (SKBasePrivateDeclarations)
- (NSInteger)currentHistoryIndex;
- (id)pageViewForPageAtIndex:(NSUInteger)index;
@end

@interface NSView (SKPDFPageViewPrivateDeclarations)
- (void)addAnnotation:(PDFAnnotation *)annotation;
- (void)updateAnnotation:(PDFAnnotation *)annotation;
- (void)removeAnnotation:(PDFAnnotation *)annotation;
@end

@interface SKBasePDFView ()

- (void)handleScrollerStyleChangedNotification:(NSNotification *)notification;

@end

@implementation SKBasePDFView

#pragma mark Dark mode and color inversion

static inline NSArray *defaultKeysToObserve() {
    if (@available(macOS 10.14, *))
        return @[SKInvertColorsInDarkModeKey, SKSepiaToneKey, SKWhitePointKey];
    else
        return @[SKSepiaToneKey, SKWhitePointKey];
}

// make sure we don't use the same method name as a superclass or a subclass
- (void)commonBaseInitialization {
    minHistoryIndex = 0;
    
    NSScrollView *scrollView = [self embeddedScrollView];
    
    if (@available(macOS 10.14, *)) {
        [self setAppearance:nil];
        [[scrollView contentView] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
            [scrollView setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
        
        [self handleScrollerStyleChangedNotification:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleScrollerStyleChangedNotification:)
                                                         name:NSPreferredScrollerStyleDidChangeNotification object:nil];
    }
    
    [scrollView setContentFilters:SKColorEffectFilters()];
    
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    for (NSString *key in defaultKeysToObserve())
        [sud addObserver:self forKeyPath:key options:0 context:&SKBasePDFViewDefaultsObservationContext];
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonBaseInitialization];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        [self commonBaseInitialization];
    }
    return self;
}

- (void)dealloc {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    for (NSString *key in defaultKeysToObserve()) {
        @try { [sud removeObserver:self forKeyPath:key context:&SKBasePDFViewDefaultsObservationContext]; }
        @catch (id e) {}
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKBasePDFViewDefaultsObservationContext)
        [self colorFiltersDidChange];
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)colorFiltersDidChange {
    NSScrollView *scrollView = [self embeddedScrollView];
    if (@available(macOS 10.14, *)) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
            [scrollView setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
        else
            [scrollView setAppearance:nil];
    }
    [scrollView setContentFilters:SKColorEffectFilters()];
}

- (void)viewDidChangeEffectiveAppearance {
    if (@available(macOS 10.14, *))
        [super viewDidChangeEffectiveAppearance];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
        [[self embeddedScrollView] setContentFilters:SKColorEffectFilters()];
}

- (void)handleScrollerStyleChangedNotification:(NSNotification *)notification {
    if (@available(macOS 26.0, *)) {
        [[self embeddedScrollView] setScrollerStyle:NSScrollerStyleOverlay];
    } else if (@available(macOS 11.0, *)) {} else if (@available(macOS 10.14, *)) {
        NSAppearance *appearance = nil;
        if ([NSScroller preferredScrollerStyle] != NSScrollerStyleLegacy)
            appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        NSScrollView *scrollView = [self embeddedScrollView];
        [[scrollView verticalScroller] setAppearance:appearance];
        [[scrollView horizontalScroller] setAppearance:appearance];
    }
}

#pragma mark Annotation updating

- (NSView *)safePageViewForPage:(PDFPage *)page forSelector:(SEL)selector {
    if ([self respondsToSelector:@selector(pageViewForPageAtIndex:)] == NO || [self isPageAtIndexDisplayed:[page pageIndex]] == NO)
        return nil;
    id pageView = [self pageViewForPageAtIndex:[page pageIndex]];
    if ([pageView respondsToSelector:selector])
        return pageView;
    return nil;
}

- (void)updatedAnnotation:(PDFAnnotation *)annotation {
    [[self safePageViewForPage:[annotation page] forSelector:@selector(updateAnnotation:)] updateAnnotation:annotation];
}

- (void)addedAnnotation:(PDFAnnotation *)annotation onPage:(PDFPage *)page {
    [[self safePageViewForPage:page forSelector:@selector(addAnnotation:)] addAnnotation:annotation];
}

- (void)removedAnnotation:(PDFAnnotation *)annotation onPage:(PDFPage *)page {
    [[self safePageViewForPage:page forSelector:@selector(removeAnnotation:)] removeAnnotation:annotation];
}

#pragma mark Page shadows

- (void)setDisplaysPageBreaks:(BOOL)pageBreaks {
    [super setDisplaysPageBreaks:pageBreaks];
    if (@available(macOS 10.14, *))
        [self enablePageShadows:pageBreaks];
}

#pragma mark History

- (BOOL)canGoBack {
    BOOL canGoBack = [super canGoBack];
    if (minHistoryIndex > 0) {
        if ([self respondsToSelector:@selector(currentHistoryIndex)]) {
            canGoBack = minHistoryIndex < [self currentHistoryIndex];
        } else {
            @try {
                canGoBack = minHistoryIndex < [[self valueForKeyPath:@"_private.historyIndex"] integerValue];
            }
            @catch (id e) {}
        }
    }
    return canGoBack;
}

- (void)resetHistory {
    if ([self respondsToSelector:@selector(currentHistoryIndex)]) {
        minHistoryIndex = [self currentHistoryIndex];
    } else {
        @try {
            minHistoryIndex = [[self valueForKeyPath:@"_private.historyIndex"] integerValue];
        }
        @catch (id e) {}
    }
}

#pragma mark Responding overrides

- (BOOL)respondsToSelector:(SEL)aSelector {
    return aSelector != @selector(printDocument:) && [super respondsToSelector:aSelector];
}

// we don't want to steal the printDocument: action from the responder chain
- (void)printDocument:(id)sender{}

// PDFView has duplicated key equivalents for Cmd-+/- as well as Opt-Cmd-+/-, which is totoally unnecessary and harmful
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent { return NO; }

#pragma mark Bug fixes

- (void)setDocument:(PDFDocument *)document {
    // setting the document sets the maxScaleFactor to an insane 100
    [super setDocument:document];
    BOOL autoScale = [self autoScales];
    [self setMaxScaleFactor:20.0];
    // setting the maxScaleFactor resets autoScales
    if (autoScale != [self autoScales])
        [self setAutoScales:autoScale];
}

- (void)goToRect:(NSRect)rect onPage:(PDFPage *)page {
    if (@available(macOS 10.14, *)) {
        [super goToRect:rect onPage:page];
    } else {
        NSView *docView = [self documentView];
        if ([self isPageAtIndexDisplayed:[page pageIndex]] == NO)
            [self goToPage:page];
        [docView scrollRectToVisible:[self convertRect:[self convertRect:rect fromPage:page] toView:docView]];
    }
}

- (void)horizontallyGoToPage:(PDFPage *)page {
    if (page == [self currentPage])
        return;
    NSScrollView *scrollView = [self embeddedScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSRect bounds = [clipView bounds];
    NSRect docRect = [[scrollView documentView] frame];
    if (NSWidth(docRect) <= NSWidth(bounds))
        return;
    NSRect pageBounds = [self convertRect:[self convertRect:[page boundsForBox:[self displayBox]] fromPage:page] toView:clipView];
    CGFloat margin = 0.0;
    if ([self displaysPageBreaks])
        margin = [self pageBreakMargins].left;
    bounds.origin.x = fmin(fmax(fmin(NSMidX(pageBounds) - 0.5 * NSWidth(bounds), NSMinX(pageBounds) - margin), NSMinX(docRect)), NSMaxX(docRect) - NSWidth(bounds));
    [self goToPage:page];
    [clipView scrollToPoint:bounds.origin];
    [scrollView reflectScrolledClipView:clipView];
}

- (void)scrollToPage:(PDFPage *)page mode:(PDFDisplayMode)mode {
    NSScrollView *scrollView = [self embeddedScrollView];
    NSRect pageRect = [self convertRect:[page boundsForBox:[self displayBox]] fromPage:page];
    NSPoint center = SKCenterPoint([self bounds]);
    BOOL vertically = (mode & kPDFDisplaySinglePageContinuous) && (NSMinY(pageRect) > center.y - 0.5 * [scrollView contentInsets].top || NSMaxY(pageRect) < center.y);
    BOOL horizontally = (mode & kPDFDisplayTwoUp) && (NSMinX(pageRect) > center.x || NSMaxX(pageRect) < center.x);
    if (vertically == NO && horizontally == NO)
        return;
    NSClipView *clipView = [scrollView contentView];
    NSRect bounds = [clipView bounds];
    NSRect docRect = [[scrollView documentView] frame];
    CGFloat margin = 0.0;
    if (horizontally && NSWidth(docRect) <= NSWidth(bounds)) {
        horizontally = NO;
        if (vertically == NO)
            return;
    }
    pageRect = [self convertRect:pageRect toView:clipView];
    if (vertically) {
        CGFloat inset = [clipView contentInsets].top;
        CGFloat scrollerWidth = 0.0;
        if ([self displaysPageBreaks])
            margin = [self pageBreakMargins].top;
        if ([scrollView hasHorizontalScroller] && [scrollView scrollerStyle] == NSScrollerStyleLegacy)
            scrollerWidth = [self convertSize:NSMakeSize(0.0, [NSScroller effectiveScrollerWidth]) toView:clipView].height;
        if ([clipView isFlipped])
            bounds.origin.y = fmin(fmax(fmin(NSMaxY(pageRect) - 0.5 * (NSHeight(bounds) + fmax(scrollerWidth, inset)), NSMinY(pageRect) - margin - inset), NSMinY(docRect) - inset), NSMaxY(docRect) - NSHeight(bounds));
        else
            bounds.origin.y = fmax(fmin(fmax(NSMinY(pageRect) - 0.5 * (NSHeight(bounds) - fmax(scrollerWidth, inset)), NSMaxY(pageRect) + margin - NSHeight(bounds) + inset), NSMaxY(docRect) - NSHeight(bounds) + inset), NSMinY(docRect));
    }
    if (horizontally) {
        if ([self displaysPageBreaks])
            margin = [self pageBreakMargins].left;
        bounds.origin.x = fmin(NSMinX(pageRect) - margin, NSMaxX(docRect) - NSWidth(bounds));
    }
    [clipView scrollToPoint:bounds.origin];
    [scrollView reflectScrolledClipView:clipView];
}

- (void)verticallyScrollToTop {
    NSScrollView *scrollView = [self embeddedScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSRect bounds = [clipView bounds];
    CGFloat inset = [clipView contentInsets].top;
    NSRect docRect = [[scrollView documentView] frame];
    if (NSHeight(docRect) <= NSHeight(bounds) - inset)
        return;
    if ([clipView isFlipped])
        bounds.origin.y = NSMinY(docRect) - inset;
    else
        bounds.origin.y = NSMaxY(docRect) - NSHeight(bounds) + inset;
    [clipView scrollToPoint:bounds.origin];
    [scrollView reflectScrolledClipView:clipView];
}

- (void)verticallyScrollToBottom {
    NSScrollView *scrollView = [self embeddedScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSRect bounds = [clipView bounds];
    CGFloat inset = [clipView contentInsets].top;
    NSRect docRect = [[scrollView documentView] frame];
    if (NSHeight(docRect) <= NSHeight(bounds) - inset)
        return;
    if ([clipView isFlipped])
        bounds.origin.y = NSMaxY(docRect) - NSHeight(bounds);
    else
        bounds.origin.y = NSMinY(docRect);
    [clipView scrollToPoint:bounds.origin];
    [scrollView reflectScrolledClipView:clipView];
}

- (void)goToPreviousPage:(id)sender {
    PDFDisplayMode displayMode = [self displayMode];
    if ((displayMode & kPDFDisplaySinglePageContinuous) == 0 || [self canGoToPreviousPage] == NO) {
        [super goToPreviousPage:sender];
    } else if (displayMode == kPDFDisplaySinglePageContinuous && [self displayDirection]) {
        PDFDocument *doc = [self document];
        [self horizontallyGoToPage:[doc pageAtIndex:[doc indexForPage:[self currentPage]] - 1]];
    } else {
        PDFDocument *doc = [self document];
        NSUInteger i = [doc indexForPage:[self currentPage]];
        if (displayMode == kPDFDisplayTwoUpContinuous && (i > 1 || [self displaysAsBook] == NO))
            --i;
        [super goToPreviousPage:sender];
        if (i-- > 0)
            [self scrollToPage:[doc pageAtIndex:i] mode:kPDFDisplaySinglePageContinuous];
    }
}

- (void)goToNextPage:(id)sender {
    PDFDisplayMode displayMode = [self displayMode];
    if ((displayMode & kPDFDisplaySinglePageContinuous) == 0 || [self canGoToNextPage] == NO) {
        [super goToNextPage:sender];
    } else if (displayMode == kPDFDisplaySinglePageContinuous && [self displayDirection]) {
        PDFDocument *doc = [self document];
        [self horizontallyGoToPage:[doc pageAtIndex:[doc indexForPage:[self currentPage]] + 1]];
    } else {
        PDFDocument *doc = [self document];
        NSUInteger i = [doc indexForPage:[self currentPage]];
        if (displayMode == kPDFDisplayTwoUpContinuous && (i > 0 || [self displaysAsBook] == NO) && i + 2 < [doc pageCount])
            ++i;
        [super goToNextPage:sender];
        if (++i  < [doc pageCount])
            [self scrollToPage:[doc pageAtIndex:i] mode:kPDFDisplaySinglePageContinuous];
    }
}

- (void)goToFirstPage:(id)sender {
    PDFDisplayMode displayMode = [self displayMode];
    if (displayMode == kPDFDisplaySinglePageContinuous && [self displayDirection] && [self canGoToFirstPage]) {
        PDFDocument *doc = [self document];
        [self horizontallyGoToPage:[doc pageAtIndex:0]];
    } else {
        [super goToFirstPage:sender];
    }
}

- (void)goToLastPage:(id)sender {
    PDFDisplayMode displayMode = [self displayMode];
    if (displayMode == kPDFDisplaySinglePageContinuous && [self displayDirection] && [self canGoToLastPage]) {
        PDFDocument *doc = [self document];
        [self horizontallyGoToPage:[doc pageAtIndex:[doc pageCount] - 1]];
    } else {
        [super goToLastPage:sender];
    }
}

- (void)goAndScrollToPage:(PDFPage *)page {
    PDFDisplayMode displayMode = [self displayMode];
    if (displayMode == kPDFDisplaySinglePageContinuous && [self displayDirection]) {
        [self horizontallyGoToPage:page];
    } else {
        [self goToPage:page];
        if (displayMode != kPDFDisplaySinglePage)
            [self scrollToPage:page mode:displayMode];
   }
}

- (void)scrollToSKDestination:(SKDestination)dest {
    PDFPage *page = [[self document] pageAtIndex:dest.pageIndex];
    if (NSEqualPoints(dest.point, SKUnspecifiedPoint) == NO) {
        NSScrollView *scrollView = [self embeddedScrollView];
        NSClipView *clipView = [scrollView contentView];
        NSRect bounds = [clipView bounds];
        NSPoint origin = bounds.origin;
        bounds.origin = [self convertPoint:[self convertPoint:dest.point fromPage:page] toView:clipView];
        if ([clipView isFlipped])
            bounds.origin.y -= [clipView contentInsets].top;
        else
            bounds.origin.y -= NSHeight(bounds) - [clipView contentInsets].top;
        bounds = [clipView constrainBoundsRect:bounds];
        if (NSEqualPoints(bounds.origin, origin) == NO) {
            [clipView scrollToPoint:bounds.origin];
            [scrollView reflectScrolledClipView:clipView];
        }
    } else if ([self displayDirection] == kPDFDisplayDirectionVertical && ([self displayMode] & kPDFDisplaySinglePageContinuous)) {
        [self scrollToPage:page mode:kPDFDisplaySinglePageContinuous];
    }
}

- (void)goToDestination:(PDFDestination *)destination {
    destination = [destination effectiveDestinationForView:self];
    if ([destination zoom] < kPDFDestinationUnspecifiedValue && [destination zoom] > 0.0 && [[NSUserDefaults standardUserDefaults] boolForKey:SKNeverChangeZoomFromLinksKey] == NO)
        [self setScaleFactor:[destination zoom]];
    [super goToDestination:destination];
}

- (void)keyDown:(NSEvent *)event {
    unichar ch = [event firstCharacter];
    if (ch == NSPageDownFunctionKey || ch == NSDownArrowFunctionKey)
        keyDirection = 1;
    else if (ch == NSPageUpFunctionKey || ch == NSUpArrowFunctionKey)
        keyDirection = -1;
    else if (ch == SKSpaceCharacter)
        keyDirection = ([event modifierFlags] & NSEventModifierFlagShift) ? -1 : 1;
    [super keyDown:event];
    keyDirection = 0;
}

// PDFView binds PageDown to scrollPageUp: and ArrowDown to scrollPageUp: and v.v. (wrong!)
// the clipView is not flipped (wrong!)
// ... at least until macOS 15, but macOS 26 seems to scroll in the wrong direction

- (void)scrollPageUp:(id)sender {
    NSScrollView *scrollView = nil;
    NSClipView *clipView = nil;
    NSRect bounds = NSZeroRect;
    NSUInteger pageIndex = NSNotFound;
    PDFDisplayMode displayMode = [self displayMode];
    
    if ((displayMode & kPDFDisplaySinglePageContinuous) == 0) {
        // Apple scrolls to the bottom of the next page rather than the top
        pageIndex = [[self currentPage] pageIndex];
    } else if (displayMode == kPDFDisplayTwoUpContinuous || [self displayDirection] == kPDFDisplayDirectionVertical) {
        // Apple scrolls by too much, so correct for it
        scrollView = [self embeddedScrollView];
        clipView = [scrollView contentView];
        bounds = [clipView bounds];
    } else if ((keyDirection == -1 ? [self canGoToPreviousPage] : keyDirection == 1 ? [self canGoToNextPage] : NO)) {
        clipView = [[self embeddedScrollView] contentView];
        bounds = [clipView bounds];
    }
    
    // always call super, as it also updates the current page
    [super scrollPageUp:sender];
    
    if (scrollView) {
        CGFloat inset = [clipView contentInsets].top;
        CGFloat height = NSHeight(bounds) - inset;
        CGFloat offset = fmax(height - [scrollView verticalPageScroll], 0.5 * height);
        CGFloat scroll = NSMinY([clipView bounds]) - NSMinY(bounds);
        // check whether we have scrolled and in which direction
        // consider all implementation details as they are wrong and can change
        if ([clipView isFlipped] == NO)
            inset = 0.0;
        if (scroll < -offset)
            bounds.origin.y = fmax(NSMinY([[scrollView documentView] frame]) - inset, NSMinY(bounds) - offset);
        else if (scroll > offset)
            bounds.origin.y = fmin(NSMaxY([[scrollView documentView] frame]) - height - inset, NSMinY(bounds) + offset);
        else
            return;
        [clipView scrollToPoint:bounds.origin];
        [scrollView reflectScrolledClipView:clipView];
    } else if (pageIndex != NSNotFound) {
        // check whether we jumped pages
        NSUInteger currentPageIndex = [[self currentPage] pageIndex];
        if (currentPageIndex > pageIndex)
            [self verticallyScrollToTop];
        else if (currentPageIndex < pageIndex)
            [self verticallyScrollToBottom];
    } else if (clipView && fabs(NSMinY([clipView bounds]) - NSMinY(bounds)) <= 0.0) {
        if (keyDirection == -1) {
            [self goToPreviousPage:sender];
            [self verticallyScrollToBottom];
        } else {
            [self goToNextPage:sender];
            [self verticallyScrollToTop];
        }
    }
}

- (void)scrollPageDown:(id)sender {
    NSScrollView *scrollView = nil;
    NSClipView *clipView = nil;
    NSRect bounds = NSZeroRect;
    NSUInteger pageIndex = NSNotFound;
    PDFDisplayMode displayMode = [self displayMode];
    
    if ((displayMode & kPDFDisplaySinglePageContinuous) == 0) {
        // Apple scrolls to the top of the next page rather than the bottom
        pageIndex = [[self currentPage] pageIndex];
    } else if (displayMode == kPDFDisplayTwoUpContinuous || [self displayDirection] == kPDFDisplayDirectionVertical) {
        // Apple scrolls by too much, so correct for it
        scrollView = [self embeddedScrollView];
        clipView = [scrollView contentView];
        bounds = [clipView bounds];
    } else if ((keyDirection == 1 ? [self canGoToNextPage] : keyDirection == -1 ? [self canGoToPreviousPage] : NO)) {
        clipView = [[self embeddedScrollView] contentView];
        bounds = [clipView bounds];
    }
    
    // always call super, as it also updates the current page
    [super scrollPageDown:sender];
    
    if (scrollView) {
        CGFloat inset = [clipView contentInsets].top;
        CGFloat height = NSHeight(bounds) - inset;
        CGFloat offset = fmax(height - [scrollView verticalPageScroll], 0.5 * height);
        CGFloat scroll = NSMinY([clipView bounds]) - NSMinY(bounds);
        // check whether we have scrolled and in which direction
        // consider all implementation details as they are wrong and can change
        if ([clipView isFlipped] == NO)
            inset = 0.0;
        if (scroll > offset)
            bounds.origin.y = fmin(NSMaxY([[scrollView documentView] frame]) - height - inset, NSMinY(bounds) + offset);
        else if (scroll < -offset)
            bounds.origin.y = fmax(NSMinY([[scrollView documentView] frame]) - inset, NSMinY(bounds) - offset);
        else
            return;
        [clipView scrollToPoint:bounds.origin];
        [scrollView reflectScrolledClipView:clipView];
    } else if (pageIndex != NSNotFound) {
        // check whether we jumped pages
        NSUInteger currentPageIndex = [[self currentPage] pageIndex];
        if (currentPageIndex < pageIndex)
            [self verticallyScrollToBottom];
        else if (currentPageIndex > pageIndex)
            [self verticallyScrollToTop];
    } else if (clipView && fabs(NSMinY([clipView bounds]) - NSMinY(bounds)) <= 0.0) {
        if (keyDirection == 1) {
            [self goToNextPage:sender];
            [self verticallyScrollToTop];
        } else {
            [self goToPreviousPage:sender];
            [self verticallyScrollToBottom];
        }
    }
}

- (void)scrollLineUp:(id)sender {
    NSUInteger pageIndex = ([self displayMode] & kPDFDisplaySinglePageContinuous) ? NSNotFound : [[self currentPage] pageIndex];
    
    [super scrollLineUp:sender];
    
    if (pageIndex != NSNotFound) {
        // Apple scrolls to the bottom of the next page rather than the top
        // check whether we jumped pages
        NSUInteger currentPageIndex = [[self currentPage] pageIndex];
        if (currentPageIndex > pageIndex)
            [self verticallyScrollToTop];
        else if (currentPageIndex < pageIndex)
            [self verticallyScrollToBottom];
    }
}

- (void)scrollLineDown:(id)sender {
    NSUInteger pageIndex = ([self displayMode] & kPDFDisplaySinglePageContinuous) ? NSNotFound : [[self currentPage] pageIndex];
    
    [super scrollLineDown:sender];
    
    if (pageIndex != NSNotFound) {
        // Apple scrolls to the top of the next page rather than the bottom
        // check whether we jumped pages
        NSUInteger currentPageIndex = [[self currentPage] pageIndex];
        if (currentPageIndex < pageIndex)
            [self verticallyScrollToBottom];
        else if (currentPageIndex > pageIndex)
            [self verticallyScrollToTop];
    }
}

@end
