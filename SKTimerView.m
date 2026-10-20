//
//  SKTimerView.m
//  Skim
//
//  Created by Christiaan Hofmanon 20/10/2026.
/*
 This software is Copyright (c) 2026
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

#import "SKTimerView.h"

@implementation SKTimerView

@synthesize active;

- (instancetype)init {
    self = [self initWithFrame:NSMakeRect(0.0, 0.0, 40.0, 40.0)];
    if (self) {
        imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 40.0, 40.0)];
        [imageView setImage:[NSImage imageWithSize:NSMakeSize(40.0, 40.0) flipped:NO drawingHandler:^(NSRect rect){
            NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(4.0, 4.0, 32.0, 32.0)];
            [path moveToPoint:NSMakePoint(20.0, 30.0)];
            [path lineToPoint:NSMakePoint(20.0, 20.0)];
            [path lineToPoint:NSMakePoint(15.0, 15.0)];
            [path setLineCapStyle:NSRoundLineCapStyle];
            [path setLineWidth:4.0];
            [[NSColor whiteColor] setStroke];
            [path stroke];
            [path setLineWidth:2.0];
            [[NSColor blackColor] setStroke];
            [path stroke];
            return YES;
        }]];
        [imageView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self addSubview:imageView];
        [NSLayoutConstraint activateConstraints:@[
            [[imageView widthAnchor] constraintEqualToConstant:40.0],
            [[imageView heightAnchor] constraintEqualToConstant:40.0],
            [[imageView centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [[self centerYAnchor] constraintEqualToAnchor:[imageView centerYAnchor]]
        ]];
        [self setWantsLayer:YES];
        [[self layer] setCornerRadius:20.0];
        [[self layer] setMasksToBounds:YES];
    }
    return self;
}

- (void)dealloc {
    [timer invalidate];
    timer = nil;
}

- (void)updateTime {
    ++time;
    if (time >= 3600)
        [textField setStringValue:[NSString stringWithFormat:@"%lu:%.2lu:%.2lu", time / 3600, (time / 60) % 60, time % 60]];
    else
        [textField setStringValue:[NSString stringWithFormat:@"%.2lu:%.2lu", time / 60, time % 60]];
}

- (void)mouseDown:(NSEvent *)event {
    if (active == NO) {
        if (timer == nil) {
            __weak SKTimerView *weakSelf = self;
            timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *aTimer){
                [weakSelf updateTime];
            }];
        }
        if (bgView == nil) {
            bgView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 40.0, 40.0)];
            if (@available(macOS 10.14, *))
                [bgView setMaterial:NSVisualEffectMaterialHUDWindow];
            else
                [bgView setMaterial:NSVisualEffectMaterialDark];
            [bgView setState:NSVisualEffectStateActive];
            if (@available(macOS 10.14, *))
                [bgView setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
            [bgView setTranslatesAutoresizingMaskIntoConstraints:NO];
        }
        if (textField == nil) {
            textField = [[NSTextField alloc] init];
            [textField setBezeled:NO];
            [textField setBordered:NO];
            [textField setDrawsBackground:NO];
            [textField setEditable:NO];
            [textField setSelectable:NO];
            [textField setTextColor:[NSColor whiteColor]];
            [textField setFont:[NSFont monospacedDigitSystemFontOfSize:36.0 weight:NSFontWeightMedium]];
            [textField setAlignment:NSTextAlignmentCenter];
            [textField setTranslatesAutoresizingMaskIntoConstraints:NO];
            [textField setStringValue:@"00:00"];
            [self setTranslatesAutoresizingMaskIntoConstraints:NO];
            [NSLayoutConstraint activateConstraints:@[
                (widthConstraint = [[self widthAnchor] constraintEqualToConstant:40.0]),
                [[self heightAnchor] constraintEqualToConstant:40.0]
            ]];
        }
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
            [[imageView animator] removeFromSuperview];
            [[self animator] addSubview:textField positioned:NSWindowAbove relativeTo:nil];
            [NSLayoutConstraint activateConstraints:@[
                [[textField centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
                [[self centerYAnchor] constraintEqualToAnchor:[textField centerYAnchor] constant:2.0]
            ]];
            [[self animator] addSubview:bgView positioned:NSWindowBelow relativeTo:nil];
            [NSLayoutConstraint activateConstraints:@[
                [[bgView leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
                [[self trailingAnchor] constraintEqualToAnchor:[bgView trailingAnchor]],
                [[bgView topAnchor] constraintEqualToAnchor:[self topAnchor]],
                [[self bottomAnchor] constraintEqualToAnchor:[bgView bottomAnchor]]
            ]];
            [[widthConstraint animator] setConstant:150.0];
        } completionHandler:^{}];
        active = YES;
    } else {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
            [[textField animator] removeFromSuperview];
            [[bgView animator] removeFromSuperview];
            [[self animator] addSubview:imageView];
            [NSLayoutConstraint activateConstraints:@[
                [[imageView widthAnchor] constraintEqualToConstant:40.0],
                [[imageView heightAnchor] constraintEqualToConstant:40.0],
                [[imageView centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
                [[self centerYAnchor] constraintEqualToAnchor:[imageView centerYAnchor]]
            ]];
            [[widthConstraint animator] setConstant:40.0];
        } completionHandler:^{}];
        active = NO;
    }
}

@end
