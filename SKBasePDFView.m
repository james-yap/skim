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

@interface PDFView (SKHistoryPrivateDeclarations)
- (NSInteger)currentHistoryIndex;
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
    
    if (@available(macOS 10.14, *)) {
        [self setAppearance:nil];
        [[[self embeddedScrollView] contentView] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
            [[self embeddedScrollView] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
        
        if (@available(macOS 11.0, *)) {} else {
            [self handleScrollerStyleChangedNotification:nil];
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleScrollerStyleChangedNotification:)
                                                             name:NSPreferredScrollerStyleDidChangeNotification object:nil];
        }
    }
    
    [[self embeddedScrollView] setContentFilters:SKColorEffectFilters()];
    
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
    if (@available(macOS 10.14, *)) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
            [[self embeddedScrollView] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
        else
            [[self embeddedScrollView] setAppearance:nil];
    }
    [[self embeddedScrollView] setContentFilters:SKColorEffectFilters()];
}

- (void)viewDidChangeEffectiveAppearance {
    if (@available(macOS 10.14, *))
        [super viewDidChangeEffectiveAppearance];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
        [[self embeddedScrollView] setContentFilters:SKColorEffectFilters()];
}

- (void)handleScrollerStyleChangedNotification:(NSNotification *)notification {
    if (@available(macOS 10.14, *)) {
        NSAppearance *appearance = nil;
        if ([NSScroller preferredScrollerStyle] != NSScrollerStyleLegacy)
            appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        [[[self embeddedScrollView] verticalScroller] setAppearance:appearance];
        [[[self embeddedScrollView] horizontalScroller] setAppearance:appearance];
    }
}

- (void)setDisplaysPageBreaks:(BOOL)pageBreaks {
    [super setDisplaysPageBreaks:pageBreaks];
    if (@available(macOS 10.14, *))
        [self enablePageShadows:pageBreaks];
}

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

static inline BOOL hasHorizontalLayout(PDFView *pdfView) {
    return [pdfView displayDirection] == kPDFDisplayDirectionHorizontal && [pdfView displayMode] == kPDFDisplaySinglePageContinuous;
}

static inline BOOL hasVerticalLayout(PDFView *pdfView) {
    return [pdfView displayDirection] == kPDFDisplayDirectionVertical && ([pdfView displayMode] & kPDFDisplaySinglePageContinuous);
}

