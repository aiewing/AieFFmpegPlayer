//
//  Aie1Controller.m
//  FFmpegTest
//
//  Created by fenglixin on 2017/7/11.
//  Copyright © 2017年 times. All rights reserved.
//

#import "Aie1Controller.h"
#import "AieDecoder.h"
#import "AieGLView.h"

#define LOCAL_MIN_BUFFERED_DURATION   0.2
#define LOCAL_MAX_BUFFERED_DURATION   0.4

@interface Aie1Controller () <AieDecoderDelegate>
{
    AieDecoder * _decoder;
    dispatch_queue_t _dispatchQueue;
    NSMutableArray * _videoFrames;
    
    NSData * _currentAudioFrame;
    NSUInteger _currentAudioFramePos;
    
    AieGLView * _glView;
    
    CGFloat _bufferedDuration;
    CGFloat _minBufferedDuration;
    CGFloat _maxBufferedDuration;
    BOOL _buffered;
}

@property (nonatomic, copy) NSString * path;


@end

@implementation Aie1Controller

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    UIButton * aButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [aButton setTitle:@"start" forState:UIControlStateNormal];
    [aButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    aButton.frame = CGRectMake(100, 100, 50, 50);
    [aButton addTarget:self action:@selector(restorePlay) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:aButton];

    
    [self start];
}

- (void)start
{
    _path = [[NSBundle mainBundle] pathForResource:@"cuc_ieschool2" ofType:@"mp4"];
    
    __weak Aie1Controller * weakSelf = self;
    
    AieDecoder * decoder = [[AieDecoder alloc] init];
    decoder.delegate = self;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSError * error = nil;
        [decoder openFile:_path error:&error];
        
        __strong Aie1Controller * strongSelf = weakSelf;
        if (strongSelf)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf setMovieDecoder:decoder];
            });
        }
        
    });
}

- (void)setMovieDecoder:(AieDecoder *)decoder
{
    if (decoder)
    {
        _decoder = decoder;
        _dispatchQueue = dispatch_queue_create("AieMovie", DISPATCH_QUEUE_SERIAL);
        _videoFrames = [NSMutableArray array];
//        _audioFrames = [NSMutableArray array];
    }
    
    _minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
    _maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
    
    if (self.isViewLoaded)
    {
        [self setupPresentView];
    }
}

- (void)restorePlay
{
    // 两次播放 不然开始播放的时候容易卡顿
    [self play];
    [self play];
}

- (void)setupPresentView
{
    _glView = [[AieGLView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 200, 300, 200) decoder:_decoder];
    [self.view addSubview:_glView];
    
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)play
{
    // 解码视频 并把视频存储到_videoFrames
    [self asyncDecodeFrames];
    
    // 延迟0.1秒后 绘制_videoFrames中的图像
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self tick];
    });
    
    // 播放音频
//    [self enableAudio:YES];
}

- (void)asyncDecodeFrames
{
    __weak Aie1Controller * weakSelf = self;
    __weak AieDecoder * weakDecoder = _decoder;
    
    dispatch_async(_dispatchQueue, ^{

        // 当已经解码的视频总时间大于_maxBufferedDuration 停止解码
        BOOL good = YES;
        while (good) {
            good = NO;
            
            @autoreleasepool {
                __strong AieDecoder * strongDecoder = weakDecoder;
                
                if (strongDecoder) {
                    NSArray * frames = [strongDecoder decodeFrames:0.1];
                    
                    if (frames.count) {
                        __strong Aie1Controller * strongSelf = weakSelf;
                        
                        if (strongSelf) {
                            good = [strongSelf addFrames:frames];
                        }
                    }
                }
            }
        }
    });
}

- (BOOL)addFrames:(NSArray *)frames
{
    
    @synchronized (_videoFrames)
    {
        for (AieFrame * frame in frames)
        {
            if (frame.type == AieFrameTypeVideo)
            {
                [_videoFrames addObject:frame];
                
                _bufferedDuration += frame.duration;
            }
        }
    }
    
    return _bufferedDuration < _maxBufferedDuration;
}

- (void)tick
{
    // 返回当前播放帧的播放时间
    CGFloat interval = [self presentFrame];
    
    const NSUInteger leftFrames =_videoFrames.count;
    if (0 == leftFrames) {
        return;
    }
    // 当_videoFrames中已经没有解码过后的数据 或者剩余的时间小于_minBufferedDuration最小 就继续解码
    if (!leftFrames ||
        !(_bufferedDuration > _minBufferedDuration))
    {
        [self asyncDecodeFrames];
    }
    
    // 播放完一帧之后 继续播放下一帧 两帧之间的播放间隔不能小于0.01秒
    const NSTimeInterval time = MAX(interval, 0.01);
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        [self tick];
    });
}

- (CGFloat)presentFrame
{
    CGFloat interval = 0;
    AieVideoFrame * frame;
    
    @synchronized (_videoFrames) {
        if (_videoFrames.count > 0) {
            frame = _videoFrames[0];
            [_videoFrames removeObjectAtIndex:0];
            _bufferedDuration -= frame.duration;
        }
    }
    
    if (frame) {
        if (_glView) {
            [_glView render:frame];
        }
        interval = frame.duration;
    }
    return interval;
}





@end
