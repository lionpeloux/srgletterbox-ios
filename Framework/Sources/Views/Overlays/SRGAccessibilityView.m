//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGAccessibilityView.h"

#import "NSBundle+SRGLetterbox.h"
#import "SRGLetterboxBaseView+Subclassing.h"
#import "SRGLetterboxView+Private.h"

@implementation SRGAccessibilityView

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (NSString *)accessibilityLabel
{
    return (self.contextLetterboxView.controller.media.mediaType == SRGMediaTypeAudio) ? SRGLetterboxAccessibilityLocalizedString(@"Audio", @"The main area on the letterbox view, where the audio or its thumbnail is displayed") : SRGLetterboxAccessibilityLocalizedString(@"Video", @"The main area on the letterbox view, where the video or its thumbnail is displayed");
}

- (NSString *)accessibilityHint
{
    SRGLetterboxView *contextLetterboxView = self.contextLetterboxView;
    if (contextLetterboxView.userInterfaceBehavior == SRGLetterboxViewBehaviorNormal) {
        return contextLetterboxView.userInterfaceTogglable ? SRGLetterboxAccessibilityLocalizedString(@"Double tap to display or hide player controls.", @"Hint for the letterbox view") : nil;
    }
    else {
        return nil;
    }
}

@end
