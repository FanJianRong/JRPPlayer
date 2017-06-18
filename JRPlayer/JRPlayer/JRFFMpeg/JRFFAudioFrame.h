//
//  JRFFAudioFrame.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/16.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import "JRFFFrame.h"

@interface JRFFAudioFrame : JRFFFrame

{
@public
    float *samples;
    int length;
    int output_offset;
}

- (void)setSamplesLength:(NSUInteger)samplesLength;

@end
