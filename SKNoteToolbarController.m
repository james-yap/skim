//
//  SKNoteToolbarController.m
//  Skim
//
//  Created by Christiaan Hofman on 16/03/2025.
/*
 This software is Copyright (c) 2025
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

#import "SKNoteToolbarController.h"
#import "SKMainWindowController.h"
#import "SKPDFView.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "NSSegmentedControl_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKApplicationController.h"

static char SKDefaultsObservationContext;

static char SKToolbarObservationContext;

@interface SKNoteToolbarController ()
- (void)updateSizeMode;
- (void)handleValidationChangedNotification:(NSNotification *)notification;
@end

@implementation SKNoteToolbarController

@synthesize mainController;
@dynamic visible;

- (BOOL)isVisible {
    return [self isViewLoaded] && [[self view] window] != nil;
}

- (void)loadView {
    NSArray *images = @[[NSImage imageNamed:SKImageNameToolbarAddTextNote],
                       [NSImage imageNamed:SKImageNameToolbarAddAnchoredNote],
                       [NSImage imageNamed:SKImageNameToolbarAddCircleNote],
                       [NSImage imageNamed:SKImageNameToolbarAddSquareNote],
                       [NSImage imageNamed:SKImageNameToolbarAddHighlightNote],
                       [NSImage imageNamed:SKImageNameToolbarAddUnderlineNote],
                       [NSImage imageNamed:SKImageNameToolbarAddStrikeOutNote],
                       [NSImage imageNamed:SKImageNameToolbarAddLineNote],
                       [NSImage imageNamed:SKImageNameToolbarAddInkNote]];
    noteButton = [NSSegmentedControl segmentedControlWithImages:images trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(createNewNote:)];
    [noteButton setSegmentStyle:NSSegmentStyleSeparated];
    for (NSInteger i = 0; i < 9; i++)
        [noteButton setImageScaling:NSImageScaleNone forSegment:i];
    [noteButton setHelp:NSLocalizedString(@"Add New Text Note", @"Tool tip message") forSegment:SKNoteTypeFreeText];
    [noteButton setHelp:NSLocalizedString(@"Add New Anchored Note", @"Tool tip message") forSegment:SKNoteTypeAnchored];
    [noteButton setHelp:NSLocalizedString(@"Add New Circle", @"Tool tip message") forSegment:SKNoteTypeCircle];
    [noteButton setHelp:NSLocalizedString(@"Add New Box", @"Tool tip message") forSegment:SKNoteTypeSquare];
    [noteButton setHelp:NSLocalizedString(@"Add New Highlight", @"Tool tip message") forSegment:SKNoteTypeHighlight];
    [noteButton setHelp:NSLocalizedString(@"Add New Underline", @"Tool tip message") forSegment:SKNoteTypeUnderline];
    [noteButton setHelp:NSLocalizedString(@"Add New Strike Out", @"Tool tip message") forSegment:SKNoteTypeStrikeOut];
    [noteButton setHelp:NSLocalizedString(@"Add New Line", @"Tool tip message") forSegment:SKNoteTypeLine];
    [noteButton setHelp:NSLocalizedString(@"Add New Freehand", @"Tool tip message") forSegment:SKNoteTypeInk];
    [noteButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    colorsButton = [NSSegmentedControl segmentedControlWithImages:@[[NSImage imageNamed:SKImageNameToolbarColors]] trackingMode:NSSegmentSwitchTrackingMomentary target:nil action:@selector(orderFrontColorPanel:)];
    [colorsButton setImageScaling:NSImageScaleNone forSegment:0];
    [colorsButton setHelp:NSLocalizedString(@"Colors", @"Tool tip message") forSegment:0];
    [colorsButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSMenu *menu = [NSMenu menu];
    [colorsButton setMenu:menu forSegment:0];
    [self updateColorsMenu];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:SKSwatchColorsKey options:0 context:&SKDefaultsObservationContext];
    
    linesButton = [NSSegmentedControl segmentedControlWithImages:@[[NSImage imageNamed:SKImageNameToolbarLines]] trackingMode:NSSegmentSwitchTrackingMomentary target:nil action:@selector(orderFrontLineInspector:)];
    [linesButton setImageScaling:NSImageScaleNone forSegment:0];
    [linesButton setHelp:NSLocalizedString(@"Lines", @"Tool tip message") forSegment:0];
    [linesButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    menu = [NSMenu menu];
    NSSize size = NSMakeSize(32.0, 16.0);
    for (NSInteger i = 1; i < 11; i++) {
        NSMenuItem *menuItem = [menu addItemWithTitle:@"" action:@selector(selectLineWidth:) target:self tag:i];
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
    
    fontsButton = [NSSegmentedControl segmentedControlWithImages:@[[NSImage imageNamed:SKImageNameToolbarFonts]] trackingMode:NSSegmentSwitchTrackingMomentary target:nil action:@selector(orderFrontFontPanel:)];
    [fontsButton setImageScaling:NSImageScaleNone forSegment:0];
    [fontsButton setHelp:NSLocalizedString(@"Fonts", @"Tool tip message") forSegment:0];
    [fontsButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    menu = [NSMenu menu];
    NSInteger sizes[11] = {9, 10, 11, 12, 13, 14, 16, 18, 20, 24, 36};
    for (NSInteger i = 0; i < 11; i++) {
        [menu addItemWithTitle:[NSString stringWithFormat:@"%ld", (long)sizes[i]] action:@selector(selectFontSize:) target:self tag:sizes[i]];
    }
    [fontsButton setMenu:menu forSegment:0];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleValidationChangedNotification:) name:SKPDFViewCanSelectNoteDidChangeNotification object:mainController.pdfView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleValidationChangedNotification:) name:SKMainWindowControllerDidShowOrHideOverviewNotification object:mainController];
    [self handleValidationChangedNotification:nil];
    
    NSView *view = [[NSView alloc] init];
    [view addSubview:noteButton];
    [view addSubview:colorsButton];
    [view addSubview:fontsButton];
    [view addSubview:linesButton];
    
    NSArray *constraints = @[
        [[noteButton leadingAnchor] constraintEqualToAnchor:[view leadingAnchor] constant:10.0],
        [[noteButton centerYAnchor] constraintEqualToAnchor:[view centerYAnchor]],
        [[colorsButton leadingAnchor] constraintEqualToAnchor:[noteButton trailingAnchor] constant:20.0],
        [[colorsButton centerYAnchor] constraintEqualToAnchor:[noteButton centerYAnchor]],
        [[linesButton leadingAnchor] constraintEqualToAnchor:[colorsButton trailingAnchor] constant:8.0],
        [[linesButton centerYAnchor] constraintEqualToAnchor:[noteButton centerYAnchor]],
        [[fontsButton leadingAnchor] constraintEqualToAnchor:[linesButton trailingAnchor] constant:8.0],
        [[fontsButton centerYAnchor] constraintEqualToAnchor:[noteButton centerYAnchor]]
    ];
    [NSLayoutConstraint activateConstraints:constraints];
    
    [self setView:view];
    
    [self updateSizeMode];
    [[[mainController window] toolbar] addObserver:self forKeyPath:@"sizeMode" options:0 context:&SKToolbarObservationContext];
}

- (void)setMainController:(SKMainWindowController *)newMainController {
    if (mainController) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        if (noteButton) {
            @try { [[[mainController window] toolbar] removeObserver:self forKeyPath:@"sizeMode" context:&SKToolbarObservationContext]; }
            @catch (id e) {}
        }
        if (colorsButton) {
            @try { [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:SKSwatchColorsKey context:&SKDefaultsObservationContext]; }
            @catch (id e) {}
        }
    }
    mainController = newMainController;
}

- (void)createNewNote:(id)sender {
    if ([mainController.pdfView canSelectNote]) {
        NSInteger type = [sender selectedSegment];
        [mainController.pdfView addAnnotationWithType:type];
    } else NSBeep();
}

- (void)selectColor:(id)sender {
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

- (void)selectFontSize:(id)sender {
    PDFAnnotation *annotation = [mainController.pdfView currentAnnotation];
    if ([mainController hasOverview] == NO && [annotation isSkimNote] && [annotation isText]) {
        NSFont *font = [[NSFontManager sharedFontManager] convertFont:[annotation font] toSize:[sender tag]];
        [annotation setFont:font];
        if (([NSEvent modifierFlags] & NSEventModifierFlagShift)) {
            [[NSUserDefaults standardUserDefaults] setDouble:[font pointSize] forKey:SKFreeTextNoteFontSizeKey];
        }
    }
}

- (void)selectLineWidth:(id)sender {
    PDFAnnotation *annotation = [mainController.pdfView currentAnnotation];
    if ([mainController hasOverview] == NO && [annotation hasBorder]) {
        BOOL isShift = ([NSEvent modifierFlags] & NSEventModifierFlagShift) != 0;
        [annotation setLineWidth:[sender tag] updateDefaults:isShift];
    }
}

- (void)updateColorsMenu {
    NSMenu *menu = [colorsButton menuForSegment:0];
    
    [menu removeAllItems];
    
    NSSize size = NSMakeSize(16.0, 16.0);
    for (NSColor *color in [NSColor favoriteColors]) {
        NSMenuItem *item;
        NSImage *image = [NSImage imageWithSize:size drawingHandler:^(NSRect dstRect){
            [color drawSwatchInRoundedRect:dstRect];
            return YES;
        }];
        [image setAccessibilityDescription:[color accessibilityValue]];
        item = [menu addItemWithTitle:@"" action:@selector(selectColor:) target:self];
        [item setRepresentedObject:color];
        [item setImage:image];
    }
}

- (void)updateSizeMode {
    NSToolbarSizeMode sizeMode = [[[mainController window] toolbar] sizeMode];
    NSControlSize controlSize = sizeMode == NSToolbarSizeModeSmall ? NSControlSizeSmall : NSControlSizeRegular;
    [noteButton setControlSize:controlSize];
    [colorsButton setControlSize:controlSize];
    [fontsButton setControlSize:controlSize];
    [linesButton setControlSize:controlSize];
}

- (void)handleValidationChangedNotification:(NSNotification *)notification {
    [noteButton setEnabled:[mainController hasOverview] == NO && [mainController.pdfView canSelectNote]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == &SKDefaultsObservationContext) {
        [self updateColorsMenu];
    } else if (context == &SKToolbarObservationContext) {
        [self updateSizeMode];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
