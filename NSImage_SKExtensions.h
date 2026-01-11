//
//  NSImage_SKExtensions.h
//  Skim
//
//  Created by Christiaan Hofman on 7/27/07.
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSImageName const SKImageNameTextNote;
extern NSImageName const SKImageNameAnchoredNote;
extern NSImageName const SKImageNameCircleNote;
extern NSImageName const SKImageNameSquareNote;
extern NSImageName const SKImageNameHighlightNote;
extern NSImageName const SKImageNameUnderlineNote;
extern NSImageName const SKImageNameStrikeOutNote;
extern NSImageName const SKImageNameLineNote;
extern NSImageName const SKImageNameInkNote;
extern NSImageName const SKImageNameWidgetNote;

extern NSImageName const SKImageNameToolbarPageUp;
extern NSImageName const SKImageNameToolbarPageDown;
extern NSImageName const SKImageNameToolbarFirstPage;
extern NSImageName const SKImageNameToolbarLastPage;
extern NSImageName const SKImageNameToolbarBack;
extern NSImageName const SKImageNameToolbarForward;
extern NSImageName const SKImageNameToolbarZoomIn;
extern NSImageName const SKImageNameToolbarZoomOut;
extern NSImageName const SKImageNameToolbarZoomActual;
extern NSImageName const SKImageNameToolbarZoomToFit;
extern NSImageName const SKImageNameToolbarZoomToSelection;
extern NSImageName const SKImageNameToolbarAutoScales;
extern NSImageName const SKImageNameToolbarRotateRight;
extern NSImageName const SKImageNameToolbarRotateLeft;
extern NSImageName const SKImageNameToolbarCrop;
extern NSImageName const SKImageNameToolbarFullScreen;
extern NSImageName const SKImageNameToolbarPresentation;
extern NSImageName const SKImageNameToolbarSinglePage;
extern NSImageName const SKImageNameToolbarTwoUp;
extern NSImageName const SKImageNameToolbarSinglePageContinuous;
extern NSImageName const SKImageNameToolbarTwoUpContinuous;
extern NSImageName const SKImageNameToolbarHorizontal;
extern NSImageName const SKImageNameToolbarRTL;
extern NSImageName const SKImageNameToolbarBookMode;
extern NSImageName const SKImageNameToolbarPageBreaks;
extern NSImageName const SKImageNameToolbarMediaBox;
extern NSImageName const SKImageNameToolbarCropBox;
extern NSImageName const SKImageNameToolbarLeftPane;
extern NSImageName const SKImageNameToolbarRightPane;
extern NSImageName const SKImageNameToolbarSplitPDF;
extern NSImageName const SKImageNameToolbarTextNoteMenu;
extern NSImageName const SKImageNameToolbarAnchoredNoteMenu;
extern NSImageName const SKImageNameToolbarCircleNoteMenu;
extern NSImageName const SKImageNameToolbarSquareNoteMenu;
extern NSImageName const SKImageNameToolbarHighlightNoteMenu;
extern NSImageName const SKImageNameToolbarUnderlineNoteMenu;
extern NSImageName const SKImageNameToolbarStrikeOutNoteMenu;
extern NSImageName const SKImageNameToolbarLineNoteMenu;
extern NSImageName const SKImageNameToolbarInkNoteMenu;
extern NSImageName const SKImageNameToolbarAddTextNote;
extern NSImageName const SKImageNameToolbarAddAnchoredNote;
extern NSImageName const SKImageNameToolbarAddCircleNote;
extern NSImageName const SKImageNameToolbarAddSquareNote;
extern NSImageName const SKImageNameToolbarAddHighlightNote;
extern NSImageName const SKImageNameToolbarAddUnderlineNote;
extern NSImageName const SKImageNameToolbarAddStrikeOutNote;
extern NSImageName const SKImageNameToolbarAddLineNote;
extern NSImageName const SKImageNameToolbarAddInkNote;
extern NSImageName const SKImageNameToolbarAddTextNoteMenu;
extern NSImageName const SKImageNameToolbarAddAnchoredNoteMenu;
extern NSImageName const SKImageNameToolbarAddCircleNoteMenu;
extern NSImageName const SKImageNameToolbarAddSquareNoteMenu;
extern NSImageName const SKImageNameToolbarAddHighlightNoteMenu;
extern NSImageName const SKImageNameToolbarAddUnderlineNoteMenu;
extern NSImageName const SKImageNameToolbarAddStrikeOutNoteMenu;
extern NSImageName const SKImageNameToolbarAddLineNoteMenu;
extern NSImageName const SKImageNameToolbarAddInkNoteMenu;
extern NSImageName const SKImageNameToolbarNotes;
extern NSImageName const SKImageNameToolbarTextTool;
extern NSImageName const SKImageNameToolbarMoveTool;
extern NSImageName const SKImageNameToolbarMagnifyTool;
extern NSImageName const SKImageNameToolbarSelectTool;
extern NSImageName const SKImageNameToolbarSnapshotTool;
extern NSImageName const SKImageNameToolbarShare;
extern NSImageName const SKImageNameToolbarPlay;
extern NSImageName const SKImageNameToolbarPause;
extern NSImageName const SKImageNameToolbarInfo;
extern NSImageName const SKImageNameToolbarColors;
extern NSImageName const SKImageNameToolbarFonts;
extern NSImageName const SKImageNameToolbarLines;
extern NSImageName const SKImageNameToolbarPrint;

