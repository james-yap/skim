//
//  SKOutlineView.m
//  Skim
//
//  Created by Christiaan Hofman on 8/22/07.
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

#import "SKOutlineView.h"
#import "SKTypeSelectHelper.h"
#import "SKImageToolTipWindow.h"
#import "NSEvent_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"

#define SKImageToolTipRowNumberKey @"SKImageToolTipRowView"

@implementation SKOutlineView

@synthesize typeSelectHelper, hasImageToolTips, supportsQuickLook;
@dynamic selectedItems, canDelete, canCopy, canPaste, delegate;

- (NSArray *)itemsAtRowIndexes:(NSIndexSet *)indexes {
    NSMutableArray *items = [NSMutableArray array];
    [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [items addObject:[self itemAtRow:idx]];
    }];
    return items;
}

- (NSArray *)selectedItems {
    return [self itemsAtRowIndexes:[self selectedRowIndexes]];
}

- (void)setTypeSelectHelper:(SKTypeSelectHelper *)newTypeSelectHelper {
    if (typeSelectHelper != newTypeSelectHelper) {
        if ([typeSelectHelper delegate] == self)
            [typeSelectHelper setDelegate:nil];
        typeSelectHelper = newTypeSelectHelper;
        [typeSelectHelper setDelegate:self];
    }
}

- (void)expandItem:(id)item expandChildren:(BOOL)collapseChildren {
    [super expandItem:item expandChildren:collapseChildren];
    [self reloadTypeSelectStrings];
}

- (void)collapseItem:(id)item collapseChildren:(BOOL)collapseChildren {
    [super collapseItem:item collapseChildren:collapseChildren];
    [self reloadTypeSelectStrings];
}

- (void)reloadData{
    [super reloadData];
    [self reloadTypeSelectStrings];
}

- (void)reloadDataForRowIndexes:(NSIndexSet *)rowIndexes columnIndexes:(NSIndexSet *)columnIndexes {
    [super reloadDataForRowIndexes:rowIndexes columnIndexes:columnIndexes];
    [self reloadTypeSelectStrings];
}

- (void)reloadItem:(id)item reloadChildren:(BOOL)reloadChildren {
    [super reloadItem:item reloadChildren:reloadChildren];
    [self reloadTypeSelectStrings];
}

- (void)endUpdates {
    [super endUpdates];
    [self reloadTypeSelectStrings];
}

- (void)reloadTypeSelectStrings {
    [typeSelectHelper rebuildTypeSelectSearchCache];
}

