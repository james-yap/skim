//
//  SKColorSwatch.m
//  Skim
//
//  Created by Christiaan Hofman on 7/4/07.
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

#import "SKColorSwatch.h"
#import "NSColor_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSShadow_SKExtensions.h"
#import "NSObject_SKExtensions.h"

NSBindingName const SKColorsBinding = @"colors";

NSString *SKColorSwatchOrWellWillActivateNotification = @"SKColorSwatchOrWellWillActivateNotification";

#define AUTORESIZES_KEY @"autoResizes"
#define SELECTS_KEY     @"selects"
#define BEZELHEIGHT_KEY @"bezelHeight"

#define COLOR_KEY                 @"color"
#define SELECTEDCOLORINDEX_KEY    @"selectedColorIndex"

#define BEZEL_INSET_LEFT    1.0
#define BEZEL_INSET_RIGHT   1.0
#define BEZEL_INSET_TOP     1.0
#define BEZEL_INSET_BOTTOM  2.0
#define COLOR_INSET         2.0

static inline CGFloat cornerRadius(NSControlSize controlSize) {
    if (@available(macOS 11.0, *)) {
        switch (controlSize) {
            case NSControlSizeRegular:  return 3.0;
            case NSControlSizeSmall:    return 2.0;
            case NSControlSizeMini:     return 1.0;
            case NSControlSizeLarge:    return 4.0;
            default:                    return 5.0;
        }
    } else {
        return controlSize == NSControlSizeRegular ? 2.0 : 1.0;
    }
}

@interface SKColorSwatchBackgroundView : NSSegmentedControl
@end
 
typedef NS_ENUM(NSUInteger, SKColorSwatchDropLocation) {
    SKColorSwatchNoDrop,
    SKColorSwatchDropOn,
    SKColorSwatchDropBefore,
    SKColorSwatchDropAfter
};

@interface SKColorSwatchItemView : NSView <NSAccessibilityElement> {
    NSColor *color;
    BOOL highlighted;
    BOOL selected;
    SKColorSwatchDropLocation dropLocation;
}
@property (nonatomic, strong) NSColor *color;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, getter=isSelected) BOOL selected;
@property (nonatomic) SKColorSwatchDropLocation dropLocation;

@end

#pragma mark -

@interface SKColorSwatch (SKAccessibilityColorSwatchElementParent)
- (BOOL)isItemViewFocused:(SKColorSwatchItemView *)itemView;
- (void)itemView:(SKColorSwatchItemView *)itemView setFocused:(BOOL)focused;
- (void)pressItemView:(SKColorSwatchItemView *)itemView alternate:(BOOL)alternate;
@end

@interface SKColorSwatch ()
@property (nonatomic, readonly) CGFloat contentWidth;
@property (nonatomic) CGFloat bezelWidth;
- (NSRect)frameForItemViewAtIndex:(NSInteger)anIndex;
- (void)_setColor:(NSColor *)color atIndex:(NSInteger)i;
@end

@implementation SKColorSwatch

@synthesize autoResizes, selects, alternate, clickedColorIndex=clickedIndex, selectedColorIndex=selectedIndex, bezelWidth;
@dynamic colors, color, contentWidth;

