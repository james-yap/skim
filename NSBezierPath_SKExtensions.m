//
//  NSBezierPath_SKExtensions.m
//  Skim
//
//  Created by Adam Maxwell on 10/22/05.
/*
 This software is Copyright (c) 2005
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "NSBezierPath_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"


@implementation NSBezierPath (SKExtensions)

- (NSArray *)dashPattern {
    NSInteger i, count = 0;
    NSMutableArray *array = [NSMutableArray array];
    [self getLineDash:NULL count:&count phase:NULL];
    if (count > 0) {
        CGFloat pattern[count];
        [self getLineDash:pattern count:&count phase:NULL];
        for (i = 0; i < count; i++)
            [array addObject:[NSNumber numberWithDouble:pattern[i]]];
    }
    return array;
}

- (void)setDashPattern:(NSArray *)newPattern {
    NSInteger i, count = [newPattern count];
    CGFloat pattern[count];
    for (i = 0; i< count; i++)
        pattern[i] = [[newPattern objectAtIndex:i] doubleValue];
    [self setLineDash:pattern count:count phase:0];
}

- (NSPoint)associatedPointForElementAtIndex:(NSUInteger)anIndex {
    NSPoint points[3];
    if (NSCurveToBezierPathElement == [self elementAtIndex:anIndex associatedPoints:points])
        return points[2];
    else
        return points[0];
}

- (NSRect)nonEmptyBounds {
    NSRect bounds = [self bounds];
    if (NSIsEmptyRect(bounds) && [self elementCount]) {
        NSPoint point, minPoint = NSZeroPoint, maxPoint = NSZeroPoint;
        NSUInteger i, count = [self elementCount];
        for (i = 0; i < count; i++) {
            point = [self associatedPointForElementAtIndex:i];
            if (i == 0) {
                minPoint = maxPoint = point;
            } else {
                minPoint.x = fmin(minPoint.x, point.x);
                minPoint.y = fmin(minPoint.y, point.y);
                maxPoint.x = fmax(maxPoint.x, point.x);
                maxPoint.y = fmax(maxPoint.y, point.y);
            }
        }
        bounds = NSMakeRect(minPoint.x - 0.1, minPoint.y - 0.1, maxPoint.x - minPoint.x + 0.2, maxPoint.y - minPoint.y + 0.2);
    }
    return bounds;
}

- (void)addToCGPath:(CGMutablePathRef)mutablePath transform:(const CGAffineTransform * __nullable)m {
    NSInteger numElements = [self elementCount];
    NSPoint points[3];
    NSInteger i;
    
    for (i = 0; i < numElements; i++) {
        switch ([self elementAtIndex:i associatedPoints:points]) {
            case NSMoveToBezierPathElement:
                CGPathMoveToPoint(mutablePath, m, points[0].x, points[0].y);
                break;
            case NSLineToBezierPathElement:
                CGPathAddLineToPoint(mutablePath, m, points[0].x, points[0].y);
                break;
            case NSCurveToBezierPathElement:
                CGPathAddCurveToPoint(mutablePath, m, points[0].x, points[0].y, points[1].x, points[1].y, points[2].x, points[2].y);
                break;
            case NSClosePathBezierPathElement:
                CGPathCloseSubpath(mutablePath);
                break;
        }
    }
}

// distance ratio for control points to approximate a quarter ellipse by a cubic bezier curve
#define KAPPA (4.0 * (M_SQRT2 - 1.0) / 3.0)

- (void)halfEllipseFromPoint:(NSPoint)halfwayPoint toPoint:(NSPoint)endPoint {
    NSPoint startPoint = [self currentPoint];
    NSPoint diff1 = NSMakePoint(KAPPA * (halfwayPoint.x - 0.5 * (endPoint.x + startPoint.x)), KAPPA * (halfwayPoint.y - 0.5 * (endPoint.y + startPoint.y)));
    NSPoint diff2 = NSMakePoint(KAPPA * 0.5 * (endPoint.x - startPoint.x), KAPPA * 0.5 * (endPoint.y - startPoint.y));
    [self curveToPoint:halfwayPoint controlPoint1:SKAddPoints(startPoint, diff1) controlPoint2:SKSubstractPoints(halfwayPoint, diff2)];
    [self curveToPoint:endPoint controlPoint1:SKAddPoints(halfwayPoint, diff2) controlPoint2:SKAddPoints(endPoint, diff1)];
}

+ (NSBezierPath *)openHandBezierPath {
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(12.5559, 15.4258)];
    [path curveToPoint:NSMakePoint(12.1496, 16.9777) controlPoint1:NSMakePoint(12.4578, 15.8008) controlPoint2:NSMakePoint(12.3598, 16.2727)];
    [path curveToPoint:NSMakePoint(11.6797, 18.2109) controlPoint1:NSMakePoint(11.9828, 17.5348) controlPoint2:NSMakePoint(11.8078, 17.8367)];
    [path curveToPoint:NSMakePoint(11.1836, 19.3918) controlPoint1:NSMakePoint(11.5246, 18.6656) controlPoint2:NSMakePoint(11.3766, 18.9316)];
    [path curveToPoint:NSMakePoint(10.7266, 20.8316) controlPoint1:NSMakePoint(11.0445, 19.7207) controlPoint2:NSMakePoint(10.8195, 20.4398)];
    [path curveToPoint:NSMakePoint(10.9707, 22.0379) controlPoint1:NSMakePoint(10.6078, 21.3406) controlPoint2:NSMakePoint(10.7598, 21.7559)];
    [path curveToPoint:NSMakePoint(12.3277, 22.3887) controlPoint1:NSMakePoint(11.2238, 22.377) controlPoint2:NSMakePoint(11.9328, 22.5277)];
    [path curveToPoint:NSMakePoint(13.2438, 21.6008) controlPoint1:NSMakePoint(12.6988, 22.259) controlPoint2:NSMakePoint(13.0719, 21.877)];
    [path curveToPoint:NSMakePoint(13.9605, 20.059) controlPoint1:NSMakePoint(13.5316, 21.1406) controlPoint2:NSMakePoint(13.6008, 20.9688)];
    [path curveToPoint:NSMakePoint(14.5719, 17.8277) controlPoint1:NSMakePoint(14.3535, 19.0668) controlPoint2:NSMakePoint(14.5246, 18.1406)];
    [path lineToPoint:NSMakePoint(14.6566, 17.3758)];
    [path curveToPoint:NSMakePoint(14.6129, 18.5379) controlPoint1:NSMakePoint(14.6559, 17.4156) controlPoint2:NSMakePoint(14.6137, 18.4977)];
    [path curveToPoint:NSMakePoint(14.5746, 21.477) controlPoint1:NSMakePoint(14.5777, 19.5668) controlPoint2:NSMakePoint(14.5527, 20.3609)];
    [path curveToPoint:NSMakePoint(14.6586, 22.1918) controlPoint1:NSMakePoint(14.5766, 21.6027) controlPoint2:NSMakePoint(14.6387, 22.0637)];
    [path curveToPoint:NSMakePoint(15.3316, 23.1707) controlPoint1:NSMakePoint(14.7367, 22.6918) controlPoint2:NSMakePoint(14.9637, 22.9918)];
    [path curveToPoint:NSMakePoint(16.7328, 23.1879) controlPoint1:NSMakePoint(15.7438, 23.3719) controlPoint2:NSMakePoint(16.2578, 23.3859)];
    [path curveToPoint:NSMakePoint(17.4195, 22.1656) controlPoint1:NSMakePoint(17.1559, 23.0148) controlPoint2:NSMakePoint(17.3586, 22.6379)];
    [path curveToPoint:NSMakePoint(17.5129, 21.059) controlPoint1:NSMakePoint(17.4336, 22.0566) controlPoint2:NSMakePoint(17.5137, 21.1789)];
    [path curveToPoint:NSMakePoint(17.5277, 18.8848) controlPoint1:NSMakePoint(17.4996, 20.034) controlPoint2:NSMakePoint(17.5188, 19.418)];
    [path curveToPoint:NSMakePoint(17.5445, 17.4156) controlPoint1:NSMakePoint(17.5316, 18.6539) controlPoint2:NSMakePoint(17.5309, 17.2598)];
    [path curveToPoint:NSMakePoint(17.8887, 21.3578) controlPoint1:NSMakePoint(17.6059, 18.0719) controlPoint2:NSMakePoint(17.6387, 20.6047)];
    [path curveToPoint:NSMakePoint(18.6828, 22.2867) controlPoint1:NSMakePoint(18.0328, 21.7906) controlPoint2:NSMakePoint(18.2938, 22.1039)];
    [path curveToPoint:NSMakePoint(20.0867, 22.0438) controlPoint1:NSMakePoint(19.1137, 22.4898) controlPoint2:NSMakePoint(19.7957, 22.3566)];
    [path curveToPoint:NSMakePoint(20.5688, 20.8906) controlPoint1:NSMakePoint(20.3719, 21.7387) controlPoint2:NSMakePoint(20.5328, 21.352)];
    [path curveToPoint:NSMakePoint(20.5488, 19.6457) controlPoint1:NSMakePoint(20.6008, 20.4859) controlPoint2:NSMakePoint(20.5496, 19.9938)];
    [path curveToPoint:NSMakePoint(20.5117, 17.5246) controlPoint1:NSMakePoint(20.5488, 18.7789) controlPoint2:NSMakePoint(20.5277, 18.3219)];
    [path curveToPoint:NSMakePoint(20.5348, 17.343) controlPoint1:NSMakePoint(20.5105, 17.4867) controlPoint2:NSMakePoint(20.4969, 17.227)];
    [path curveToPoint:NSMakePoint(20.8008, 18.0879) controlPoint1:NSMakePoint(20.6285, 17.6227) controlPoint2:NSMakePoint(20.7227, 17.8848)];
    [path curveToPoint:NSMakePoint(21.1598, 18.9469) controlPoint1:NSMakePoint(20.8496, 18.2129) controlPoint2:NSMakePoint(21.0418, 18.702)];
    [path curveToPoint:NSMakePoint(21.5746, 19.6348) controlPoint1:NSMakePoint(21.2738, 19.1809) controlPoint2:NSMakePoint(21.3707, 19.3156)];
    [path curveToPoint:NSMakePoint(22.2426, 20.1957) controlPoint1:NSMakePoint(21.7746, 19.9477) controlPoint2:NSMakePoint(21.9898, 20.0828)];
    [path curveToPoint:NSMakePoint(23.5438, 19.6047) controlPoint1:NSMakePoint(22.7828, 20.4309) controlPoint2:NSMakePoint(23.3516, 20.084)];
    [path curveToPoint:NSMakePoint(23.5156, 18.4996) controlPoint1:NSMakePoint(23.6297, 19.3898) controlPoint2:NSMakePoint(23.5527, 18.8918)];
    [path curveToPoint:NSMakePoint(23.1637, 16.852) controlPoint1:NSMakePoint(23.4547, 17.8527) controlPoint2:NSMakePoint(23.2617, 17.1938)];
    [path curveToPoint:NSMakePoint(22.8238, 15.2508) controlPoint1:NSMakePoint(23.0355, 16.4047) controlPoint2:NSMakePoint(22.8898, 15.6168)];
    [path curveToPoint:NSMakePoint(22.4648, 13.4309) controlPoint1:NSMakePoint(22.7516, 14.8566) controlPoint2:NSMakePoint(22.5898, 13.8688)];
    [path curveToPoint:NSMakePoint(21.8129, 12.0469) controlPoint1:NSMakePoint(22.3785, 13.1297) controlPoint2:NSMakePoint(22.0938, 12.4527)];
    [path curveToPoint:NSMakePoint(20.6207, 10.2348) controlPoint1:NSMakePoint(21.8129, 12.0469) controlPoint2:NSMakePoint(20.7387, 10.7969)];
    [path curveToPoint:NSMakePoint(20.5195, 9.26992) controlPoint1:NSMakePoint(20.5035, 9.67188) controlPoint2:NSMakePoint(20.5426, 9.66797)];
    [path curveToPoint:NSMakePoint(20.6406, 8.34688) controlPoint1:NSMakePoint(20.4957, 8.8707) controlPoint2:NSMakePoint(20.4957, 8.8707)];
    [path curveToPoint:NSMakePoint(19.4066, 8.31289) controlPoint1:NSMakePoint(20.6406, 8.34688) controlPoint2:NSMakePoint(19.8387, 8.24297)];
    [path curveToPoint:NSMakePoint(18.4066, 9.39063) controlPoint1:NSMakePoint(19.0156, 8.37461) controlPoint2:NSMakePoint(18.5316, 9.15391)];
    [path curveToPoint:NSMakePoint(17.7246, 9.41367) controlPoint1:NSMakePoint(18.2348, 9.71875) controlPoint2:NSMakePoint(17.8676, 9.65586)];
    [path curveToPoint:NSMakePoint(16.6738, 8.30078) controlPoint1:NSMakePoint(17.4996, 9.03086) controlPoint2:NSMakePoint(17.0156, 8.34375)];
    [path curveToPoint:NSMakePoint(13.5348, 8.28086) controlPoint1:NSMakePoint(16.0059, 8.2168) controlPoint2:NSMakePoint(14.6195, 8.2707)];
    [path curveToPoint:NSMakePoint(13.3078, 9.63867) controlPoint1:NSMakePoint(13.5348, 8.28086) controlPoint2:NSMakePoint(13.7195, 9.2918)];
    [path curveToPoint:NSMakePoint(12.1637, 10.6988) controlPoint1:NSMakePoint(13.0027, 9.89883) controlPoint2:NSMakePoint(12.4777, 10.4227)];
    [path lineToPoint:NSMakePoint(11.3316, 11.6199)];
    [path curveToPoint:NSMakePoint(10.0887, 13.6047) controlPoint1:NSMakePoint(11.0477, 11.9797) controlPoint2:NSMakePoint(10.7027, 12.7129)];
    [path curveToPoint:NSMakePoint(8.80469, 15.184) controlPoint1:NSMakePoint(9.74063, 14.109) controlPoint2:NSMakePoint(9.06172, 14.6898)];
    [path curveToPoint:NSMakePoint(8.61484, 16.509) controlPoint1:NSMakePoint(8.58164, 15.609) controlPoint2:NSMakePoint(8.47383, 16.1379)];
    [path curveToPoint:NSMakePoint(9.97656, 17.3406) controlPoint1:NSMakePoint(8.83984, 17.1027) controlPoint2:NSMakePoint(9.28984, 17.4059)];
    [path curveToPoint:NSMakePoint(11.2148, 16.8039) controlPoint1:NSMakePoint(10.4957, 17.2906) controlPoint2:NSMakePoint(10.8246, 17.1348)];
    [path curveToPoint:NSMakePoint(11.9648, 16.0559) controlPoint1:NSMakePoint(11.4398, 16.6137) controlPoint2:NSMakePoint(11.7879, 16.2699)];
    [path curveToPoint:NSMakePoint(12.3418, 15.5469) controlPoint1:NSMakePoint(12.1277, 15.8609) controlPoint2:NSMakePoint(12.1676, 15.7797)];
    [path curveToPoint:NSMakePoint(12.5559, 15.4258) controlPoint1:NSMakePoint(12.5719, 15.2398) controlPoint2:NSMakePoint(12.6438, 15.0879)];
    [path closePath];
    [path setLineJoinStyle:NSRoundLineJoinStyle];
    [path setLineCapStyle:NSRoundLineCapStyle];
    return path;
}

+ (NSBezierPath *)closedHandBezierPath {
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(12.573, 18.9641)];
    [path curveToPoint:NSMakePoint(14.2504, 18.491) controlPoint1:NSMakePoint(13.0531, 19.1418) controlPoint2:NSMakePoint(14.0004, 19.0328)];
    [path curveToPoint:NSMakePoint(14.6563, 17.416) controlPoint1:NSMakePoint(14.4633, 18.0289) controlPoint2:NSMakePoint(14.6461, 17.25)];
    [path curveToPoint:NSMakePoint(14.7934, 19.) controlPoint1:NSMakePoint(14.6801, 17.7848) controlPoint2:NSMakePoint(14.632, 18.5828)];
    [path curveToPoint:NSMakePoint(15.4793, 19.691) controlPoint1:NSMakePoint(14.9102, 19.3039) controlPoint2:NSMakePoint(15.1402, 19.5898)];
    [path curveToPoint:NSMakePoint(16.3953, 19.7461) controlPoint1:NSMakePoint(15.7641, 19.777) controlPoint2:NSMakePoint(16.0992, 19.807)];
    [path curveToPoint:NSMakePoint(17.1602, 19.2469) controlPoint1:NSMakePoint(16.7082, 19.682) controlPoint2:NSMakePoint(17.0371, 19.459)];
    [path curveToPoint:NSMakePoint(17.5453, 17.416) controlPoint1:NSMakePoint(17.5223, 18.6238) controlPoint2:NSMakePoint(17.5281, 17.348)];
    [path curveToPoint:NSMakePoint(17.8281, 19.) controlPoint1:NSMakePoint(17.6094, 17.6879) controlPoint2:NSMakePoint(17.6152, 18.6449)];
    [path curveToPoint:NSMakePoint(18.5152, 19.4789) controlPoint1:NSMakePoint(17.9691, 19.2348) controlPoint2:NSMakePoint(18.3254, 19.4449)];
    [path curveToPoint:NSMakePoint(19.4793, 19.4867) controlPoint1:NSMakePoint(18.8094, 19.5309) controlPoint2:NSMakePoint(19.1711, 19.5469)];
    [path curveToPoint:NSMakePoint(20.1563, 19.) controlPoint1:NSMakePoint(19.7281, 19.4379) controlPoint2:NSMakePoint(20.0652, 19.143)];
    [path curveToPoint:NSMakePoint(20.5352, 17.3418) controlPoint1:NSMakePoint(20.3754, 18.6559) controlPoint2:NSMakePoint(20.498, 17.684)];
    [path curveToPoint:NSMakePoint(20.8281, 18.0777) controlPoint1:NSMakePoint(20.5512, 17.2008) controlPoint2:NSMakePoint(20.6094, 17.7348)];
    [path curveToPoint:NSMakePoint(22.7262, 17.4391) controlPoint1:NSMakePoint(21.2344, 18.7168) controlPoint2:NSMakePoint(22.6723, 18.841)];
    [path curveToPoint:NSMakePoint(22.7461, 16.375) controlPoint1:NSMakePoint(22.7523, 16.7848) controlPoint2:NSMakePoint(22.7461, 16.8148)];
    [path curveToPoint:NSMakePoint(22.7063, 15.173) controlPoint1:NSMakePoint(22.7461, 15.859) controlPoint2:NSMakePoint(22.7344, 15.5469)];
    [path curveToPoint:NSMakePoint(22.4652, 13.4309) controlPoint1:NSMakePoint(22.6762, 14.7738) controlPoint2:NSMakePoint(22.5902, 13.8688)];
    [path curveToPoint:NSMakePoint(21.8121, 12.0469) controlPoint1:NSMakePoint(22.3793, 13.1301) controlPoint2:NSMakePoint(22.0941, 12.4527)];
    [path curveToPoint:NSMakePoint(20.6211, 10.2348) controlPoint1:NSMakePoint(21.8121, 12.0469) controlPoint2:NSMakePoint(20.7383, 10.7969)];
    [path curveToPoint:NSMakePoint(20.5191, 9.26992) controlPoint1:NSMakePoint(20.5043, 9.67188) controlPoint2:NSMakePoint(20.5434, 9.66797)];
    [path curveToPoint:NSMakePoint(20.6402, 8.34688) controlPoint1:NSMakePoint(20.4961, 8.87109) controlPoint2:NSMakePoint(20.4961, 8.87109)];
    [path curveToPoint:NSMakePoint(19.4063, 8.31289) controlPoint1:NSMakePoint(20.6402, 8.34688) controlPoint2:NSMakePoint(19.8391, 8.24297)];
    [path curveToPoint:NSMakePoint(18.4063, 9.39102) controlPoint1:NSMakePoint(19.0152, 8.375) controlPoint2:NSMakePoint(18.5313, 9.15273)];
    [path curveToPoint:NSMakePoint(17.7242, 9.41406) controlPoint1:NSMakePoint(18.2344, 9.71875) controlPoint2:NSMakePoint(17.8672, 9.65586)];
    [path curveToPoint:NSMakePoint(16.6742, 8.30078) controlPoint1:NSMakePoint(17.5004, 9.03086) controlPoint2:NSMakePoint(17.0152, 8.34375)];
    [path curveToPoint:NSMakePoint(13.5344, 8.28086) controlPoint1:NSMakePoint(16.0051, 8.2168) controlPoint2:NSMakePoint(14.6191, 8.27109)];
    [path curveToPoint:NSMakePoint(13.307, 9.63906) controlPoint1:NSMakePoint(13.5344, 8.28086) controlPoint2:NSMakePoint(13.7191, 9.2918)];
    [path curveToPoint:NSMakePoint(12.1633, 10.6988) controlPoint1:NSMakePoint(13.0023, 9.89883) controlPoint2:NSMakePoint(12.4773, 10.423)];
    [path lineToPoint:NSMakePoint(11.3313, 11.6199)];
    [path curveToPoint:NSMakePoint(10.0883, 13.6051) controlPoint1:NSMakePoint(11.048, 11.9801) controlPoint2:NSMakePoint(10.3293, 12.5488)];
    [path curveToPoint:NSMakePoint(10.1254, 15.375) controlPoint1:NSMakePoint(9.87539, 14.541) controlPoint2:NSMakePoint(9.89609, 15.)];
    [path curveToPoint:NSMakePoint(10.9793, 16.) controlPoint1:NSMakePoint(10.357, 15.7559) controlPoint2:NSMakePoint(10.7953, 15.9641)];
    [path curveToPoint:NSMakePoint(11.8543, 15.9379) controlPoint1:NSMakePoint(11.1871, 16.0418) controlPoint2:NSMakePoint(11.6711, 16.0391)];
    [path curveToPoint:NSMakePoint(12.3422, 15.5469) controlPoint1:NSMakePoint(12.0773, 15.8148) controlPoint2:NSMakePoint(12.1672, 15.7789)];
    [path curveToPoint:NSMakePoint(12.5551, 15.4258) controlPoint1:NSMakePoint(12.5723, 15.2398) controlPoint2:NSMakePoint(12.6543, 15.091)];
    [path curveToPoint:NSMakePoint(12.1211, 16.3961) controlPoint1:NSMakePoint(12.4793, 15.6879) controlPoint2:NSMakePoint(12.2332, 16.0211)];
    [path curveToPoint:NSMakePoint(11.741, 17.9219) controlPoint1:NSMakePoint(12.0121, 16.757) controlPoint2:NSMakePoint(11.7203, 17.3391)];
    [path curveToPoint:NSMakePoint(12.573, 18.9641) controlPoint1:NSMakePoint(11.7492, 18.143) controlPoint2:NSMakePoint(11.8441, 18.693)];
    [path closePath];
    [path setLineJoinStyle:NSRoundLineJoinStyle];
    [path setLineCapStyle:NSRoundLineCapStyle];
    return path;
}

@end

