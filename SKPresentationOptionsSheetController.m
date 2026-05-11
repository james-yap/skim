//
//  SKPresentationOptionsSheetController.m
//  Skim
//
//  Created by Christiaan Hofman on 9/28/08.
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

#import "SKPresentationOptionsSheetController.h"
#import <Quartz/Quartz.h>
#import "SKMainWindowController.h"
#import "SKDocumentController.h"
#import "SKTransitionController.h"
#import "SKTransitionInfo.h"
#import "SKThumbnail.h"
#import "SKTableView.h"
#import "SKMainWindowController.h"
#import "SKImageToolTipWindow.h"
#import "NSWindowController_SKExtensions.h"
#import "NSDocument_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "SKPresentationView.h"
#import "SKAnimatedBorderlessWindow.h"

#define PAGE_COLUMNID @"page"
#define IMAGE_COLUMNID @"image"
#define TOIMAGE_COLUMNID @"toImage"

#define STYLE_KEY @"style"
#define DURATION_KEY @"duration"
#define SHOULDRESTRICT_KEY @"shouldRestrict"
#define PROPERTIES_KEY @"properties"
#define INFO_KEY @"info"
#define SEPARATE_KEY @"separate"

#define MAX_PAGE_COLUMN_WIDTH 100.0

#define TABLE_OFFSET 28.0
#define BOX_OFFSET 20.0

#define PREVIEW_INSET 6.0
#define PREVIEW_CORNER_RADIUS 6.0
#define PREVIEW_DELAY 1.0

static char *SKTransitionPropertiesObservationContext;

#define SKTouchBarItemIdentifierOK     @"net.sourceforge.skim-app.touchbar-item.OK"
#define SKTouchBarItemIdentifierCancel @"net.sourceforge.skim-app.touchbar-item.cancel"

@interface SKPlusOneTransformer : NSValueTransformer
@end

#pragma mark -

@interface SKPresentationOptionsSheetController ()

- (NSArray *)makeTransitions:(NSArray *)properties;

- (void)startObservingTransitions:(NSArray<SKLabeledTransitionInfo *> *)infos;
- (void)stopObservingTransitions:(NSArray<SKLabeledTransitionInfo *> *)infos;

@end

@implementation SKPresentationOptionsSheetController

@synthesize notesDocumentPopUpButton, tableView, stylePopUpButton, okButton, cancelButton, previewButton, tableWidthConstraint, boxLeadingConstraint, arrayController, separate, transitions;
@dynamic availableTransitions;

+ (void)initialize {
    SKINITIALIZE;
    [NSValueTransformer setValueTransformer:[[SKPlusOneTransformer alloc] init] forName:@"SKPlusOne"];
}

- (instancetype)initForController:(SKMainWindowController *)aController {
    self = [super initWithWindow:nil];
    if (self) {
        controller = aController;
        
        SKTransitionController *transitionController = [controller transitionControllerCreating:NO];
        
        if ([transitionController transition])
            transition = [[SKLabeledTransitionInfo alloc] initWithTransitionInfo:[transitionController transition]];
        else
            transition = [[SKLabeledTransitionInfo alloc] init];
        if ([transitionController pageTransitions]) {
            transitions = [self makeTransitions:[transitionController pageTransitions]];
            separate = YES;
        } else {
            transitions = @[transition];
            separate = NO;
        }
        
        [self startObservingTransitions:transitions];
    }
    return self;
}

- (void)dealloc {
    SKENSURE_MAIN_THREAD(
        [self stopObservingTransitions:transitions];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[self window] setDelegate:nil];
        [tableView setDelegate:nil];
        [tableView setDataSource:nil];
    );
}

- (NSString *)windowNibName {
    return @"TransitionSheet";
}