+ (id)defaultAnimationForKey:(NSString *)key {
    if ([key isEqualToString:@"bezelWidth"]) {
        CABasicAnimation *anim = [CABasicAnimation animation];
        [anim setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
        return anim;
    } else
        return [super defaultAnimationForKey:key];
}

- (Class)valueClassForBinding:(NSBindingName)binding {
    if ([binding isEqualToString:SKColorsBinding])
        return [NSArray class];
    else
        return [super valueClassForBinding:binding];
}

- (void)commonInit {
    focusedIndex = 0;
    clickedIndex = -1;
    selectedIndex = -1;
    draggedIndex = -1;
    
    bezelWidth = [self contentWidth];
    
    [self registerForDraggedTypes:[NSColor readableTypesForPasteboard:[NSPasteboard pasteboardWithName:NSPasteboardNameDrag]]];
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        if (@available(macOS 11.0, *))
            autoResizes = NO;
        else
            autoResizes = YES;
        selects = NO;
        bezelHeight = 22.0;
        
        backgroundView = [[SKColorSwatchBackgroundView alloc] initWithFrame:[self bounds]];
        [backgroundView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self addSubview:backgroundView];
        NSArray *constraints = @[
            [[backgroundView leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[self trailingAnchor] constraintEqualToAnchor:[backgroundView trailingAnchor]],
            [[backgroundView topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[self bottomAnchor] constraintEqualToAnchor:[backgroundView bottomAnchor]]];
        [constraints setValue:@YES forKey:@"shouldBeArchived"];
        [NSLayoutConstraint activateConstraints:constraints];
        
        SKColorSwatchItemView *itemView = [[SKColorSwatchItemView alloc] initWithFrame:[self frameForItemViewAtIndex:0]];
        [itemView setAutoresizingMask:NSViewNotSizable];
        [itemView setColor:[NSColor whiteColor]];
        [self addSubview:itemView];
        itemViews = [[NSMutableArray alloc] initWithObjects:itemView, nil];

        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        autoResizes = [decoder decodeBoolForKey:AUTORESIZES_KEY];
        selects = [decoder decodeBoolForKey:SELECTS_KEY];
        bezelHeight = [decoder decodeDoubleForKey:BEZELHEIGHT_KEY];

        itemViews = [[NSMutableArray alloc] init];
        for (NSView *view in [self subviews]) {
            if ([view isKindOfClass:[SKColorSwatchBackgroundView class]])
                backgroundView = (SKColorSwatchBackgroundView *)view;
            else if ([view isKindOfClass:[SKColorSwatchItemView class]])
                [itemViews addObject:(SKColorSwatchItemView *)view];
        }

        [self commonInit];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeBool:autoResizes forKey:AUTORESIZES_KEY];
    [coder encodeBool:selects forKey:SELECTS_KEY];
    [coder encodeDouble:bezelHeight forKey:BEZELHEIGHT_KEY];
}

- (void)dealloc {
    if ([self infoForBinding:SKColorsBinding])
        SKENSURE_MAIN_THREAD( [self unbind:SKColorsBinding]; );
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent { return YES; }

- (BOOL)acceptsFirstResponder { return YES; }

#pragma mark Layout

#define DISTANCE_BETWEEN_COLORS (bezelHeight - COLOR_INSET)

- (NSRect)frameForColorAtIndex:(NSInteger)anIndex {
    NSEdgeInsets insets = [self alignmentRectInsets];
    NSRect rect = NSMakeRect(insets.left, insets.bottom, bezelHeight, bezelHeight);
    rect = NSInsetRect(rect, COLOR_INSET, COLOR_INSET);
    if (anIndex > 0)
        rect.origin.x += anIndex * DISTANCE_BETWEEN_COLORS;
    return rect;
}

- (NSRect)frameForItemViewAtIndex:(NSInteger)anIndex {
    return NSInsetRect([self frameForColorAtIndex:anIndex], -COLOR_INSET, -COLOR_INSET);
}

- (NSRect)frameForCollapsedItemViewAtIndex:(NSInteger)anIndex {
    return SKShrinkRect([self frameForItemViewAtIndex:anIndex], DISTANCE_BETWEEN_COLORS, NSRectEdgeMaxX);
}

- (NSInteger)colorIndexAtPoint:(NSPoint)point {
    NSRect rect = [self frameForColorAtIndex:0];
    NSInteger i, count = [itemViews count];
    
    for (i = 0; i < count; i++) {
        if (NSMouseInRect(point, rect, [self isFlipped]))
            return i;
        rect.origin.x += DISTANCE_BETWEEN_COLORS;
    }
    return -1;
}

- (NSInteger)insertionIndexAtPoint:(NSPoint)point {
    NSRect rect = [self frameForColorAtIndex:0];
    CGFloat x = NSMidX(rect);
    NSInteger i, count = [itemViews count];
    
    for (i = 0; i < count; i++) {
        if (point.x < x)
            return i;
        x += DISTANCE_BETWEEN_COLORS;
    }
    return count;
}

- (CGFloat)contentWidth {
    return COLOR_INSET + [itemViews count] * DISTANCE_BETWEEN_COLORS;
}

- (void)setBezelWidth:(CGFloat)width {
    bezelWidth = width;
    [self invalidateIntrinsicContentSize];
}

- (NSSize)intrinsicContentSize {
    return NSMakeSize(bezelWidth, bezelHeight);
}

- (NSSize)intrinsicFrameSize {
    NSEdgeInsets insets = [self alignmentRectInsets];
    return NSMakeSize([self contentWidth] + insets.left + insets.right, bezelHeight + insets.bottom + insets.top);
}

- (void)sizeToFit {
    [self setFrameSize:[self intrinsicFrameSize]];
}

- (NSEdgeInsets)alignmentRectInsets {
    return NSEdgeInsetsMake(BEZEL_INSET_TOP, BEZEL_INSET_LEFT, BEZEL_INSET_BOTTOM, BEZEL_INSET_RIGHT);
}

- (void)updateItemViewFramesAnimating:(BOOL)animate {
    [itemViews enumerateObjectsUsingBlock:^(SKColorSwatchItemView *itemView, NSUInteger i, BOOL *stop){
        NSRect rect = [self frameForItemViewAtIndex:i];
        if (NSEqualRects(rect, [itemView frame]) == NO)
            [animate ? [itemView animator] : itemView setFrame:rect];
    }];
}

- (void)updateBezelHeight {
    CGFloat height = [backgroundView intrinsicContentSize].height;
    if (fabs(height - bezelHeight) > 0.0) {
        bezelHeight = height;
        [self setBezelWidth:[self contentWidth]];
        [self updateItemViewFramesAnimating:NO];
        if (autoResizes)
            [self sizeToFit];
    }
}

- (void)setControlSize:(NSControlSize)controlSize {
    [super setControlSize:controlSize];
    if (controlSize != [backgroundView controlSize]) {
        [backgroundView setControlSize:controlSize];
        [self updateBezelHeight];
    }
}

#pragma mark Drawing

- (NSRect)focusRingMaskBounds {
    if (focusedIndex == -1)
        return NSZeroRect;
    return [self frameForColorAtIndex:focusedIndex];
}

- (void)drawFocusRingMask {
    NSRect rect = [self focusRingMaskBounds];
    if (NSIsEmptyRect(rect) == NO) {
        CGFloat r = cornerRadius([self controlSize]);
        [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:r yRadius:r] fill];
    }
}

#pragma mark Notification handling

- (void)deactivate:(NSNotification *)note {
    [self deactivate];
}

- (void)handleColorPanelColorChanged:(NSNotification *)note {
    if (selectedIndex != -1) {
        NSColor *color = [[NSColorPanel sharedColorPanel] color];
        [self _setColor:color atIndex:selectedIndex];
    }
}

- (void)handleKeyOrMainStateChanged:(NSNotification *)note {
    if ([[note name] isEqualToString:NSWindowDidResignMainNotification])
        [self deactivate];
    [[self subviews] setValue:@YES forKey:@"needsDisplay"];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    NSWindow *oldWindow = [self window];
    NSArray *names = @[NSWindowDidBecomeMainNotification, NSWindowDidResignMainNotification, NSWindowDidBecomeKeyNotification, NSWindowDidResignKeyNotification];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    if (oldWindow) {
        for (NSString *name in names)
            [nc removeObserver:self name:name object:oldWindow];
    }
    if (newWindow) {
        for (NSString *name in names)
            [nc addObserver:self selector:@selector(handleKeyOrMainStateChanged:) name:name object:newWindow];
    }
    [self deactivate];
    [super viewWillMoveToWindow:newWindow];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if ([self window])
        [self updateBezelHeight];
}

#pragma mark Event handling and actions

- (void)mouseDown:(NSEvent *)theEvent {
    NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSInteger i = [self colorIndexAtPoint:mouseLoc];
    
    if (i != -1) {
        if ([self isEnabled])
            [[itemViews objectAtIndex:i] setHighlighted:YES];
        
        NSEvent *downEvent = theEvent;
        BOOL keepOn = YES;
        while (keepOn) {
            theEvent = [[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged];
            switch ([theEvent type]) {
                case NSEventTypeLeftMouseDragged:
                {
                    if ([self isEnabled])
                        [[itemViews objectAtIndex:i] setHighlighted:NO];
                    
                    draggedIndex = i;
                    
                    NSColor *color = [[itemViews objectAtIndex:i] color];
                    
                    CGFloat r = cornerRadius(NSControlSizeRegular) - 0.5;
                    
                    NSImage *image = [NSImage bitmapImageWithSize:NSMakeSize(12.0, 12.0) forView:self drawingHandler:^(NSRect rect){
                        [color drawSwatchInRect:NSInsetRect(rect, 1.0, 1.0)];
                        [[NSColor blackColor] set];
                        [NSBezierPath setDefaultLineWidth:1.0];
                        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 0.5, 0.5) xRadius:r yRadius:r] stroke];
                    }];
                    
                    NSRect rect = SKRectFromCenterAndSquareSize([self convertPoint:[theEvent locationInWindow] fromView:nil], 12.0);
                    
                    NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:color];
                    [dragItem setDraggingFrame:rect contents:image];
                    [self beginDraggingSessionWithItems:@[dragItem] event:downEvent source:self];
                    
                    keepOn = NO;
                    break;
                }
                case NSEventTypeLeftMouseUp:
                    if ([self isEnabled]) {
                        if ([self selects]) {
                            if (selectedIndex != -1 && selectedIndex == i)
                                [self deactivate];
                            else
                                [self selectColorAtIndex:i];
                        }
                        clickedIndex = i;
                        [self sendAction:[self action] to:[self target]];
                        [[itemViews objectAtIndex:i] setHighlighted:NO];
                        clickedIndex = -1;
                    }
                    keepOn = NO;
                    break;
                default:
                    break;
            }
        }
    }
}

