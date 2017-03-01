//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGDataProvider/SRGDataProvider.h>
#import <SRGLetterbox/SRGLetterbox.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SegmentsPlayerViewController : UIViewController <SRGLetterboxViewDelegate>

- (instancetype)initWithURN:(nullable SRGMediaURN *)URN;

@end

NS_ASSUME_NONNULL_END