//
//  SKFontWell.m
//  Skim
//
//  Created by Christiaan Hofman on 4/13/08.
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

#import "SKFontWell.h"
#import "NSGraphics_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "NSObject_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "SKApplication.h"

#define SKNSFontPanelDescriptorsPboardType @"NSFontPanelDescriptorsPboardType"
#define SKNSFontPanelFamiliesPboardType @"NSFontPanelFamiliesPboardType"

#define SKNSFontCollectionFontDescriptors @"NSFontCollectionFontDescriptors"

#define SKFontWellWillBecomeActiveNotification @"SKFontWellWillBecomeActiveNotification"

#define TEXTCOLOR_KEY    @"textColor"
#define HASTEXTCOLOR_KEY @"hasTextColor"

#define ACTION_KEY       @"action"
#define TARGET_KEY       @"target"


@interface SKFontWell ()
- (void)changeActive:(id)sender;
@end


@implementation SKFontWell

@dynamic active, textColor, hasTextColor;

+ (Class)cellClass {
    return [SKFontWellCell class];
}

- (Class)valueClassForBinding:(NSBindingName)binding {
    if ([binding isEqualToString:NSTextColorBinding])
        return [NSColor class];
    else
        return [super valueClassForBinding:binding];
}

- (void)commonInit {
    if ([self font] == nil)
        [self setFont:[NSFont userFontOfSize:0.0]];
    [self setTitle:[NSString stringWithFormat:@"%@ %.0f", [[self font] displayName], [[self font] pointSize]]];
    [[self cell] setAction:@selector(changeActive:)];
    [[self cell] setTarget:self];
    [self registerForDraggedTypes:@[SKNSFontPanelDescriptorsPboardType, SKNSFontPanelFamiliesPboardType, NSPasteboardTypeColor]];
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
		NSButtonCell *oldCell = [self cell];
		if (NO == [oldCell isKindOfClass:[[self class] cellClass]]) {
			SKFontWellCell *newCell = [[[[self class] cellClass] alloc] init];
			[newCell setAlignment:[oldCell alignment]];
			[newCell setEditable:[oldCell isEditable]];
			[newCell setTarget:[oldCell target]];
			[newCell setAction:[oldCell action]];
			[self setCell:newCell];
		}
        action = NSSelectorFromString([decoder decodeObjectForKey:ACTION_KEY]);
        target = [decoder decodeObjectForKey:TARGET_KEY];
        [self commonInit];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:NSStringFromSelector(action) forKey:ACTION_KEY];
    [coder encodeConditionalObject:target forKey:TARGET_KEY];
}

- (void)dealloc {
    if ([self infoForBinding:NSTextColorBinding])
        SKENSURE_MAIN_THREAD( [self unbind:NSTextColorBinding]; );
}

- (BOOL)isOpaque{ return NO; }

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    [self deactivate];
    [super viewWillMoveToWindow:newWindow];
}

- (void)fontWellWillBecomeActive:(NSNotification *)notification {
    id sender = [notification object];
    if (sender != self && [self isActive]) {
        [self deactivate];
    }
}

- (void)fontPanelWillClose:(NSNotification *)notification {
    [self deactivate];
}

- (void)changeFontFromFontManager:(id)sender {
    if ([self isActive]) {
        NSFont *font = [sender convertFont:[self font]];
        [self setFont:font];
        [self propagateValue:[font fontName] forBinding:NSFontNameBinding];
        [self propagateValue:[NSNumber numberWithDouble:[font pointSize]] forBinding:NSFontSizeBinding];
        [self sendAction:[self action] to:[self target]];
    }
}

- (void)changeAttributesFromFontManager:(id)sender {
    if ([self isActive] && [self hasTextColor]) {
        NSColor *color = [[sender convertAttributes:@{NSForegroundColorAttributeName:[self textColor] ?: [NSColor blackColor]}] valueForKey:NSForegroundColorAttributeName];
        [self setTextColor:color];
        [self propagateValue:color forBinding:NSTextColorBinding];
        [self sendAction:[self action] to:[self target]];
    }
}