- (void)performClickAtIndex:(NSInteger)i {
    if ([self isEnabled] && i != -1) {
        clickedIndex = i;
        [[itemViews objectAtIndex:i] setHighlighted:YES];
        if ([self selects]) {
            if (selectedIndex != -1 && selectedIndex == i)
                [self deactivate];
            else
                [self selectColorAtIndex:i];
        }
        [self sendAction:[self action] to:[self target]];
        DISPATCH_MAIN_AFTER_SEC(0.2, ^{
            [[itemViews objectAtIndex:i] setHighlighted:NO];
            clickedIndex = -1;
        });
    }
}

- (void)performClick:(id)sender {
    [self performClickAtIndex:focusedIndex];
}

- (void)moveRight:(id)sender {
    if (++focusedIndex >= (NSInteger)[itemViews count])
        focusedIndex = 0;
    [self noteFocusRingMaskChanged];
    NSAccessibilityPostNotification(self, NSAccessibilityFocusedUIElementChangedNotification);
}

- (void)moveLeft:(id)sender {
    if (--focusedIndex < 0)
        focusedIndex = (NSInteger)[itemViews count] - 1;
    [self noteFocusRingMaskChanged];
    NSAccessibilityPostNotification(self, NSAccessibilityFocusedUIElementChangedNotification);
}

