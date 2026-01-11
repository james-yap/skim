//
//  SKOverviewView.m
//  Skim
//
//  Created by Christiaan Hofman on 20/03/2020.
/*
This software is Copyright (c) 2020
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

#import "SKOverviewView.h"
#import "SKTypeSelectHelper.h"
#import "NSEvent_SKExtensions.h"
#import "SKApplication.h"
#import "SKMainWindowController_Actions.h"


@interface NSCollectionView (SKPrivateDeclarations)
- (BOOL)validateUserInterfaceItem:(id)item;
@end

@implementation SKOverviewView

@synthesize action, sendActionOnSingleClick, typeSelectHelper;

- (void)keyDown:(NSEvent *)theEvent {
    unichar eventChar = [theEvent firstCharacter];
    NSEventModifierFlags modifiers = [theEvent deviceIndependentModifierFlags] & ~NSEventModifierFlagCapsLock;
    NSEventModifierFlags standardModifiers = modifiers & ~NSEventModifierFlagNumericPad & ~NSEventModifierFlagFunction;
    
    if ((eventChar == NSNewlineCharacter || eventChar == NSEnterCharacter || eventChar == NSCarriageReturnCharacter) && modifiers == 0 && [self action]) {
        [self tryToPerform:[self action] with:self];
    } else if (eventChar == 'p' && modifiers == 0 && [self sendActionOnSingleClick] && [self action]) {
        [self tryToPerform:[self action] with:self];
    } else if ((eventChar == NSDownArrowFunctionKey && standardModifiers == NSEventModifierFlagOption) || (eventChar == NSRightArrowFunctionKey && standardModifiers == NSEventModifierFlagCommand) || (eventChar == NSPageDownFunctionKey && standardModifiers == 0)) {
        [self tryToPerform:@selector(doGoToNextPage:) with:self];
    } else if ((eventChar == NSUpArrowFunctionKey && standardModifiers == NSEventModifierFlagOption) || (eventChar == NSLeftArrowFunctionKey && standardModifiers == NSEventModifierFlagCommand) || (eventChar == NSPageUpFunctionKey && standardModifiers == 0)) {
        [self tryToPerform:@selector(doGoToPreviousPage:) with:self];
    } else if ((eventChar == NSLeftArrowFunctionKey && standardModifiers == NSEventModifierFlagOption) || (eventChar == NSUpArrowFunctionKey && standardModifiers == NSEventModifierFlagCommand) || (eventChar == NSHomeFunctionKey && standardModifiers == 0)) {
        [self tryToPerform:@selector(doGoToFirstPage:) with:self];
    } else if ((eventChar == NSRightArrowFunctionKey && standardModifiers == NSEventModifierFlagOption) || (eventChar == NSDownArrowFunctionKey && standardModifiers == NSEventModifierFlagCommand) || (eventChar == NSEndFunctionKey && standardModifiers == 0)) {
        [self tryToPerform:@selector(doGoToLastPage:) with:self];
    } else if ([typeSelectHelper handleEvent:theEvent] == NO) {
        [super keyDown:theEvent];
    }
}

- (void)copy:(id)sender {
    NSUInteger i = [[self selectionIndexes] firstIndex];
    if (i != NSNotFound) {
        id view = [[self itemAtIndex:i] view];
        if ([view respondsToSelector:_cmd])
            [view copy:sender];
    }
}

- (void)copyURL:(id)sender {
    NSUInteger i = [[self selectionIndexes] firstIndex];
    if (i != NSNotFound) {
        id view = [[self itemAtIndex:i] view];
        if ([view respondsToSelector:_cmd])
            [view copyURL:sender];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL itemAction = [menuItem action];
    if (itemAction == @selector(copy:) || itemAction == @selector(copyURL:)) {
        NSUInteger i = [[self selectionIndexes] firstIndex];
        if (i == NSNotFound)
            return NO;
        id view = [[self itemAtIndex:i] view];
        if ([view respondsToSelector:itemAction] == NO)
            return NO;
        if ([view respondsToSelector:_cmd])
            return [view validateMenuItem:menuItem];
        return YES;
    } else if ([[SKOverviewView superclass] instancesRespondToSelector:_cmd]) {
        return [super validateMenuItem:menuItem];
    } else if ([self respondsToSelector:@selector(validateUserInterfaceItem:)]) {
        return [self validateUserInterfaceItem:menuItem];
    } else {
        return YES;
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    BOOL shouldSendAction = [self action] && (([theEvent clickCount] == 1 && [self sendActionOnSingleClick]) || [theEvent clickCount] == 2) && [NSApp willDragMouse] == NO;
    
    [super mouseDown:theEvent];
    
    if (shouldSendAction)
        DISPATCH_MAIN_AFTER_SEC(0.01, ^{ [self tryToPerform:[self action] with:self]; });
}

- (id)newViewWithIdentifier:(NSString *)identifier {
    for (id view in cachedViews) {
        if ([[view identifier] isEqualToString:identifier]) {
            id newView = view;
            [cachedViews removeObject:view];
            [newView prepareForReuse];
            return newView;
        }
    }
    return nil;
}

- (void)cacheView:(id)view {
    if (cachedViews == nil)
        cachedViews = [[NSMutableArray alloc] init];
    if ([cachedViews count] < 20 || [[view identifier] isEqualToString:@"highlight"] == NO)
        [cachedViews addObject:view];
}

- (void)selectAll:(id)sender {
    if ([self numberOfSections])
        [self setSelectionIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfItemsInSection:0])]];
}

- (void)deselectAll:(id)sender {
    [self setSelectionIndexes:[NSIndexSet indexSet]];
}

@end
