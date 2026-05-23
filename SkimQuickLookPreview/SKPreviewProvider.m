//
//  SKPreviewProvider.m
//  SkimQuickLookPreview
//
//  Created by Christiaan Hofman on 22/05/2026.
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

#import "SKPreviewProvider.h"
#import "SKQLConverter.h"

@implementation SKPreviewProvider

/*

 Use a QLPreviewProvider to provide data-based previews.
 
 To set up your extension as a data-based preview extension:

 - Modify the extension's Info.plist by setting
   <key>QLIsDataBasedPreview</key>
   <true/>
 
 - Add the supported content types to QLSupportedContentTypes array in the extension's Info.plist.

 - Change the NSExtensionPrincipalClass to this class.
   e.g.
   <key>NSExtensionPrincipalClass</key>
   <string>PreviewProvider</string>
 
 - Implement providePreviewForFileRequest:completionHandler:
 
 */

- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request completionHandler:(void (^)(QLPreviewReply *reply, NSError *error))handler
{
    NSURL *fileURL = [request fileURL];
    UTType *fileType = nil;
    QLPreviewReply *reply = nil;
    
    [fileURL getResourceValue:&fileType forKey:NSURLContentTypeKey error:NULL];
    
    if ([fileType conformsToType:[UTType typeWithIdentifier:@"net.sourceforge.skim-app.pdfd"]]) {
        
        NSURL *pdfURL = SKQLPDFURLForPDFBundleURL(fileURL);
        if (pdfURL)
            reply = [[QLPreviewReply alloc] initWithFileURL:pdfURL];
        
    } else if ([fileType conformsToType:[UTType typeWithIdentifier:@"net.sourceforge.skim-app.skimnotes"]]) {
        
        reply = [[QLPreviewReply alloc] initWithDataOfContentType:UTTypeHTML contentSize:CGSizeMake(800, 800) dataCreationBlock:^NSData *(QLPreviewReply *replyToUpdate, NSError **error) {
            NSData *data = [[NSData alloc] initWithContentsOfURL:fileURL options:NSDataReadingUncached error:NULL];
            if (data) {
                NSArray *notes = [SKQLConverter notesWithData:data];
                NSString *htmlString = [SKQLConverter htmlStringWithNotes:notes];
                if ((data = [htmlString dataUsingEncoding:NSUTF8StringEncoding])) {
                    NSSet *types = [NSSet setWithArray:[notes valueForKey:@"type"]];
                    NSMutableDictionary *attachments = [NSMutableDictionary dictionary];
                    NSBundle *bundle = [NSBundle mainBundle];
                    for (NSString *type in types) {
                        NSURL *imageURL = [bundle URLForImageResource:type];
                        if (imageURL) {
                            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
                            if (imageData) {
                                QLPreviewReplyAttachment *attachment = [[QLPreviewReplyAttachment alloc] initWithData:imageData contentType:UTTypePNG];
                                [attachments setObject:attachment forKey:[type stringByAppendingPathExtension:@"png"]];
                            }
                        }
                    }
                    [replyToUpdate setAttachments:attachments];
                    [replyToUpdate setStringEncoding:NSUTF8StringEncoding];
                    return data;
                }
            }
            return nil;
        }];
        
    } else if ([fileType conformsToType:[UTType typeWithIdentifier:@"com.adobe.postscript"]]) {
        
        if (@available(macOS 14.0, *)) {} else {
            reply = [[QLPreviewReply alloc] initWithDataOfContentType:UTTypePDF contentSize:CGSizeMake(800, 800) dataCreationBlock:^NSData *(QLPreviewReply *replyToUpdate, NSError **error) {
                bool converted = false;
                CGPSConverterCallbacks converterCallbacks = { 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL };
                CGPSConverterRef converter = CGPSConverterCreate(NULL, &converterCallbacks, NULL);
                CGDataProviderRef provider = CGDataProviderCreateWithURL((__bridge CFURLRef)fileURL);
                CFMutableDataRef data = CFDataCreateMutable(NULL, 0);
                CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData(data);
                if (provider != NULL && consumer != NULL)
                    converted = CGPSConverterConvert(converter, provider, consumer, NULL);
                CGDataProviderRelease(provider);
                CGDataConsumerRelease(consumer);
                CFRelease(converter);
                
                return converted ? CFBridgingRelease(data) : nil;
            }];
        }
    }

    handler(reply, nil);
}

@end

