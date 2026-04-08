//
//  SKSideViewController.m
//  Skim
//
//  Created by Christiaan Hofman on 3/28/10.
/*
 This software is Copyright (c) 2010
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

#import "SKSideViewController.h"
#import "SKImageToolTipWindow.h"
#import "SKTopBarView.h"
#import "SKImageToolTipWindow.h"
#import "NSGeometry_SKExtensions.h"
#import "SKStringConstants.h"
#import "NSView_SKExtensions.h"
#import "NSWindow_SKExtensions.h"

#define BORDER_INSET 1.0
#define DURATION 0.7

@implementation SKSideViewController

@synthesize mainController, sideView, topBar, topConstraint, button, alternateButton, searchField, currentView;
@dynamic topInset, tableViews;

- (void)viewDidLoad {
    [super viewDidLoad];
    [topBar setAccessibilityLabel:NSLocalizedString(@"search bar", @"Accessibility description")];
}

#pragma mark Accessors

- (void)setMainController:(SKMainWindowController *)newMainController {
    if (newMainController == nil) {
        [[self tableViews] setValue:nil forKey:@"dataSource"];
        [[self tableViews] setValue:nil forKey:@"delegate"];
    }
    mainController = newMainController;
}

- (NSArray *)tableViews { return @[]; }

- (CGFloat)topInset {
    return [topConstraint constant];
}

- (void)setTopInset:(CGFloat)topInset {
    [topConstraint setConstant:topInset];
    topInset += NSHeight([topBar frame]);
    for (NSTableView *view in [self tableViews]) {
        NSScrollView *scrollView = [view enclosingScrollView];
        CGFloat inset = [scrollView borderType] == NSNoBorder ? 0.0 : BORDER_INSET;
        NSEdgeInsets insets = NSEdgeInsetsMake(topInset + inset, inset, inset, inset);
        [scrollView setAutomaticallyAdjustsContentInsets:NO];
        [scrollView setContentInsets:insets];
    }
}

#pragma mark View animation

- (BOOL)requiresAlternateButtonForView:(NSView *)aView {
    return NO;
}

- (void)displayTableAtIndex:(NSUInteger)idx animate:(BOOL)animate {
    NSScrollView *newView = [[[self tableViews] objectAtIndex:idx] enclosingScrollView];
    if ([newView superview] != nil)
        return;
    
    if (animate && ([NSView shouldShowFadeAnimation] == NO || [currentView window] == nil))
        animate = NO;
    
    NSView *oldView = currentView;
    self.currentView = newView;
    
    BOOL wasAlternate = [self requiresAlternateButtonForView:oldView];
    BOOL isAlternate = [self requiresAlternateButtonForView:newView];
    BOOL changeButton = alternateButton && wasAlternate != isAlternate;
    NSSegmentedControl *oldButton = wasAlternate ? alternateButton : button;
    NSSegmentedControl *newButton = isAlternate ? alternateButton : button;
    NSView *contentView = [oldView superview];
    id firstResponder = nil;
    
    if ([[oldView window] firstResponderIsDescendantOf:oldView])
        firstResponder = newView;
    else if (changeButton && [[[oldView window] firstResponder] isEqual:oldButton])
        firstResponder = newButton;
    
    [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
    
    [newView setFrame:[oldView frame]];
    CGFloat inset = [newView borderType] == NSNoBorder ? 0.0 : -BORDER_INSET;
    NSArray *constraints = @[
        [[newView leadingAnchor] constraintEqualToAnchor:[contentView leadingAnchor] constant:inset],
        [[contentView trailingAnchor] constraintEqualToAnchor:[newView trailingAnchor] constant:inset],
        [[newView topAnchor] constraintEqualToAnchor:[contentView topAnchor] constant:inset],
        [[contentView bottomAnchor] constraintEqualToAnchor:[newView bottomAnchor] constant:inset]];
    
    if (animate) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [context setDuration:DURATION];
                [[contentView animator] replaceSubview:oldView with:newView];
                [NSLayoutConstraint activateConstraints:constraints];
                if (changeButton) {
                    [[newButton animator] setHidden:NO];
                    [[oldButton animator] setHidden:YES];
                }
            }];
    } else {
        [contentView replaceSubview:oldView with:newView];
        [NSLayoutConstraint activateConstraints:constraints];
        if (changeButton) {
            [newButton setHidden:NO];
            [oldButton setHidden:YES];
        }
    }
    [[firstResponder window] makeFirstResponder:firstResponder];
    [[contentView window] recalculateKeyViewLoop];
}

- (void)displayTableAtIndex:(NSUInteger)idx {
    [self displayTableAtIndex:idx animate:NO];
}

@end