static void horizontallyGoToPage(PDFView *pdfView, PDFPage *page) {
    if (page == [pdfView currentPage])
        return;
    NSScrollView *scrollView = [pdfView embeddedScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSRect bounds = [clipView bounds];
    NSRect docRect = [[scrollView documentView] frame];
    if (NSWidth(docRect) <= NSWidth(bounds))
        return;
    NSRect pageBounds = [pdfView convertRect:[pdfView convertRect:[page boundsForBox:[pdfView displayBox]] fromPage:page] toView:clipView];
    CGFloat margin = 0.0;
    if ([pdfView displaysPageBreaks])
        margin = [pdfView pageBreakMargins].left;
    bounds.origin.x = fmin(fmax(fmin(NSMidX(pageBounds) - 0.5 * NSWidth(bounds), NSMinX(pageBounds) - margin), NSMinX(docRect)), NSMaxX(docRect) - NSWidth(bounds));
    [pdfView goToPage:page];
    [clipView scrollPoint:bounds.origin];
}

static void verticallyScrollToPage(PDFView *pdfView, PDFPage *page) {
    NSScrollView *scrollView = [pdfView embeddedScrollView];
    NSRect pageRect = [pdfView convertRect:[page boundsForBox:[pdfView displayBox]] fromPage:page];
    CGFloat midY = NSMidY([pdfView bounds]);
    if (NSMinY(pageRect) <= midY - 0.5 * [scrollView contentInsets].top && NSMaxY(pageRect) >= midY)
        return;
    NSClipView *clipView = [scrollView contentView];
    NSRect bounds = [clipView bounds];
    NSRect docRect = [[scrollView documentView] frame];
    CGFloat margin = 0.0;
    CGFloat inset = [clipView contentInsets].top;
    CGFloat scrollerWidth = 0.0;
    if ([pdfView displaysPageBreaks])
        margin = [pdfView pageBreakMargins].top;
    if ([scrollView hasHorizontalScroller] && [scrollView scrollerStyle] == NSScrollerStyleLegacy)
        scrollerWidth = [pdfView convertSize:NSMakeSize(0.0, [NSScroller effectiveScrollerWidth]) toView:clipView].height;
    pageRect = [pdfView convertRect:pageRect toView:clipView];
    if ([clipView isFlipped])
        bounds.origin.y = fmin(fmax(fmin(NSMaxY(pageRect) - 0.5 * (NSHeight(bounds) + fmax(scrollerWidth, inset)), NSMinY(pageRect) - margin - inset), NSMinY(docRect) - inset), NSMaxY(docRect) - NSHeight(bounds));
    else
        bounds.origin.y = fmax(fmin(fmax(NSMinY(pageRect) - 0.5 * (NSHeight(bounds) - fmax(scrollerWidth, inset)), NSMaxY(pageRect) + margin - NSHeight(bounds) + inset), NSMaxY(docRect) - NSHeight(bounds) + inset), NSMinY(docRect));
    [clipView scrollPoint:bounds.origin];
}

static void horizontallyScrollToPage(PDFView *pdfView, PDFPage *page) {
    NSScrollView *scrollView = [pdfView embeddedScrollView];
    NSRect pageRect = [pdfView convertRect:[page boundsForBox:[pdfView displayBox]] fromPage:page];
    CGFloat midX = NSMidX([pdfView bounds]);
    if (NSMinX(pageRect) <= midX && NSMaxX(pageRect) >= midX)
        return;
    NSClipView *clipView = [scrollView contentView];
    NSRect bounds = [clipView bounds];
    NSRect docRect = [[scrollView documentView] frame];
    if (NSWidth(bounds) >= NSWidth(docRect))
        return;
    CGFloat margin = 0.0;
    if ([pdfView displaysPageBreaks])
        margin = [pdfView pageBreakMargins].left;
    pageRect = [pdfView convertRect:pageRect toView:clipView];
    bounds.origin.x = fmin(NSMinX(pageRect) - margin, NSMaxX(docRect) - NSWidth(bounds));
    [clipView scrollPoint:bounds.origin];
}

static void verticallyScrollToTop(PDFView *pdfView) {
    NSScrollView *scrollView = [pdfView embeddedScrollView];
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
    [clipView scrollPoint:bounds.origin];
}

static void verticallyScrollToBottom(PDFView *pdfView) {
    NSScrollView *scrollView = [pdfView embeddedScrollView];
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
    [clipView scrollPoint:bounds.origin];
}

- (void)goToPreviousPage:(id)sender {
    if (hasHorizontalLayout(self) && [self canGoToPreviousPage]) {
        PDFDocument *doc = [self document];
        PDFPage *page = [doc pageAtIndex:[doc indexForPage:[self currentPage]] - 1];
        horizontallyGoToPage(self, page);
    } else {
        PDFPage *page = nil;
        if (hasVerticalLayout(self)) {
            NSUInteger i = [[self currentPage] pageIndex];
            NSUInteger di = ([self displayMode] == kPDFDisplayTwoUpContinuous && (i > 1 || [self displaysAsBook] == NO)) ? 2 : 1;
            if (i >= di)
                page = [[self document] pageAtIndex:i - di];
        }
        [super goToPreviousPage:sender];
        if (page)
            verticallyScrollToPage(self, page);
    }
}

- (void)goToNextPage:(id)sender {
    if (hasHorizontalLayout(self) && [self canGoToNextPage]) {
        PDFDocument *doc = [self document];
        PDFPage *page = [doc pageAtIndex:[doc indexForPage:[self currentPage]] + 1];
        horizontallyGoToPage(self, page);
    } else {
        PDFPage *page = nil;
        if (hasVerticalLayout(self)) {
            NSUInteger i = [[self currentPage] pageIndex];
            NSUInteger di = ([self displayMode] == kPDFDisplayTwoUpContinuous && (i > 0 || [self displaysAsBook] == NO)) ? 2 : 1;
            if (i + di  < [[self document] pageCount])
                page = [[self document] pageAtIndex:i + di];
            else if (di == 2 && i + 1  < [[self document] pageCount])
                page = [[self document] pageAtIndex:i + 1];
        }
        [super goToNextPage:sender];
        if (page)
            verticallyScrollToPage(self, page);
    }
}

- (void)goToFirstPage:(id)sender {
    if (hasHorizontalLayout(self) && [self canGoToFirstPage]) {
        PDFDocument *doc = [self document];
        PDFPage *page = [doc pageAtIndex:0];
        horizontallyGoToPage(self, page);
    } else {
        [super goToFirstPage:sender];
    }
}

- (void)goToLastPage:(id)sender {
    if (hasHorizontalLayout(self) && [self canGoToLastPage]) {
        PDFDocument *doc = [self document];
        PDFPage *page = [doc pageAtIndex:[doc pageCount] - 1];
        horizontallyGoToPage(self, page);
    } else {
        [super goToLastPage:sender];
    }
}

- (void)goAndScrollToPage:(PDFPage *)page {
    if (hasHorizontalLayout(self)) {
        horizontallyGoToPage(self, page);
    } else {
        [self goToPage:page];
        if (hasVerticalLayout(self))
            verticallyScrollToPage(self, page);
        if (([self displayMode] & kPDFDisplayTwoUp) != 0)
            horizontallyScrollToPage(self, page);
   }
}

- (void)scrollToSKDestination:(SKDestination)dest {
    PDFPage *page = [[self document] pageAtIndex:dest.pageIndex];
    if (NSEqualPoints(dest.point, SKUnspecifiedPoint) == NO) {
        NSScrollView *scrollView = [self embeddedScrollView];
        NSClipView *clipView = [scrollView contentView];
        dest.point = [self convertPoint:[self convertPoint:dest.point fromPage:page] toView:clipView];
        if ([clipView isFlipped])
            dest.point.y -= [clipView contentInsets].top;
        else
            dest.point.y -= NSHeight([clipView bounds]) - [clipView contentInsets].top;
        [clipView scrollPoint:dest.point];
    } else if (hasVerticalLayout(self)) {
        verticallyScrollToPage(self, page);
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
    
    if (([self displayMode] & kPDFDisplaySinglePageContinuous) == 0) {
        // Apple scrolls to the bottom of the next page rather than the top
        pageIndex = [[self currentPage] pageIndex];
    } else if (hasVerticalLayout(self)) {
        // Apple scrolls by too much, so correct for it
        scrollView = [self embeddedScrollView];
        clipView = [scrollView contentView];
        bounds = [clipView bounds];
    } else if (hasHorizontalLayout(self) && (keyDirection == -1 ? [self canGoToPreviousPage] : keyDirection == 1 ? [self canGoToNextPage] : NO)) {
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
        [clipView scrollPoint:bounds.origin];
    } else if (pageIndex != NSNotFound) {
        // check whether we jumped pages
        NSUInteger currentPageIndex = [[self currentPage] pageIndex];
        if (currentPageIndex > pageIndex)
            verticallyScrollToTop(self);
        else if (currentPageIndex < pageIndex)
            verticallyScrollToBottom(self);
    } else if (clipView && NSEqualPoints([clipView bounds].origin, bounds.origin)) {
        if (keyDirection == -1) {
            [self goToPreviousPage:sender];
            verticallyScrollToBottom(self);
        } else {
            [self goToNextPage:sender];
            verticallyScrollToTop(self);
        }
    }
}

- (void)scrollPageDown:(id)sender {
    NSScrollView *scrollView = nil;
    NSClipView *clipView = nil;
    NSRect bounds = NSZeroRect;
    NSUInteger pageIndex = NSNotFound;
    
    if (([self displayMode] & kPDFDisplaySinglePageContinuous) == 0) {
        // Apple scrolls to the top of the next page rather than the bottom
        pageIndex = [[self currentPage] pageIndex];
    } else if (hasVerticalLayout(self)) {
        // Apple scrolls by too much, so correct for it
        scrollView = [self embeddedScrollView];
        clipView = [scrollView contentView];
        bounds = [clipView bounds];
    } else if (hasHorizontalLayout(self) && (keyDirection == 1 ? [self canGoToNextPage] : keyDirection == -1 ? [self canGoToPreviousPage] : NO)) {
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
        [clipView scrollPoint:bounds.origin];
    } else if (pageIndex != NSNotFound) {
        // check whether we jumped pages
        NSUInteger currentPageIndex = [[self currentPage] pageIndex];
        if (currentPageIndex < pageIndex)
            verticallyScrollToBottom(self);
        else if (currentPageIndex > pageIndex)
            verticallyScrollToTop(self);
    } else if (clipView && NSEqualPoints([clipView bounds].origin, bounds.origin)) {
        if (keyDirection == 1) {
            [self goToNextPage:sender];
            verticallyScrollToTop(self);
        } else {
            [self goToPreviousPage:sender];
            verticallyScrollToBottom(self);
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
            verticallyScrollToTop(self);
        else if (currentPageIndex < pageIndex)
            verticallyScrollToBottom(self);
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
            verticallyScrollToBottom(self);
        else if (currentPageIndex > pageIndex)
            verticallyScrollToTop(self);
    }
}

@end
