//
//  SKPresentationView.h
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const SKPresentationViewPageChangedNotification;
extern NSNotificationName const SKPresentationViewAutoScalesChangedNotification;

@class PDFPage, SKTransitionController, SKNavigationWindow, SKCursorStyleWindow;

@interface SKPDFPageView : NSView {
    CALayer *pageLayer;
    PDFPage *page;
    SKTransitionController *transitionController;
}

@property (nonatomic, nullable, strong) PDFPage *page;

@property (nonatomic, nullable, strong) SKTransitionController *transitionController;

@property (nonatomic) BOOL canGoToNextPage;
@property (nonatomic) BOOL canGoToPreviousPage;
@property (nonatomic) BOOL canGoToFirstPage;
@property (nonatomic) BOOL canGoToLastPage;

- (void)goToNextPage:(nullable id)sender;
- (void)goToPreviousPage:(nullable id)sender;
- (void)goToFirstPage:(nullable id)sender;
- (void)goToLastPage:(nullable id)sender;

- (void)displayPage:(PDFPage *)page completionHandler:(void (^ _Nullable)(void))completionHandler;
- (void)animateToNextPage:(void (^)(void))completionHandler;

@end

#pragma mark -

@interface SKPresentationView : SKPDFPageView {
    NSMapTable *predrawnImages;
    SKNavigationWindow *navWindow;
    SKCursorStyleWindow *cursorWindow;
    NSInteger laserPointerColor;
    CGFloat scrollDelta;
    struct _pvFlags {
        unsigned int autoScales:1;
        unsigned int cursorHidden:1;
        unsigned int useArrowCursor:1;
        unsigned int removeLaserPointerShadow:1;
        unsigned int enableDrawing:1;
        unsigned int handleScroll:1;
        unsigned int didScrollNext:1;
        unsigned int didScrollPrevious:1;
    } pvFlags;
    
}

@property (nonatomic) BOOL autoScales;

@property (nonatomic) BOOL hasBlackout;

@property (nonatomic) NSInteger cursorStyle;
@property (nonatomic) BOOL removeCursorShadow;
@property (nonatomic) BOOL drawInPresentation;

- (void)toggleAutoActualSize:(nullable id)sender;

- (void)exitPresentation:(nullable id)sender;

- (void)showCursorStyleWindow:(nullable id)sender;
- (void)closeCursorStyleWindow:(nullable id)sender;

- (void)changeCursorStyle:(nullable id)sender;
- (void)toggleRemoveCursorShadow:(nullable id)sender;
- (void)toggleDrawInPresentation:(nullable id)sender;

- (void)didOpen;
- (void)willClose;

- (void)setNeedsDisplayForPage:(nullable PDFPage *)aPage;

@end

NS_ASSUME_NONNULL_END
