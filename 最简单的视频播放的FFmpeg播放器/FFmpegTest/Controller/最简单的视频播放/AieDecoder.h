//
//  AieDecoder.h
//  FFmpegTest
//
//  Created by fenglixin on 2017/7/11.
//  Copyright © 2017年 times. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum {
   AieFrameTypeAudio,
    AieFrameTypeVideo,
}AieFrameType;

typedef enum {
    AieVideoFrameFormatRGB,
    AieVideoFrameFormatYUV,
}AieVideoFrameFormat;

@interface AieFrame : NSObject
@property (nonatomic, assign) AieFrameType type;
@property (nonatomic, assign) CGFloat position;
@property (nonatomic, assign) CGFloat duration;
@end

@interface AieAudioFrame : AieFrame
@property (nonatomic, strong) NSData * samples;
@end

@interface AieVideoFrame : AieFrame
@property (nonatomic, assign) AieVideoFrameFormat format;
@property (nonatomic, assign) NSUInteger width;
@property (nonatomic, assign) NSUInteger height;
@end

@interface AieVideoFrameRGB : AieVideoFrame
@property (nonatomic, assign) NSUInteger linesize;
@property (nonatomic, strong) NSData * rgb;
@end

@interface AieVideoFrameYUV : AieVideoFrame
@property (nonatomic, strong) NSData * luma;
@property (nonatomic, strong) NSData * chromaB;
@property (nonatomic, strong) NSData * chromaR;
@end


@protocol AieDecoderDelegate

- (void)getYUV420Data:(void *)pData width:(int)width height:(int)height;

@end

@interface AieDecoder : NSObject

@property (nonatomic, weak) __weak id<AieDecoderDelegate> delegate;

@property (nonatomic, strong, readonly) NSString * path;
@property (nonatomic, assign) CGFloat fps;

@property (nonatomic, assign) NSUInteger frameWidth;
@property (nonatomic, assign) NSUInteger frameHeight;

- (BOOL)setupVideoFrameFormat:(AieVideoFrameFormat)format;
- (BOOL)openFile:(NSString *)path error:(NSError **)perror;
- (NSArray *)decodeFrames:(CGFloat)minDuration;
@end


