//
//  SKMainWindowController_Actions.m
//  Skim
//
//  Created by Christiaan Hofman on 2/14/09.
/*
 This software is Copyright (c) 2009
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

#import "SKMainWindowController_Actions.h"
#import "SKMainWindowController_FullScreen.h"
#import "SKLeftSideViewController.h"
#import "SKRightSideViewController.h"
#import "SKMainToolbarController.h"
#import <Quartz/Quartz.h>
#import <SkimNotes/SkimNotes.h>
#import "SKStringConstants.h"
#import "SKPDFView.h"
#import "SKSecondaryPDFView.h"
#import "PDFAnnotation_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "SKTextFieldSheetController.h"
#import "SKPresentationOptionsSheetController.h"
#import "SKInfoWindowController.h"
#import "SKMainDocument.h"
#import "SKStatusBar.h"
#import "SKSideWindow.h"
#import "SKImageToolTipWindow.h"
#import "SKLineInspector.h"
#import "NSEvent_SKExtensions.h"
#import "NSWindowController_SKExtensions.h"
#import "NSPointerArray_SKExtensions.h"
#import "NSDocument_SKExtensions.h"
#import "NSWindow_SKExtensions.h"
#import "SKFindController.h"
#import "PDFView_SKExtensions.h"
#import "SKSnapshotWindowController.h"
#import "PDFDocument_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "NSScroller_SKExtensions.h"
#import "SKNoteText.h"
#import "SKNoteWindowController.h"
#import "SKNoteTextView.h"
#import "SKMainTouchBarController.h"
#import "SKThumbnailItem.h"
#import "PDFSelection_SKExtensions.h"
#import "SKOutlineView.h"
#import "SKOverviewView.h"
#import "SKPresentationView.h"
#import "NSUserDefaults_SKExtensions.h"
#import "SKNoteToolbarController.h"
#import "NSView_SKExtensions.h"
#import "PDFOutline_SKExtensions.h"

#define STATUSBAR_HEIGHT 22.0

#define MIN_SPLIT_PANE_HEIGHT 50.0

#define SKShowToolbarInFullScreenKey @"SKShowToolbarInFullScreen"

@interface SKMainWindowController (SKPrivateUI)
- (void)updateNoteFilterPredicate;
- (void)updateSnapshotFilterPredicate;
@end

@implementation SKMainWindowController (Actions)

- (IBAction)changeColor:(id)sender{
    PDFAnnotation *annotation = [pdfView currentAnnotation];
    if (mwcFlags.updatingColor == 0 && [self hasOverview] == NO && [annotation isSkimNote]) {
        BOOL isFill = [colorAccessoryView state] == NSControlStateValueOn && [annotation hasInteriorColor];
        BOOL isText = [textColorAccessoryView state] == NSControlStateValueOn && [annotation isText];
        BOOL isShift = ([NSEvent modifierFlags] & NSEventModifierFlagShift) != 0;
        mwcFlags.updatingColor = 1;
        [annotation setColor:[sender color] alternate:isFill || isText updateDefaults:isShift];
        mwcFlags.updatingColor = 0;
    }
}

- (IBAction)changeFont:(id)sender{
    PDFAnnotation *annotation = [pdfView currentAnnotation];
    if (mwcFlags.updatingFont == 0 && [self hasOverview] == NO && [annotation isSkimNote] && [annotation isText]) {
        NSFont *font = [sender convertFont:[annotation font]];
        BOOL isShift = ([NSEvent modifierFlags] & NSEventModifierFlagShift) != 0;
        mwcFlags.updatingFont = 1;
        [annotation setFont:font];
        mwcFlags.updatingFont = 0;
        if (isShift && [sender currentFontAction] == NSViaPanelFontAction) {
            [[NSUserDefaults standardUserDefaults] setObject:[font fontName] forKey:SKFreeTextNoteFontNameKey];
            [[NSUserDefaults standardUserDefaults] setDouble:[font pointSize] forKey:SKFreeTextNoteFontSizeKey];
        }
    }
}

- (IBAction)changeAttributes:(id)sender{
    PDFAnnotation *annotation = [pdfView currentAnnotation];
    if (mwcFlags.updatingFontAttributes == 0 && mwcFlags.updatingColor == 0 && [self hasOverview] == NO && [annotation isSkimNote] && [annotation isText]) {
        NSColor *color = [annotation fontColor];
        NSColor *newColor = [[sender convertAttributes:[NSDictionary dictionaryWithObjectsAndKeys:color, NSForegroundColorAttributeName, nil]] valueForKey:NSForegroundColorAttributeName];
        if ([newColor isEqual:color] == NO) {
            BOOL isShift = ([NSEvent modifierFlags] & NSEventModifierFlagShift) != 0;
            mwcFlags.updatingFontAttributes = 1;
            [annotation setFontColor:newColor];
            mwcFlags.updatingFontAttributes = 0;
            if (isShift)
                [[NSUserDefaults standardUserDefaults] setColor:newColor forKey:SKFreeTextNoteFontColorKey];
        }
    }
}

- (IBAction)alignLeft:(id)sender {
    PDFAnnotation *annotation = [pdfView currentAnnotation];
    if ([self hasOverview] == NO && [annotation isSkimNote] && [annotation isText]) {
        [annotation setAlignment:NSTextAlignmentLeft];
    }
}

- (IBAction)alignRight:(id)sender {
    PDFAnnotation *annotation = [pdfView currentAnnotation];
    if ([self hasOverview] == NO && [annotation isSkimNote] && [annotation isText]) {
        [annotation setAlignment:NSTextAlignmentRight];
    }
}

- (IBAction)alignCenter:(id)sender {
    PDFAnnotation *annotation = [pdfView currentAnnotation];
    if ([self hasOverview] == NO && [annotation isSkimNote] && [annotation isText]) {
        [annotation setAlignment:NSTextAlignmentCenter];
    }
}

- (void)changeLineAttribute:(id)sender {
    SKLineChangeAction action = [sender currentLineChangeAction];
    PDFAnnotation *annotation = [pdfView currentAnnotation];
    if (mwcFlags.updatingLine == 0 && [self hasOverview] == NO && [annotation hasBorder]) {
        BOOL isShift = ([NSEvent modifierFlags] & NSEventModifierFlagShift) != 0;
        mwcFlags.updatingLine = 1;
        switch (action) {
            case SKLineChangeActionLineWidth:
                [annotation setLineWidth:[sender lineWidth] updateDefaults:isShift];
                break;
            case SKLineChangeActionStyle:
                [annotation setBorderStyle:[(SKLineInspector *)sender style] updateDefaults:isShift];
                break;
            case SKLineChangeActionDashPattern:
                [annotation setDashPattern:[sender dashPattern] updateDefaults:isShift];
                break;
            case SKLineChangeActionStartLineStyle:
                if ([annotation isLine])
                    [annotation setStartLineStyle:[sender startLineStyle] updateDefaults:isShift];
                break;
            case SKLineChangeActionEndLineStyle:
                if ([annotation isLine])
                    [annotation setEndLineStyle:[sender endLineStyle] updateDefaults:isShift];
                break;
            case SKNoLineChangeAction:
                break;
        }
        // in case one property changes another, e.g. when adding a dashPattern the borderStyle can change
        [[SKLineInspector sharedLineInspector] setAnnotationStyle:annotation];
        mwcFlags.updatingLine = 0;
    }
}

- (IBAction)createNewNote:(id)sender{
    if ([pdfView canSelectNote])
        [pdfView addAnnotationWithType:[sender tag]];
    else NSBeep();
}

- (void)addNoteFromPanel:(id)sender {
    if ([self hasOverview] == NO) {
        [self createNewNote:sender];
        [[self window] makeKeyWindow];
        [[self window] makeFirstResponder:[self pdfView]];
    }
}

- (void)selectSelectedNote:(id)sender{
    if ([pdfView hideNotes] == NO && [self hasOverview] == NO) {
        NSIndexSet *rowIndexes = [sender selectedRowIndexes];
        if ([rowIndexes count] == 1) {
            id item = [sender itemAtRow:[rowIndexes firstIndex]];
            PDFAnnotation *annotation = nil;
            if ([(PDFAnnotation *)item type]) {
                annotation = item;
                if ([pdfView canSelectNote]) {
                    NSInteger column = [sender clickedColumn];
                    if (column != -1) {
                        NSString *colID = [[[sender tableColumns] objectAtIndex:column] identifier];
                        if ([colID isEqualToString:@"color"])
                            [[NSColorPanel sharedColorPanel] orderFront:nil];
                    }
                }
            } else {
                annotation = [(SKNoteText *)item note];
                if ([annotation isNote]) {
                    [self showNote:annotation];
                    SKNoteWindowController *noteController = (SKNoteWindowController *)[self windowControllerForNote:annotation];
                    [[noteController window] makeFirstResponder:[noteController textView]];
                    [[noteController textView] selectAll:nil];
                }
            }
            [pdfView scrollAnnotationToVisible:annotation];
            if ([pdfView canSelectNote])
                [pdfView setCurrentAnnotation:annotation];
        }
    } else NSBeep();
}

- (void)goToSelectedOutlineItem:(id)sender {
    PDFOutline *outlineItem = [leftSideController.tocOutlineView itemAtRow:[leftSideController.tocOutlineView selectedRow]];
    mwcFlags.updatingOutlineSelection = 1;
    if ([outlineItem action])
        [pdfView performAction:[outlineItem action]];
    else if ([outlineItem destination])
        [pdfView goToDestination:[outlineItem destination]];
    if ([self interactionMode] == SKPresentationMode) {
        PDFPage *page = [outlineItem page];
        if (page) {
            [presentationView setPage:page];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:SKAutoHidePresentationContentsKey])
                [self hideSideWindow];
        }
    }
    mwcFlags.updatingOutlineSelection = 0;
}

- (void)goToSelectedFindResults:(id)sender {
    if ([sender numberOfSelectedRows] > 0) {
        searchResultIndex = 0;
        [self updateSearchResultHighlights];
        
        if ([self interactionMode] == SKPresentationMode && [[NSUserDefaults standardUserDefaults] boolForKey:SKAutoHidePresentationContentsKey])
            [self hideSideWindow];
    }
}

- (void)toggleSelectedSnapshots:(id)sender {
    // there should only be a single snapshot
    NSInteger row = [rightSideController.snapshotTableView selectedRow];
    if (row == -1)
        return;
    SKSnapshotWindowController *controller = [[rightSideController.snapshotArrayController arrangedObjects] objectAtIndex:row];
    if ([[controller window] isVisible])
        [controller miniaturize];
    else
        [controller deminiaturize];
}

- (IBAction)editNote:(id)sender{
    if ([pdfView hideNotes] == NO) {
        [pdfView editCurrentAnnotation:sender];
    } else NSBeep();
}

- (IBAction)autoSizeNote:(id)sender{
    if ([pdfView hideNotes] == NO) {
        [pdfView autoSizeCurrentAnnotation:sender];
    } else NSBeep();
}

- (IBAction)toggleHideNotes:(id)sender{
    NSNumber *wasHidden = [NSNumber numberWithBool:[pdfView hideNotes]];
    [notes setValue:wasHidden forKey:@"shouldDisplay"];
    [notes setValue:wasHidden forKey:@"shouldPrint"];
    if ([pdfView hideNotes] == NO)
        [pdfView setCurrentAnnotation:nil];
    [pdfView setHideNotes:[pdfView hideNotes] == NO];
}

- (IBAction)takeSnapshot:(id)sender{
    [pdfView takeSnapshot:sender];
}

- (IBAction)changeDisplayTwoUp:(id)sender {
    PDFDisplayMode displayMode = ([pdfView displayMode] & ~kPDFDisplayTwoUp) | [sender tag];
    if ([pdfView displayDirection] == kPDFDisplayDirectionHorizontal && displayMode == kPDFDisplaySinglePageContinuous)
        displayMode = kPDFDisplayHorizontalContinuous;
    [pdfView setExtendedDisplayModeAndRewind:displayMode];
}

- (IBAction)changeDisplayContinuous:(id)sender {
    PDFDisplayMode displayMode = ([pdfView displayMode] & ~kPDFDisplaySinglePageContinuous) | [sender tag];
    if ([pdfView displayDirection] == kPDFDisplayDirectionHorizontal && displayMode == kPDFDisplaySinglePageContinuous)
        displayMode = kPDFDisplayHorizontalContinuous;
    [pdfView setExtendedDisplayModeAndRewind:displayMode];
}

- (IBAction)changeDisplayMode:(id)sender {
    [pdfView setExtendedDisplayModeAndRewind:[sender tag]];
}

- (IBAction)changeDisplayDirection:(id)sender {
    [pdfView setDisplayDirectionAndRewind:[sender tag]];
}

- (IBAction)toggleDisplaysRTL:(id)sender {
    [pdfView setDisplaysRTLAndRewind:[pdfView displaysRTL] == NO];
}

- (IBAction)toggleDisplaysAsBook:(id)sender {
    [pdfView setDisplaysAsBookAndRewind:[pdfView displaysAsBook] == NO];
}

- (IBAction)toggleDisplayPageBreaks:(id)sender {
    [pdfView setDisplaysPageBreaks:[pdfView displaysPageBreaks] == NO];
}

- (IBAction)changeDisplayBox:(id)sender {
    [pdfView setDisplayBoxAndRewind:[sender tag]];
}

- (IBAction)doGoToNextPage:(id)sender {
    if ([self interactionMode] == SKPresentationMode)
        [presentationView goToNextPage:sender];
    else
        [pdfView goToNextPage:sender];
}

- (IBAction)doGoToPreviousPage:(id)sender {
    if ([self interactionMode] == SKPresentationMode)
        [presentationView goToPreviousPage:sender];
    else
        [pdfView goToPreviousPage:sender];
}


- (IBAction)doGoToFirstPage:(id)sender {
    if ([self interactionMode] == SKPresentationMode)
        [presentationView goToFirstPage:sender];
    else
        [pdfView goToFirstPage:sender];
}

- (IBAction)doGoToLastPage:(id)sender {
    if ([self interactionMode] == SKPresentationMode)
        [presentationView goToLastPage:sender];
    else
        [pdfView goToLastPage:sender];
}

- (IBAction)doGoToPage:(id)sender {
    SKTextFieldSheetController *pageSheetController = [[SKTextFieldSheetController alloc] initWithWindowNibName:@"PageSheet"];
    
    [(NSComboBox *)[pageSheetController textField] addItemsWithObjectValues:pageLabels];
    [pageSheetController setStringValue:[self pageLabel]];
    
    [pageSheetController beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK) {
                NSString *label = [pageSheetController stringValue];
                if ([pageLabels containsObject:label]) {
                    [self willChangeValueForKey:@"pageLabel"];
                    [self setPageLabel:label];
                    [self didChangeValueForKey:@"pageLabel"];
                } else
                    NSBeep();
            }
        }];
}

- (IBAction)doGoBack:(id)sender {
    [pdfView goBack:sender];
    if ([self interactionMode] == SKPresentationMode)
        [presentationView setPage:[pdfView currentPage]];
}

- (IBAction)doGoForward:(id)sender {
    [pdfView goForward:sender];
    if ([self interactionMode] == SKPresentationMode)
        [presentationView setPage:[pdfView currentPage]];
}

- (IBAction)goToMarkedPage:(id)sender {
    PDFDocument *pdfDoc = [pdfView document];
    NSUInteger currentPageIndex = [[pdfView currentPage] pageIndex];
    if (markedPage.pageIndex == NSNotFound || [pdfDoc isLocked] || [pdfDoc pageCount] == 0) {
        NSBeep();
        return;
    } else if (beforeMarkedPage.pageIndex != NSNotFound) {
        beforeMarkedPage.pageIndex = MIN(beforeMarkedPage.pageIndex, [pdfDoc pageCount] - 1);
        [pdfView goToSKDestination:beforeMarkedPage];
    } else if (currentPageIndex != markedPage.pageIndex) {
        beforeMarkedPage = [pdfView currentSKDestination:NO];
        markedPage.pageIndex = MIN(markedPage.pageIndex, [pdfDoc pageCount] - 1);
        [pdfView goToSKDestination:markedPage];
    }
    if ([self interactionMode] == SKPresentationMode)
        [presentationView setPage:[pdfView currentPage]];
}

- (IBAction)markPage:(id)sender {
    if (markedPage.pageIndex != NSNotFound) {
        [(SKThumbnailItem *)[overviewView itemAtIndexPath:[NSIndexPath indexPathForItem:markedPage.pageIndex inSection:0]] setMarked:NO];
        [[(NSTableCellView *)[leftSideController.thumbnailTableView viewAtColumn:1 row:markedPage.pageIndex makeIfNecessary:NO] imageView] setObjectValue:nil];
    }
    markedPage = [pdfView currentSKDestination:NO];
    beforeMarkedPage.pageIndex = NSNotFound;
    [(SKThumbnailItem *)[overviewView itemAtIndexPath:[NSIndexPath indexPathForItem:markedPage.pageIndex inSection:0]] setMarked:YES];
    [[(NSTableCellView *)[leftSideController.thumbnailTableView viewAtColumn:1 row:markedPage.pageIndex makeIfNecessary:NO] imageView] setObjectValue:[NSImage markImage]];
}

- (IBAction)doZoomIn:(id)sender {
    [pdfView zoomIn:sender];
}

- (IBAction)doZoomOut:(id)sender {
    [pdfView zoomOut:sender];
}

- (IBAction)doZoomToPhysicalSize:(id)sender {
    [pdfView setPhysicalScaleFactor:1.0];
}

- (IBAction)doZoomToActualSize:(id)sender {
    if ([self interactionMode] == SKPresentationMode)
        [presentationView setAutoScales:NO];
    else
        [pdfView setScaleFactor:1.0];
}

- (IBAction)doZoomToSelection:(id)sender {
    if ([pdfView toolMode] == SKToolModeSelect) {
        NSRect selRect = [pdfView selectToolRect];
        PDFPage *page = [pdfView currentPage];
        if (NSIsEmptyRect(selRect) == NO && page)
            [pdfView zoomToRect:selRect onPage:page];
        else NSBeep();
    } else {
        [pdfView setTemporaryToolMode:SKToolModeZoom];
    }
}

- (IBAction)doZoomToFit:(id)sender {
    [pdfView setAutoScales:YES];
    [pdfView setAutoScales:NO];
}

- (IBAction)alternateZoomToFit:(id)sender {
    PDFDisplayMode displayMode = [pdfView extendedDisplayMode];
    NSRect frame = [pdfView frame];
    PDFPage *page = [pdfView currentPage];
    NSRect pageRect = [pdfView boundsIncludingMarginsForPage:page];
    CGFloat width, height;
    CGFloat scrollerWidth = 0.0;
    CGFloat scaleFactor;
    NSUInteger pageCount = [[pdfView document] pageCount];
    if (([page rotation] % 180) == 0) {
        width = NSWidth(pageRect);
        height = NSHeight(pageRect);
    } else {
        width = NSHeight(pageRect);
        height = NSWidth(pageRect);
    }
    frame.size.height -= [[pdfView embeddedScrollView] contentInsets].top;
    if ((displayMode & kPDFDisplaySinglePageContinuous) == 0) {
        // zoom to width
        if (NSWidth(frame) * height > NSHeight(frame) * width)
            scrollerWidth = [NSScroller effectiveScrollerWidth];
        scaleFactor = ( NSWidth(frame) - scrollerWidth ) / width;
    } else {
        // zoom to height
        NSUInteger numCols = 1;
        if (displayMode == kPDFDisplayTwoUpContinuous && pageCount > 1 + (NSUInteger)[pdfView displaysAsBook])
            numCols = 2;
        if (NSHeight(frame) * width * numCols > NSWidth(frame) * height)
            scrollerWidth = [NSScroller effectiveScrollerWidth];
        scaleFactor = ( NSHeight(frame) - scrollerWidth ) / height;
    }
    [pdfView setScaleFactor:scaleFactor];
    [pdfView layoutDocumentView];
    [pdfView goToRect:pageRect onPage:page];
}

- (IBAction)doAutoScale:(id)sender {
    if ([self interactionMode] == SKPresentationMode)
        [presentationView setAutoScales:YES];
    else
        [pdfView setAutoScales:YES];
}

- (IBAction)toggleAutoScale:(id)sender {
    if ([self interactionMode] == SKPresentationMode)
        [presentationView toggleAutoActualSize:sender];
    else
        [pdfView setAutoScales:[pdfView autoScales] == NO];
}

- (void)rotatePageAtIndex:(NSUInteger)idx by:(NSInteger)rotation {
    NSUndoManager *undoManager = [[self document] undoManager];
    [[undoManager prepareWithInvocationTarget:self] rotatePageAtIndex:idx by:-rotation];
    if ([undoManager isUndoing] == NO && [undoManager isRedoing] == NO)
        [undoManager setActionName:NSLocalizedString(@"Rotate Page", @"Undo action name")];
    [undoManager setActionIsDiscardable:YES];
    
    PDFPage *page = [[pdfView document] pageAtIndex:idx];
    [page setRotation:[page rotation] + rotation];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFPageBoundsDidChangeNotification 
                                                        object:[pdfView document] userInfo:@{SKPDFPageActionKey:SKPDFPageActionRotate, SKPDFPagePageKey:page}];
}

- (void)rotateAllBy:(NSInteger)rotation {
    NSUndoManager *undoManager = [[self document] undoManager];
    [[undoManager prepareWithInvocationTarget:self] rotateAllBy:-rotation];
    if ([undoManager isUndoing] == NO && [undoManager isRedoing] == NO)
        [undoManager setActionName:NSLocalizedString(@"Rotate", @"Undo action name")];
    [undoManager setActionIsDiscardable:YES];
    
    if (([pdfView displayMode] & kPDFDisplaySinglePageContinuous))
        [pdfView setNeedsRewind:YES];
    
    for (PDFPage *page in [pdfView document])
        [page setRotation:[page rotation] + rotation];
    [pdfView layoutDocumentView];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFPageBoundsDidChangeNotification 
                                                        object:[pdfView document] userInfo:@{SKPDFPageActionKey:SKPDFPageActionRotate}];
}

- (IBAction)rotateRight:(id)sender {
    [self rotatePageAtIndex:[[pdfView currentPage] pageIndex] by:90];
}

- (IBAction)rotateLeft:(id)sender {
    [self rotatePageAtIndex:[[pdfView currentPage] pageIndex] by:-90];
}

- (IBAction)rotateAllRight:(id)sender {
    [self rotateAllBy:90];
}

- (IBAction)rotateAllLeft:(id)sender {
    [self rotateAllBy:-90];
}

- (void)cropPageAtIndex:(NSUInteger)anIndex toRect:(NSRect)rect {
    NSRect oldRect = [[[pdfView document] pageAtIndex:anIndex] boundsForBox:kPDFDisplayBoxCropBox];
    NSUndoManager *undoManager = [[self document] undoManager];
    [[undoManager prepareWithInvocationTarget:self] cropPageAtIndex:anIndex toRect:oldRect];
    if ([undoManager isUndoing] == NO && [undoManager isRedoing] == NO)
        [undoManager setActionName:NSLocalizedString(@"Crop Page", @"Undo action name")];
    [undoManager setActionIsDiscardable:YES];
    
    PDFPage *page = [[pdfView document] pageAtIndex:anIndex];
    rect = NSIntersectionRect(rect, [page boundsForBox:kPDFDisplayBoxMediaBox]);
    [page setBounds:rect forBox:kPDFDisplayBoxCropBox];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFPageBoundsDidChangeNotification 
                                                        object:[pdfView document] userInfo:@{SKPDFPageActionKey:SKPDFPageActionCrop, SKPDFPagePageKey:page}];
    
    // make sure we show the crop box
    [pdfView setDisplayBox:kPDFDisplayBoxCropBox];
}

- (IBAction)crop:(id)sender {
    NSRect rect = NSIntegralRect([pdfView selectToolRect]);
    PDFPage *page = [pdfView selectToolPage] ?: [pdfView currentPage];
    if (NSIsEmptyRect(rect))
        rect = [page autoCropBox];
    [self cropPageAtIndex:[page pageIndex] toRect:rect];
}

- (void)cropPagesToRects:(NSPointerArray *)rects {
    if (([pdfView displayMode] & kPDFDisplaySinglePageContinuous))
        [pdfView setNeedsRewind:YES];
    
    NSInteger i, count = [[pdfView document] pageCount];
    NSInteger rectCount = [rects count];
    NSPointerArray *oldRects = [[NSPointerArray alloc] initForRectPointers];
    for (i = 0; i < count; i++) {
        PDFPage *page = [[pdfView document] pageAtIndex:i];
        NSRect rect = NSIntersectionRect([rects rectAtIndex:i % rectCount], [page boundsForBox:kPDFDisplayBoxMediaBox]);
        NSRect oldRect = [page boundsForBox:kPDFDisplayBoxCropBox];
        [oldRects addPointer:&oldRect];
        [page setBounds:rect forBox:kPDFDisplayBoxCropBox];
    }
    
    NSUndoManager *undoManager = [[self document] undoManager];
    [[undoManager prepareWithInvocationTarget:self] cropPagesToRects:oldRects];
    if ([undoManager isUndoing] == NO && [undoManager isRedoing] == NO)
        [undoManager setActionName:NSLocalizedString(@"Crop", @"Undo action name")];
    [undoManager setActionIsDiscardable:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFPageBoundsDidChangeNotification 
                                                        object:[pdfView document] userInfo:@{SKPDFPageActionKey:SKPDFPageActionCrop}];
    
    // make sure we show the crop box
    [pdfView setDisplayBox:kPDFDisplayBoxCropBox];
}

- (IBAction)cropAll:(id)sender {
    NSRect rect[2] = {NSIntegralRect([pdfView selectToolRect]), NSZeroRect};
    NSPointerArray *rectArray = [[NSPointerArray alloc] initForRectPointers];
    BOOL emptySelection = NSIsEmptyRect(rect[0]);
    
    if (emptySelection) {
        NSInteger i, j, count = [[pdfView document] pageCount];
        rect[0] = rect[1] = NSZeroRect;
        
        if (count == 0)
            return;
        
        [self beginProgressSheetWithMessage:[NSLocalizedString(@"Cropping Pages", @"Message for progress sheet") stringByAppendingEllipsis] maxValue:MIN(18, count)];
        
        if (count == 1) {
            rect[0] = [[[pdfView document] pageAtIndex:0] autoCropBox];
            [self incrementProgressSheet];
        } else if (count < 19) {
            for (i = 0; i < count; i++) {
                rect[i % 2] = NSUnionRect(rect[i % 2], [[[pdfView document] pageAtIndex:i] autoCropBox]);
                [self incrementProgressSheet];
            }
        } else {
            NSInteger start[3] = {1, (count - 5) / 2, count - 6};
            for (j = 0; j < 3; j++) {
                for (i = start[j]; i < start[j] + 6; i++) {
                    rect[i % 2] = NSUnionRect(rect[i % 2], [[[pdfView document] pageAtIndex:i] autoCropBox]);
                    [self incrementProgressSheet];
                }
            }
        }
        CGFloat w = fmax(NSWidth(rect[0]), NSWidth(rect[1]));
        CGFloat h = fmax(NSHeight(rect[0]), NSHeight(rect[1]));
        for (j = 0; j < 2; j++)
            rect[j] = NSMakeRect(floor(NSMidX(rect[j]) - 0.5 * w), floor(NSMidY(rect[j]) - 0.5 * h), w, h);
        [rectArray addPointer:rect];
        [rectArray addPointer:rect + 1];
        
        [self dismissProgressSheet];
    } else {
        [rectArray addPointer:rect];
    }
    
    [self cropPagesToRects:rectArray];
    
    if (emptySelection == NO)
        [pdfView setSelectToolRect:NSZeroRect];
}

- (IBAction)autoCropAll:(id)sender {
    NSPointerArray *rectArray = [[NSPointerArray alloc] initForRectPointers];
    PDFDocument *pdfDoc = [pdfView document];
    NSInteger i, iMax = [[pdfView document] pageCount];
    
    [self beginProgressSheetWithMessage:[NSLocalizedString(@"Cropping Pages", @"Message for progress sheet") stringByAppendingEllipsis] maxValue:iMax];
    
    for (i = 0; i < iMax; i++) {
        NSRect rect = [[pdfDoc pageAtIndex:i] autoCropBox];
        [rectArray addPointer:&rect];
        [self incrementProgressSheet];
        if (i && i % 10 == 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    [self dismissProgressSheet];
    
    [self cropPagesToRects:rectArray];
}

- (IBAction)smartAutoCropAll:(id)sender {
    NSPointerArray *rectArray = [[NSPointerArray alloc] initForRectPointers];
    PDFDocument *pdfDoc = [pdfView document];
    NSInteger i, iMax = [pdfDoc pageCount];
    NSSize size = NSZeroSize;
    
	[self beginProgressSheetWithMessage:[NSLocalizedString(@"Cropping Pages", @"Message for progress sheet") stringByAppendingEllipsis] maxValue:11 * iMax / 10];
    
    for (i = 0; i < iMax; i++) {
        NSRect bbox = [[pdfDoc pageAtIndex:i] autoCropBox];
        size.width = fmax(size.width, NSWidth(bbox));
        size.height = fmax(size.height, NSHeight(bbox));
        [self incrementProgressSheet];
        if (i && i % 10 == 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    for (i = 0; i < iMax; i++) {
        PDFPage *page = [pdfDoc pageAtIndex:i];
        NSRect rect = [page autoCropBox];
        NSRect bounds = [page boundsForBox:kPDFDisplayBoxMediaBox];
        if (NSMinX(rect) - NSMinX(bounds) > NSMaxX(bounds) - NSMaxX(rect))
            rect.origin.x = NSMaxX(rect) - size.width;
        rect.origin.y = NSMaxY(rect) - size.height;
        rect.size = size;
        rect = SKConstrainRect(rect, bounds);
        [rectArray addPointer:&rect];
        if (i && i % 10 == 0) {
            [self incrementProgressSheet];
            if (i && i % 100 == 0)
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
    }
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
    [self dismissProgressSheet];
    
    [self cropPagesToRects:rectArray];
}

- (IBAction)resetCrop:(id)sender {
    NSPointerArray *rectArray = [[NSPointerArray alloc] initForRectPointers];
    BOOL hasChanges = NO;
    
    for (PDFPage *page in [pdfView document]) {
        NSRect rect = NSRectFromCGRect(CGPDFPageGetBoxRect([page pageRef], kCGPDFCropBox));
        if (hasChanges == NO && NSEqualRects(rect, [page boundsForBox:kPDFDisplayBoxCropBox]) == NO)
            hasChanges = YES;
        [rectArray addPointer:&rect];
    }
    
    if (hasChanges)
        [self cropPagesToRects:rectArray];
    
    mwcFlags.hasCropped = 0;
}

- (IBAction)autoSelectContent:(id)sender {
    [pdfView autoSelectContent:sender];
}

- (IBAction)delete:(id)sender {
    [pdfView delete:sender];
}

- (IBAction)paste:(id)sender {
    [pdfView paste:sender];
}

- (IBAction)alternatePaste:(id)sender {
    [pdfView alternatePaste:sender];
}

- (IBAction)pasteAsPlainText:(id)sender {
    [pdfView pasteAsPlainText:sender];
}

- (IBAction)copy:(id)sender {
    [pdfView copy:sender];
}

- (IBAction)cut:(id)sender {
    [pdfView cut:sender];
}

- (IBAction)deselectAll:(id)sender {
    [pdfView deselectAll:sender];
}

- (IBAction)changeToolMode:(id)sender {
    [pdfView setToolMode:[sender tag]];
}

- (IBAction)changeAnnotationMode:(id)sender {
    [pdfView setToolMode:SKToolModeNote];
    [pdfView setAnnotationMode:[sender tag]];
}

- (IBAction)statusBarClicked:(id)sender {
    [self updateRightStatus];
}

- (IBAction)toggleStatusBar:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:(NO == [statusBar isVisible]) forKey:SKShowStatusBarKey];
    [statusBar toggleBelowView:[splitViewController view] animate:YES];
}

- (void)selectSearchFieldForSideViewController:(SKSideViewController *)sideViewController {
    if ([self hasOverview]) {
        [self hideOverviewWithCompletionHandler:^{ [self selectSearchFieldForSideViewController:sideViewController]; }];
    } else {
        NSSplitViewItem *item = [splitViewController splitViewItemForViewController:sideViewController];
        if ([item isCollapsed] == NO) {
            [sideViewController.searchField selectText:nil];
        } else if ([NSView shouldShowSlideAnimation]) {
            // workaround for an AppKit bug: when selecting immediately before the animation, the search fields does not display its text
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                    [[item animator] setCollapsed:NO];
                } completionHandler:^{
                    [sideViewController.searchField selectText:nil];
                }];
        } else {
            [item setCollapsed:NO];
            [sideViewController.searchField selectText:nil];
        }
    }
}

- (IBAction)searchPDF:(id)sender {
    [self selectSearchFieldForSideViewController:leftSideController];
}

- (IBAction)filterNotes:(id)sender {
    [self selectSearchFieldForSideViewController:rightSideController];
}

- (IBAction)search:(id)sender {
    
    PDFDocument *pdfDoc = [pdfView document];
    NSString *searchString = [sender stringValue];
    
    // cancel any previous find to remove those results, or else they stay around
    if ([pdfDoc isFinding])
        [pdfDoc cancelFindString];
    [pdfView setHighlightedSelections:nil];
    
    if ([searchString length] == 0) {
        
        if ([self displaysFindPane])
            [leftSideController displayTableAtIndex:mwcFlags.leftSidePaneState animate:YES];
        [self updateRightStatus];
        
        [self setSearchResults:nil];
        [self setGroupedSearchResults:nil];
    } else {
        NSInteger options = mwcFlags.caseInsensitiveSearch ? NSCaseInsensitiveSearch : 0;
        if (mwcFlags.wholeWordSearch) {
            NSScanner *scanner = [NSScanner scannerWithString:searchString];
            NSMutableArray *words = [NSMutableArray array];
            NSString *word;
            [scanner setCharactersToBeSkipped:nil];
            while ([scanner isAtEnd] == NO) {
                if ('"' == [[scanner string] characterAtIndex:[scanner scanLocation]]) {
                    [scanner setScanLocation:[scanner scanLocation] + 1];
                    if ([scanner scanUpToString:@"\"" intoString:&word])
                        [words addObject:word];
                    if ([scanner isAtEnd] == NO)
                        [scanner setScanLocation:[scanner scanLocation] + 1];
                } else if ([scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&word]) {
                    [words addObject:word];
                }
                [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
            }
            [pdfDoc beginFindStrings:words withOptions:options];
        } else {
            [pdfDoc beginFindString:[sender stringValue] withOptions:options];
        }
        if ([self displaysFindPane] == NO)
            [leftSideController displayTableAtIndex:2 + mwcFlags.findPaneState animate:YES];
        
        NSPasteboard *findPboard = [NSPasteboard pasteboardWithName:NSPasteboardNameFind];
        [findPboard clearContents];
        [findPboard writeObjects:@[searchString]];
    }
}

- (IBAction)searchNotes:(id)sender {
    if (mwcFlags.rightSidePaneState == SKSidePaneStateNote)
        [self updateNoteFilterPredicate];
    else
        [self updateSnapshotFilterPredicate];
    NSString *searchString = [sender stringValue];
    if ([searchString length]) {
        NSPasteboard *findPboard = [NSPasteboard pasteboardWithName:NSPasteboardNameFind];
        [findPboard clearContents];
        [findPboard writeObjects:@[searchString]];
    }
}

- (IBAction)performFit:(id)sender {
    if ([self interactionMode] != SKNormalMode) {
        NSBeep();
        return;
    }
    
    PDFDisplayMode displayMode = [[self pdfView] displayMode];
    NSUInteger pageCount = [[[self pdfView] document] pageCount];
    BOOL multiplColumns = NO, multipleRows = NO;
    
    if (pageCount > 1) {
        if (displayMode == kPDFDisplaySinglePageContinuous) {
            if ([[self pdfView] displayDirection] == kPDFDisplayDirectionHorizontal)
                multiplColumns = YES;
            else
                multipleRows = YES;
        } else if (displayMode == kPDFDisplayTwoUpContinuous) {
            multipleRows = pageCount > 2 || [[self pdfView] displaysAsBook];
        }
    }
    
    NSRect frame = [[self window] frame];
    NSSize size, oldSize = [[self pdfView] frame].size;
    NSRect documentRect = [[[self pdfView] documentView] convertRect:[[[self pdfView] documentView] bounds] toView:nil];
    PDFPage *page = [[self pdfView] currentPage];
    NSRect pageRect;
    CGFloat scrollerWidth = [NSScroller effectiveScrollerWidth];
    
    if (multipleRows || multiplColumns)
        pageRect = [pdfView boundsIncludingMarginsForPage:page];
    
    oldSize.height -= [[[self pdfView] embeddedScrollView] contentInsets].top;
    
    // Calculate the new size for the pdfView
    if (multiplColumns)
        size.width = NSWidth([[self pdfView] convertRect:pageRect fromPage:page]);
    else
        size.width = NSWidth(documentRect);
    if (multipleRows)
        size.height = NSHeight([[self pdfView] convertRect:pageRect fromPage:page]);
    else
        size.height = NSHeight(documentRect);
    if ([[self pdfView] autoScales]) {
        CGFloat scaleFactor = [[self pdfView] scaleFactor];
        size.width /= scaleFactor;
        size.height /= scaleFactor;
    }
    if (scrollerWidth > 0.0) {
        if (multipleRows)
            size.width += scrollerWidth;
        else if (multiplColumns)
            size.height += scrollerWidth;
    }
    
    // Calculate the new size for the window
    size.width = ceil(NSWidth(frame) + size.width - oldSize.width);
    size.height = ceil(NSHeight(frame) + size.height - oldSize.height);
    // Align the window frame from the old topleft point and constrain to the screen
    frame.origin.y = NSMaxY(frame) - size.height;
    frame.size = size;
    frame = [[self window] constrainFrameRect:frame toScreen:[[self window] screen] ?: [NSScreen mainScreen]];
    
    [[self window] setFrame:frame display:[[self window] isVisible]];
    
    if (multipleRows || multiplColumns)
        [[self pdfView] goToRect:pageRect onPage:page];
}

- (IBAction)password:(id)sender {
    SKTextFieldSheetController *passwordSheetController = [[SKTextFieldSheetController alloc] initWithWindowNibName:@"PasswordSheet"];
    [passwordSheetController setInformativeText:[[pdfView document] isLocked] ? NSLocalizedString(@"The document is locked", @"Informative text") : NSLocalizedString(@"The document has access restrictions", @"Informative text")];
    
    [passwordSheetController beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK) {
                [[passwordSheetController window] orderOut:nil];
                [[pdfView document] unlockWithPassword:[passwordSheetController stringValue]];
            }
        }];
}

- (IBAction)toggleReadingBar:(id)sender {
    [pdfView toggleReadingBar];
}

- (IBAction)togglePacer:(id)sender {
    if ([self interactionMode] != SKPresentationMode)
        [pdfView togglePacer];
}

- (IBAction)changePacerSpeed:(id)sender {
    NSInteger tag = [sender tag];
    if (tag == 0)
        [pdfView setPacerSpeed:[pdfView pacerSpeed] + 1.0];
    else if (tag == -1)
        [pdfView setPacerSpeed:fmax(1.0, [pdfView pacerSpeed] - 1.0)];
    else if (tag > 0)
        [pdfView setPacerSpeed:[[sender title] doubleValue]];
}

- (IBAction)chooseTransition:(id)sender {
    NSWindowLevel level = NSNormalWindowLevel;
    if (interactionMode == SKPresentationMode) {
        level = [[self window] level];
        if (level > NSNormalWindowLevel)
            [[self window] setLevel:NSNormalWindowLevel];
    }
    
    SKPresentationOptionsSheetController *presentationSheetController = [[SKPresentationOptionsSheetController alloc] initForController:self];
    
    [presentationSheetController beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse response){
        if (level > NSNormalWindowLevel)
            [[self window] setLevel:level];
    }];
}

- (IBAction)toggleCaseInsensitiveSearch:(id)sender {
    mwcFlags.caseInsensitiveSearch = (0 == mwcFlags.caseInsensitiveSearch);
    if ([[self searchString] length])
        [self search:leftSideController.searchField];
    [[NSUserDefaults standardUserDefaults] setBool:mwcFlags.caseInsensitiveSearch forKey:SKCaseInsensitiveSearchKey];
}

- (IBAction)toggleWholeWordSearch:(id)sender {
    mwcFlags.wholeWordSearch = (0 == mwcFlags.wholeWordSearch);
    if ([[self searchString] length])
        [self search:leftSideController.searchField];
    [[NSUserDefaults standardUserDefaults] setBool:mwcFlags.wholeWordSearch forKey:SKWholeWordSearchKey];
}

- (IBAction)toggleCaseInsensitiveFilter:(id)sender {
    mwcFlags.caseInsensitiveFilter = (0 == mwcFlags.caseInsensitiveFilter);
    if ([[rightSideController.searchField stringValue] length])
        [self searchNotes:rightSideController.searchField];
    [[NSUserDefaults standardUserDefaults] setBool:mwcFlags.caseInsensitiveFilter forKey:SKCaseInsensitiveFilterKey];
}

- (IBAction)toggleLeftSidePane:(id)sender {
    if ([self interactionMode] == SKPresentationMode) {
        if ([sideWindow isVisible])
            [self hideSideWindow];
        else
            [self showSideWindow];
    } else if ([self hasOverview]) {
        [self hideOverviewWithCompletionHandler:^{ [self toggleLeftSidePane:sender]; }];
    } else {
        NSSplitViewItem *item = [[splitViewController splitViewItems] firstObject];
        BOOL collapse = [item isCollapsed] == NO;
        if ([NSView shouldShowSlideAnimation])
            [[item animator] setCollapsed:collapse];
        else
            [item setCollapsed:collapse];
    }
}

- (IBAction)toggleRightSidePane:(id)sender {
    if ([self interactionMode] == SKPresentationMode) {
    } else if ([self hasOverview]) {
        [self hideOverviewWithCompletionHandler:^{ [self toggleRightSidePane:sender]; }];
    } else {
        NSSplitViewItem *item = [[splitViewController splitViewItems] lastObject];
        BOOL collapse = [item isCollapsed] == NO;
        if ([NSView shouldShowSlideAnimation])
            [[item animator] setCollapsed:collapse];
        else
            [item setCollapsed:collapse];
    }
}

- (IBAction)changeLeftSidePaneState:(id)sender {
    [self setLeftSidePaneState:[sender tag]];
}

- (IBAction)changeRightSidePaneState:(id)sender {
    [self setRightSidePaneState:[sender tag]];
}

- (IBAction)changeFindPaneState:(id)sender {
    [self setFindPaneState:[sender tag]];
}

- (IBAction)toggleOverview:(id)sender {
    if ([self hasOverview])
        [self hideOverviewAnimating:YES];
    else
        [self showOverviewAnimating:YES];
}

- (IBAction)toggleSplitPDF:(id)sender {
    if ([self hasOverview]) {
        [self hideOverviewWithCompletionHandler:^{ [self toggleSplitPDF:sender]; }];
        return;
    }
    
    if (mwcFlags.isAnimatingSplitPDF)
        return;
    
    if ([secondaryPdfView superview]) {
        
        NSSplitViewItem *item = [[pdfSplitViewController splitViewItems] lastObject];
        
        if ([item isCollapsed] == NO && [[self window] firstResponderIsDescendantOf:secondaryPdfView])
            [[self window] makeFirstResponder:pdfView];
        
        if ([item isCollapsed] || [NSView shouldShowSlideAnimation] == NO) {
            [item setCollapsed:YES];
            [[pdfSplitViewController splitView] setDividerStyle:NSSplitViewDividerStyleThin];
            [pdfSplitViewController removeSplitViewItem:item];
        } else {
            mwcFlags.isAnimatingSplitPDF = YES;
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                    [[item animator] setCollapsed:YES];
                } completionHandler:^{
                    [[pdfSplitViewController splitView] setDividerStyle:NSSplitViewDividerStyleThin];
                    [pdfSplitViewController removeSplitViewItem:item];
                    mwcFlags.isAnimatingSplitPDF = NO;
                }];
        }
        
        [toolbarController splitPDFDidShowOrHide:NO];
        
    } else {
        
        NSRect frame = [pdfView bounds];
        NSSplitViewItem *item = nil;
        
        if (secondaryPdfView == nil) {
            NSPoint point = frame.origin;
            PDFPage *page = nil;
            BOOL fixedAtBottom = [[[pdfView embeddedScrollView] contentView] isFlipped] == NO;
            secondaryPdfView = [[SKSecondaryPDFView alloc] initWithFrame:NSMakeRect(0.0, 0.0, NSWidth(frame), 250.0)];
            [secondaryPdfView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
            
            NSViewController *viewController = [[NSViewController alloc] init];
            [viewController setView:secondaryPdfView];
            item = [NSSplitViewItem splitViewItemWithViewController:viewController];
            [item setCanCollapse:YES];
            [item setCollapsed:YES];
            [item setMinimumThickness:MIN_SPLIT_PANE_HEIGHT];
            [pdfSplitViewController addSplitViewItem:item];
            [[pdfSplitViewController splitView] setDividerStyle:NSSplitViewDividerStylePaneSplitter];
            
            // Because of a PDFView bug, display properties can not be changed before it is placed in a window
            [secondaryPdfView setSynchronizedPDFView:pdfView];
            [secondaryPdfView setBackgroundColor:[pdfView backgroundColor]];
            [secondaryPdfView setDisplaysPageBreaks:NO];
            [secondaryPdfView setInterpolationQuality:[[NSUserDefaults standardUserDefaults] integerForKey:SKInterpolationQualityKey]];
            [secondaryPdfView setSynchronizeZoom:YES];
            [secondaryPdfView setDocument:[pdfView document]];
            point.y += fixedAtBottom ? -250.0 : 250.0 + [[pdfSplitViewController splitView] dividerThickness];
            page = [pdfView pageForPoint:point nearest:YES];
            [secondaryPdfView goToPage:page];
            [secondaryPdfView layoutDocumentView];
            NSScrollView *scrollView = [secondaryPdfView embeddedScrollView];
            NSClipView *clipView = [scrollView contentView];
            point = [secondaryPdfView convertPoint:[secondaryPdfView convertPoint:[pdfView convertPoint:point toPage:page] fromPage:page] toView:clipView];
            [clipView scrollToPoint:point];
            [scrollView reflectScrolledClipView:clipView];
            [secondaryPdfView resetHistory];
            
        } else {
            NSViewController *viewController = [[NSViewController alloc] init];
            [viewController setView:secondaryPdfView];
            item = [NSSplitViewItem splitViewItemWithViewController:viewController];
            [item setCanCollapse:YES];
            [item setCollapsed:YES];
            [item setMinimumThickness:50.0];
            [pdfSplitViewController addSplitViewItem:item];
            [[pdfSplitViewController splitView] setDividerStyle:NSSplitViewDividerStylePaneSplitter];
        }
        
        if ([NSView shouldShowSlideAnimation]) {
            mwcFlags.isAnimatingSplitPDF = YES;
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                    [[item animator] setCollapsed:NO];
                } completionHandler:^{
                    mwcFlags.isAnimatingSplitPDF = NO;
                }];
        } else {
            [item setCollapsed:NO];
        }
        
        [toolbarController splitPDFDidShowOrHide:YES];
    }
    
    [[self window] recalculateKeyViewLoop];
}

- (IBAction)toggleNoteToolbar:(id)sender {
    if ([self interactionMode] == SKPresentationMode)
        return;
    if ([noteToolbarController isVisible]) {
        NSUInteger i = [[[self window] titlebarAccessoryViewControllers] indexOfObject:noteToolbarController];
        if (i != NSNotFound)
            [[self window] removeTitlebarAccessoryViewControllerAtIndex:i];
    } else {
        BOOL needsFullScreenHeight = NO;
        if (noteToolbarController == nil) {
            noteToolbarController = [[SKNoteToolbarController alloc] init];
            [noteToolbarController setMainController:self];
            needsFullScreenHeight = [[NSUserDefaults standardUserDefaults] integerForKey:SKShowToolbarInFullScreenKey] > 1;
        }
        [[self window] addTitlebarAccessoryViewController:noteToolbarController];
        if (needsFullScreenHeight)
            [noteToolbarController setFullScreenMinHeight:NSHeight([[noteToolbarController view] frame])];
    }
    [toolbarController noteToolbarDidShowOrHide:[noteToolbarController isVisible]];
}

- (IBAction)toggleFullscreen:(id)sender {
    if ([self canExitFullscreen])
        [self exitFullscreen];
    else if ([self canEnterFullscreen])
        [self enterFullscreen];
}

- (IBAction)togglePresentation:(id)sender {
    if ([self canExitPresentation])
        [self exitPresentation];
    else if ([self canEnterPresentation])
        [self enterPresentation];
}

- (IBAction)toggleNewNoteRequiresSelection:(id)sender {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    [sud setBool:NO == [sud boolForKey:SKNewNoteRequiresSelectionKey] forKey:SKNewNoteRequiresSelectionKey];
}

- (IBAction)toggleUpdateContentsFromEnclosedText:(id)sender {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    NSInteger value = [sud integerForKey:SKDisableUpdateContentsFromEnclosedTextKey];
    NSInteger option = [sender tag];
    value = value >= option ? 0 : option;
    [sud setInteger:value forKey:SKDisableUpdateContentsFromEnclosedTextKey];
}

- (void)toggleDisplayNoteBounds:(nullable id)sender {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    [sud setBool:NO == [sud boolForKey:SKDisplayNoteBoundsKey] forKey:SKDisplayNoteBoundsKey];
    [self updateRightStatus];
}

- (void)toggleDisplayPageBounds:(nullable id)sender {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    [sud setBool:NO == [sud boolForKey:SKDisplayPageBoundsKey] forKey:SKDisplayPageBoundsKey];
    [self updateRightStatus];
}

- (IBAction)performFindPanelAction:(id)sender {
    if ([self interactionMode] == SKPresentationMode) {
        NSBeep();
        return;
    }
    
    if ([self hasOverview]) {
        [self hideOverviewWithCompletionHandler:^{ [self performFindPanelAction:sender]; }];
        return;
    }
	
    NSStringCompareOptions forward = YES;
    NSString *findString = nil;
    
    switch ([sender tag]) {
		case NSFindPanelActionShowFindPanel:
            [self showFindBar];
            break;
		case NSFindPanelActionPrevious:
            forward = NO;
		case NSFindPanelActionNext:
            if ([[findController view] window]) {
                [findController findForward:forward];
            } else {
                NSPasteboard *findPboard = [NSPasteboard pasteboardWithName:NSPasteboardNameFind];
                findString = [[findPboard readObjectsForClasses:@[[NSString class]] options:@{}] firstObject];
                if ([findString length] > 0)
                    [self findString:findString forward:forward];
                else
                    NSBeep();
            }
            break;
		case NSFindPanelActionSetFindString:
            findString = [[[self pdfView] currentSelection] string];
            if ([findString length] == 0) {
                NSBeep();
            } else if ([[findController view] window]) {
                [findController setFindString:findString];
                [findController updateFindPboard];
            } else {
                NSPasteboard *findPboard = [NSPasteboard pasteboardWithName:NSPasteboardNameFind];
                [findPboard clearContents];
                [findPboard writeObjects:@[findString]];
            }
            break;
        default:
            NSBeep();
            break;
	}
}

- (IBAction)centerSelectionInVisibleArea:(id)sender {
    if ([self interactionMode] == SKPresentationMode) {
        NSBeep();
        return;
    }
    
    if ([self hasOverview]) {
        [self hideOverviewWithCompletionHandler:^{ [self centerSelectionInVisibleArea:sender]; }];
        return;
    }
    
    PDFSelection *selection = [pdfView currentSelection];
    if ([selection hasCharacters] == NO) {
        NSBeep();
        return;
    }
    
    [pdfView goToSelection:selection];
    PDFPage *page = [selection safeFirstPage];
    NSRect rect = [pdfView convertRect:[selection boundsForPage:page] fromPage:page];
    NSView *clipView = [[pdfView embeddedScrollView] contentView];
    NSRect visibleRect = [pdfView convertRect:[clipView visibleRect] fromView:clipView];
    visibleRect.origin.x = floor(NSMidX(rect) - 0.5 * NSWidth(visibleRect));
    visibleRect.origin.y = ceil(NSMidY(rect) - 0.5 * NSHeight(visibleRect));
    visibleRect = [pdfView convertRect:visibleRect toView:[pdfView documentView]];
    [[pdfView documentView] scrollRectToVisible:visibleRect];
}

- (void)cancelOperation:(id)sender {
    if ([self hasOverview])
        [self hideOverviewAnimating:YES];
    else if ([self canExitPresentation])
        [self exitPresentation];
    else if ([self canExitFullscreen])
        [self exitFullscreen];
}

- (void)doScrollUp:(id)sender {
    NSScrollView *scrollView = [[self pdfView] embeddedScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSPoint point = [clipView bounds].origin;
    point.y += [clipView isFlipped] ? -4.0 * [scrollView verticalLineScroll] : 4.0 * [scrollView verticalLineScroll];
    [clipView scrollPoint:point];
}

- (void)doScrollDown:(id)sender {
    NSScrollView *scrollView = [[self pdfView] embeddedScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSPoint point = [clipView bounds].origin;
    point.y += [clipView isFlipped] ? 4.0 * [scrollView verticalLineScroll] : -4.0 * [scrollView verticalLineScroll];
    [clipView scrollPoint:point];
}

- (void)doScrollRight:(id)sender {
    NSScrollView *scrollView = [[self pdfView] embeddedScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSPoint point = [clipView bounds].origin;
    point.x += + 4.0 * [scrollView horizontalLineScroll];
    [clipView scrollPoint:point];
}

- (void)doScrollLeft:(id)sender {
    NSScrollView *scrollView = [[self pdfView] embeddedScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSPoint point = [clipView bounds].origin;
    point.x += -4.0 * [scrollView horizontalLineScroll];
    [clipView scrollPoint:point];
}

@end