#pragma mark Accessors

- (NSArray *)colors {
    return [itemViews valueForKey:COLOR_KEY];
}

- (void)setColors:(NSArray *)newColors {
    NSUInteger count = [newColors count], oldCount = [itemViews count];
    if (selectedIndex != -1 && (selectedIndex >= (NSInteger)count || [[newColors objectAtIndex:selectedIndex] isEqual:[[itemViews objectAtIndex:selectedIndex] color]] == NO))
        [self deactivate];
    [newColors enumerateObjectsUsingBlock:^(NSColor *color, NSUInteger i, BOOL *stop){
        SKColorSwatchItemView *itemView;
        if (i < oldCount) {
            itemView = [itemViews objectAtIndex:i];
        } else {
            itemView = [[SKColorSwatchItemView alloc] initWithFrame:[self frameForItemViewAtIndex:i]];
            [itemView setAutoresizingMask:NSViewNotSizable];
            [self addSubview:itemView];
            [itemViews addObject:itemView];
        }
        [itemView setColor:color];
    }];
    while ([itemViews count] > count) {
        [[itemViews objectAtIndex:count] removeFromSuperview];
        [itemViews removeObjectAtIndex:count];
    }
    if (count != oldCount) {
        if (autoResizes)
            [self sizeToFit];
        [self setBezelWidth:[self contentWidth]];
    }
    if (focusedIndex >= (NSInteger)count)
        focusedIndex = count - 1;
}

- (NSColor *)color {
    return clickedIndex == -1 ? nil : [[itemViews objectAtIndex:clickedIndex] color];
}

- (void)setEnabled:(BOOL)enabled {
    if (enabled == NO)
        [self deactivate];
    [super setEnabled:enabled];
}

#pragma mark Modification

#define VALID_INDEX(i, op) (i >= 0 && i op (NSInteger)[itemViews count])

- (void)selectColorAtIndex:(NSInteger)idx {
    if (idx == -1) {
        [self deactivate];
    } else if ([self selects] && VALID_INDEX(idx, <) && idx != selectedIndex && [self isEnabled] && [[self window] isMainWindow]) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
        if (selectedIndex != -1) {
            [nc removeObserver:self name:NSColorPanelColorDidChangeNotification object:colorPanel];
        } else {
            [nc postNotificationName:SKColorSwatchOrWellWillActivateNotification object:self];
            [nc addObserver:self selector:@selector(deactivate:) name:SKColorSwatchOrWellWillActivateNotification object:nil];
            [nc addObserver:self selector:@selector(deactivate:) name:NSWindowWillCloseNotification object:colorPanel];
        }
        [[[NSApp mainWindow] contentView] deactivateColorWellSubcontrols];
        [[[NSApp keyWindow] contentView] deactivateColorWellSubcontrols];
        if (selectedIndex != -1)
            [[itemViews objectAtIndex:selectedIndex] setSelected:NO];
        [self willChangeValueForKey:SELECTEDCOLORINDEX_KEY];
        selectedIndex = idx;
        [self didChangeValueForKey:SELECTEDCOLORINDEX_KEY];
        [[itemViews objectAtIndex:selectedIndex] setSelected:YES];
        [colorPanel setColor:[[itemViews objectAtIndex:selectedIndex] color]];
        [colorPanel orderFront:nil];
        [nc addObserver:self selector:@selector(handleColorPanelColorChanged:) name:NSColorPanelColorDidChangeNotification object:colorPanel];
    }
}

