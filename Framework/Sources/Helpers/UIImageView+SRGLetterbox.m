//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UIImageView+SRGLetterbox.h"

#import "NSBundle+SRGLetterbox.h"
#import "UIImage+SRGLetterbox.h"

#import <SRGAppearance/SRGAppearance.h>
#import <YYWebImage/YYWebImage.h>

@implementation UIImageView (SRGLetterbox)

#pragma mark Class methods

+ (UIImageView *)srg_loadingImageView35WithTintColor:(UIColor *)tintColor
{
    return [self srg_animatedImageViewNamed:@"loading-35" withTintColor:tintColor duration:1.];
}

// Expect a sequence of images named "name-N", where N must begin at 0. Stops when no image is found for some N
+ (UIImageView *)srg_animatedImageViewNamed:(NSString *)name withTintColor:(UIColor *)tintColor duration:(NSTimeInterval)duration
{
    NSArray<UIImage *> *images = [self srg_animatedImageNamed:name withTintColor:tintColor];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:images.firstObject];
    imageView.animationImages = [images copy];
    imageView.animationDuration = duration;
    return imageView;
}

+ (NSArray<UIImage *> *)srg_animatedImageNamed:(NSString *)name withTintColor:(UIColor *)tintColor
{
    NSMutableArray<UIImage *> *images = [NSMutableArray array];
    
    NSInteger count = 0;
    while (1) {
        NSString *imageName = [NSString stringWithFormat:@"%@-%@", name, @(count)];
        UIImage *image = [[UIImage imageNamed:imageName
                                     inBundle:[NSBundle srg_letterboxBundle]
                compatibleWithTraitCollection:nil] srg_imageTintedWithColor:tintColor];
        if (! image) {
            break;
        }
        [images addObject:image];
        
        ++count;
    }
    
    NSAssert(images.count != 0, @"Invalid asset %@", name);
    return [images copy];
}

#pragma mark Standard image loading

- (void)srg_requestImageForObject:(id<SRGImageMetadata>)object
                        withScale:(SRGImageScale)imageScale
{
    CGSize size = SRGSizeForImageScale(imageScale);
    UIImage *placeholderImage = [UIImage srg_vectorImageAtPath:SRGLetterboxMediaPlaceholderFilePath() withSize:size];
    if (! object) {
        self.image = placeholderImage;
        return;
    }
    
    NSURL *URL = [object imageURLForDimension:SRGImageDimensionWidth withValue:size.width];
    [self yy_setImageWithURL:URL placeholder:placeholderImage options:YYWebImageOptionSetImageWithFadeAnimation completion:nil];
}

- (void)srg_requestFirstValidImageForObjects:(NSArray<id<SRGImageMetadata>> *)objects
                                   withScale:(SRGImageScale)imageScale
{
    if (objects.count == 0) {
        return;
    }
    
    CGSize size = SRGSizeForImageScale(imageScale);
    for (id<SRGImageMetadata> object in objects) {
        NSURL *URL = [object imageURLForDimension:SRGImageDimensionWidth withValue:size.width];
        if (URL && ! [URL.absoluteString containsString:@"NOT_SPECIFIED.jpg"]) {
            UIImage *placeholderImage = [UIImage srg_vectorImageAtPath:SRGLetterboxMediaPlaceholderFilePath() withSize:size];
            [self yy_setImageWithURL:URL placeholder:placeholderImage options:YYWebImageOptionSetImageWithFadeAnimation completion:nil];
            return;
        }
    }
}

- (void)srg_cancelCurrentImageRequest
{
    [self yy_cancelCurrentImageRequest];
}

@end
