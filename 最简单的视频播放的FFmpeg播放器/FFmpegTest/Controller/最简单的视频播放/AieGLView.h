//
//  AieGLView.h
//  FFmpegTest
//
//  Created by fenglixin on 2017/7/12.
//  Copyright © 2017年 times. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AieDecoder.h"

@interface AieGLView : UIView

- (id) initWithFrame:(CGRect)frame
             decoder: (AieDecoder *) decoder;

- (void) render: (AieVideoFrame *) frame;

@end