- (void)deactivate {
    if (selectedIndex != -1) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:NSColorPanelColorDidChangeNotification object:[NSColorPanel sharedColorPanel]];
        [nc removeObserver:self name:SKColorSwatchOrWellWillActivateNotification object:nil];
        [[itemViews objectAtIndex:selectedIndex] setSelected:NO];
        [self willChangeValueForKey:SELECTEDCOLORINDEX_KEY];
        selectedIndex = -1;
        [self didChangeValueForKey:SELECTEDCOLORINDEX_KEY];
    }
}

- (void)setSelects:(BOOL)flag {
    if (flag != selects) {
        if (flag == NO)
            [self deactivate];
        selects = flag;
    }
}

- (void)willChangeColors {
    [self willChangeValueForKey:SKColorsBinding];
}

- (void)didChangeColors {
    [self didChangeValueForKey:SKColorsBinding];
    [self propagateValue:[self colors] forBinding:SKColorsBinding];
}

- (void)_setColor:(NSColor *)color atIndex:(NSInteger)i {
    if (VALID_INDEX(i, <)) {
        [self willChangeColors];
        SKColorSwatchItemView *itemView = [itemViews objectAtIndex:i];
        [itemView setColor:color];
        NSAccessibilityPostNotification(itemView, NSAccessibilityValueChangedNotification);
        [self didChangeColors];
    }
}

- (void)setColor:(NSColor *)color atIndex:(NSInteger)i {
    [self _setColor:color atIndex:i];
    if (VALID_INDEX(i, <) && selectedIndex == i) {
        NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:NSColorPanelColorDidChangeNotification object:colorPanel];
        [colorPanel setColor:color];
        [nc addObserver:self selector:@selector(handleColorPanelColorChanged:) name:NSColorPanelColorDidChangeNotification object:colorPanel];
    }
}

- (void)insertColor:(NSColor *)color atIndex:(NSInteger)i {
    if (VALID_INDEX(i, <=)) {
        [self willChangeColors];
        bezelWidth = [self contentWidth];
        SKColorSwatchItemView *itemView = [[SKColorSwatchItemView alloc] initWithFrame:[self frameForCollapsedItemViewAtIndex:i]];
        [itemView setAutoresizingMask:NSViewNotSizable];
        [itemView setColor:color];
        if (i < (NSInteger)[itemViews count])
            [self addSubview:itemView positioned:NSWindowBelow relativeTo:[itemViews objectAtIndex:i]];
        else
            [self addSubview:itemView positioned:NSWindowAbove relativeTo:nil];
        [itemViews insertObject:itemView atIndex:i];
        if (selectedIndex >= i) {
            [self willChangeValueForKey:SELECTEDCOLORINDEX_KEY];
            selectedIndex++;
            [self didChangeValueForKey:SELECTEDCOLORINDEX_KEY];
        }
        if (focusedIndex >= i) {
            focusedIndex++;
            [self noteFocusRingMaskChanged];
        }
        [self didChangeColors];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [self updateItemViewFramesAnimating:YES];
                [[self animator] setBezelWidth:[self contentWidth]];
                if (autoResizes)
                    [[self animator] setFrameSize:[self intrinsicFrameSize]];
            }];
    }
}

- (void)removeColorAtIndex:(NSInteger)i {
    if (VALID_INDEX(i, <) && [itemViews count] > 1) {
        if (selectedIndex == i)
            [self deactivate];
        [self willChangeColors];
        bezelWidth = [self contentWidth];
        SKColorSwatchItemView *itemView = [itemViews objectAtIndex:i];
        [itemViews removeObjectAtIndex:i];
        if (selectedIndex > i) {
            [self willChangeValueForKey:SELECTEDCOLORINDEX_KEY];
            selectedIndex--;
            [self didChangeValueForKey:SELECTEDCOLORINDEX_KEY];
        }
        if (focusedIndex > i || focusedIndex == (NSInteger)[itemViews count]) {
            focusedIndex--;
            [self noteFocusRingMaskChanged];
        }
        [self didChangeColors];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [[itemView animator] setFrame:[self frameForCollapsedItemViewAtIndex:i]];
                [self updateItemViewFramesAnimating:YES];
                [[self animator] setBezelWidth:[self contentWidth]];
                if (autoResizes)
                    [[self animator] setFrameSize:[self intrinsicFrameSize]];
            }
            completionHandler:^{
                [itemView removeFromSuperview];
            }];
    }
}

