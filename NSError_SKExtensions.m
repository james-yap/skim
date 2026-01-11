//
//  NSError_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 1/21/11.
/*
 This software is Copyright (c) 2011
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

#import "NSError_SKExtensions.h"

NSErrorDomain const SKDocumentErrorDomain = @"SKDocumentErrorDomain";

#define ELLIPSIS_CHARACTER (unichar)0x2026

@implementation NSError (SKExtensions)

+ (instancetype)documentErrorWithCode:(NSInteger)code localizedDescription:(NSString *)description {
    return [NSError errorWithDomain:SKDocumentErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description}];
}

+ (instancetype)userCancelledErrorWithUnderlyingError:(NSError *)error {
    return [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:error, NSUnderlyingErrorKey, nil]];
}

+ (NSError *)combineErrors:(NSArray *)errors maximum:(NSUInteger)max {
    NSError *error = [errors firstObject];
    if ([errors count] > 1) {
        NSMutableDictionary *userInfo = [[error userInfo] mutableCopy];
        NSString *description;
        NSMutableArray *descriptions = [NSMutableArray array];
        for (NSError *err in errors) {
            NSString *desc = [err localizedDescription];
            if ([descriptions containsObject:desc] == NO)
                [descriptions addObject:desc];
        }
        if ([descriptions count] > max)
            description = [[[descriptions subarrayWithRange:NSMakeRange(0, max)] componentsJoinedByString:@"\n"] stringByAppendingFormat:@"\n%C", ELLIPSIS_CHARACTER];
        else
            description = [descriptions componentsJoinedByString:@"\n"];
        [userInfo setObject:description forKey:NSLocalizedDescriptionKey];
        error = [NSError errorWithDomain:[error domain] code:[error code] userInfo:userInfo];
    }
    return error;
}

- (BOOL)isUserCancelledError {
    return [[self domain] isEqualToString:NSCocoaErrorDomain] && [self code] == NSUserCancelledError;
}

@end