- (void)handleDocumentsDidChangeNotification:(NSNotification *)note {
    id currentDoc = [[notesDocumentPopUpButton selectedItem] representedObject];
    
    while ([notesDocumentPopUpButton numberOfItems] > 3)
        [notesDocumentPopUpButton removeItemAtIndex:[notesDocumentPopUpButton numberOfItems] - 1];
    
    NSDocument *document = [controller document];
    NSMutableArray *documents = [NSMutableArray array];
    NSUInteger pageCount = [[document pdfDocument] pageCount];
    for (NSDocument *doc in [[NSDocumentController sharedDocumentController] documents]) {
        if ([doc isPDFDocument] && doc != document && [[doc pdfDocument] pageCount] == pageCount)
            [documents addObject:doc];
    }
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
    [documents sortUsingDescriptors:@[sortDescriptor]];
    
    for (NSDocument *doc in documents) {
        [notesDocumentPopUpButton addItemWithTitle:[doc displayName]];
        [[notesDocumentPopUpButton lastItem] setRepresentedObject:doc];
    }
    
    NSInteger docIndex = [notesDocumentPopUpButton indexOfItemWithRepresentedObject:currentDoc];
    [notesDocumentPopUpButton selectItemAtIndex:docIndex == -1 ? 0 : docIndex];
}

- (NSArray *)makeTransitions:(NSArray *)properties {
    NSMutableArray *array = [NSMutableArray array];
    NSEnumerator *ptEnum = [properties objectEnumerator];
    SKThumbnail *tn = nil;
    SKLabeledTransitionInfo *info;
    
    for (SKThumbnail *next in [controller thumbnails]) {
        if (tn) {
            if (properties)
                info = [[SKLabeledTransitionInfo alloc] initWithProperties:[ptEnum nextObject]];
            else
                info = [[SKLabeledTransitionInfo alloc] initWithTransitionInfo:transition];
            [info setThumbnail:tn];
            [info setToThumbnail:next];
            [array addObject:info];
        }
        tn = next;
    }
    
    return array;
}

- (void)showHideTableView {
    NSScrollView *scrollView = [tableView enclosingScrollView];
    
    if (separate && [tableView tag] == 0) {
        // determine the table width by getting the largest page label
        NSTableColumn *tableColumn = [tableView tableColumnWithIdentifier:PAGE_COLUMNID];
        id cell = [[tableColumn dataCell] copy];
        CGFloat labelWidth = 0.0;
        
        [cell setFont:[[NSFontManager sharedFontManager] convertFont:[cell font] toHaveTrait:NSBoldFontMask]];
        
        for (SKLabeledTransitionInfo *info in transitions) {
            [cell setStringValue:[info label] ?: @""];
            labelWidth = fmax(labelWidth, [cell cellSize].width);
        }
        
        labelWidth = fmin(ceil(labelWidth), MAX_PAGE_COLUMN_WIDTH);
        [tableColumn setMinWidth:labelWidth];
        [tableColumn setMaxWidth:labelWidth];
        [tableColumn setWidth:labelWidth];
        
        CGFloat width = [[[tableView tableColumns] valueForKeyPath:@"@sum.width"] doubleValue] + NSWidth([scrollView frame]) - [scrollView contentSize].width + 3.0 * [tableView intercellSpacing].width;
        [tableWidthConstraint setConstant:width];
        
        // we use this to know we have set the widths
        [tableView setTag:1];
    }
    
    NSWindow *window = [self window];
    NSWindow *parent = [window sheetParent];
    CGFloat width = separate ? [tableWidthConstraint constant] + TABLE_OFFSET : BOX_OFFSET;
    
    if (parent && [NSView shouldShowSlideAnimation]) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [[boxLeadingConstraint animator] setConstant:width];
                [[scrollView animator] setHidden:separate == NO];
            }
            completionHandler:^{
                if (@available(macOS 11.0, *)) {} else {
                    NSRect frame = [window frame];
                    [window setFrameOrigin:NSMakePoint(NSMidX([parent frame]) - 0.5 * NSWidth(frame), NSMinY(frame))];
                }
            }];
    } else {
        [boxLeadingConstraint setConstant:width];
        [scrollView setHidden:separate == NO];
        if (@available(macOS 11.0, *)) {} else {
            if (parent) {
                NSRect frame = [window frame];
                [window setFrameOrigin:NSMakePoint(NSMidX([parent frame]) - 0.5 * NSWidth(frame), NSMinY(frame))];
            }
        }
    }
}