- (void)moveColorAtIndex:(NSInteger)from toIndex:(NSInteger)to {
    if (VALID_INDEX(from, <) && VALID_INDEX(to, <) && from != to) {
        [self willChangeColors];
        SKColorSwatchItemView *itemView = [itemViews objectAtIndex:from];
        [itemViews removeObjectAtIndex:from];
        [itemViews insertObject:itemView atIndex:to];
        if (to > from)
            [self addSubview:itemView positioned:NSWindowAbove relativeTo:[itemViews objectAtIndex:to - 1]];
        if (selectedIndex >= MIN(from, to) && selectedIndex <= MAX(from, to)) {
            [self willChangeValueForKey:SELECTEDCOLORINDEX_KEY];
            if (selectedIndex == from)
                selectedIndex = to;
            else if (selectedIndex > from)
                selectedIndex--;
            else
                selectedIndex++;
            [self didChangeValueForKey:SELECTEDCOLORINDEX_KEY];
        }
        if (focusedIndex >= MIN(from, to) && focusedIndex <= MAX(from, to)) {
            if (focusedIndex == from)
                focusedIndex = to;
            else if (focusedIndex > from && focusedIndex <= to)
                focusedIndex--;
            else if (focusedIndex < from && focusedIndex >= to)
                focusedIndex++;
            [self noteFocusRingMaskChanged];
        }
        [self didChangeColors];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [self updateItemViewFramesAnimating:YES];
            }
            completionHandler:^{
                if (to < from)
                    [self addSubview:itemView positioned:NSWindowBelow relativeTo:[itemViews objectAtIndex:to + 1]];
            }];
    }
}

#pragma mark NSDraggingSource protocol 

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    return context == NSDraggingContextWithinApplication ? NSDragOperationGeneric : [itemViews count] > 1 ? NSDragOperationDelete : NSDragOperationNone;
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
    if ((operation & NSDragOperationDelete) != 0 && operation != NSDragOperationEvery && draggedIndex != -1 && [self isEnabled])
        [self removeColorAtIndex:draggedIndex];
    draggedIndex = -1;
}

#pragma mark NSDraggingDestination protocol 

