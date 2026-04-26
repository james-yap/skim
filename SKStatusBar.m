//
//  SKStatusBar.m
//  Skim
//
//  Created by Christiaan Hofman on 7/8/07.
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

#import "SKStatusBar.h"
#import "NSGeometry_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKApplication.h"
#import "NSView_SKExtensions.h"
#import <Quartz/Quartz.h>

#define LEFT_MARGIN         8.0
#define RIGHT_MARGIN        16.0
#define SEPARATION          4.0
#define ICON_OFFSET         1.0

@interface SKStatusTextField : NSTextField
@end

@interface SKStatusTextFieldCell : NSTextFieldCell {
    BOOL underlined;
}
@property (nonatomic, getter=isUnderlined) BOOL underlined;
@end

#pragma mark -

@implementation SKStatusBar

@synthesize animating, leftField, rightField, progressIndicator, bottomConstraint;
@dynamic visible, icon, progressIndicatorStyle;

+ (id)defaultAnimationForKey:(NSString *)key {
    if ([key isEqualToString:@"windowContentBorderThickness"])
        return [CABasicAnimation animation];
    else
        return [super defaultAnimationForKey:key];
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        leftField = [[SKStatusTextField alloc] init];
        [leftField setBezeled:NO];
        [leftField setBordered:NO];
        [leftField setDrawsBackground:NO];
        [leftField setEditable:NO];
        [leftField setSelectable:NO];
        [leftField setTextColor:[NSColor labelColor]];
        [leftField setControlSize:NSControlSizeSmall];
        [leftField setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self addSubview:leftField];
        
        rightField = [[SKStatusTextField alloc] init];
        [rightField setBezeled:NO];
        [rightField setBordered:NO];
        [rightField setDrawsBackground:NO];
        [rightField setEditable:NO];
        [rightField setSelectable:NO];
        [rightField setTextColor:[NSColor labelColor]];
        [rightField setControlSize:NSControlSizeSmall];
        [rightField setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self addSubview:rightField];
        
        NSArray *constraints = @[
            [[leftField leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:LEFT_MARGIN],
            [[leftField centerYAnchor]constraintEqualToAnchor:[self centerYAnchor]],
            [[self trailingAnchor]constraintEqualToAnchor:[rightField trailingAnchor] constant:RIGHT_MARGIN],
            [[rightField centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]]];
        leftLeadingConstraint = [constraints objectAtIndex:0];
        rightTrailingConstraint = [constraints objectAtIndex:2];
        [NSLayoutConstraint activateConstraints:constraints];
        
        iconView = nil;
		progressIndicator = nil;
        animating = NO;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
	self = [super initWithCoder:decoder];
    if (self) {
        leftField = [decoder decodeObjectForKey:@"leftField"];
        rightField = [decoder decodeObjectForKey:@"rightField"];
        iconView = [decoder decodeObjectForKey:@"iconView"];
        progressIndicator = [decoder decodeObjectForKey:@"progressIndicator"];
        
        NSArray *constraints = @[
            [[leftField leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:LEFT_MARGIN],
            [[leftField centerYAnchor]constraintEqualToAnchor:[self centerYAnchor]],
            [[self trailingAnchor]constraintEqualToAnchor:[rightField trailingAnchor] constant:RIGHT_MARGIN],
            [[rightField centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]]];
        leftLeadingConstraint = [constraints objectAtIndex:0];
        rightTrailingConstraint = [constraints objectAtIndex:2];
        [NSLayoutConstraint activateConstraints:constraints];
        
        if (iconView) {
            [iconView removeFromSuperview];
            iconView = nil;
        }
        if (progressIndicator) {
            [progressIndicator removeFromSuperview];
            progressIndicator = nil;
        }
        animating = NO;
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeConditionalObject:leftField forKey:@"leftField"];
    [coder encodeConditionalObject:rightField forKey:@"rightField"];
    [coder encodeConditionalObject:iconView forKey:@"iconView"];
    [coder encodeConditionalObject:progressIndicator forKey:@"progressIndicator"];
}

- (BOOL)isVisible {
	return [self superview] && [self isHidden] == NO;
}

- (CGFloat)windowContentBorderThickness {
    return [[self window] contentBorderThicknessForEdge:NSRectEdgeMinY];
}

- (void)setWindowContentBorderThickness:(CGFloat)thickness {
    [[self window] setContentBorderThickness:thickness forEdge:NSRectEdgeMinY];
}

- (void)toggleBelowView:(NSView *)view animate:(BOOL)animate {
    if (animating)
        return;
    if ([NSView shouldShowSlideAnimation] == NO)
        animate = NO;
    
    NSView *contentView = [view superview];
    BOOL visible = (nil == [self superview]);
    CGFloat statusHeight = NSHeight([self frame]);
    NSLayoutConstraint *newBottomConstraint = nil;
    
    if (visible) {
        [contentView addSubview:self];
        NSArray *constraints = @[
            [[self leadingAnchor] constraintEqualToAnchor:[contentView leadingAnchor]],
            [[contentView trailingAnchor]constraintEqualToAnchor:[self trailingAnchor]],
            [[self topAnchor] constraintEqualToAnchor:[view bottomAnchor]],
            [[contentView bottomAnchor] constraintEqualToAnchor:[self bottomAnchor] constant:animate ? -statusHeight : 0.0]];
        [bottomConstraint setActive:NO];
        [NSLayoutConstraint activateConstraints:constraints];
        [contentView layoutSubtreeIfNeeded];
        bottomConstraint = [constraints lastObject];
    } else {
        newBottomConstraint = [[contentView bottomAnchor] constraintEqualToAnchor:[view bottomAnchor]];
    }
    
    if (animate) {
        animating = YES;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [context setDuration:0.5 * [context duration]];
                [[bottomConstraint animator] setConstant:visible ? 0.0 : -statusHeight];
                [[self animator] setWindowContentBorderThickness:visible ? statusHeight : 0.0];
            }
            completionHandler:^{
                if (visible) {
                    // this fixes an AppKit bug, the window does not notice that its draggable areas change
                    [[self window] setMovableByWindowBackground:YES];
                    [[self window] setMovableByWindowBackground:NO];
                } else {
                    [self removeFromSuperview];
                    [newBottomConstraint setActive:YES];
                    bottomConstraint = newBottomConstraint;
                }
                animating = NO;
            }];
    } else if (visible) {
        [[self window] setContentBorderThickness:statusHeight forEdge:NSRectEdgeMinY];
    } else {
        [[self window] setContentBorderThickness:0.0 forEdge:NSRectEdgeMinY];
        [self removeFromSuperview];
        [newBottomConstraint setActive:YES];
        [contentView layoutSubtreeIfNeeded];
        bottomConstraint = newBottomConstraint;
    }
}