- (void)keyDown:(NSEvent *)theEvent {
    unichar eventChar = [theEvent firstCharacter];
    NSEventModifierFlags modifierFlags = [theEvent deviceIndependentModifierFlags];
    
    if ((eventChar == NSNewlineCharacter || eventChar == NSEnterCharacter || eventChar == NSCarriageReturnCharacter) && modifierFlags == 0 && [self doubleAction]) {
        if ([self sendAction:[self doubleAction] to:[self target]] == NO)
            NSBeep();
    } else if ((eventChar == SKSpaceCharacter) && modifierFlags == 0 && [typeSelectHelper isProcessing] == NO) {
        if (supportsQuickLook == NO)
            [[self enclosingScrollView] pageDown:nil];
        else if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible])
            [[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
        else
            [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil];
    } else if ((eventChar == SKSpaceCharacter) && modifierFlags == NSEventModifierFlagShift) {
        if (supportsQuickLook == NO)
            [[self enclosingScrollView] pageUp:nil];
	} else if ((eventChar == NSDeleteCharacter || eventChar == NSDeleteFunctionKey) && (modifierFlags & ~NSEventModifierFlagFunction) == 0 && [self canDelete]) {
        [self delete:self];
    } else if (eventChar == NSLeftArrowFunctionKey && (modifierFlags & ~(NSEventModifierFlagFunction | NSEventModifierFlagNumericPad)) == (NSEventModifierFlagCommand | NSEventModifierFlagOption)) {
        [self collapseItem:nil collapseChildren:YES];
    } else if (eventChar == NSRightArrowFunctionKey && (modifierFlags & ~(NSEventModifierFlagFunction | NSEventModifierFlagNumericPad)) == (NSEventModifierFlagCommand | NSEventModifierFlagOption)) {
        [self expandItem:nil expandChildren:YES];
    } else if ([typeSelectHelper handleEvent:theEvent] == NO) {
        [super keyDown:theEvent];
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    if ([self hasImageToolTips])
        [[SKImageToolTipWindow sharedToolTipWindow] remove];
    [super mouseDown:theEvent];
}

- (BOOL)canDelete {
    NSArray *items = [self selectedItems];
    if ([items count] && [[self delegate] respondsToSelector:@selector(outlineView:deleteItems:)]) {
        if ([[self delegate] respondsToSelector:@selector(outlineView:canDeleteItems:)])
            return [[self delegate] outlineView:self canDeleteItems:items];
        else
            return YES;
    }
    return NO;
}

- (void)delete:(id)sender {
    if ([self canDelete])
        [[self delegate] outlineView:self deleteItems:[self selectedItems]];
    else
        NSBeep();
}

- (BOOL)canCopy {
    NSArray *items = [self selectedItems];
    if ([items count] && [[self delegate] respondsToSelector:@selector(outlineView:copyItems:)]) {
        if ([[self delegate] respondsToSelector:@selector(outlineView:canCopyItems:)])
            return [[self delegate] outlineView:self canCopyItems:items];
        else
            return YES;
    }
    return NO;
}

- (void)copy:(id)sender {
    if ([self canCopy])
        [[self delegate] outlineView:self copyItems:[self selectedItems]];
    else
        NSBeep();
}

- (BOOL)canPaste {
    if ([[self delegate] respondsToSelector:@selector(outlineView:pasteFromPasteboard:)]) {
        if ([[self delegate] respondsToSelector:@selector(outlineView:canPasteFromPasteboard:)])
            return [[self delegate] outlineView:self canPasteFromPasteboard:[NSPasteboard generalPasteboard]];
        else
            return YES;
    }
    return NO;
}

- (void)paste:(id)sender {
    if ([self canPaste])
        [[self delegate] outlineView:self pasteFromPasteboard:[NSPasteboard generalPasteboard]];
    else
        NSBeep();
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item {
    if ([item action] == @selector(delete:))
        return [self canDelete];
    else if ([item action] == @selector(copy:))
        return [self canCopy];
    else if ([item action] == @selector(paste:))
        return [self canPaste];
    else if ([item action] == @selector(selectAll:))
        return [self allowsMultipleSelection];
    else if ([item action] == @selector(deselectAll:))
        return [self allowsEmptySelection];
    else
        return [super validateUserInterfaceItem:item];
    return YES;
}

- (NSFont *)font {
    return font;
}

- (void)setFont:(NSFont *)newFont {
    if (font != newFont) {
        font = newFont;
        
        for (NSTableColumn *tc in [self tableColumns]) {
            NSCell *cell = [tc dataCell];
            if ([cell type] == NSTextCellType)
                [cell setFont:font];
        }
        
        CGFloat rowHeight = SKDefaultLineHeightForFont(font);
        if ([self selectionHighlightStyle] == NSTableViewSelectionHighlightStyleSourceList)
            rowHeight += 2.0;
        [self setRowHeight:rowHeight];
        [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger roww){
            NSInteger col, numCols = [rowView numberOfColumns];
            for (col = 0; col < numCols; col++) {
                id view = [rowView viewAtColumn:col];
                if ([view respondsToSelector:@selector(setFont:)])
                    [view setFont:newFont];
                else if ([view respondsToSelector:@selector(textField)])
                    [[view textField] setFont:newFont];
            }
        }];
        [self noteHeightOfRowsChanged];
    }
}

- (id)makeViewWithIdentifier:(NSString *)identifier owner:(id)owner {
    id view = [super makeViewWithIdentifier:identifier owner:owner];
    if (font) {
        if ([view respondsToSelector:@selector(setFont:)])
            [view setFont:font];
        else if ([view respondsToSelector:@selector(textField)])
            [[view textField] setFont:font];
    }
    return view;
}

- (void)noteHeightOfRowsChanged {
    [self noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])]];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if ([self window] == nil)
        [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row){ [rowView setEmphasized:NO]; }];
}

#pragma mark Tracking

- (void)addTrackingAreaForRowView:(NSTableRowView *)rowView {
    NSInteger row = [self rowForView:rowView];
    NSDictionary *userInfo = @{SKImageToolTipRowNumberKey: [NSNumber numberWithInteger:row]};
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[rowView bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:userInfo];
    [rowView addTrackingArea:area];
}