- (void)windowDidLoad {
    // hide and disable the "Multiple effects" placeholder item
    [[stylePopUpButton itemAtIndex:0] setHidden:YES];
    [[stylePopUpButton itemAtIndex:0] setEnabled:NO];
    
    [[notesDocumentPopUpButton itemAtIndex:1] setRepresentedObject:[controller document]];
    [[notesDocumentPopUpButton itemAtIndex:2] setRepresentedObject:[controller document]];

    if (@available(macOS 11.0, *))
        [tableView setStyle:NSTableViewStylePlain];
    
    [tableView registerForDraggedTypes:[SKTransitionInfo readableTypesForPasteboard:[NSPasteboard pasteboardWithName:NSPasteboardNameDrag]]];
    
    [tableView setTypeSelectHelper:[SKTypeSelectHelper typeSelectHelperWithMatchOption:SKFullStringMatch]];
    
    [tableView setImageToolTipLayout:SKTableImageToolTipByCell];
    
    [tableView setSupportsQuickLook:YES];

    [tableView setDoubleAction:@selector(preview:)];
    
    [self showHideTableView];
    
    // set the current notes document and observe changes for the popup
    [self handleDocumentsDidChangeNotification:nil];
    NSDocument *currentDoc = [controller presentationNotesDocument];
    NSInteger docIndex = [notesDocumentPopUpButton indexOfItemWithRepresentedObject:currentDoc];
    if (currentDoc == [controller document])
        docIndex = [controller presentationNotesOffset] > 0 ? 2 : 1;
    [notesDocumentPopUpButton selectItemAtIndex:docIndex > 0 ? docIndex : 0];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDocumentsDidChangeNotification:) 
                                                 name:SKDocumentDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDocumentsDidChangeNotification:)
                                                 name:SKDocumentControllerDidRemoveDocumentNotification object:nil];
}

- (void)dismissSheet:(id)sender {
    [[SKImageToolTipWindow sharedToolTipWindow] orderOut:nil];
    if ([sender tag] == NSModalResponseCancel) {
        [super dismissSheet:sender];
    } else if ([arrayController commitEditing]) {
        // don't make changes when nothing was changed
        if ([undoManager canUndo]) {
            SKTransitionController *transitionController = [controller transitionControllerCreating:separate || [transition style] != SKNoTransition];
            if (transitionController) {
                [transitionController setTransition:transition];
                if (separate && [transitions count])
                    [transitionController setPageTransitions:[transitions valueForKey:PROPERTIES_KEY]];
                else
                    [transitionController setPageTransitions:nil];
                [[[controller document] undoManager] setActionName:NSLocalizedString(@"Change Transitions", @"Undo action name")];
            }
        }
        NSMenuItem *notesDocumentItem = [notesDocumentPopUpButton selectedItem];
        [controller setPresentationNotesDocument:[notesDocumentItem representedObject]];
        [controller setPresentationNotesOffset:[notesDocumentItem tag]];
        [super dismissSheet:sender];
    }
}