- (void)setDropLocation:(SKColorSwatchDropLocation)dropLocation atIndex:(NSInteger)anIndex {
    [itemViews enumerateObjectsUsingBlock:^(SKColorSwatchItemView *itemView,  NSUInteger i, BOOL *stop){
        SKColorSwatchDropLocation location = SKColorSwatchNoDrop;
        if ((NSInteger)i == anIndex)
            location = dropLocation;
        else if (dropLocation == SKColorSwatchDropBefore && (NSInteger)i + 1 == anIndex)
            location = SKColorSwatchDropAfter;
        [[itemViews objectAtIndex:i] setDropLocation:location];
    }];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    return [self draggingUpdated:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    NSPoint mouseLoc = [self convertPoint:[sender draggingLocation] fromView:nil];
    BOOL isCopy = ([NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagOption;
    BOOL isMove = [sender draggingSource] == self && isCopy == NO;
    NSInteger i = isCopy || isMove ? [self insertionIndexAtPoint:mouseLoc] : [self colorIndexAtPoint:mouseLoc];
    NSDragOperation dragOp = isCopy ? NSDragOperationCopy : NSDragOperationGeneric;
    if ([self isEnabled] == NO || i == -1 ||
        (isMove && (i == draggedIndex || i == draggedIndex + 1))) {
        [self setDropLocation:SKColorSwatchNoDrop atIndex:-1];
        dragOp = NSDragOperationNone;
    } else {
        [self setDropLocation:(isCopy || isMove) ? SKColorSwatchDropBefore : SKColorSwatchDropOn atIndex:i];
    }
    return dragOp;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    [self setDropLocation:SKColorSwatchNoDrop atIndex:-1];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSColor *color = [NSColor colorFromPasteboard:pboard];
    NSPoint mouseLoc = [self convertPoint:[sender draggingLocation] fromView:nil];
    BOOL isCopy = ([NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagOption;
    BOOL isMove = [sender draggingSource] == self && isCopy == NO;
    NSInteger i = isCopy || isMove ? [self insertionIndexAtPoint:mouseLoc] : [self colorIndexAtPoint:mouseLoc];
    if ([self isEnabled] && i != -1 &&
        (isMove == NO || (i != draggedIndex && i != draggedIndex + 1))) {
        if (isMove)
            [self moveColorAtIndex:draggedIndex toIndex:i > draggedIndex ? i - 1 : i];
        else if (isCopy)
            [self insertColor:color atIndex:i];
        else
            [self setColor:color atIndex:i];
    }
    
    [self setDropLocation:SKColorSwatchNoDrop atIndex:-1];
    
	return YES;
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSString *)accessibilityRole {
    return NSAccessibilityGroupRole;
}

- (NSString *)accessibilityRoleDescription {
    return NSAccessibilityRoleDescription(NSAccessibilityGroupRole, nil);
}

- (NSRect)accessibilityFrame {
    return [[self window] convertRectToScreen:[self convertRect:[self bounds] toView:nil]];
}

- (id)accessibilityParent {
    return NSAccessibilityUnignoredAncestor([self superview]);
}

- (NSArray *)accessibilityChildren {
    return NSAccessibilityUnignoredChildren(itemViews);
}

- (NSArray *)accessibilityContents {
    return [self accessibilityChildren];
}

- (NSString *)accessibilityLabel {
    return NSLocalizedString(@"colors", @"accessibility description");
}

- (NSArray *)accessibilitySelectedChildren {
    if ([self selects] == NO)
        return nil;
    else if (selectedIndex == -1)
        return @[];
    else
        return NSAccessibilityUnignoredChildrenForOnlyChild([itemViews objectAtIndex:selectedIndex]);
}

- (id)accessibilityHitTest:(NSPoint)point {
    NSPoint localPoint = [self convertPoint:[[self window] convertPointFromScreen:point] fromView:nil];
    NSInteger i = [self colorIndexAtPoint:localPoint];
    if (i != -1) {
        return NSAccessibilityUnignoredAncestor([itemViews objectAtIndex:i]);
    } else {
        return [super accessibilityHitTest:point];
    }
}

- (id)accessibilityFocusedUIElement {
    if (focusedIndex != -1 && focusedIndex < (NSInteger)[itemViews count])
        return NSAccessibilityUnignoredAncestor([itemViews objectAtIndex:focusedIndex]);
    else
        return NSAccessibilityUnignoredAncestor(self);
}

- (BOOL)isItemViewFocused:(SKColorSwatchItemView *)itemView {
    return [[self window] firstResponder] == self && focusedIndex == (NSInteger)[itemViews indexOfObject:itemView];
}

- (void)itemView:(SKColorSwatchItemView *)itemView setFocused:(BOOL)focused {
    if (focused) {
        NSUInteger anIndex = [itemViews indexOfObject:itemView];
        if (anIndex < [itemViews count]) {
            focusedIndex = anIndex;
            [self noteFocusRingMaskChanged];
        }
        if ([[self window] firstResponder] != self)
            [[self window] makeFirstResponder:self];
    }
}

- (BOOL)isItemViewSelected:(SKColorSwatchItemView *)itemView {
    return selectedIndex !=-1 && selectedIndex == (NSInteger)[itemViews indexOfObject:itemView];
}

- (void)pressItemView:(SKColorSwatchItemView *)itemView  alternate:(BOOL)isAlternate {
    NSUInteger anIndex = [itemViews indexOfObject:itemView];
    if (anIndex < [itemViews count]) {
        alternate = isAlternate;
        [self performClickAtIndex:anIndex];
        alternate = NO;
    }
}

@end

#pragma mark -
@implementation SKColorWell

- (void)activate:(BOOL)exclusive {
    [[NSNotificationCenter defaultCenter] postNotificationName:SKColorSwatchOrWellWillActivateNotification object:self];
    [super activate:exclusive];
}

@end

#pragma mark -

@implementation SKColorSwatchBackgroundView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self setSegmentCount:1];
        [self setWidth:0.0 forSegment:0];
        [self setSegmentDistribution:NSSegmentDistributionFill];
        [self setSegmentStyle:NSSegmentStyleTexturedSquare];
        [self setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
        [self setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
    }
    return self;
}

- (BOOL)canBecomeKeyView { return NO; }

- (void)mouseDown:(NSEvent *)event {
    [[self superview] mouseDown:event];
}

- (void)rightMouseDown:(NSEvent *)event {
    [[self superview] rightMouseDown:event];
}

- (void)keyDown:(NSEvent *)event {
    [[self superview] keyDown:event];
}

- (void)performClick:(id)sender {}

- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

- (BOOL)isAccessibilityElement {
    return NO;
}

- (NSArray *)accessibilityChildren {
    return nil;
}

@end

#pragma mark -

@implementation SKColorSwatchItemView

@synthesize color, highlighted, selected, dropLocation;

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        color = [decoder decodeObjectForKey:COLOR_KEY];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:color forKey:COLOR_KEY];
}

- (void)setColor:(NSColor *)newColor {
    if (color != newColor) {
        color = newColor;
        [self setNeedsDisplay:YES];
    }
}

- (void)setHighlighted:(BOOL)flag {
    if (highlighted != flag) {
        highlighted = flag;
        [self setNeedsDisplay:YES];
    }
}

- (void)setSelected:(BOOL)flag {
    if (selected != flag) {
        selected = flag;
        [self setNeedsDisplay:YES];
    }
}

- (void)setDropLocation:(SKColorSwatchDropLocation)location {
    if (location != dropLocation) {
        dropLocation = location;
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect rect = [self bounds];
    if (NSWidth(rect) < 5.0)
        return;
    rect = NSInsetRect(rect, COLOR_INSET, COLOR_INSET);
    SKColorSwatch *colorSwatch = (SKColorSwatch *)[self superview];
    CGFloat r = cornerRadius([colorSwatch controlSize]);
    BOOL disabled = NO;
    if (@available(macOS 10.14, *)) {
        NSWindow *window = [self window];
        disabled = [window isMainWindow] == NO && [window isKeyWindow] == NO && [[colorSwatch superview] isDescendantOf:[window contentView]] == NO;
    }
    CGFloat stroke = [[NSWorkspace sharedWorkspace] accessibilityDisplayShouldIncreaseContrast] ? 0.55 : 0.25;
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 0.5, 0.5) xRadius:r - 0.5 yRadius:r - 0.5];

    if (NSWidth(rect) > 2.0) {
        [NSGraphicsContext saveGraphicsState];
        
        NSColor *aColor = color;
        if (disabled) {
            aColor = [aColor colorUsingColorSpace:[NSColorSpace genericGamma22GrayColorSpace]];
            CGContextSetAlpha([[NSGraphicsContext currentContext] CGContext], 0.5);
        }
        
        [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:r yRadius:r] addClip];
        [aColor drawSwatchInRect:rect];
        
        if (SKHasDarkAppearance()) {
            [[NSColor colorWithGenericGamma22White:1.0 alpha:stroke] setStroke];
            [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositingOperationScreen];
        } else {
            [[NSColor colorWithGenericGamma22White:0.0 alpha:stroke] setStroke];
            [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositingOperationMultiply];
        }
        [path stroke];
        
        [NSGraphicsContext restoreGraphicsState];
    }
    
    [NSGraphicsContext saveGraphicsState];
    
    if (highlighted || selected) {
        if (selected) {
            path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:r yRadius:r];
            [path setLineWidth:2.0];
        }
        [[NSColor systemGrayColor] setStroke];
        [path stroke];
    }
    
    if (dropLocation != SKColorSwatchNoDrop) {
        NSColor *dropColor = disabled ? [NSColor secondarySelectedControlColor] : [NSColor alternateSelectedControlColor];
        [dropColor setStroke];
        if (dropLocation == SKColorSwatchDropOn) {
            path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:r yRadius:r];
        } else if (dropLocation == SKColorSwatchDropBefore) {
            path = [NSBezierPath bezierPath];
            [path moveToPoint:NSMakePoint(NSMinX(rect) - 0.5, NSMinY(rect) - 1.0)];
            [path lineToPoint:NSMakePoint(NSMinX(rect) - 0.5, NSMaxY(rect) + 1.0)];
        } else if (dropLocation == SKColorSwatchDropAfter) {
            path = [NSBezierPath bezierPath];
            [path moveToPoint:NSMakePoint(NSMaxX(rect) + 0.5, NSMinY(rect) - 1.0)];
            [path lineToPoint:NSMakePoint(NSMaxX(rect) + 0.5, NSMaxY(rect) + 1.0)];
        }
        [path setLineWidth:3.0];
        if ((dropLocation == SKColorSwatchDropBefore && NSMinX([colorSwatch bounds]) + COLOR_INSET >= NSMinX([self frame])) ||
            (dropLocation == SKColorSwatchDropAfter && NSMaxX([colorSwatch bounds]) - COLOR_INSET <= NSMaxX([self frame])))
            [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, -COLOR_INSET, -COLOR_INSET) xRadius:r + COLOR_INSET yRadius:r + COLOR_INSET] addClip];
        [path stroke];
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSString *)accessibilityRole {
    return NSAccessibilityColorWellRole;
}