- (void)removeTrackingAreaForRowView:(NSTableRowView *)rowView {
    for (NSTrackingArea *area in [rowView trackingAreas]) {
        if ([[area userInfo] objectForKey:SKImageToolTipRowNumberKey]) {
            [rowView removeTrackingArea:area];
            break;
        }
    }
}

- (void)addTrackingAreasIfNeeded {
    if ([self hasImageToolTips] && [[self delegate] respondsToSelector:@selector(outlineView:imageContextForItem:scale:)])
        [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row){
            [self addTrackingAreaForRowView:rowView];
        }];
}

- (void)removeTrackingAreasIfNeeded {
    if ([self hasImageToolTips] && [[self delegate] respondsToSelector:@selector(outlineView:imageContextForItem:scale:)])
        [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row){
            [self removeTrackingAreaForRowView:rowView];
        }];
}

- (void)didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    [super didAddRowView:rowView forRow:row];
    if ([self hasImageToolTips] && [[self delegate] respondsToSelector:@selector(outlineView:imageContextForItem:scale:)])
        [self addTrackingAreaForRowView:rowView];
}

- (void)didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    [super didRemoveRowView:rowView forRow:row];
    if ([self hasImageToolTips])
        [self removeTrackingAreaForRowView:rowView];
}

- (void)setHasImageToolTips:(BOOL)flag {
    if (flag != hasImageToolTips) {
        [self removeTrackingAreasIfNeeded];
        hasImageToolTips = flag;
        [self addTrackingAreasIfNeeded];
    }
}

- (void)mouseEntered:(NSEvent *)theEvent{
    if ([self hasImageToolTips]) {
        NSNumber *rowNumber = [[[theEvent trackingArea] userInfo] objectForKey:SKImageToolTipRowNumberKey];
        if (rowNumber) {
            NSInteger row = [rowNumber integerValue];
            if (row != -1) {
                id item = [self itemAtRow:row];
                if (item) {
                    CGFloat scale = 1.0;
                    id <SKImageToolTipContext> context = [[self delegate] outlineView:self imageContextForItem:item scale:&scale];
                    if (context)
                        [[SKImageToolTipWindow sharedToolTipWindow] showForImageContext:context scale:scale atPoint:NSZeroPoint];
                }
            }
            return;
        }
    }
    if ([[SKOutlineView superclass] instancesRespondToSelector:_cmd])
        [super mouseEntered:theEvent];
}

- (void)mouseExited:(NSEvent *)theEvent{
    if ([self hasImageToolTips] && [[[theEvent trackingArea] userInfo] objectForKey:SKImageToolTipRowNumberKey])
        [[SKImageToolTipWindow sharedToolTipWindow] fadeOut];
    else if ([[SKOutlineView superclass] instancesRespondToSelector:_cmd])
        [super mouseEntered:theEvent];
}

#pragma mark SKTypeSelectHelper datasource protocol

- (NSArray *)typeSelectHelperSelectionStrings {
    if ([[self delegate] respondsToSelector:@selector(outlineViewTypeSelectHelperSelectionStrings:)])
        return [[self delegate] outlineViewTypeSelectHelperSelectionStrings:self];
    return nil;
}

- (NSUInteger)typeSelectHelperCurrentlySelectedIndex {
    return [[self selectedRowIndexes] lastIndex];
}

- (void)typeSelectHelperSelectItemAtIndex:(NSUInteger)itemIndex {
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
    [self scrollRowToVisible:itemIndex];
}

- (void)typeSelectHelperDidFailToFindMatchForSearchString:(NSString *)searchString {
    if ([[self delegate] respondsToSelector:@selector(outlineView:typeSelectHelperDidFailToFindMatchForSearchString:)])
        [[self delegate] outlineView:self typeSelectHelperDidFailToFindMatchForSearchString:searchString];
}

- (void)typeSelectHelperUpdateSearchString:(NSString *)searchString {
    if ([[self delegate] respondsToSelector:@selector(outlineView:typeSelectHelperUpdateSearchString:)])
        [[self delegate] outlineView:self typeSelectHelperUpdateSearchString:searchString];
}

- (void)setDelegate:(id <SKOutlineViewDelegate>)newDelegate {
    [self removeTrackingAreasIfNeeded];
    [super setDelegate:newDelegate];
    [self addTrackingAreasIfNeeded];
}

@end
