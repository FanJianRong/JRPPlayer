//
//  JRImageTool.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/8.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <UIKit/UIKit.h>

UIImage *imageWithCGImage(CGImageRef image);


// CVPixelBufferRef
UIImage *imageWithCVPixelBuffer(CVPixelBufferRef pixelBufferRef);
CIImage *imageCIImageWithCVPixelBuffer(CVPixelBufferRef pixelBuffer);
CGImageRef imageCGImageWithCVPixelBuffer(CVPixelBufferRef pixelBuffer);

// RGB data buffer
UIImage *imageWithRGBData(UInt8 *rgb_data, int linesize, int width, int height);
CGImageRef cgimageWithRGBData(UInt8 *rgb_data, int linesize, int width, int height);
