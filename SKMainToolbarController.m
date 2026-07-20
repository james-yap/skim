//
//  SKMainToolbarController.m
//  Skim
//
//  Created by Christiaan Hofman on 4/2/08.
/*
 This software is Copyright (c) 2008
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

#import "SKMainToolbarController.h"
#import "SKMainWindowController.h"
#import "SKMainWindowController_Actions.h"
#import "SKMainWindowController_FullScreen.h"
#import "SKToolbarItem.h"
#import "NSToolbarItem_SKExtensions.h"
#import "NSSegmentedControl_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKPDFView.h"
#import "SKColorSwatch.h"
#import "NSValueTransformer_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import "PDFSelection_SKExtensions.h"
#import "SKTextFieldSheetController.h"
#import "NSWindowController_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "NSEvent_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "PDFAnnotation_SKExtensions.h"
#import "PDFDocument_SKExtensions.h"
#import "SKShareMenuController.h"
#import "NSGraphics_SKExtensions.h"
#import "SKNoteToolbarController.h"
#import "NSObject_SKExtensions.h"
#import "SKApplicationController.h"

#define SKDocumentToolbarIdentifier @"SKDocumentToolbar"

#define SKDocumentToolbarPreviousItemIdentifier @"SKDocumentToolbarPreviousItemIdentifier"
#define SKDocumentToolbarNextItemIdentifier @"SKDocumentToolbarNextItemIdentifier"
#define SKDocumentToolbarPreviousNextItemIdentifier @"SKDocumentToolbarPreviousNextItemIdentifier"
#define SKDocumentToolbarPreviousNextFirstLastItemIdentifier @"SKDocumentToolbarPreviousNextFirstLastItemIdentifier"
#define SKDocumentToolbarBackForwardItemIdentifier @"SKDocumentToolbarBackForwardItemIdentifier"
#define SKDocumentToolbarPageNumberItemIdentifier @"SKDocumentToolbarPageNumberItemIdentifier"
#define SKDocumentToolbarScaleItemIdentifier @"SKDocumentToolbarScaleItemIdentifier"
#define SKDocumentToolbarZoomActualItemIdentifier @"SKDocumentToolbarZoomActualItemIdentifier"
#define SKDocumentToolbarZoomToSelectionItemIdentifier @"SKDocumentToolbarZoomToSelectionItemIdentifier"
#define SKDocumentToolbarZoomToFitItemIdentifier @"SKDocumentToolbarZoomToFitItemIdentifier"
#define SKDocumentToolbarZoomInOutItemIdentifier @"SKDocumentToolbarZoomInOutItemIdentifier"
#define SKDocumentToolbarZoomInActualOutItemIdentifier @"SKDocumentToolbarZoomInActualOutItemIdentifier"
#define SKDocumentToolbarAutoScalesItemIdentifier @"SKDocumentToolbarAutoScalesItemIdentifier"
#define SKDocumentToolbarRotateRightItemIdentifier @"SKDocumentToolbarRotateRightItemIdentifier"
#define SKDocumentToolbarRotateLeftItemIdentifier @"SKDocumentToolbarRotateLeftItemIdentifier"
#define SKDocumentToolbarRotateLeftRightItemIdentifier @"SKDocumentToolbarRotateLeftRightItemIdentifier"
#define SKDocumentToolbarCropItemIdentifier @"SKDocumentToolbarCropItemIdentifier"
#define SKDocumentToolbarFullScreenItemIdentifier @"SKDocumentToolbarFullScreenItemIdentifier"
#define SKDocumentToolbarPresentationItemIdentifier @"SKDocumentToolbarPresentationItemIdentifier"
#define SKDocumentToolbarNewTextNoteItemIdentifier @"SKDocumentToolbarNewTextNoteItemIdentifier"
#define SKDocumentToolbarNewCircleNoteItemIdentifier @"SKDocumentToolbarNewCircleNoteItemIdentifier"
#define SKDocumentToolbarNewMarkupItemIdentifier @"SKDocumentToolbarNewMarkupItemIdentifier"
#define SKDocumentToolbarNewLineItemIdentifier @"SKDocumentToolbarNewLineItemIdentifier"
#define SKDocumentToolbarNewNoteItemIdentifier @"SKDocumentToolbarNewNoteItemIdentifier"
#define SKDocumentToolbarNotesItemIdentifier @"SKDocumentToolbarNotesItemIdentifier"
#define SKDocumentToolbarInfoItemIdentifier @"SKDocumentToolbarInfoItemIdentifier"
#define SKDocumentToolbarToolModeItemIdentifier @"SKDocumentToolbarToolModeItemIdentifier"
#define SKDocumentToolbarSingleTwoUpItemIdentifier @"SKDocumentToolbarSingleTwoUpItemIdentifier"
#define SKDocumentToolbarContinuousItemIdentifier @"SKDocumentToolbarContinuousItemIdentifier"
#define SKDocumentToolbarDisplayModeItemIdentifier @"SKDocumentToolbarDisplayModeItemIdentifier"
#define SKDocumentToolbarDisplayDirectionItemIdentifier @"SKDocumentToolbarDisplayDirectionItemIdentifier"
#define SKDocumentToolbarDisplaysRTLItemIdentifier @"SKDocumentToolbarDisplaysRTLItemIdentifier"
#define SKDocumentToolbarBookModeItemIdentifier @"SKDocumentToolbarBookModeItemIdentifier"
#define SKDocumentToolbarPageBreaksItemIdentifier @"SKDocumentToolbarPageBreaksItemIdentifier"
#define SKDocumentToolbarDisplayBoxItemIdentifier @"SKDocumentToolbarDisplayBoxItemIdentifier"
#define SKDocumentToolbarColorSwatchItemIdentifier @"SKDocumentToolbarColorSwatchItemIdentifier"
#define SKDocumentToolbarShareItemIdentifier @"SKDocumentToolbarShareItemIdentifier"
#define SKDocumentToolbarPacerItemIdentifier @"SKDocumentToolbarPacerItemIdentifier"
#define SKDocumentToolbarColorsItemIdentifier @"SKDocumentToolbarColorsItemIdentifier"
#define SKDocumentToolbarFontsItemIdentifier @"SKDocumentToolbarFontsItemIdentifier"
#define SKDocumentToolbarLinesItemIdentifier @"SKDocumentToolbarLinesItemIdentifier"
#define SKDocumentToolbarContentsPaneItemIdentifier @"SKDocumentToolbarContentsPaneItemIdentifier"
#define SKDocumentToolbarNotesPaneItemIdentifier @"SKDocumentToolbarNotesPaneItemIdentifier"
#define SKDocumentToolbarSplitPDFItemIdentifier @"SKDocumentToolbarSplitPDFItemIdentifier"
#define SKDocumentToolbarPrintItemIdentifier @"SKDocumentToolbarPrintItemIdentifier"

#define SKLastTextNoteTypeKey   @"SKLastTextNoteType"
#define SKLastShapeNoteTypeKey  @"SKLastShapeNoteType"
#define SKLastMarkupNoteTypeKey @"SKLastMarkupNoteType"
#define SKLastLineNoteTypeKey   @"SKLastLineNoteType"

static NSString *noteToolImageNames[] = {@"ToolbarTextNoteMenu", @"ToolbarAnchoredNoteMenu", @"ToolbarCircleNoteMenu", @"ToolbarSquareNoteMenu", @"ToolbarHighlightNoteMenu", @"ToolbarUnderlineNoteMenu", @"ToolbarStrikeOutNoteMenu", @"ToolbarLineNoteMenu", @"ToolbarInkNoteMenu"};

static NSString *addNoteToolImageNames[] = {@"ToolbarAddTextNoteMenu", @"ToolbarAddAnchoredNoteMenu", @"ToolbarAddCircleNoteMenu", @"ToolbarAddSquareNoteMenu", @"ToolbarAddHighlightNoteMenu", @"ToolbarAddUnderlineNoteMenu", @"ToolbarAddStrikeOutNoteMenu", @"ToolbarAddLineNoteMenu", @"ToolbarAddInkNoteMenu"};

static char SKDefaultsObservationContext;

#pragma mark -

@interface SKToolbar : NSToolbar
@end

@implementation SKToolbar

- (void)validateVisibleItems {
    [super validateVisibleItems];
    if ([self displayMode] == NSToolbarDisplayModeLabelOnly && [[self delegate] respondsToSelector:@selector(validateToolbarItem:)]) {
        for (NSToolbarItem *item in [self visibleItems]) {
            if ([[item menuFormRepresentation] hasSubmenu] == NO)
                [item setEnabled:[(id)[self delegate] validateToolbarItem:item]];
        }
    }
}

@end

#pragma mark -

@interface SKMainToolbarController ()
- (void)handleColorSwatchFrameChangedNotification:(NSNotification *)notification;
- (void)updateColorsMenu:(NSMenu *)menu;
- (void)setNoteType:(NSInteger)type forButton:(NSSegmentedControl *)button;
@end


@implementation SKMainToolbarController

@synthesize mainController, backForwardButton, pageNumberField, previousNextPageButton, previousPageButton, nextPageButton, previousNextFirstLastPageButton, zoomInOutButton, zoomInActualOutButton, zoomActualButton, zoomFitButton, zoomSelectionButton, autoScalesButton, rotateLeftButton, rotateRightButton, rotateLeftRightButton, cropButton, fullScreenButton, presentationButton, leftPaneButton, rightPaneButton, splitPDFButton, toolModeButton, textNoteButton, circleNoteButton, markupNoteButton, lineNoteButton, singleTwoUpButton, continuousButton, displayModeButton, displayDirectionButton, displaysRTLButton, bookModeButton, pageBreaksButton, displayBoxButton, infoButton, colorsButton, fontsButton, linesButton, printButton, scaleField, noteButton, notesButton, colorSwatch, pacerButton, pacerSpeedField, pacerSpeedStepper, shareButton;

- (void)dealloc {
    @try { [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:SKSwatchColorsKey context:&SKDefaultsObservationContext]; }
    @catch (id e) {}
}

- (NSString *)nibName {
    return @"MainToolbar";
}

- (void)setMainController:(SKMainWindowController *)newMainController {
    if (newMainController == nil) {
        if ([colorSwatch infoForBinding:SKColorsBinding])
            [colorSwatch unbind:SKColorsBinding];
        [[NSNotificationCenter defaultCenter] removeObserver: self];
    }
    mainController = newMainController;
}

- (void)setupToolbar {
    // make sure the nib is loaded
    [self view];
    
    // Create a new toolbar instance, and attach it to our document window
    NSToolbar *toolbar = [[SKToolbar alloc] initWithIdentifier:SKDocumentToolbarIdentifier];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
        
    // We are the delegate
    [toolbar setDelegate:self];
    
    // Attach the toolbar to the window
    [[mainController window] setToolbar:toolbar];
    
    [self registerForNotifications];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:SKSwatchColorsKey options:0 context:&SKDefaultsObservationContext];
}

- (NSToolbarItem *)toolbarItemForItemIdentifier:(NSString *)identifier {
    NSToolbarItem *item = [toolbarItems objectForKey:identifier];
    NSMenu *menu;
    NSMenuItem *menuItem;
    
    if (item == nil) {
        
        if (toolbarItems == nil)
            toolbarItems = [[NSMutableDictionary alloc] init];
        
        static NSSet *groupIdentifiers = nil;
        if (groupIdentifiers == nil)
            groupIdentifiers = [NSSet setWithObjects:SKDocumentToolbarPreviousNextItemIdentifier, SKDocumentToolbarPreviousNextFirstLastItemIdentifier, SKDocumentToolbarBackForwardItemIdentifier, SKDocumentToolbarZoomInOutItemIdentifier, SKDocumentToolbarPacerItemIdentifier, nil];
        
        if ([groupIdentifiers containsObject:identifier])
            item = [[SKToolbarItemGroup alloc] initWithItemIdentifier:identifier];
        else
            item = [[SKToolbarItem alloc] initWithItemIdentifier:identifier];
        [toolbarItems setObject:item forKey:identifier];
    
        if ([identifier isEqualToString:SKDocumentToolbarPreviousNextItemIdentifier]) {
            
            [item setToolTip:NSLocalizedString(@"Previous/Next", @"Tool tip message")];
            [previousNextPageButton setHelp:NSLocalizedString(@"Go To Previous Page", @"Tool tip message") forSegment:0];
            [previousNextPageButton setHelp:NSLocalizedString(@"Go To Next Page", @"Tool tip message") forSegment:1];
            [previousNextPageButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:previousNextPageButton];
            
            NSToolbarItem *item1 = [[NSToolbarItem alloc] initWithItemIdentifier:@""];
            [item1 setLabels:NSLocalizedString(@"Previous", @"Toolbar item label")];
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Previous", @"Toolbar item label") action:@selector(doGoToPreviousPage:) target:mainController];
            [item1 setMenuFormRepresentation:menuItem];
            [item1 setEnabled:[mainController.pdfView canGoToPreviousPage]];
            NSToolbarItem *item2 = [[NSToolbarItem alloc] initWithItemIdentifier:@""];
            [item2 setLabels:NSLocalizedString(@"Next", @"Toolbar item label")];
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Next", @"Toolbar item label") action:@selector(doGoToNextPage:) target:mainController];
            [item2 setMenuFormRepresentation:menuItem];
            [item2 setEnabled:[mainController.pdfView canGoToNextPage]];
            [(NSToolbarItemGroup *)item setSubitems:@[item1, item2]];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPreviousItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Previous", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Previous", @"Menu item title") action:@selector(doGoToPreviousPage:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"First", @"Menu item title") action:@selector(doGoToFirstPage:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Previous", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Go To Previous Page", @"Tool tip message")];
            [previousPageButton setHelp:NSLocalizedString(@"Go To First page", @"Tool tip message") forSegment:0];
            [previousPageButton setHelp:NSLocalizedString(@"Go To Previous Page", @"Tool tip message") forSegment:1];
            [previousPageButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:previousPageButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNextItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Next", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Next", @"Menu item title") action:@selector(doGoToNextPage:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Last", @"Menu item title") action:@selector(doGoToLastPage:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Next", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Go To Next Page", @"Tool tip message")];
            [nextPageButton setHelp:NSLocalizedString(@"Go To Next Page", @"Tool tip message") forSegment:0];
            [nextPageButton setHelp:NSLocalizedString(@"Go To Last page", @"Tool tip message") forSegment:1];
            [nextPageButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:nextPageButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPreviousNextFirstLastItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Previous/Next", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Previous", @"Menu item title") action:@selector(doGoToPreviousPage:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Next", @"Menu item title") action:@selector(doGoToNextPage:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"First", @"Menu item title") action:@selector(doGoToFirstPage:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Last", @"Menu item title") action:@selector(doGoToLastPage:) target:mainController];
            
            [item setToolTip:NSLocalizedString(@"Go To First, Previous, Next or Last Page", @"Tool tip message")];
            [previousNextFirstLastPageButton setHelp:NSLocalizedString(@"Go To First page", @"Tool tip message") forSegment:0];
            [previousNextFirstLastPageButton setHelp:NSLocalizedString(@"Go To Previous Page", @"Tool tip message") forSegment:1];
            [previousNextFirstLastPageButton setHelp:NSLocalizedString(@"Go To Next Page", @"Tool tip message") forSegment:2];
            [previousNextFirstLastPageButton setHelp:NSLocalizedString(@"Go To Last page", @"Tool tip message") forSegment:3];
            [previousNextFirstLastPageButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:previousNextFirstLastPageButton];
            [item setMenuFormRepresentation:menuItem];
            
            NSToolbarItem *item1 = [[NSToolbarItem alloc] initWithItemIdentifier:@""];
            [item1 setEnabled:[mainController.pdfView canGoToFirstPage]];
            NSToolbarItem *item2 = [[NSToolbarItem alloc] initWithItemIdentifier:@""];
            [item2 setLabels:NSLocalizedString(@"Previous", @"Toolbar item label")];
            [item2 setEnabled:[mainController.pdfView canGoToPreviousPage]];
            NSToolbarItem *item3 = [[NSToolbarItem alloc] initWithItemIdentifier:@""];
            [item3 setLabels:NSLocalizedString(@"Next", @"Toolbar item label")];
            [item3 setEnabled:[mainController.pdfView canGoToNextPage]];
            NSToolbarItem *item4 = [[NSToolbarItem alloc] initWithItemIdentifier:@""];
            [item4 setEnabled:[mainController.pdfView canGoToLastPage]];
            [(NSToolbarItemGroup *)item setSubitems:@[item1, item2, item3, item4]];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarBackForwardItemIdentifier]) {
            
            [item setToolTip:NSLocalizedString(@"Back/Forward", @"Tool tip message")];
            [backForwardButton setHelp:NSLocalizedString(@"Go Back", @"Tool tip message") forSegment:0];
            [backForwardButton setHelp:NSLocalizedString(@"Go Forward", @"Tool tip message") forSegment:1];
            [backForwardButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:backForwardButton];
            
            NSToolbarItem *item1 = [[NSToolbarItem alloc] initWithItemIdentifier:@""];
            [item1 setLabels:NSLocalizedString(@"Back", @"Toolbar item label")];
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Back", @"Menu item title") action:@selector(doGoBack:) target:mainController];
            [item1 setMenuFormRepresentation:menuItem];
            [item1 setEnabled:[mainController.pdfView canGoBack]];
            NSToolbarItem *item2 = [[NSToolbarItem alloc] initWithItemIdentifier:@""];
            [item2 setLabels:NSLocalizedString(@"Forward", @"Toolbar item label")];
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Forward", @"Menu item title") action:@selector(doGoForward:) target:mainController];
            [item2 setMenuFormRepresentation:menuItem];
            [item2 setEnabled:[mainController.pdfView canGoForward]];
            [(NSToolbarItemGroup *)item setSubitems:@[item1, item2]];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPageNumberItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Page", @"Menu item title") action:@selector(doGoToPage:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Page", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Go To Page", @"Tool tip message")];
            [item setView:pageNumberField];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarScaleItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Scale", @"Menu item title") action:@selector(chooseScale:) target:self];
            
            [item setLabels:NSLocalizedString(@"Scale", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Scale", @"Tool tip message")];
            [item setView:scaleField];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarZoomActualItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Actual Size", @"Menu item title") action:@selector(zoomActualPhysical:) target:self];
            
            [item setLabels:NSLocalizedString(@"Actual Size", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Zoom To Actual Size", @"Tool tip message")];
            [item setView:zoomActualButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarZoomToFitItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Zoom To Fit", @"Menu item title") action:@selector(doZoomToFit:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Zoom To Fit", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Zoom To Fit", @"Tool tip message")];
            [item setView:zoomFitButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarZoomToSelectionItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Zoom To Selection", @"Menu item title") action:@selector(doZoomToSelection:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Zoom To Selection", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Zoom To Selection", @"Tool tip message")];
            [item setView:zoomSelectionButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarZoomInOutItemIdentifier]) {
            
            [item setLabels:NSLocalizedString(@"Zoom", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Zoom", @"Tool tip message")];
            [zoomInOutButton setHelp:NSLocalizedString(@"Zoom Out", @"Tool tip message") forSegment:0];
            [zoomInOutButton setHelp:NSLocalizedString(@"Zoom In", @"Tool tip message") forSegment:1];
            [zoomInOutButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:zoomInOutButton];
            
            NSToolbarItem *item1 = [[NSToolbarItem alloc] initWithItemIdentifier:@""];
            [item1 setLabels:NSLocalizedString(@"Zoom Out", @"Toolbar item label")];
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Zoom Out", @"Menu item title") action:@selector(doZoomOut:) target:mainController];
            [item1 setMenuFormRepresentation:menuItem];
            [item1 setEnabled:[mainController.pdfView canZoomOut]];
            NSToolbarItem *item2 = [[NSToolbarItem alloc] initWithItemIdentifier:@""];
            [item2 setLabels:NSLocalizedString(@"Zoom In", @"Toolbar item label")];
            [item2 setEnabled:[mainController.pdfView canZoomIn]];
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Zoom In", @"Menu item title") action:@selector(doZoomIn:) target:mainController];
            [item2 setMenuFormRepresentation:menuItem];
            [(NSToolbarItemGroup *)item setSubitems:@[item1, item2]];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarZoomInActualOutItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Zoom", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Zoom In", @"Menu item title") action:@selector(doZoomIn:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Zoom Out", @"Menu item title") action:@selector(doZoomOut:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Actual Size", @"Menu item title") action:@selector(zoomActualPhysical:) target:self];
            
            [item setLabels:NSLocalizedString(@"Zoom", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Zoom", @"Tool tip message")];
            [zoomInActualOutButton setHelp:NSLocalizedString(@"Zoom Out", @"Tool tip message") forSegment:0];
            [zoomInActualOutButton setHelp:NSLocalizedString(@"Zoom To Actual Size", @"Tool tip message") forSegment:1];
            [zoomInActualOutButton setHelp:NSLocalizedString(@"Zoom In", @"Tool tip message") forSegment:2];
            [zoomInActualOutButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:zoomInActualOutButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarAutoScalesItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Automatically Resize", @"Menu item title") action:@selector(toggleAutoScale:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Automatically Resize", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Automatically Resize", @"Tool tip message")];
            [autoScalesButton setHelp:NSLocalizedString(@"Automatically Resize", @"Tool tip message") forSegment:0];
            [item setView:autoScalesButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarRotateRightItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Rotate Right", @"Menu item title") action:@selector(rotateAllRight:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Rotate Right", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Rotate Right", @"Tool tip message")];
            [item setView:rotateRightButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarRotateLeftItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Rotate Left", @"Menu item title") action:@selector(rotateAllLeft:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Rotate Left", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Rotate Left", @"Tool tip message")];
            [item setView:rotateLeftButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarRotateLeftRightItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Rotate", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Rotate Right", @"Menu item title") action:@selector(rotateAllRight:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Rotate Left", @"Menu item title") action:@selector(rotateAllLeft:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Rotate", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Rotate Left or Right", @"Tool tip message")];
            [rotateLeftRightButton setHelp:NSLocalizedString(@"Rotate Left", @"Tool tip message") forSegment:0];
            [rotateLeftRightButton setHelp:NSLocalizedString(@"Rotate Right", @"Tool tip message") forSegment:1];
            [rotateLeftRightButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:rotateLeftRightButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarCropItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Crop", @"Menu item title") action:@selector(cropAll:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Crop", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Crop", @"Tool tip message")];
            [item setView:cropButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarFullScreenItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Full Screen", @"Menu item title") action:@selector(toggleFullscreen:) target:self];
            
            [item setLabels:NSLocalizedString(@"Full Screen", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Full Screen", @"Tool tip message")];
            [item setView:fullScreenButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPresentationItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Presentation", @"Menu item title") action:@selector(togglePresentation:) target:self];
            
            [item setLabels:NSLocalizedString(@"Presentation", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Presentation", @"Tool tip message")];
            [item setView:presentationButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNewTextNoteItemIdentifier]) {
            
            [self setNoteType:[[NSUserDefaults standardUserDefaults] integerForKey:SKLastTextNoteTypeKey] forButton:textNoteButton];
            
            menu = [NSMenu menu];
            [menu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") imageNamed:SKImageNameToolbarAddTextNote action:@selector(createNewTextNote:) target:self tag:SKNoteTypeFreeText];
            [menu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") imageNamed:SKImageNameToolbarAddAnchoredNote action:@selector(createNewTextNote:) target:self tag:SKNoteTypeAnchored];
            [textNoteButton setMenu:menu forSegment:0];
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Add Note", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") imageNamed:SKImageNameToolbarAddTextNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeFreeText];
            [menu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") imageNamed:SKImageNameToolbarAddAnchoredNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeAnchored];
            
            [item setLabels:NSLocalizedString(@"Add Note", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Add New Note", @"Tool tip message")];
            [item setView:textNoteButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNewCircleNoteItemIdentifier]) {
            
            [self setNoteType:[[NSUserDefaults standardUserDefaults] integerForKey:SKLastShapeNoteTypeKey] forButton:circleNoteButton];
            
            menu = [NSMenu menu];
            [menu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") imageNamed:SKImageNameToolbarAddCircleNote action:@selector(createNewShapeNote:) target:self tag:SKNoteTypeCircle];
            [menu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") imageNamed:SKImageNameToolbarAddSquareNote action:@selector(createNewShapeNote:) target:self tag:SKNoteTypeSquare];
            [circleNoteButton setMenu:menu forSegment:0];
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Add Shape", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") imageNamed:SKImageNameToolbarAddCircleNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeCircle];
            [menu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") imageNamed:SKImageNameToolbarAddSquareNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeSquare];
            
            [item setLabels:NSLocalizedString(@"Add Shape", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Add New Circle or Box", @"Tool tip message")];
            [item setView:circleNoteButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNewMarkupItemIdentifier]) {
            
            [self setNoteType:[[NSUserDefaults standardUserDefaults] integerForKey:SKLastMarkupNoteTypeKey] forButton:markupNoteButton];
            
            menu = [NSMenu menu];
            [menu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") imageNamed:SKImageNameToolbarAddHighlightNote action:@selector(createNewMarkupNote:) target:self tag:SKNoteTypeHighlight];
            [menu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") imageNamed:SKImageNameToolbarAddUnderlineNote action:@selector(createNewMarkupNote:) target:self tag:SKNoteTypeUnderline];
            [menu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") imageNamed:SKImageNameToolbarAddStrikeOutNote action:@selector(createNewMarkupNote:) target:self tag:SKNoteTypeStrikeOut];
            [markupNoteButton setMenu:menu forSegment:0];
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Add Markup", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") imageNamed:SKImageNameToolbarAddHighlightNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeHighlight];
            [menu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") imageNamed:SKImageNameToolbarAddUnderlineNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeUnderline];
            [menu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") imageNamed:SKImageNameToolbarAddStrikeOutNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeStrikeOut];
            
            [item setLabels:NSLocalizedString(@"Add Markup", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Add New Markup", @"Tool tip message")];
            [item setView:markupNoteButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNewLineItemIdentifier]) {
            
            [self setNoteType:[[NSUserDefaults standardUserDefaults] integerForKey:SKLastLineNoteTypeKey] forButton:lineNoteButton];
            
            menu = [NSMenu menu];
            [menu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") imageNamed:SKImageNameToolbarAddLineNote action:@selector(createNewLineNote:) target:self tag:SKNoteTypeLine];
            [menu addItemWithTitle:NSLocalizedString(@"Freehand", @"Menu item title") imageNamed:SKImageNameToolbarAddInkNote action:@selector(createNewLineNote:) target:self tag:SKNoteTypeInk];
            [lineNoteButton setMenu:menu forSegment:0];
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Add Line", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") imageNamed:SKImageNameToolbarAddLineNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeLine];
            [menu addItemWithTitle:NSLocalizedString(@"Freehand", @"Menu item title") imageNamed:SKImageNameToolbarAddInkNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeInk];
            
            [item setLabels:NSLocalizedString(@"Add Line", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Add New Line", @"Tool tip message")];
            [item setView:lineNoteButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNewNoteItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Add Note", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") imageNamed:SKImageNameToolbarAddTextNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeFreeText];
            [menu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") imageNamed:SKImageNameToolbarAddAnchoredNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeAnchored];
            [menu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") imageNamed:SKImageNameToolbarAddCircleNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeCircle];
            [menu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") imageNamed:SKImageNameToolbarAddSquareNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeSquare];
            [menu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") imageNamed:SKImageNameToolbarAddHighlightNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeHighlight];
            [menu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") imageNamed:SKImageNameToolbarAddUnderlineNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeUnderline];
            [menu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") imageNamed:SKImageNameToolbarAddStrikeOutNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeStrikeOut];
            [menu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") imageNamed:SKImageNameToolbarAddLineNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeLine];
            [menu addItemWithTitle:NSLocalizedString(@"Freehand", @"Menu item title") imageNamed:SKImageNameToolbarAddInkNote action:@selector(createNewNote:) target:mainController tag:SKNoteTypeInk];
            
            [item setLabels:NSLocalizedString(@"Add Note", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Add New Note", @"Tool tip message")];
            [noteButton setHelp:NSLocalizedString(@"Add New Text Note", @"Tool tip message") forSegment:SKNoteTypeFreeText];
            [noteButton setHelp:NSLocalizedString(@"Add New Anchored Note", @"Tool tip message") forSegment:SKNoteTypeAnchored];
            [noteButton setHelp:NSLocalizedString(@"Add New Circle", @"Tool tip message") forSegment:SKNoteTypeCircle];
            [noteButton setHelp:NSLocalizedString(@"Add New Box", @"Tool tip message") forSegment:SKNoteTypeSquare];
            [noteButton setHelp:NSLocalizedString(@"Add New Highlight", @"Tool tip message") forSegment:SKNoteTypeHighlight];
            [noteButton setHelp:NSLocalizedString(@"Add New Underline", @"Tool tip message") forSegment:SKNoteTypeUnderline];
            [noteButton setHelp:NSLocalizedString(@"Add New Strike Out", @"Tool tip message") forSegment:SKNoteTypeStrikeOut];
            [noteButton setHelp:NSLocalizedString(@"Add New Line", @"Tool tip message") forSegment:SKNoteTypeLine];
            [noteButton setHelp:NSLocalizedString(@"Add New Freehand", @"Tool tip message") forSegment:SKNoteTypeInk];
            [noteButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:noteButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNotesItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Notes", @"Toolbar item label") action:@selector(toggleNoteToolbar:) target:self];
            
            menu = [menuItem submenu];
            [item setLabels:NSLocalizedString(@"Notes", @"Toolbar item label")];
            [item setToolTip:[mainController hasNoteToolbar] ? NSLocalizedString(@"Hide Note Toolbar", @"Tool tip message") : NSLocalizedString(@"Show Note Toolbar", @"Tool tip message")];
            [item setView:notesButton];
            [item setMenuFormRepresentation:menuItem];
            
            [self noteToolbarDidShowOrHide:[mainController hasNoteToolbar]];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarToolModeItemIdentifier]) {
            
            menu = [NSMenu menu];
            [menu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") imageNamed:SKImageNameTextNote action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeFreeText];
            [menu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") imageNamed:SKImageNameAnchoredNote action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeAnchored];
            [menu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") imageNamed:SKImageNameCircleNote action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeCircle];
            [menu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") imageNamed:SKImageNameSquareNote action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeSquare];
            [menu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") imageNamed:SKImageNameHighlightNote action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeHighlight];
            [menu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") imageNamed:SKImageNameUnderlineNote action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeUnderline];
            [menu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") imageNamed:SKImageNameStrikeOutNote action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeStrikeOut];
            [menu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") imageNamed:SKImageNameLineNote action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeLine];
            [menu addItemWithTitle:NSLocalizedString(@"Freehand", @"Menu item title") imageNamed:SKImageNameInkNote action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeInk];
            [toolModeButton setMenu:menu forSegment:SKToolModeNote];
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Tool Mode", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Text Tool", @"Menu item title") action:@selector(changeToolMode:) target:mainController tag:SKToolModeText];
            [menu addItemWithTitle:NSLocalizedString(@"Scroll Tool", @"Menu item title") action:@selector(changeToolMode:) target:mainController tag:SKToolModeMove];
            [menu addItemWithTitle:NSLocalizedString(@"Magnify Tool", @"Menu item title") action:@selector(changeToolMode:) target:mainController tag:SKToolModeMagnify];
            [menu addItemWithTitle:NSLocalizedString(@"Select Tool", @"Menu item title") action:@selector(changeToolMode:) target:mainController tag:SKToolModeSelect];
            [menu addItem:[NSMenuItem separatorItem]];
            [menu addItemWithTitle:NSLocalizedString(@"Text Note Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeFreeText];
            [menu addItemWithTitle:NSLocalizedString(@"Anchored Note Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeAnchored];
            [menu addItemWithTitle:NSLocalizedString(@"Circle Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeCircle];
            [menu addItemWithTitle:NSLocalizedString(@"Box Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeSquare];
            [menu addItemWithTitle:NSLocalizedString(@"Highlight Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeHighlight];
            [menu addItemWithTitle:NSLocalizedString(@"Underline Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeUnderline];
            [menu addItemWithTitle:NSLocalizedString(@"Strike Out Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeStrikeOut];
            [menu addItemWithTitle:NSLocalizedString(@"Line Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeLine];
            [menu addItemWithTitle:NSLocalizedString(@"Freehand Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKNoteTypeInk];
            
            [item setLabels:NSLocalizedString(@"Tool Mode", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Tool Mode", @"Tool tip message")];
            [toolModeButton setHelp:NSLocalizedString(@"Text Tool", @"Tool tip message") forSegment:SKToolModeText];
            [toolModeButton setHelp:NSLocalizedString(@"Scroll Tool", @"Tool tip message") forSegment:SKToolModeMove];
            [toolModeButton setHelp:NSLocalizedString(@"Magnify Tool", @"Tool tip message") forSegment:SKToolModeMagnify];
            [toolModeButton setHelp:NSLocalizedString(@"Select Tool", @"Tool tip message") forSegment:SKToolModeSelect];
            [toolModeButton setHelp:NSLocalizedString(@"Note Tool", @"Tool tip message") forSegment:SKToolModeNote];
            [item setView:toolModeButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarSingleTwoUpItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Single/Two Pages", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Single Page", @"Menu item title") action:@selector(changeDisplayTwoUp:) target:mainController tag:kPDFDisplaySinglePage];
            [menu addItemWithTitle:NSLocalizedString(@"Two Pages", @"Menu item title") action:@selector(changeDisplayTwoUp:) target:mainController tag:kPDFDisplayTwoUp];
            
            [item setLabels:NSLocalizedString(@"Single/Two Pages", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Single/Two Pages", @"Tool tip message")];
            [singleTwoUpButton setHelp:NSLocalizedString(@"Single Page", @"Tool tip message") forSegment:0];
            [singleTwoUpButton setHelp:NSLocalizedString(@"Two Pages", @"Tool tip message") forSegment:1];
            [item setView:singleTwoUpButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarContinuousItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Continuous", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Non Continuous", @"Menu item title") action:@selector(changeDisplayContinuous:) target:mainController tag:kPDFDisplaySinglePage];
            [menu addItemWithTitle:NSLocalizedString(@"Continuous", @"Menu item title") action:@selector(changeDisplayContinuous:) target:mainController tag:kPDFDisplaySinglePageContinuous];
            
            [item setLabels:NSLocalizedString(@"Continuous", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Continuous", @"Tool tip message")];
            [continuousButton setHelp:NSLocalizedString(@"Non Continuous", @"Tool tip message") forSegment:0];
            [continuousButton setHelp:NSLocalizedString(@"Continuous", @"Tool tip message") forSegment:1];
            [item setView:continuousButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarDisplayModeItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Display Mode", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Single Page", @"Menu item title") action:@selector(changeDisplayMode:) target:mainController tag:kPDFDisplaySinglePage];
            [menu addItemWithTitle:NSLocalizedString(@"Single Page Continuous", @"Menu item title") action:@selector(changeDisplayMode:) target:mainController tag:kPDFDisplaySinglePageContinuous];
            [menu addItemWithTitle:NSLocalizedString(@"Two Pages", @"Menu item title") action:@selector(changeDisplayMode:) target:mainController tag:kPDFDisplayTwoUp];
            [menu addItemWithTitle:NSLocalizedString(@"Two Pages Continuous", @"Menu item title") action:@selector(changeDisplayMode:) target:mainController tag:kPDFDisplayTwoUpContinuous];
            [menu addItemWithTitle:NSLocalizedString(@"Horizontal Continuous", @"Menu item title") action:@selector(changeDisplayMode:) target:mainController tag:4];

            [item setLabels:NSLocalizedString(@"Display Mode", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Display Mode", @"Tool tip message")];
            [displayModeButton setHelp:NSLocalizedString(@"Single Page", @"Tool tip message") forSegment:kPDFDisplaySinglePage];
            [displayModeButton setHelp:NSLocalizedString(@"Single Page Continuous", @"Tool tip message") forSegment:kPDFDisplaySinglePageContinuous];
            [displayModeButton setHelp:NSLocalizedString(@"Two Pages", @"Tool tip message") forSegment:kPDFDisplayTwoUp];
            [displayModeButton setHelp:NSLocalizedString(@"Two Pages Continuous", @"Tool tip message") forSegment:kPDFDisplayTwoUpContinuous];
            [displayModeButton setHelp:NSLocalizedString(@"Horizontal Continuous", @"Tool tip message") forSegment:4];
            
            [item setView:displayModeButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarDisplayDirectionItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Direction", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Vertical", @"Menu item title") action:@selector(changeDisplayDirection:) target:mainController tag:0];
            [menu addItemWithTitle:NSLocalizedString(@"Horizontal", @"Menu item title") action:@selector(changeDisplayDirection:) target:mainController tag:1];
            
            [item setLabels:NSLocalizedString(@"Direction", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Direction", @"Tool tip message")];
            [displayDirectionButton setHelp:NSLocalizedString(@"Vertical", @"Tool tip message") forSegment:0];
            [displayDirectionButton setHelp:NSLocalizedString(@"Horizontal", @"Tool tip message") forSegment:1];
            [item setView:displayDirectionButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarDisplayDirectionItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Direction", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Vertical", @"Menu item title") action:@selector(changeDisplayDirection:) target:mainController tag:0];
            [menu addItemWithTitle:NSLocalizedString(@"Horizontal", @"Menu item title") action:@selector(changeDisplayDirection:) target:mainController tag:1];
            
            [item setLabels:NSLocalizedString(@"Direction", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Direction", @"Tool tip message")];
            [displayDirectionButton setHelp:NSLocalizedString(@"Vertical", @"Tool tip message") forSegment:0];
            [displayDirectionButton setHelp:NSLocalizedString(@"Horizontal", @"Tool tip message") forSegment:1];
            [item setView:displayDirectionButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarDisplaysRTLItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Right to Left", @"Menu item title") action:@selector(toggleDisplaysRTL:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Right to Left", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Right to Left", @"Tool tip message")];
            [item setView:displaysRTLButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarBookModeItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Book Mode", @"Menu item title") action:@selector(toggleDisplaysAsBook:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Book Mode", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Book Mode", @"Tool tip message")];
            [item setView:bookModeButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPageBreaksItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Page Breaks", @"Menu item title") action:@selector(toggleDisplayPageBreaks:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Page Breaks", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Page Breaks", @"Tool tip message")];
            [item setView:pageBreaksButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarDisplayBoxItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Display Box", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Media Box", @"Menu item title") action:@selector(changeDisplayBox:) target:mainController tag:kPDFDisplayBoxMediaBox];
            [menu addItemWithTitle:NSLocalizedString(@"Crop Box", @"Menu item title") action:@selector(changeDisplayBox:) target:mainController tag:kPDFDisplayBoxCropBox];
            
            [item setLabels:NSLocalizedString(@"Display Box", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Display Box", @"Tool tip message")];
            [item setView:displayBoxButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarColorSwatchItemIdentifier]) {
            
            NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:SKUnarchiveColorArrayTransformerName];
            NSDictionary *options = @{NSValueTransformerBindingOption:transformer};
            [colorSwatch bind:SKColorsBinding toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:SKSwatchColorsKey] options:options];
            [colorSwatch sizeToFit];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleColorSwatchFrameChangedNotification:)
                                                         name:NSViewFrameDidChangeNotification object:colorSwatch];

            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Favorite Colors", @"Toolbar item label")];
            
            [item setLabels:NSLocalizedString(@"Favorite Colors", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Favorite Colors", @"Tool tip message")];
            [item setView:colorSwatch];
            [item setMenuFormRepresentation:menuItem];
            [self handleColorSwatchFrameChangedNotification:nil];
            [self updateColorsMenu:[menuItem submenu]];

        } else if ([identifier isEqualToString:SKDocumentToolbarShareItemIdentifier]) {
            
            shareMenuController = [[SKShareMenuController alloc] init];
            [shareMenuController setDocument:[[self mainController] document]];
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Share", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu setDelegate:shareMenuController];
            
            menu = [[NSMenu alloc] init];
            [menu setDelegate:shareMenuController];
            [shareButton setMenu:menu forSegment:0];
            
            [item setLabels:NSLocalizedString(@"Share", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Share", @"Toolbar item label")];
            [item setView:shareButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPacerItemIdentifier]) {
            
            [pacerButton sizeToFit];
            NSRect frame;
            frame = [pacerButton frame];
            if (NSHeight(frame) < 25.0) {
                frame.size.height = 25.0;
                [pacerButton setFrame:frame];
            }
            frame = [pacerSpeedField frame];
            frame.size.height = NSHeight([pacerButton frame]);
            [pacerSpeedField setFrame:frame];
            frame = [pacerSpeedStepper frame];
            frame.origin.y = ceil(NSMidY([pacerButton frame]) - 0.5 * NSHeight([pacerSpeedStepper frame]));
            [pacerSpeedStepper setFrame:frame];
            
            menuItem = [[NSMenuItem alloc] initWithSubmenuAndTitle:NSLocalizedString(@"Pacer", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Start Pacer", @"Menu item title") action:@selector(togglePacer:) target:mainController tag:0];
            [menu addItemWithTitle:NSLocalizedString(@"Pacer Speed", @"Menu item title") action:@selector(choosePacerSpeed:) target:self tag:0];
            [menu addItemWithTitle:NSLocalizedString(@"Faster", @"Menu item title") action:@selector(changePacerSpeed:) target:mainController tag:0];
            [menu addItemWithTitle:NSLocalizedString(@"Slower", @"Menu item title") action:@selector(changePacerSpeed:) target:mainController tag:-1];
            
            [item setLabel:NSLocalizedString(@"Pacer", @"Toolbar item label")];
            [item setPaletteLabel:NSLocalizedString(@"Pacer", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Pacer", @"Tool tip message")];
            [pacerButton setHelp:NSLocalizedString(@"Pacer", @"Tool tip message") forSegment:0];
            [pacerSpeedField setToolTip:NSLocalizedString(@"Pacer Speed", @"Tool tip message")];
            [pacerSpeedStepper setToolTip:NSLocalizedString(@"Pacer Speed", @"Tool tip message")];
            [item setMenuFormRepresentation:menuItem];
            
            NSToolbarItem *item1 = [[SKToolbarItem alloc] initWithItemIdentifier:@""];
            [item1 setView:pacerButton];
            NSToolbarItem *item2 = [[SKToolbarItem alloc] initWithItemIdentifier:@""];
            [item2 setView:pacerSpeedField];
            NSToolbarItem *item3 = [[SKToolbarItem alloc] initWithItemIdentifier:@""];
            [item3 setView:pacerSpeedStepper];
            [(NSToolbarItemGroup *)item setSubitems:@[item1, item2, item3]];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarColorsItemIdentifier]) {
            
            menu = [NSMenu menu];
            [colorsButton setMenu:menu forSegment:0];
            [self updateColorsMenu:menu];
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Colors", @"Menu item title") action:@selector(orderFrontColorPanel:) target:nil];
            
            [item setLabels:NSLocalizedString(@"Colors", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Colors", @"Tool tip message")];
            [item setView:colorsButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarFontsItemIdentifier]) {
            
            NSInteger sizes[11] = {9, 10, 11, 12, 13, 14, 16, 18, 20, 24, 36};
            menu = [NSMenu menu];
            for (NSInteger i = 0; i < 11; i++) {
                [menu addItemWithTitle:[NSString stringWithFormat:@"%ld", (long)sizes[i]] action:@selector(selectFontSize:) target:self tag:sizes[i]];
            }
            [fontsButton setMenu:menu forSegment:0];
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Fonts", @"Menu item title") action:@selector(orderFrontFontPanel:) target:nil];
            
            [item setLabels:NSLocalizedString(@"Fonts", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Fonts", @"Tool tip message")];
            [item setView:fontsButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarLinesItemIdentifier]) {
            
            menu = [NSMenu menu];
            NSSize size = NSMakeSize(32.0, 16.0);
            for (NSInteger i = 1; i < 11; i++) {
                menuItem = [menu addItemWithTitle:@"" action:@selector(selectLineWidth:) target:self tag:i];
                NSImage *image = [NSImage imageWithSize:size drawingHandler:^(NSRect r){
                    [[NSColor blackColor] setStroke];
                    NSBezierPath *path = [NSBezierPath bezierPath];
                    [path setLineWidth:i];
                    [path moveToPoint:NSMakePoint(0.0, 8.0 + 0.5 * (i % 2))];
                    [path relativeLineToPoint:NSMakePoint(32.0, 0.0)];
                    [path stroke];
                    return YES;
                }];
                [image setAccessibilityDescription:[NSString stringWithFormat:@"%ld", (long)i]];
                [image setTemplate:YES];
                [menuItem setImage:image];
            }
            [linesButton setMenu:menu forSegment:0];
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Lines", @"Menu item title") action:@selector(orderFrontLineInspector:) target:nil];
            
            [item setLabels:NSLocalizedString(@"Lines", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Lines", @"Tool tip message")];
            [item setView:linesButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarInfoItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Info", @"Menu item title") action:@selector(getInfo:) target:nil];
            
            [item setLabels:NSLocalizedString(@"Info", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Get Document Info", @"Tool tip message")];
            [item setView:infoButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarContentsPaneItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Contents Pane", @"Menu item title") action:@selector(toggleLeftSidePane:) target:self];
            
            [item setLabels:NSLocalizedString(@"Contents Pane", @"Toolbar item label")];
            [item setToolTip:[mainController leftSidePaneIsOpen] ? NSLocalizedString(@"Hide Contents Pane", @"Tool tip message") : NSLocalizedString(@"Show Contents Pane", @"Tool tip message")];
            [item setView:leftPaneButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNotesPaneItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Notes Pane", @"Menu item title") action:@selector(toggleRightSidePane:) target:self];
            
            [item setLabels:NSLocalizedString(@"Notes Pane", @"Toolbar item label")];
            [item setToolTip:[mainController rightSidePaneIsOpen] ? NSLocalizedString(@"Hide Notes Pane", @"Tool tip message") : NSLocalizedString(@"Show Notes Pane", @"Tool tip message")];
            [item setView:rightPaneButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarSplitPDFItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Notes Pane", @"Menu item title") action:@selector(toggleSplitPDF:) target:self];
            
            [item setLabels:NSLocalizedString(@"Split PDF", @"Toolbar item label")];
            [item setToolTip:[(NSView *)mainController.secondaryPdfView superview] ? NSLocalizedString(@"Hide Split PDF", @"Tool tip message") : NSLocalizedString(@"Show Split PDF", @"Tool tip message")];
            [item setView:splitPDFButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPrintItemIdentifier]) {
            
            menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Print", @"Menu item title") action:@selector(printDocument:) target:nil];
            
            [item setLabels:NSLocalizedString(@"Print", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Print Document", @"Tool tip message")];
            [item setView:printButton];
            [item setMenuFormRepresentation:menuItem];
            
        }
    }
    
    return item;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL)willBeInserted {

    NSToolbarItem *item = [self toolbarItemForItemIdentifier:itemIdent];
    
    if (willBeInserted == NO) {
        if ([itemIdent isEqualToString:SKDocumentToolbarShareItemIdentifier])
             [[shareButton menuForSegment:0] removeAllItems];
        item = [item copy];
        [item setEnabled:YES];
        id view = [item view];
        if ([view respondsToSelector:@selector(setEnabled:)])
            [view setEnabled:YES];
        if ([view respondsToSelector:@selector(setEnabledForAllSegments:)])
            [view setEnabledForAllSegments:YES];
        if ([view respondsToSelector:@selector(setControlSize:)])
            [view setControlSize:NSControlSizeRegular];
    }
    
    return item;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[SKDocumentToolbarPreviousNextItemIdentifier,
        SKDocumentToolbarPageNumberItemIdentifier,
        SKDocumentToolbarZoomInActualOutItemIdentifier,
        SKDocumentToolbarToolModeItemIdentifier,
        SKDocumentToolbarNewNoteItemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[SKDocumentToolbarPreviousNextItemIdentifier,
        SKDocumentToolbarPreviousNextFirstLastItemIdentifier,
        SKDocumentToolbarPreviousItemIdentifier,
        SKDocumentToolbarPageNumberItemIdentifier,
        SKDocumentToolbarNextItemIdentifier,
        SKDocumentToolbarBackForwardItemIdentifier,
        SKDocumentToolbarZoomInActualOutItemIdentifier,
        SKDocumentToolbarZoomInOutItemIdentifier,
        SKDocumentToolbarZoomActualItemIdentifier,
        SKDocumentToolbarZoomToFitItemIdentifier,
        SKDocumentToolbarZoomToSelectionItemIdentifier,
        SKDocumentToolbarAutoScalesItemIdentifier,
        SKDocumentToolbarScaleItemIdentifier,
        SKDocumentToolbarDisplayModeItemIdentifier,
        SKDocumentToolbarSingleTwoUpItemIdentifier,
        SKDocumentToolbarContinuousItemIdentifier,
        SKDocumentToolbarDisplayDirectionItemIdentifier,
        SKDocumentToolbarBookModeItemIdentifier,
        SKDocumentToolbarDisplaysRTLItemIdentifier,
        SKDocumentToolbarPageBreaksItemIdentifier,
        SKDocumentToolbarDisplayBoxItemIdentifier,
        SKDocumentToolbarFullScreenItemIdentifier,
        SKDocumentToolbarPresentationItemIdentifier,
        SKDocumentToolbarContentsPaneItemIdentifier,
        SKDocumentToolbarNotesPaneItemIdentifier,
        SKDocumentToolbarSplitPDFItemIdentifier,
        SKDocumentToolbarRotateRightItemIdentifier,
        SKDocumentToolbarRotateLeftItemIdentifier,
        SKDocumentToolbarRotateLeftRightItemIdentifier,
        SKDocumentToolbarCropItemIdentifier,
        SKDocumentToolbarToolModeItemIdentifier,
        SKDocumentToolbarNotesItemIdentifier,
        SKDocumentToolbarNewNoteItemIdentifier,
        SKDocumentToolbarNewTextNoteItemIdentifier,
        SKDocumentToolbarNewCircleNoteItemIdentifier,
        SKDocumentToolbarNewMarkupItemIdentifier,
        SKDocumentToolbarNewLineItemIdentifier,
        SKDocumentToolbarShareItemIdentifier,
        SKDocumentToolbarPacerItemIdentifier,
        SKDocumentToolbarColorSwatchItemIdentifier,
        SKDocumentToolbarColorsItemIdentifier,
        SKDocumentToolbarFontsItemIdentifier,
        SKDocumentToolbarLinesItemIdentifier,
        SKDocumentToolbarInfoItemIdentifier,
        SKDocumentToolbarPrintItemIdentifier,
        NSToolbarFlexibleSpaceItemIdentifier,
        NSToolbarSpaceItemIdentifier];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem {
    NSString *identifier = [toolbarItem itemIdentifier];
    
    if ([identifier isEqualToString:SKDocumentToolbarZoomActualItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarZoomToFitItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO && [mainController.pdfView autoScales] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarZoomToSelectionItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO && (NSIsEmptyRect([mainController.pdfView selectToolRect]) == NO || [mainController.pdfView toolMode] != SKToolModeSelect);
    } else if ([identifier isEqualToString:SKDocumentToolbarZoomActualItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarZoomInOutItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarZoomInActualOutItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarAutoScalesItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarScaleItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarPageNumberItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarDisplayBoxItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarDisplayModeItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarSingleTwoUpItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarContinuousItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarPageBreaksItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarDisplaysRTLItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarBookModeItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarDisplayDirectionItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarToolModeItemIdentifier]) {
        return [mainController hasOverview] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarNewTextNoteItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarNewCircleNoteItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarNewLineItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarNewMarkupItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarNewLineItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarNewNoteItemIdentifier]) {
        return [mainController hasOverview] == NO && [mainController.pdfView canSelectNote];
    } else if ([identifier isEqualToString:SKDocumentToolbarFullScreenItemIdentifier]) {
        return [mainController canEnterFullscreen] || [mainController canExitFullscreen];
    } else if ([identifier isEqualToString:SKDocumentToolbarPresentationItemIdentifier]) {
        return [mainController canEnterPresentation] || [mainController canExitPresentation];
    } else if ([identifier isEqualToString:SKDocumentToolbarRotateRightItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarRotateLeftItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarRotateLeftRightItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarCropItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO;
    } else if ([identifier isEqualToString:NSToolbarPrintItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO;
    }
    return YES;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if (action == @selector(chooseScale:)) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO;
    } else if (action == @selector(zoomActualPhysical:)) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO;
    } else if (action == @selector(createNewTextNote:)) {
        [menuItem setState:[textNoteButton tagForSegment:0] == [menuItem tag] ? NSControlStateValueOn : NSControlStateValueOff];
        return [mainController interactionMode] != SKPresentationMode && [mainController hasOverview] == NO && [mainController.pdfView canSelectNote];
    } else if (action == @selector(createNewShapeNote:)) {
        [menuItem setState:[circleNoteButton tagForSegment:0] == [menuItem tag] ? NSControlStateValueOn : NSControlStateValueOff];
        return [mainController hasOverview] == NO && [mainController.pdfView canSelectNote];
    } else if (action == @selector(createNewMarkupNote:)) {
        [menuItem setState:[markupNoteButton tagForSegment:0] == [menuItem tag] ? NSControlStateValueOn : NSControlStateValueOff];
        return [mainController hasOverview] == NO && [mainController.pdfView canSelectNote];
    } else if (action == @selector(toggleFullscreen:)) {
        return [mainController canEnterFullscreen] || [mainController canExitFullscreen];
    } else if (action == @selector(togglePresentation:)) {
        return [mainController canEnterPresentation] || [mainController canExitPresentation];
    }
    return YES;
}

- (void)handleColorSwatchFrameChangedNotification:(NSNotification *)notification {
    if (@available(macOS 11.0, *))
        return;
    NSToolbarItem *toolbarItem = [self toolbarItemForItemIdentifier:SKDocumentToolbarColorSwatchItemIdentifier];
    NSSize size = [colorSwatch bounds].size;
    [toolbarItem setMinSize:size];
    [toolbarItem setMaxSize:size];
}

- (void)updateColorsMenu:(NSMenu *)menu {
    NSMenu *menu1 = nil;
    NSMenu *menu2 = nil;
    
    if (menu) {
        menu1 = menu;
    } else {
        menu1 = [colorsButton menuForSegment:0];
        menu2 = [[[toolbarItems objectForKey:SKDocumentToolbarColorSwatchItemIdentifier] menuFormRepresentation] submenu];
    }
    
    if (menu1 == nil && menu2 == nil)
        return;
    
    [menu1 removeAllItems];
    [menu2 removeAllItems];
    
    NSSize size = NSMakeSize(16.0, 16.0);
    for (NSColor *color in [NSColor favoriteColors]) {
        NSMenuItem *item;
        NSImage *image = [NSImage imageWithSize:size drawingHandler:^(NSRect dstRect){
            [color drawSwatchInRoundedRect:dstRect];
            return YES;
        }];
        [image setAccessibilityDescription:[color accessibilityValue]];
        if (menu1) {
            item = [menu1 addItemWithTitle:@"" action:@selector(selectColor:) target:self];
            [item setRepresentedObject:color];
            [item setImage:image];
        }
        if (menu2) {
            item = [menu2 addItemWithTitle:@"" action:@selector(selectColor:) target:self];
            [item setRepresentedObject:color];
            [item setImage:image];
        }
    }
}

- (void)noteToolbarDidShowOrHide:(BOOL)show {
    [notesButton setSelected:show forSegment:0];
    NSToolbarItem *item = [toolbarItems objectForKey:SKDocumentToolbarNotesItemIdentifier];
    [item setToolTip:show ? NSLocalizedString(@"Hide Note Toolbar", @"Tool tip message") : NSLocalizedString(@"Show Note Toolbar", @"Tool tip message")];
}

- (void)leftSidePaneDidShowOrHide:(BOOL)show {
    NSToolbarItem *item = [toolbarItems objectForKey:SKDocumentToolbarContentsPaneItemIdentifier];
    [item setToolTip:show ? NSLocalizedString(@"Hide Contents Pane", @"Tool tip message") : NSLocalizedString(@"Show Contents Pane", @"Tool tip message")];
}

- (void)rightSidePaneDidShowOrHide:(BOOL)show {
    NSToolbarItem *item = [toolbarItems objectForKey:SKDocumentToolbarNotesPaneItemIdentifier];
    [item setToolTip:show ? NSLocalizedString(@"Hide Notes Pane", @"Tool tip message") : NSLocalizedString(@"Show Notes Pane", @"Tool tip message")];
}

- (void)splitPDFDidShowOrHide:(BOOL)show {
    NSToolbarItem *item = [toolbarItems objectForKey:SKDocumentToolbarSplitPDFItemIdentifier];
    [item setToolTip:show ? NSLocalizedString(@"Hide Split PDF", @"Tool tip message") : NSLocalizedString(@"Show Split PDF", @"Tool tip message")];
}

- (IBAction)goToPreviousNextFirstLastPage:(id)sender {
    NSInteger tag = [sender selectedTag];
    if (tag == -1)
        [mainController.pdfView goToPreviousPage:sender];
    else if (tag == 1)
        [mainController.pdfView goToNextPage:sender];
    else if (tag == -2)
        [mainController.pdfView goToFirstPage:sender];
    else if (tag == 2)
        [mainController.pdfView goToLastPage:sender];
}

- (IBAction)goBackOrForward:(id)sender {
    if ([sender selectedTag] == 1)
        [mainController.pdfView goForward:sender];
    else
        [mainController.pdfView goBack:sender];
}

- (IBAction)changeScaleFactor:(id)sender {
    [mainController.pdfView setScaleFactor:[sender doubleValue]];
    [mainController.pdfView setAutoScales:NO];
}

- (IBAction)chooseScale:(id)sender {
    SKTextFieldSheetController *scaleSheetController = [[SKTextFieldSheetController alloc] initWithWindowNibName:@"ScaleSheet"];
    
    [(NSNumberFormatter *)[[scaleSheetController textField] formatter] setMinimum:[NSNumber numberWithDouble:[mainController.pdfView minScaleFactor]]];
    [(NSNumberFormatter *)[[scaleSheetController textField] formatter] setMaximum:[NSNumber numberWithDouble:[mainController.pdfView maxScaleFactor]]];
    [[scaleSheetController textField] setDoubleValue:[mainController.pdfView scaleFactor]];
    
    [scaleSheetController beginSheetModalForWindow:[mainController window] completionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK)
                [mainController.pdfView setScaleFactor:[[scaleSheetController textField] doubleValue]];
        }];
}

- (IBAction)zoomActualPhysical:(id)sender {
    ([NSEvent modifierFlags] & NSEventModifierFlagOption) ? [mainController.pdfView setPhysicalScaleFactor:1.0] : [mainController.pdfView setScaleFactor:1.0];
}

- (IBAction)zoomInActualOut:(id)sender {
    NSInteger tag = [sender selectedTag];
    if (tag == -1)
        [mainController.pdfView zoomOut:sender];
    else if (tag == 0)
        ([NSEvent modifierFlags] & NSEventModifierFlagOption) ? [mainController.pdfView setPhysicalScaleFactor:1.0] : [mainController.pdfView setScaleFactor:1.0];
    else if (tag == 1)
        [mainController.pdfView zoomIn:sender];
}

- (IBAction)zoomToFit:(id)sender {
    [mainController doZoomToFit:sender];
}

- (IBAction)zoomToSelection:(id)sender {
    [mainController doZoomToSelection:sender];
}

- (IBAction)changeAutoScales:(id)sender {
    [mainController toggleAutoScale:sender];
}

- (IBAction)rotateAllLeftRight:(id)sender {
    if ([sender selectedTag] == 1)
        [mainController rotateAllRight:sender];
    else
        [mainController rotateAllLeft:sender];
}

- (IBAction)cropAll:(id)sender {
    [mainController cropAll:sender];
}

- (IBAction)toggleFullscreen:(id)sender {
    [mainController toggleFullscreen:sender];
}

- (IBAction)togglePresentation:(id)sender {
    [mainController togglePresentation:sender];
}

- (IBAction)toggleLeftSidePane:(id)sender {
    [mainController toggleLeftSidePane:sender];
}

- (IBAction)toggleRightSidePane:(id)sender {
    [mainController toggleRightSidePane:sender];
}

- (IBAction)toggleSplitPDF:(id)sender {
    [mainController toggleSplitPDF:sender];
}

- (IBAction)changeDisplayBox:(id)sender {
    [mainController.pdfView setDisplayBoxAndRewind:[sender selectedTag]];
}

- (IBAction)changeDisplayTwoUp:(id)sender {
    PDFDisplayMode displayMode = ([mainController.pdfView displayMode] & ~kPDFDisplayTwoUp) | [sender selectedTag];
    if ([mainController.pdfView displayDirection] == kPDFDisplayDirectionHorizontal && displayMode == kPDFDisplaySinglePageContinuous)
        displayMode = kPDFDisplayHorizontalContinuous;
    [mainController.pdfView setExtendedDisplayModeAndRewind:displayMode];
}

- (IBAction)changeDisplayContinuous:(id)sender {
    PDFDisplayMode displayMode = ([mainController.pdfView displayMode] & ~kPDFDisplaySinglePageContinuous) | [sender selectedTag];
    if ([mainController.pdfView displayDirection] == kPDFDisplayDirectionHorizontal && displayMode == kPDFDisplaySinglePageContinuous)
        displayMode = kPDFDisplayHorizontalContinuous;
    [mainController.pdfView setExtendedDisplayModeAndRewind:displayMode];
}

- (IBAction)changeDisplayMode:(id)sender {
    PDFDisplayMode displayMode = [sender selectedTag];
    [mainController.pdfView setExtendedDisplayModeAndRewind:displayMode];
}

- (IBAction)changeDisplayDirection:(id)sender {
    PDFDisplayDirection direction = [sender selectedTag];
    [mainController.pdfView setDisplayDirectionAndRewind:direction];
}

- (IBAction)changeDisplaysRTL:(id)sender {
    [mainController.pdfView setDisplaysRTLAndRewind:NO == [mainController.pdfView displaysRTL]];
}

- (IBAction)changeBookMode:(id)sender {
    [mainController.pdfView setDisplaysAsBookAndRewind:NO == [mainController.pdfView displaysAsBook]];
}

- (IBAction)changePageBreaks:(id)sender {
    [mainController.pdfView setDisplaysPageBreaks:NO == [mainController.pdfView displaysPageBreaks]];
}

- (void)setNoteType:(NSInteger)type forButton:(NSSegmentedControl *)button {
    if (type != [button tagForSegment:0]) {
        [button setTag:type forSegment:0];
        [button setImage:[NSImage imageNamed:addNoteToolImageNames[type]] forSegment:0];
    }
}

- (void)createNewNoteWithType:(NSInteger)type forButton:(NSSegmentedControl *)button defaultsKey:(NSString *)defaultsKey  {
    if ([mainController.pdfView canSelectNote]) {
        [mainController.pdfView addAnnotationWithType:type];
        [self setNoteType:type forButton:button];
        [[NSUserDefaults standardUserDefaults] setInteger:type forKey:defaultsKey];
    } else NSBeep();
}

- (void)createNewTextNote:(id)sender {
    [self createNewNoteWithType:[sender tag] forButton:textNoteButton defaultsKey:SKLastTextNoteTypeKey];
}

- (void)createNewShapeNote:(id)sender {
    [self createNewNoteWithType:[sender tag] forButton:circleNoteButton defaultsKey:SKLastShapeNoteTypeKey];
}

- (void)createNewMarkupNote:(id)sender {
    [self createNewNoteWithType:[sender tag] forButton:markupNoteButton defaultsKey:SKLastMarkupNoteTypeKey];
}

- (void)createNewLineNote:(id)sender {
    [self createNewNoteWithType:[sender tag] forButton:lineNoteButton defaultsKey:SKLastLineNoteTypeKey];
}

- (IBAction)createNewNote:(id)sender {
    if ([mainController.pdfView canSelectNote]) {
        NSInteger type = [sender selectedTag];
        [mainController.pdfView addAnnotationWithType:type];
    } else NSBeep();
}

- (void)toggleNoteToolbar:(id)sender {
    [mainController toggleNoteToolbar:sender];
}

- (IBAction)changeToolMode:(id)sender {
    NSInteger newToolMode = [sender selectedTag];
    [mainController.pdfView setToolMode:newToolMode];
}

- (IBAction)selectColor:(id)sender {
    PDFAnnotation *annotation = [mainController.pdfView currentAnnotation];
    NSColor *newColor = [sender respondsToSelector:@selector(color)] ? [sender color] : [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    BOOL isShift = ([NSEvent modifierFlags] & NSEventModifierFlagShift) != 0;
    BOOL isAlt = ([NSEvent modifierFlags] & NSEventModifierFlagOption) != 0;
    if (isAlt == NO && [sender respondsToSelector:@selector(isAlternate)])
        isAlt = [sender isAlternate];
    if ([annotation isSkimNote]) {
        [annotation setColor:newColor alternate:isAlt updateDefaults:isShift];
    } else {
        NSString *defaultKey = [mainController.pdfView currentColorDefaultKeyForAlternate:isAlt];
        if (defaultKey)
            [[NSUserDefaults standardUserDefaults] setColor:newColor forKey:defaultKey];
    }
}

- (IBAction)selectLineWidth:(id)sender {
    PDFAnnotation *annotation = [mainController.pdfView currentAnnotation];
    if ([mainController hasOverview] == NO && [annotation hasBorder]) {
        BOOL isShift = ([NSEvent modifierFlags] & NSEventModifierFlagShift) != 0;
        [annotation setLineWidth:[sender tag] updateDefaults:isShift];
    }
}

- (IBAction)selectFontSize:(id)sender {
    PDFAnnotation *annotation = [mainController.pdfView currentAnnotation];
    if ([mainController hasOverview] == NO && [annotation isSkimNote] && [annotation isText]) {
        NSFont *font = [[NSFontManager sharedFontManager] convertFont:[annotation font] toSize:[sender tag]];
        [annotation setFont:font];
        if (([NSEvent modifierFlags] & NSEventModifierFlagShift)) {
            [[NSUserDefaults standardUserDefaults] setDouble:[font pointSize] forKey:SKFreeTextNoteFontSizeKey];
        }
    }
}

- (IBAction)togglePacer:(id)sender {
    [mainController togglePacer:sender];
}

- (IBAction)choosePacerSpeed:(id)sender {
    SKTextFieldSheetController *speedSheetController = [[SKTextFieldSheetController alloc] initWithWindowNibName:@"SpeedSheet"];
    
    [[speedSheetController textField] setObjectValue:[NSNumber numberWithDouble:[mainController.pdfView pacerSpeed]]];
    
    [speedSheetController beginSheetModalForWindow:[mainController window] completionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK)
                [mainController.pdfView setPacerSpeed:[[speedSheetController textField] doubleValue]];
        }];
}

#pragma mark Notifications

- (void)handleChangedHistoryNotification:(NSNotification *)notification {
    [backForwardButton setEnabled:[mainController.pdfView canGoBack] forSegment:0];
    [backForwardButton setEnabled:[mainController.pdfView canGoForward] forSegment:1];
    
    NSArray *subitems = [(NSToolbarItemGroup *)[toolbarItems objectForKey:SKDocumentToolbarBackForwardItemIdentifier] subitems];
    [[subitems objectAtIndex:0] setEnabled:[mainController.pdfView canGoBack]];
    [[subitems objectAtIndex:1] setEnabled:[mainController.pdfView canGoForward]];
}

- (void)handlePageChangedNotification:(NSNotification *)notification {
    [previousNextPageButton setEnabled:[mainController.pdfView canGoToPreviousPage] forSegment:0];
    [previousNextPageButton setEnabled:[mainController.pdfView canGoToNextPage] forSegment:1];
    [previousPageButton setEnabled:[mainController.pdfView canGoToFirstPage] forSegment:0];
    [previousPageButton setEnabled:[mainController.pdfView canGoToPreviousPage] forSegment:1];
    [nextPageButton setEnabled:[mainController.pdfView canGoToNextPage] forSegment:0];
    [nextPageButton setEnabled:[mainController.pdfView canGoToLastPage] forSegment:1];
    [previousNextFirstLastPageButton setEnabled:[mainController.pdfView canGoToFirstPage] forSegment:0];
    [previousNextFirstLastPageButton setEnabled:[mainController.pdfView canGoToPreviousPage] forSegment:1];
    [previousNextFirstLastPageButton setEnabled:[mainController.pdfView canGoToNextPage] forSegment:2];
    [previousNextFirstLastPageButton setEnabled:[mainController.pdfView canGoToLastPage] forSegment:3];
    
    NSArray *subitems = [(NSToolbarItemGroup *)[toolbarItems objectForKey:SKDocumentToolbarPreviousNextItemIdentifier] subitems];
    [[subitems objectAtIndex:0] setEnabled:[mainController.pdfView canGoToPreviousPage]];
    [[subitems objectAtIndex:1] setEnabled:[mainController.pdfView canGoToNextPage]];
    subitems = [(NSToolbarItemGroup *)[toolbarItems objectForKey:SKDocumentToolbarPreviousNextFirstLastItemIdentifier] subitems];
    [[subitems objectAtIndex:0] setEnabled:[mainController.pdfView canGoToFirstPage]];
    [[subitems objectAtIndex:1] setEnabled:[mainController.pdfView canGoToPreviousPage]];
    [[subitems objectAtIndex:2] setEnabled:[mainController.pdfView canGoToNextPage]];
    [[subitems objectAtIndex:3] setEnabled:[mainController.pdfView canGoToLastPage]];
}

- (void)handleScaleChangedNotification:(NSNotification *)notification {
    [scaleField setDoubleValue:[mainController.pdfView scaleFactor]];
    
    [zoomInOutButton setEnabled:[mainController.pdfView canZoomOut] forSegment:0];
    [zoomInOutButton setEnabled:[mainController.pdfView canZoomIn] forSegment:1];
    [zoomInActualOutButton setEnabled:[mainController.pdfView canZoomOut] forSegment:0];
    [zoomInActualOutButton setEnabled:[mainController.pdfView.document isLocked] == NO forSegment:1];
    [zoomInActualOutButton setEnabled:[mainController.pdfView canZoomIn] forSegment:2];
    [zoomActualButton setEnabled:[mainController.pdfView.document isLocked] == NO];
    
    [autoScalesButton setSelected:[mainController.pdfView autoScales] forSegment:0];
    
    NSArray *subitems = [(NSToolbarItemGroup *)[toolbarItems objectForKey:SKDocumentToolbarZoomInOutItemIdentifier] subitems];
    [[subitems objectAtIndex:0] setEnabled:[mainController.pdfView canZoomOut]];
    [[subitems objectAtIndex:1] setEnabled:[mainController.pdfView canZoomIn]];
}

- (void)handleAutoScalesChangedNotification:(NSNotification *)notification {
    [autoScalesButton setSelected:[mainController.pdfView autoScales] forSegment:0];
}

- (void)handleToolModeChangedNotification:(NSNotification *)notification {
    [toolModeButton selectSegmentWithTag:[mainController.pdfView toolMode]];
}

- (void)handleTemporaryToolModeChangedNotification:(NSNotification *)notification {
    SKToolMode toolMode = [mainController.pdfView toolMode];
    NSString *name = nil;
    switch ([mainController.pdfView temporaryToolMode]) {
        case SKToolModeZoom :      name = SKImageNameToolbarZoomToSelection;  break;
        case SKToolModeSnapshot :  name = SKImageNameToolbarSnapshotTool;     break;
        case SKToolModeFreeText :  name = SKImageNameToolbarAddTextNote;     break;
        case SKToolModeAnchored :  name = SKImageNameToolbarAddAnchoredNote; break;
        case SKToolModeCircle :    name = SKImageNameToolbarAddCircleNote;   break;
        case SKToolModeSquare :    name = SKImageNameToolbarAddSquareNote;   break;
        case SKToolModeHighlight : name = SKImageNameToolbarAddHighlightNote; break;
        case SKToolModeUnderline : name = SKImageNameToolbarAddUnderlineNote; break;
        case SKToolModeStrikeOut : name = SKImageNameToolbarAddStrikeOutNote; break;
        case SKToolModeLine :      name = SKImageNameToolbarAddLineNote;      break;
        case SKToolModeInk :       name = SKImageNameToolbarAddInkNote;       break;
        case SKToolModeNone:
            switch (toolMode) {
                case SKToolModeText :    name = SKImageNameToolbarTextTool;    break;
                case SKToolModeMove :    name = SKImageNameToolbarMoveTool;    break;
                case SKToolModeMagnify : name = SKImageNameToolbarMagnifyTool; break;
                case SKToolModeSelect :  name = SKImageNameToolbarSelectTool;  break;
                case SKToolModeNote :    name = noteToolImageNames[mainController.pdfView.annotationMode]; break;
            }
            break;
    }
    [toolModeButton setImage:[NSImage imageNamed:name] forSegment:toolMode];
}

- (void)handleDisplayBoxChangedNotification:(NSNotification *)notification {
    [displayBoxButton selectSegmentWithTag:[mainController.pdfView displayBox]];
}

- (void)handleDisplayModeChangedNotification:(NSNotification *)notification {
    PDFDisplayMode displayMode = [mainController.pdfView displayMode];
    [singleTwoUpButton selectSegmentWithTag:displayMode & kPDFDisplayTwoUp];
    [continuousButton selectSegmentWithTag:displayMode & kPDFDisplaySinglePageContinuous];
    if ([mainController.pdfView displayDirection] == kPDFDisplayDirectionHorizontal && displayMode == kPDFDisplaySinglePageContinuous && [displayModeButton segmentCount] > 4)
        displayMode = kPDFDisplayHorizontalContinuous;
    [displayModeButton selectSegmentWithTag:displayMode];
}

- (void)handleDisplayDirectionChangedNotification:(NSNotification *)notification {
    NSInteger direction = [mainController.pdfView displayDirection] == kPDFDisplayDirectionHorizontal ? 1 : 0;
    [displayDirectionButton selectSegmentWithTag:direction];
    PDFDisplayMode displayMode = [mainController.pdfView displayMode];
    if (direction == 1 && displayMode == kPDFDisplaySinglePageContinuous && [displayModeButton segmentCount] > 4)
        displayMode = kPDFDisplayHorizontalContinuous;
    [displayModeButton selectSegmentWithTag:displayMode];
}

- (void)handleDisplaysRTLChangedNotification:(NSNotification *)notification {
    BOOL displaysRTL = [mainController.pdfView displaysRTL];
    [displaysRTLButton setSelected:displaysRTL forSegment:0];
}

- (void)handleBookModeChangedNotification:(NSNotification *)notification {
    BOOL displaysAsBook = [mainController.pdfView displaysAsBook];
    [bookModeButton setSelected:displaysAsBook forSegment:0];
}

- (void)handlePageBreaksChangedNotification:(NSNotification *)notification {
    BOOL displaysPageBreaks = [mainController.pdfView displaysPageBreaks];
    [pageBreaksButton setSelected:displaysPageBreaks forSegment:0];
}

- (void)handleAnnotationModeChangedNotification:(NSNotification *)notification {
    [toolModeButton setImage:[NSImage imageNamed:noteToolImageNames[[mainController.pdfView annotationMode]]] forSegment:SKToolModeNote];
}

- (void)handlePacerStartedOrStoppedNotification:(NSNotification *)notification {
    NSString *name = [mainController.pdfView hasPacer] ? SKImageNameToolbarPause : SKImageNameToolbarPlay;
    [pacerButton setImage:[NSImage imageNamed:name] forSegment:0];
}

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self selector:@selector(handlePageChangedNotification:) 
                             name:PDFViewPageChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleScaleChangedNotification:) 
                             name:PDFViewScaleChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleBookModeChangedNotification:) 
                             name:SKPDFViewDisplaysAsBookChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handlePageBreaksChangedNotification:)
                             name:SKPDFViewDisplaysPageBreaksChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleAutoScalesChangedNotification:)
                             name:SKPDFViewAutoScalesChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleToolModeChangedNotification:)
                             name:SKPDFViewToolModeChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleAnnotationModeChangedNotification:) 
                             name:SKPDFViewAnnotationModeChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleTemporaryToolModeChangedNotification:)
                             name:SKPDFViewTemporaryToolModeChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handlePacerStartedOrStoppedNotification:)
                             name:SKPDFViewPacerStartedOrStoppedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleDisplayModeChangedNotification:)
                             name:PDFViewDisplayModeChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleDisplayDirectionChangedNotification:)
                             name:SKPDFViewDisplayDirectionChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleDisplaysRTLChangedNotification:)
                             name:SKPDFViewDisplaysRTLChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleDisplayBoxChangedNotification:)
                             name:PDFViewDisplayBoxChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleChangedHistoryNotification:)
                             name:PDFViewChangedHistoryNotification object:mainController.pdfView];
    
    [self handleChangedHistoryNotification:nil];
    [self handlePageChangedNotification:nil];
    [self handleScaleChangedNotification:nil];
    [self handleAutoScalesChangedNotification:nil];
    [self handleToolModeChangedNotification:nil];
    [self handleDisplayBoxChangedNotification:nil];
    [self handleDisplayModeChangedNotification:nil];
    [self handleDisplayDirectionChangedNotification:nil];
    [self handleDisplaysRTLChangedNotification:nil];
    [self handleBookModeChangedNotification:nil];
    [self handlePageBreaksChangedNotification:nil];
    [self handleAnnotationModeChangedNotification:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == &SKDefaultsObservationContext) {
        [self updateColorsMenu:nil];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}
@end


@implementation SKToolbarTextFieldCell

- (NSRect)drawingRectForBounds:(NSRect)rect {
    NSRect r = [super drawingRectForBounds:rect];
    r.size.height = SKDefaultLineHeightForFont([self font]);
    r.origin.y = floor(0.5 * (NSHeight(rect) - NSHeight(r)));
    return r;
}

@end