- (void)changeActive:(id)sender {
    if ([self isEnabled]) {
        if ([self isActive])
            [self activate];
        else
            [self deactivate];
    }
}

- (void)activate {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSFontManager *fm = [NSFontManager sharedFontManager];
    
    [nc postNotificationName:SKFontWellWillBecomeActiveNotification object:self];
    
    [fm setSelectedFont:[self font] isMultiple:NO];
    [fm orderFrontFontPanel:self];
    if ([self hasTextColor])
        [fm setSelectedAttributes:@{NSForegroundColorAttributeName: [self textColor]} isMultiple:NO];
    
    [nc addObserver:self selector:@selector(fontWellWillBecomeActive:)
               name:SKFontWellWillBecomeActiveNotification object:nil];
    [nc addObserver:self selector:@selector(fontPanelWillClose:)
               name:NSWindowWillCloseNotification object:[fm fontPanel:YES]];
    
    [self setState:NSControlStateValueOn];
    [self setNeedsDisplay:YES];
}

- (void)deactivate {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self setState:NSControlStateValueOff];
    [self setNeedsDisplay:YES];
}

- (void)fontChanged {
    if ([self isActive])
        [[NSFontManager sharedFontManager] setSelectedFont:[self font] isMultiple:NO];
    [self setTitle:[NSString stringWithFormat:@"%@ %.0f", [[self font] displayName], [[self font] pointSize]]];
    [self setNeedsDisplay:YES];
    NSAccessibilityPostNotification([self cell], NSAccessibilityValueChangedNotification);
}

- (void)textColorChanged {
    if ([self isActive])
        [[NSFontManager sharedFontManager] setSelectedAttributes:@{NSForegroundColorAttributeName: [self textColor]} isMultiple:NO];
    [self setNeedsDisplay:YES];
}

- (void)propagateValue:(id)value forBinding:(NSBindingName)binding {
    updatedBinding = binding;
    [super propagateValue:value forBinding:binding];
    updatedBinding = nil;
}

#pragma mark Accessors

- (SEL)action { return action; }

- (void)setAction:(SEL)newAction { action = newAction; }

- (id)target { return target; }

- (void)setTarget:(id)newTarget { target = newTarget; }

- (BOOL)isActive {
    return [self state] == NSControlStateValueOn;
}

- (void)setFont:(NSFont *)newFont {
    // updating the fontName or fontSize binding triggers setFont: from KVO
    // which can set a partially updated font as it uses both bindings to build the font
    if ([updatedBinding isEqualToString:NSFontNameBinding] || [updatedBinding isEqualToString:NSFontSizeBinding])
        return;
    BOOL didChange = [[self font] isEqual:newFont] == NO;
    [super setFont:newFont];
    if (didChange)
        [self fontChanged];
}

- (NSColor *)textColor {
    return [[self cell] textColor];
}

- (void)setTextColor:(NSColor *)newTextColor {
    if ([updatedBinding isEqualToString:NSTextColorBinding])
        return;
    BOOL didChange = [[self textColor] isEqual:newTextColor] == NO;
    [[self cell] setTextColor:newTextColor];
    if (didChange)
        [self textColorChanged];
}

- (BOOL)hasTextColor {
    return [[self cell] hasTextColor];
}

- (void)setHasTextColor:(BOOL)newHasTextColor {
    if ([self hasTextColor] != newHasTextColor) {
        [[self cell] setHasTextColor:newHasTextColor];
        [self setNeedsDisplay:YES];
    }
}

#pragma mark Dragging