- (void)preview:(id)sender {
    if (previewing)
        return;
    
    [arrayController commitEditing];
    
    SKLabeledTransitionInfo *info = transition;
    NSInteger idx = -1;
    if (separate) {
        if (sender == tableView)
            idx = [tableView clickedRow];
        if (idx == -1)
            idx = [tableView selectedRow];
        if (idx == -1)
            return;
        info = [transitions objectAtIndex:idx];
    } else {
        idx = 0;
    }
    if ([info style] == SKNoTransition)
        return;
    
    NSRect rect = [[[self window] screen] frame];
    rect.size.width = round(0.5 * NSWidth(rect)) + 2.0 * PREVIEW_INSET;
    rect.size.height = round(0.5 * NSHeight(rect)) + PREVIEW_INSET + 28.0;
    
    if (previewWindow == nil) {
        previewWindow = [[NSPanel alloc] initWithContentRect:rect styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskFullSizeContentView backing:NSBackingStoreBuffered defer:NO];
        [previewWindow setReleasedWhenClosed:NO];
        [previewWindow setTitlebarAppearsTransparent:YES];
        [previewWindow setHidesOnDeactivate:NO];
        [previewWindow setFloatingPanel:YES];
        [previewWindow setAnimationBehavior:NSWindowAnimationBehaviorDocumentWindow];
        
        NSView *contentView = [previewWindow contentView];
        
        NSVisualEffectView *veView = [[NSVisualEffectView alloc] init];
        [veView setMaterial:NSVisualEffectMaterialPopover];
        [veView setState:NSVisualEffectStateActive];
        [veView setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
        [veView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [contentView addSubviewWithConstraints:veView];
        
        NSView *bgView = [[NSView alloc] init];
        CALayer *layer = [CALayer layer];
        [layer setBackgroundColor:CGColorGetConstantColor(kCGColorBlack)];
        [layer setCornerRadius:PREVIEW_CORNER_RADIUS];
        [layer setContentsScale:[[self window] backingScaleFactor]];
        [bgView setLayer:layer];
        [bgView setWantsLayer:YES];
        [bgView setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawDuringViewResize];
        [bgView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [contentView addSubview:bgView];
        NSArray *constraints = @[
            [[bgView leadingAnchor] constraintEqualToAnchor:[contentView leadingAnchor] constant:PREVIEW_INSET],
            [[contentView trailingAnchor] constraintEqualToAnchor:[bgView trailingAnchor] constant:PREVIEW_INSET],
            [[bgView topAnchor] constraintEqualToAnchor:[[previewWindow contentLayoutGuide] topAnchor] constant:0.0],
            [[contentView bottomAnchor] constraintEqualToAnchor:[bgView bottomAnchor] constant:PREVIEW_INSET]];
        [[constraints objectAtIndex:2] setPriority:NSLayoutPriorityDefaultHigh];
        [NSLayoutConstraint activateConstraints:constraints];
        
        previewView = [[SKPDFPageView alloc] init];
        [previewView setTransitionController:[[SKTransitionController alloc] init]];
        [[previewView transitionController] setShouldScale:YES];
        [bgView addSubviewWithConstraints:previewView];
    }
    
    [[previewView transitionController] setTransition:info];
    
    [previewWindow setTitle:[info localizedStyleName]];
    rect.size.height += NSHeight([previewWindow frame]) - NSHeight([previewWindow contentLayoutRect]) - 28.0;
    [previewWindow setFrame:rect display:NO];
    [previewWindow center];
    [previewWindow layoutIfNeeded];
    
    previewing = YES;
    
    [previewView displayPage:[[controller pdfDocument] pageAtIndex:idx] completionHandler:^{
        [previewWindow makeKeyAndOrderFront:nil];
        DISPATCH_MAIN_AFTER_SEC(PREVIEW_DELAY, ^{
            [previewView animateToNextPage:^{
                DISPATCH_MAIN_AFTER_SEC(PREVIEW_DELAY, ^{
                    if ([previewWindow isKeyWindow] && [[self window] isVisible])
                        [[self window] makeKeyWindow];
                    [previewWindow orderOut:nil];
                    previewing = NO;
                });
            }];
        });
    }];
}

- (NSArray *)availableTransitions {
    static NSArray *availableTransitions = nil;
    if (availableTransitions == nil) {
        NSMutableArray *titles = [NSMutableArray arrayWithObject:NSLocalizedString(@"Multiple effects", @"Menu item title")];
        [titles addObjectsFromArray:[SKTransitionInfo localizedStyleNames]];
        availableTransitions = [titles copy];
    }
    return availableTransitions;
}

- (void)setSeparate:(BOOL)newSeparate {
    if (separate != newSeparate) {
        separate = newSeparate;
        
        [[SKImageToolTipWindow sharedToolTipWindow] orderOut:nil];
        
        [arrayController commitEditing];
        
        // undo or redo will include updateTransitions: in the same group
        if ([[self undoManager] isUndoing] == NO && [[self undoManager] isRedoing] == NO)
            [self setTransitions:separate ? [self makeTransitions:nil] : @[transition]];
        
        [self showHideTableView];
        
        [[[self undoManager] prepareWithInvocationTarget:self] setSeparate:separate == NO];
    }
}

- (void)setTransitions:(NSArray *)newTransitions {
    if (transitions != newTransitions) {
        [[[self undoManager] prepareWithInvocationTarget:self] setTransitions:transitions];
        [self stopObservingTransitions:transitions];
        transitions = [newTransitions copy];
        [self startObservingTransitions:transitions];
    }
}

#pragma mark Undo

- (void)observeUndoManagerCheckpoint:(NSNotification *)notification {
    changedTransitions = nil;
}

- (NSUndoManager *)undoManager {
    if (undoManager == nil) {
        undoManager = [[NSUndoManager alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeUndoManagerCheckpoint:) name:NSUndoManagerCheckpointNotification object:undoManager];
    }
    return undoManager;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return [self undoManager];
}

- (void)startObservingTransitions:(NSArray *)infos {
    for (SKLabeledTransitionInfo *info in infos) {
        [info addObserver:self forKeyPath:STYLE_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&SKTransitionPropertiesObservationContext];
        [info addObserver:self forKeyPath:DURATION_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&SKTransitionPropertiesObservationContext];
        [info addObserver:self forKeyPath:SHOULDRESTRICT_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&SKTransitionPropertiesObservationContext];
    }
}

- (void)stopObservingTransitions:(NSArray *)infos {
    for (SKLabeledTransitionInfo *info in infos) {
        [info removeObserver:self forKeyPath:STYLE_KEY context:&SKTransitionPropertiesObservationContext];
        [info removeObserver:self forKeyPath:DURATION_KEY context:&SKTransitionPropertiesObservationContext];
        [info removeObserver:self forKeyPath:SHOULDRESTRICT_KEY context:&SKTransitionPropertiesObservationContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKTransitionPropertiesObservationContext) {
        id newValue = [change objectForKey:NSKeyValueChangeNewKey];
        id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
        
        if ([newValue isEqual:[NSNull null]]) newValue = nil;
        if ([oldValue isEqual:[NSNull null]]) oldValue = nil;
        
        if (newValue == oldValue || [newValue isEqual:oldValue])
            return;
            
        if ([keyPath isEqualToString:DURATION_KEY]) {
            if ([changedTransitions containsObject:object])
                return;
            if (changedTransitions == nil)
                changedTransitions = [[NSMutableSet alloc] init];
            [changedTransitions addObject:object];
        }
        
        [[[self undoManager] prepareWithInvocationTarget:object] setValue:oldValue forKey:keyPath];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark NSTableView dataSource and delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv { return 0; }

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row { return nil; }

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tv pasteboardWriterForRow:(NSInteger)row {
    if ([[tv selectedRowIndexes] count] > 1 && [[tv selectedRowIndexes] containsIndex:row])
        return nil;
    return [transitions objectAtIndex:row];
}

- (void)tableView:(NSTableView *)tv draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes {
    if ([rowIndexes count] != 1)
        return;
    
    NSTableRowView *view = [tv rowViewAtRow:[rowIndexes firstIndex] makeIfNecessary:NO];
    if (view) {
        NSRect frame = [[self window] convertRectToScreen:[view convertRect:[view bounds] toView:nil]];
        frame.origin.x -= screenPoint.x - [session draggingLocation].x;
        frame.origin.y -= screenPoint.y - [session draggingLocation].y;
        [session enumerateDraggingItemsWithOptions:0 forView:nil classes:@[[SKTransitionInfo class]] searchOptions:@{} usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop){
            [draggingItem setImageComponentsProvider:^{
                NSMutableArray *components = [NSMutableArray array];
                NSUInteger i, iMax = [view numberOfColumns];
                for (i = 0; i < iMax; i++) {
                    NSTableCellView *cellView = [view viewAtColumn:i];
                    NSDraggingImageComponent *component = [[cellView draggingImageComponents] firstObject];
                    NSRect rect = [component frame];
                    NSPoint offset = [cellView frame].origin;
                    rect.origin.x += offset.x;
                    rect.origin.y += offset.y;
                    [component setFrame:rect];
                    if (i == 1)
                        [component setKey:@"toIcon"];
                    [components addObject:component];
                }
                return components;
            }];
            [draggingItem setDraggingFrame:frame];
        }];
    }
}

- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
    if ([[info draggingPasteboard] canReadObjectForClasses:@[[SKTransitionInfo class]] options:@{}]) {
        if (operation == NSTableViewDropAbove)
            [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
        return NSDragOperationEvery;
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id < NSDraggingInfo >)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
    NSPasteboard *pboard = [info draggingPasteboard];
    if (operation == NSTableViewDropOn) {
        NSArray *infos = [pboard readObjectsForClasses:@[[SKTransitionInfo class]] options:@{}];
        if ([infos count] > 0) {
            if (row == -1)
                [transitions setValue:[infos firstObject] forKey:INFO_KEY];
            else
                [[transitions objectAtIndex:row] setInfo:[infos firstObject]];
            return YES;
        }
    }
    return NO;
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return [tv makeViewWithIdentifier:[tableColumn identifier] owner:self];
}

- (id <SKImageToolTipContext>)tableView:(NSTableView *)tv imageContextForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row  scale:(CGFloat *)scale {
    if ([[tableColumn identifier] isEqualToString:IMAGE_COLUMNID])
        return [[controller pdfDocument] pageAtIndex:row];
    else if ([[tableColumn identifier] isEqualToString:TOIMAGE_COLUMNID])
        return [[controller pdfDocument] pageAtIndex:row + 1];
    else
        return nil;
}

- (void)tableView:(NSTableView *)tv copyRowsWithIndexes:(NSIndexSet *)rowIndexes {
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    [pboard clearContents];
    [pboard writeObjects:@[[transitions objectAtIndex:[rowIndexes firstIndex]]]];
}

- (BOOL)tableView:(NSTableView *)tv canCopyRowsWithIndexes:(NSIndexSet *)rowIndexes {
    return [rowIndexes count] == 1;
}

- (void)tableView:(NSTableView *)tv pasteFromPasteboard:(NSPasteboard *)pboard {
    NSArray *infos = [pboard readObjectsForClasses:@[[SKTransitionInfo class]] options:@{}];
    if ([infos count] > 0)
        [[transitions objectsAtIndexes:[tableView selectedRowIndexes]] setValue:[infos objectAtIndex:0] forKey:INFO_KEY];
}

- (BOOL)tableView:(NSTableView *)tv canPasteFromPasteboard:(NSPasteboard *)pboard {
    return ([tableView selectedRow] != -1 && [pboard canReadObjectForClasses:@[[SKTransitionInfo class]] options:@{}]);
}

- (void)tableView:(NSTableView *)tv deleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
    NSArray *selTransitions = [transitions objectsAtIndexes:rowIndexes];
    SKTransitionInfo *empty = [[SKTransitionInfo alloc] init];
    [selTransitions setValue:empty forKey:INFO_KEY];
}

- (void)tableViewQuickLookPreviewItems:(NSTableView *)tv {
    [self preview:tv];
}

- (NSArray *)tableViewTypeSelectHelperSelectionStrings:(NSTableView *)tv {
    return [transitions valueForKeyPath:@"thumbnail.label"];
}

#pragma mark Touch Bar

- (NSTouchBar *)makeTouchBar {
    NSTouchBar *touchBar = [[NSTouchBar alloc] init];
    [touchBar setDelegate:self];
    [touchBar setDefaultItemIdentifiers:@[NSTouchBarItemIdentifierFlexibleSpace, SKTouchBarItemIdentifierCancel, SKTouchBarItemIdentifierOK, NSTouchBarItemIdentifierFixedSpaceLarge]];
    return touchBar;
}

- (NSTouchBarItem *)touchBar:(NSTouchBar *)aTouchBar makeItemForIdentifier:(NSString *)identifier {
    NSCustomTouchBarItem *item = nil;
    if ([identifier isEqualToString:SKTouchBarItemIdentifierOK]) {
        NSButton *button = [NSButton buttonWithTitle:[okButton title] target:[okButton target] action:[okButton action]];
        [button setTag:NSModalResponseOK];
        [button setKeyEquivalent:@"\r"];
        item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        [(NSCustomTouchBarItem *)item setView:button];
    } else if ([identifier isEqualToString:SKTouchBarItemIdentifierCancel]) {
        NSButton *button = [NSButton buttonWithTitle:[cancelButton title] target:[cancelButton target] action:[cancelButton action]];
        [button setTag:NSModalResponseCancel];
        item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        [(NSCustomTouchBarItem *)item setView:button];
    }
    return item;
}

@end

#pragma mark -

@implementation SKPlusOneTransformer

+ (Class)transformedValueClass {
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    return [NSNumber numberWithInteger:[value integerValue] + 1];
}

- (id)reverseTransformedValue:(id)value {
    return [NSNumber numberWithInteger:[value integerValue] - 1];
}

@end
