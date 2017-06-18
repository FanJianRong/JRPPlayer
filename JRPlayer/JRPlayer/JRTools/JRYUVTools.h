//
//  JRYUVTools.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/8.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "pixfmt.h"

int JRYUVChannelFilterNeedSize(int linesize, int width, int height, int channel_count);

void JRYUVChannelFilter(UInt8 * src, int linesize, int width, int height, UInt8 * dst, size_t dstsize, int channel_count);

UIImage * JRYUVConvertToImage(UInt8 * src_data[], int src_linesize[], int width, int height, enum AVPixelFormat pixelFormat);