- (void)mouseDown:(NSEvent *)theEvent {
    [[self cell] setHighlighted:YES];
    [self setNeedsDisplay:YES];
    
    if ([NSApp willDragMouse]) {
        [[self cell] setHighlighted:NO];
        [self setNeedsDisplay:YES];
        
        NSRect bounds = [self bounds];
        
        NSImage *dragImage = [NSImage bitmapImageWithSize:bounds.size forView:self drawingHandler:^(NSRect rect){
            SKRunWithAppearance(self, ^{
                [[self cell] drawInteriorWithFrame:rect inView:self];
            });
        }];
        
        NSDictionary *dict = @{SKNSFontCollectionFontDescriptors: @[[[self font] fontDescriptor]], NSFontSizeAttribute: [NSNumber numberWithDouble:[[self font] pointSize]]};
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:dict requiringSecureCoding:YES error:NULL];
        NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
        [item setData:data forType:CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassNSPboardType, (__bridge CFStringRef)SKNSFontPanelDescriptorsPboardType, kUTTypeData))];
        
        NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:item];
        [dragItem setDraggingFrame:bounds contents:dragImage];
        
        [self beginDraggingSessionWithItems:@[dragItem] event:theEvent source:self];
    } else {
        [super mouseDown:theEvent];
    }
}

#pragma mark NSDraggingSource protocol

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    return NSDragOperationGeneric;
}

#pragma mark NSDraggingDestination protocol 

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    if ([self isEnabled] && [sender draggingSource] != self && [[sender draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObjects:SKNSFontPanelDescriptorsPboardType, SKNSFontPanelFamiliesPboardType, ([self hasTextColor] ? NSPasteboardTypeColor : nil), nil]]) {
        [[self cell] setHighlighted:YES];
        [self setNeedsDisplay:YES];
        return NSDragOperationGeneric;
    } else
        return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    if ([self isEnabled] && [sender draggingSource] != self && [[sender draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObjects:SKNSFontPanelDescriptorsPboardType, SKNSFontPanelFamiliesPboardType, ([self hasTextColor] ? NSPasteboardTypeColor : nil), nil]]) {
        [[self cell] setHighlighted:NO];
        [self setNeedsDisplay:YES];
    }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
    return [self isEnabled] && [sender draggingSource] != self && [[sender draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObjects:SKNSFontPanelDescriptorsPboardType, SKNSFontPanelFamiliesPboardType, ([self hasTextColor] ? NSPasteboardTypeColor : nil), nil]];
} 

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:SKNSFontPanelDescriptorsPboardType, SKNSFontPanelFamiliesPboardType, ([self hasTextColor] ? NSPasteboardTypeColor : nil), nil]];
    NSFont *droppedFont = nil;
    NSColor *droppedColor = nil;
    
    if ([type isEqualToString:SKNSFontPanelDescriptorsPboardType]) {
        NSData *data = [pboard dataForType:type];
        if ([data isKindOfClass:[NSData class]]) {
            NSDictionary *dict = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], [NSNumber class], [NSArray class], [NSFontDescriptor class], nil] fromData:data error:NULL];
            if ([dict isKindOfClass:[NSDictionary class]]) {
                NSArray *fontDescriptors = [dict objectForKey:SKNSFontCollectionFontDescriptors];
                NSFontDescriptor *fontDescriptor = [fontDescriptors isKindOfClass:[NSArray class]] ? [fontDescriptors firstObject] : nil;
                if ([fontDescriptor isKindOfClass:[NSFontDescriptor class]]) {
                    NSNumber *size = [[fontDescriptor fontAttributes] objectForKey:NSFontSizeAttribute] ?: [dict objectForKey:NSFontSizeAttribute];
                    CGFloat fontSize = [size respondsToSelector:@selector(doubleValue)] ? [size doubleValue] : [[self font] pointSize];
                    droppedFont = [NSFont fontWithDescriptor:fontDescriptor size:fontSize];
                }
            }
        }
    } else if ([type isEqualToString:SKNSFontPanelFamiliesPboardType]) {
        NSArray *families = [pboard propertyListForType:type];
        NSString *family = ([families isKindOfClass:[NSArray class]] && [families count]) ? [families objectAtIndex:0] : nil;
        if ([family isKindOfClass:[NSString class]])
            droppedFont = [[NSFontManager sharedFontManager] convertFont:[self font] toFamily:family];
    } else if ([type isEqualToString:NSPasteboardTypeColor]) {
        droppedColor = [NSColor colorFromPasteboard:pboard];
    }

    if (droppedFont) {
        [self setFont:droppedFont];
        [self propagateValue:[droppedFont fontName] forBinding:NSFontNameBinding];
        [self propagateValue:[NSNumber numberWithDouble:[droppedFont pointSize]] forBinding:NSFontSizeBinding];
        [self sendAction:[self action] to:[self target]];
    }
    if (droppedColor) {
        [self setTextColor:droppedColor];
        [self propagateValue:droppedColor forBinding:NSTextColorBinding];
        [self sendAction:[self action] to:[self target]];
    }
    
    [[self cell] setHighlighted:NO];
    [self setNeedsDisplay:YES];
    
	return droppedFont != nil || droppedColor != nil;
}