- (NSString *)accessibilityRoleDescription {
    return NSAccessibilityRoleDescription(NSAccessibilityColorWellRole, nil);
}

- (NSRect)accessibilityFrame {
    return [[self window] convertRectToScreen:[self convertRect:[self bounds] toView:nil]];
}

- (id)accessibilityParent {
    return NSAccessibilityUnignoredAncestor([self superview]);
}

- (id)accessibilityValue {
    return [color accessibilityValue];
}

- (BOOL)isAccessibilityFocused {
    return [(SKColorSwatch *)[self superview] isItemViewFocused:self];
}

- (void)setAccessibilityFocused:(BOOL)flag {
    [(SKColorSwatch *)[self superview] itemView:self setFocused:flag];
}

- (BOOL)isAccessibilitySelected {
    return [(SKColorSwatch *)[self superview] isItemViewSelected:self];
}

- (BOOL)accessibilityPerformPress {
    [(SKColorSwatch *)[self superview] pressItemView:self alternate:NO];
    return YES;
}

- (BOOL)accessibilityPerformPick {
    [(SKColorSwatch *)[self superview] pressItemView:self alternate:YES];
    return YES;
}

- (id)accessibilityFocusedUIElement {
    return NSAccessibilityUnignoredAncestor(self);
}

@end
