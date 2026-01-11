//
//  NSAttributedString_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 6/12/08.
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

#import "NSAttributedString_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSData_SKExtensions.h"


@implementation NSAttributedString (SKExtensions)

- (NSAttributedString *)attributedStringByAddingTextColorAttribute {
    NSMutableAttributedString *attrString = [self mutableCopy];
    if ([attrString addTextColorAttribute])
        return attrString;
    return self;
}

- (NSAttributedString *)attributedStringByRemovingTextColorAttribute {
    NSMutableAttributedString *attrString = [self mutableCopy];
    if ([attrString removeTextColorAttribute])
        return attrString;
    return self;
}

- (NSAttributedString *)attributedStringByAddingControlTextColorAttribute {
    NSMutableAttributedString *attrString = [self mutableCopy];
    if ([attrString addControlTextColorAttribute])
        return attrString;
    return self;
}

#pragma mark Templating support

- (NSString *)xmlString {
    return [[self string] xmlString];
}

- (NSData *)RTFRepresentation {
    return [self RTFFromRange:NSMakeRange(0, [self length]) documentAttributes:@{NSDocumentTypeDocumentAttribute:NSRTFTextDocumentType}];
}

#pragma mark Scripting support

- (NSString *)scriptingName {
    return [[self RTFRepresentation] hexString];
}

- (NSTextStorage *)scriptingRichText {
    return [[NSTextStorage alloc] initWithAttributedString:self];
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSScriptClassDescription *containerClassDescription = [NSScriptClassDescription classDescriptionForClass:[NSApp class]];
    return [[NSNameSpecifier alloc] initWithContainerClassDescription:containerClassDescription containerSpecifier:nil key:@"richTextFormat" name:[self scriptingName]];
}

- (NSScriptObjectSpecifier *)richTextSpecifier {
    NSScriptObjectSpecifier *rtfSpecifier = [self objectSpecifier];
    return [[NSPropertySpecifier alloc] initWithContainerClassDescription:[rtfSpecifier keyClassDescription] containerSpecifier:rtfSpecifier key:@"scriptingRichText"];
}

@end


@implementation NSMutableAttributedString (SKExtensions)

- (BOOL)addTextColorAttribute {
    __block BOOL changed = NO;
    [self enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, [self length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop){
        if (value == nil) {
            changed = YES;
            [self addAttribute:NSForegroundColorAttributeName value:[NSColor textColor] range:range];
        }
    }];
    return changed;
}

- (BOOL)removeTextColorAttribute {
    __block BOOL changed = NO;
    [self enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, [self length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop){
        if ([value isEqual:[NSColor textColor]]) {
            changed = YES;
            [self removeAttribute:NSForegroundColorAttributeName range:range];
        }
    }];
    return changed;
}

- (BOOL)addControlTextColorAttribute {
    __block BOOL changed = NO;
    [self enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, [self length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop){
        if (value == nil || [value isEqual:[NSColor textColor]]) {
            changed = YES;
            [self addAttribute:NSForegroundColorAttributeName value:[NSColor controlTextColor] range:range];
        }
    }];
    return changed;
}

@end

@implementation NSTextStorage (SKExtensions)

#pragma mark Scripting support

- (NSData *)scriptingRTF {
    return [self RTFRepresentation];
}

- (void)setScriptingRTF:(NSData *)data {
    if (data) {
        NSAttributedString *attrString = [[NSAttributedString alloc] initWithData:data options:@{} documentAttributes:NULL error:NULL];
        if (attrString)
            [self setAttributedString:attrString];
    }
}

- (NSArray *)indicesOfObjectsByEvaluatingObjectSpecifier:(NSScriptObjectSpecifier *)specifier {
    // Workaround for Cocoa Scripting and AppleScript bugs.
    // Cocoa Scripting does not accept range specifiers whose start/end specifier have an absolute container specifier, but AppleScript does not accept range specifiers with relative container specifiers, so we cannot return those from PDFSelection
    if ([specifier isKindOfClass:[NSRangeSpecifier class]]) {
        NSScriptObjectSpecifier *childSpec = [(NSRangeSpecifier *)specifier startSpecifier];
        if ([childSpec containerSpecifier]) {
            [childSpec setContainerSpecifier:nil];
            [childSpec setContainerIsRangeContainerObject:YES];
        }
        childSpec = [(NSRangeSpecifier *)specifier endSpecifier];
        if ([childSpec containerSpecifier]) {
            [childSpec setContainerSpecifier:nil];
            [childSpec setContainerIsRangeContainerObject:YES];
        }
    }
    return nil;
}

@end