extern NSImageName const SKImageNameTouchBarPageUp;
extern NSImageName const SKImageNameTouchBarPageDown;
extern NSImageName const SKImageNameTouchBarFirstPage;
extern NSImageName const SKImageNameTouchBarLastPage;
extern NSImageName const SKImageNameTouchBarZoomIn;
extern NSImageName const SKImageNameTouchBarZoomOut;
extern NSImageName const SKImageNameTouchBarZoomActual;
extern NSImageName const SKImageNameTouchBarZoomToSelection;
extern NSImageName const SKImageNameTouchBarTextTool;
extern NSImageName const SKImageNameTouchBarMoveTool;
extern NSImageName const SKImageNameTouchBarMagnifyTool;
extern NSImageName const SKImageNameTouchBarSelectTool;
extern NSImageName const SKImageNameTouchBarSnapshotTool;
extern NSImageName const SKImageNameTouchBarTextNote;
extern NSImageName const SKImageNameTouchBarAnchoredNote;
extern NSImageName const SKImageNameTouchBarCircleNote;
extern NSImageName const SKImageNameTouchBarSquareNote;
extern NSImageName const SKImageNameTouchBarHighlightNote;
extern NSImageName const SKImageNameTouchBarUnderlineNote;
extern NSImageName const SKImageNameTouchBarStrikeOutNote;
extern NSImageName const SKImageNameTouchBarLineNote;
extern NSImageName const SKImageNameTouchBarInkNote;
extern NSImageName const SKImageNameTouchBarTextNotePopover;
extern NSImageName const SKImageNameTouchBarAnchoredNotePopover;
extern NSImageName const SKImageNameTouchBarCircleNotePopover;
extern NSImageName const SKImageNameTouchBarSquareNotePopover;
extern NSImageName const SKImageNameTouchBarHighlightNotePopover;
extern NSImageName const SKImageNameTouchBarUnderlineNotePopover;
extern NSImageName const SKImageNameTouchBarStrikeOutNotePopover;
extern NSImageName const SKImageNameTouchBarLineNotePopover;
extern NSImageName const SKImageNameTouchBarInkNotePopover;
extern NSImageName const SKImageNameTouchBarAddTextNote;
extern NSImageName const SKImageNameTouchBarAddAnchoredNote;
extern NSImageName const SKImageNameTouchBarAddCircleNote;
extern NSImageName const SKImageNameTouchBarAddSquareNote;
extern NSImageName const SKImageNameTouchBarAddHighlightNote;
extern NSImageName const SKImageNameTouchBarAddUnderlineNote;
extern NSImageName const SKImageNameTouchBarAddStrikeOutNote;
extern NSImageName const SKImageNameTouchBarAddLineNote;
extern NSImageName const SKImageNameTouchBarAddInkNote;
extern NSImageName const SKImageNameTouchBarNewSeparator;
extern NSImageName const SKImageNameTouchBarRefresh;
extern NSImageName const SKImageNameTouchBarStopProgress;

