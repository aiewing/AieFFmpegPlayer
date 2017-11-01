//
//  AieDecoder.m
//  FFmpegTest
//
//  Created by fenglixin on 2017/7/11.
//  Copyright © 2017年 times. All rights reserved.
//

#import "AieDecoder.h"
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#import "KxAudioManager.h"
#import <Accelerate/Accelerate.h>

@interface AieFrame ()

@end
@implementation AieFrame

@end

@interface AieVideoFrame ()

@end
@implementation AieVideoFrame

@end

@interface AieVideoFrameYUV ()

@end
@implementation AieVideoFrameYUV

@end

static void FFLog(void* context, int level, const char* format, va_list args);
@interface AieDecoder ()
{
    AVFormatContext * _formatCtx;
    AVCodecContext * _videoCodecCtx;

    AVFrame * _videoFrame;

    
    NSInteger _videoStream;

    
    CGFloat _videoTimeBase;

    CGFloat _position;
    
    NSArray * _videoStreams;
    
    SwrContext * _swrContext;
    void * _swrbuffer;
    NSUInteger _swrBufferSize;
    
    AieVideoFrameFormat _videoFrameFormat;
}

@end
@implementation AieDecoder

static void FFLog(void* context, int level, const char* format, va_list args) {
    @autoreleasepool {
        
        
    }
}

+ (void)initialize
{
    av_log_set_callback(FFLog);
    av_register_all();
    avformat_network_init();
}

- (NSUInteger)frameWidth
{
    return _videoCodecCtx ? _videoCodecCtx->width : 0;
}

- (NSUInteger)frameHeight
{
    return _videoCodecCtx ? _videoCodecCtx->height : 0;
}

#pragma mark - Public
- (BOOL)setupVideoFrameFormat:(AieVideoFrameFormat)format
{
    if (format == AieVideoFrameFormatYUV &&
        _videoCodecCtx &&
        (_videoCodecCtx->pix_fmt == AV_PIX_FMT_YUV420P ||
         _videoCodecCtx->pix_fmt == AV_PIX_FMT_YUVJ420P))
    {
        _videoFrameFormat = AieVideoFrameFormatYUV;
        return YES;
    }
    
    _videoFrameFormat = AieVideoFrameFormatRGB;
    return _videoFrameFormat == format;
}

// 打开文件
- (BOOL)openFile:(NSString *)path error:(NSError **)perror
{
    _path = path;
    
    if (![self openInput:path])
    {
        return NO;
    }
    
    // 打开音视频流
    if (![self openVideoStream])
    {
        return NO;
    }
    
    return YES;
}

- (NSArray *)decodeFrames:(CGFloat)minDuration
{
    if (_videoStream == -1) {
        return nil;
    }
    
    NSMutableArray * result = [NSMutableArray array];
    AVPacket packet;
    CGFloat decodedDuration = 0;
    BOOL finished = NO;
    
    while (!finished) {
        if (av_read_frame(_formatCtx, &packet) < 0) {
            NSLog(@"读取Frame失败");
            break;
        }
        
        if (packet.stream_index == _videoStream) {

            int pktSize = packet.size;
            while (pktSize > 0) {
                int gotFrame = 0;
                int len = avcodec_decode_video2(_videoCodecCtx, _videoFrame, &gotFrame, &packet);
                
                if (len < 0) {
                    NSLog(@"解码失败");
                    break;
                }
                
                if (gotFrame) {
                    AieVideoFrame * frame = [self handleVideoFrame];
                    frame.type = AieFrameTypeVideo;
                    NSLog(@"当前帧的时间戳:%f, 当前帧的持续时间:%f", frame.position, frame.duration);
                    
                    if (frame) {
                        [result addObject:frame];
                        
                        _position = frame.position;
                        decodedDuration += frame.duration;
                        if (decodedDuration > minDuration) {
                            finished = YES;
                        }
                    }
                }
                
                if (0 == len) {
                    break;
                }
                
                pktSize -= len;
                
            }
        }
        
        av_free_packet(&packet);
    }
    
    return result;
}

#pragma mark - private