@end


@implementation SKFontWellCell

@synthesize textColor, hasTextColor;

- (void)commonInit {
    if (textColor == nil)
        [self setTextColor:[NSColor textColor]];
    [self setBezelStyle:NSShadowlessSquareBezelStyle]; // this is mainly to make it selectable
    [self setButtonType:NSPushOnPushOffButton];
    [self setState:NSControlStateValueOff];
}
 
- (instancetype)initTextCell:(NSString *)aString {
    self = [super initTextCell:aString];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initImageCell:(NSImage *)anImage {
    self = [super initImageCell:anImage];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
	self = [super initWithCoder:decoder];
    if (self) {
        [self setTextColor:[decoder decodeObjectForKey:TEXTCOLOR_KEY]];
        [self setHasTextColor:[decoder decodeBoolForKey:HASTEXTCOLOR_KEY]];
        [self commonInit];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:textColor forKey:TEXTCOLOR_KEY];
    [coder encodeBool:hasTextColor forKey:HASTEXTCOLOR_KEY];
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView {
    SKDrawTextFieldBezel(frame, controlView);
    
    if ([self state] == NSControlStateValueOn) {
        [NSGraphicsContext saveGraphicsState];
        [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositingOperationMultiply];
        [[NSColor selectedControlColor] setFill];
        [NSBezierPath fillRect:NSInsetRect(frame, 1.0, 1.0)];
        [NSGraphicsContext restoreGraphicsState];
    }
    if ([self isHighlighted]) {
        [NSGraphicsContext saveGraphicsState];
        [[[NSColor textColor] colorWithAlphaComponent:0.3] setStroke];
        [NSBezierPath strokeRect:NSInsetRect(frame, 0.5, 0.5)];
        [NSGraphicsContext restoreGraphicsState];
    }
    
    if ([self hasTextColor]) {
        NSRect rect = NSMakeRect(NSMaxX(frame) - 12.0, 2.0, 10.0, 10.0);
        NSAttributedString *T = [[NSAttributedString alloc] initWithString:@"T" attributes:@{NSForegroundColorAttributeName: [NSColor secondaryLabelColor], NSFontAttributeName: [NSFont fontWithName:@"Palatino-Bold" size:8.0]}];
        NSSize size = [T size];
        [T drawInRect:NSMakeRect(NSMinX(rect) - ceil(size.width) - 2.0, floor(NSMidY(rect) - 0.5 * size.height), size.width, size.height)];
        [NSGraphicsContext saveGraphicsState];
        [[self textColor] drawSwatchInRect:rect];
        [[[NSColor textColor] colorWithAlphaComponent:0.5] setStroke];
        [[NSGraphicsContext currentContext] setCompositingOperation:SKHasDarkAppearance() ? NSCompositingOperationScreen : NSCompositingOperationMultiply];
        [NSBezierPath strokeRect:NSInsetRect(rect, 0.5, 0.5)];
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (NSString *)accessibilitySubrole {
    return @"AXFontWell";
}

- (NSString *)accessibilityRoleDescription {
    return NSLocalizedString(@"font well", @"Accessibility description");
}

- (id)accessibilityValue {
    return [self title];
}

- (NSString *)accessibilityLabel {
    return nil;
}

- (NSString *)accessibilityTitle {
    return nil;
}

@end