#pragma mark Accessors

- (NSImage *)icon {
    return [iconView image];
}

- (void)setIcon:(NSImage *)icon {
    if (icon) {
        if (iconView == nil) {
            iconView = [[NSImageView alloc] init];
            [iconView setTranslatesAutoresizingMaskIntoConstraints:NO];
            [self addSubview:iconView];
            [leftLeadingConstraint setActive:NO];
            NSArray *constraints = @[
                [[iconView leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:LEFT_MARGIN],
                 [[leftField leadingAnchor] constraintEqualToAnchor:[iconView trailingAnchor] constant:SEPARATION],
                 [[iconView topAnchor] constraintEqualToAnchor:[self topAnchor]],
                 [[iconView widthAnchor] constraintEqualToAnchor:[iconView heightAnchor]]];
            leftLeadingConstraint = [constraints objectAtIndex:1];
            [NSLayoutConstraint activateConstraints:constraints];
        }
        [iconView setImage:icon];
    } else if (iconView) {
        [iconView removeFromSuperview];
        iconView = nil;
        leftLeadingConstraint = [[leftField leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:LEFT_MARGIN];
        [leftLeadingConstraint setActive:YES];
    }
}

- (SKProgressIndicatorStyle)progressIndicatorStyle {
	if (progressIndicator == nil)
		return SKProgressIndicatorStyleNone;
	else
        return [progressIndicator isIndeterminate] ? SKProgressIndicatorStyleIndeterminate : SKProgressIndicatorStyleDeterminate;
}

- (void)setProgressIndicatorStyle:(SKProgressIndicatorStyle)style {
	if (style == SKProgressIndicatorStyleNone) {
		if (progressIndicator == nil)
			return;
		[progressIndicator removeFromSuperview];
		progressIndicator = nil;
        rightTrailingConstraint = [[self trailingAnchor] constraintEqualToAnchor:[rightField trailingAnchor] constant:RIGHT_MARGIN];
        [rightTrailingConstraint setActive:YES];
	} else {
		if (progressIndicator && (NSInteger)[progressIndicator style] == style)
			return;
		if (progressIndicator == nil) {
            progressIndicator = [[NSProgressIndicator alloc] init];
            [progressIndicator setControlSize:NSControlSizeSmall];
            [progressIndicator setDisplayedWhenStopped:YES];
            [progressIndicator setUsesThreadedAnimation:YES];
            [progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
            [progressIndicator setTranslatesAutoresizingMaskIntoConstraints:NO];
            [self addSubview:progressIndicator];
            [rightTrailingConstraint setActive:NO];
            NSArray *constraints = @[
                 [[self trailingAnchor] constraintEqualToAnchor:[progressIndicator trailingAnchor] constant:RIGHT_MARGIN],
                 [[progressIndicator leadingAnchor]constraintEqualToAnchor:[rightField trailingAnchor] constant:SEPARATION],
                 [[progressIndicator centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]]];
            rightTrailingConstraint = [constraints objectAtIndex:1];
            [NSLayoutConstraint activateConstraints:constraints];
		}
		[progressIndicator setIndeterminate:style == SKProgressIndicatorStyleIndeterminate];
	}
}

#pragma mark Accessibility

- (NSString *)accessibilityLabel {
    return NSLocalizedString(@"status bar", @"Accessibility description");
}

@end

#pragma mark -

@implementation SKStatusTextField

+ (Class)cellClass { return [SKStatusTextFieldCell class]; }

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[self bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingInVisibleRect owner:self userInfo:nil];
        [self addTrackingArea:area];
    }
    return self;
}

- (void)mouseEntered:(NSEvent *)theEvent {
    if ([[SKStatusTextField superclass] instancesRespondToSelector:_cmd])
        [super mouseEntered:theEvent];
    if ([self action] != NULL) {
        [(SKStatusTextFieldCell *)[self cell] setUnderlined:YES];
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseExited:(NSEvent *)theEvent {
    if ([[SKStatusTextField superclass] instancesRespondToSelector:_cmd])
        [super mouseExited:theEvent];
    if ([self action] != NULL) {
        [(SKStatusTextFieldCell *)[self cell] setUnderlined:NO];
        [self setNeedsDisplay:YES];
    }
}

- (void)setAction:(SEL)action {
    [super setAction:action];
    if ([self action] != NULL) {
        [(SKStatusTextFieldCell *)[self cell] setUnderlined:NO];
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    if ([self action]) {
        NSRect bounds = [self bounds];
        BOOL inside = YES;
        while ([theEvent type] != NSEventTypeLeftMouseUp) {
            theEvent = [[self window] nextEventMatchingMask: NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp | NSEventMaskMouseEntered | NSEventMaskMouseExited];
            inside = NSMouseInRect([self convertPoint:[theEvent locationInWindow] fromView:nil], bounds, [self isFlipped]);
            if (inside != [(SKStatusTextFieldCell *)[self cell] isUnderlined]) {
                [(SKStatusTextFieldCell *)[self cell] setUnderlined:inside];
                [self setNeedsDisplay:YES];
            }
        }
        if (inside) {
            [[self cell] setNextState];
            [self sendAction:[self action] to:[self target]];
        }
    } else {
        [super mouseDown:theEvent];
    }
}

@end

@implementation SKStatusTextFieldCell

@synthesize underlined;

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    if ([self isUnderlined]) {
        id objectValue = [self objectValue];
        NSMutableAttributedString *mutAttrString = [[self attributedStringValue] mutableCopy];
        [mutAttrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:NSMakeRange(0, [mutAttrString length])];
        [self setObjectValue:mutAttrString];
        [super drawInteriorWithFrame:cellFrame inView:controlView];
        [self setObjectValue:objectValue];
    } else {
        [super drawInteriorWithFrame:cellFrame inView:controlView];
    }
}

@end