- (BOOL)openInput:(NSString *)path
{
    AVFormatContext * formatCtx = NULL;
    
    formatCtx = avformat_alloc_context();
    if (!formatCtx)
    {
        NSLog(@"打开文件失败");
        return NO;
    }
    
    if (avformat_open_input(&formatCtx, [path cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL) < 0)
    {
        if (formatCtx)
        {
            avformat_free_context(formatCtx);
        }
        NSLog(@"打开文件失败");
        return NO;
    }
    
    if (avformat_find_stream_info(formatCtx, NULL) < 0)
    {
        avformat_close_input(&formatCtx);
        NSLog(@"无法获取流信息");
        return NO;
    }
    
    av_dump_format(formatCtx, 0, [path.lastPathComponent cStringUsingEncoding:NSUTF8StringEncoding], false);
    
    _formatCtx = formatCtx;
    
    return YES;
}

// 打开视频流
- (BOOL)openVideoStream
{
    BOOL resual = YES;
    
    _videoStream = -1;
    _videoStreams = collectStreams(_formatCtx, AVMEDIA_TYPE_VIDEO);
    for (NSNumber * n in _videoStreams)
    {
        const NSUInteger iStream = n.integerValue;
        
        if (0 == (_formatCtx->streams[iStream]->disposition &
                  AV_DISPOSITION_ATTACHED_PIC))
        {
            resual = [self openVideoStream:iStream];
            if (resual)
            {
                break;
            }
        }
    }
    
    return YES;
}

- (BOOL)openVideoStream:(NSInteger)videoStream
{
    AVCodecContext * codecCtx = _formatCtx->streams[videoStream]->codec;
    
    AVCodec * codec = avcodec_find_decoder(codecCtx->codec_id);
    if (!codec)
    {
        NSLog(@"无法找到解码器");
        return NO;
    }
    
    if (avcodec_open2(codecCtx, codec, NULL) < 0)
    {
        NSLog(@"打开解码器失败");
        return YES;
    }
    
    _videoFrame = av_frame_alloc();
    if (!_videoFrame)
    {
        avcodec_close(codecCtx);
        NSLog(@"创建视频帧失败");
        return NO;
    }
    
    _videoStream = videoStream;
    _videoCodecCtx = codecCtx;
    
    // 计算 fps 帧率
    AVStream * st = _formatCtx->streams[_videoStream];
    avStreamFPSTimeBase(st, 0.04, &_fps, &_videoTimeBase);
    
    return YES;
}


- (AieVideoFrame *)handleVideoFrame
{
    if (!_videoFrame->data[0]) {
        return nil;
    }
    
    AieVideoFrame * frame;
    if (_videoFrameFormat == AieVideoFrameFormatYUV) {
        AieVideoFrameYUV * yuvFrame = [[AieVideoFrameYUV alloc] init];
        
        yuvFrame.luma = copyFrameData(_videoFrame->data[0],
                                      _videoFrame->linesize[0],
                                      _videoCodecCtx->width,
                                      _videoCodecCtx->height);
        
        yuvFrame.chromaB = copyFrameData(_videoFrame->data[1],
                                      _videoFrame->linesize[1],
                                      _videoCodecCtx->width / 2,
                                      _videoCodecCtx->height / 2);
        
        yuvFrame.chromaR = copyFrameData(_videoFrame->data[2],
                                      _videoFrame->linesize[2],
                                      _videoCodecCtx->width / 2,
                                      _videoCodecCtx->height / 2);
        
        frame = yuvFrame;
    }
    
    frame.width = _videoCodecCtx->width;
    frame.height = _videoCodecCtx->height;
    // 以流中的时间为基础 预估的时间戳
    frame.position = av_frame_get_best_effort_timestamp(_videoFrame) * _videoTimeBase;
    
    // 获取当前帧的持续时间
    const int64_t frameDuration = av_frame_get_pkt_duration(_videoFrame);
    
    if (frameDuration) {
        frame.duration = frameDuration * _videoTimeBase;
        frame.duration += _videoFrame->repeat_pict * _videoTimeBase * 0.5;
    }
    else {
        frame.duration = 1.0 / _fps;
    }
    return frame;
}

static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase)
{
    CGFloat fps, timebase;
    
    // ffmpeg提供了一个把AVRatioal结构转换成double的函数
    // 默认0.04 意思就是25帧
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(st->codec->time_base.den && st->codec->time_base.num)
        timebase = av_q2d(st->codec->time_base);
    else
        timebase = defaultTimeBase;
    
    if (st->codec->ticks_per_frame != 1)
    {
        
    }
    
    // 平均帧率
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    if (pFPS)
        *pFPS = fps;
    if (pTimeBase)
        *pTimeBase = timebase;
}


static NSArray * collectStreams(AVFormatContext * formatCtx, enum AVMediaType codecType)
{
    NSMutableArray * ma = [NSMutableArray array];
    for (NSInteger i = 0; i < formatCtx->nb_streams; i++)
    {
        if (codecType == formatCtx->streams[i]->codec->codec_type)
        {
            [ma addObject:[NSNumber numberWithInteger:i]];
        }
    }
    return [ma copy];
}

static NSData * copyFrameData(UInt8 *src, int linesize, int width, int height)
{
    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength: width * height];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i)
    {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return md;
}


@end
