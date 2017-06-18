//
//  JRImageTool.m
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/8.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import "JRImageTools.h"

UIImage *imageWithCGImage(CGImageRef image)
{
    return [UIImage imageWithCGImage:image];
}

// CVPixelBufferRef
UIImage *imageWithCVPixelBuffer(CVPixelBufferRef pixelBufferRef)
{
    CIImage *ciImage = imageCIImageWithCVPixelBuffer(pixelBufferRef);
    if (!ciImage) {
        return nil;
    }
    return [UIImage imageWithCIImage:ciImage];
}

CIImage *imageCIImageWithCVPixelBuffer(CVPixelBufferRef pixelBuffer)
{
    CIImage *image = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    return image;
}

CGImageRef imageCGImageWithCVPixelBuffer(CVPixelBufferRef pixelBuffer)
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    size_t count = CVPixelBufferGetPlaneCount(pixelBuffer);
    if (count > 1) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return nil;
    }
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress,
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return imageRef;
}

// RGB data buffer
UIImage *imageWithRGBData(UInt8 *rgb_data, int linesize, int width, int height)
{
    CGImageRef imageRef = cgimageWithRGBData(rgb_data, linesize, width, height);
    if (!imageRef) {
        return nil;
    }
    UIImage *image = imageWithCGImage(imageRef);
    CGImageRelease(imageRef);
    return image;
}

CGImageRef cgimageWithRGBData(UInt8 *rgb_data, int linesize, int width, int height)
{
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, rgb_data, linesize * height);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageRef = CGImageCreate(width,
                                        height,
                                        8,
                                        24,
                                        linesize,
                                        colorSpace,
                                        kCGBitmapByteOrderDefault,
                                        provider,
                                        NULL,
                                        NO,
                                        kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return imageRef;
}