extern NSImageName const SKImageNameGeneralPreferences;
extern NSImageName const SKImageNameDisplayPreferences;
extern NSImageName const SKImageNameNotesPreferences;
extern NSImageName const SKImageNameSyncPreferences;

extern NSImageName const SKImageNameToolbarNewFolder;
extern NSImageName const SKImageNameToolbarNewSeparator;
extern NSImageName const SKImageNameToolbarDelete;

extern NSImageName const SKImageNameOutlineViewAdorn;
extern NSImageName const SKImageNameThumbnailViewAdorn;
extern NSImageName const SKImageNameNoteViewAdorn;
extern NSImageName const SKImageNameSnapshotViewAdorn;
extern NSImageName const SKImageNameFindViewAdorn;
extern NSImageName const SKImageNameGroupedFindViewAdorn;
extern NSImageName const SKImageNameTextToolAdorn;
extern NSImageName const SKImageNameInkToolAdorn;

extern NSImageName const SKImageNameTextAlignLeft;
extern NSImageName const SKImageNameTextAlignCenter;
extern NSImageName const SKImageNameTextAlignRight;

extern NSImageName const SKImageNameRemoteStateResize;
extern NSImageName const SKImageNameRemoteStateScroll;

@interface NSImage (SKExtensions)

+ (NSImage *)bitmapImageWithSize:(NSSize)size forView:(NSView *)view drawingHandler:(void (^)(NSRect dstRect))drawingHandler;

+ (NSImage *)imageWithSize:(NSSize)size drawingHandler:(BOOL (^)(NSRect dstRect))drawingHandler;

- (NSImage *)initPDFWithSize:(NSSize)size drawingHandler:(void (^)(NSRect dstRect))drawingHandler;

// 0=red, 1=orange, 2=yellow, 3=green, 4=blue, 5=indigo, 6=violet
+ (NSImage *)laserPointerImageWithColor:(NSInteger)color;

+ (NSImage *)stampForType:(NSString *)type;

+ (NSImage *)maskImageWithSize:(NSSize)size cornerRadius:(CGFloat)radius;

@property (class, nonatomic, readonly) NSImage *markImage;

+ (void)makeImages;

+ (NSImage *)cursorTextNoteImageWithOutlineColor:(NSColor *)outlineColor fillColor:(NSColor *)fillColor;
+ (NSImage *)cursorAnchoredNoteImageWithOutlineColor:(NSColor *)outlineColor fillColor:(NSColor *)fillColor;
+ (NSImage *)cursorCircleNoteImageWithOutlineColor:(NSColor *)outlineColor fillColor:(NSColor *)fillColor;
+ (NSImage *)cursorSquareNoteImageWithOutlineColor:(NSColor *)outlineColor fillColor:(NSColor *)fillColor;
+ (NSImage *)cursorHighlightNoteImageWithOutlineColor:(NSColor *)outlineColor fillColor:(NSColor *)fillColor;
+ (NSImage *)cursorUnderlineNoteImageWithOutlineColor:(NSColor *)outlineColor fillColor:(NSColor *)fillColor;
+ (NSImage *)cursorStrikeOutNoteImageWithOutlineColor:(NSColor *)outlineColor fillColor:(NSColor *)fillColor;
+ (NSImage *)cursorLineNoteImageWithOutlineColor:(NSColor *)outlineColor fillColor:(NSColor *)fillColor;
+ (NSImage *)cursorInkNoteImageWithOutlineColor:(NSColor *)outlineColor fillColor:(NSColor *)fillColor;

@end

NS_ASSUME_NONNULL_END
