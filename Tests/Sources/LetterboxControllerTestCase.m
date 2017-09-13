//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGLetterbox/SRGLetterbox.h>
#import <XCTest/XCTest.h>

#import "NSNotificationCenter+Tests.h"

// Imports required to test internals
#import "SRGLetterboxController+Private.h"

static SRGMediaURN *OnDemandVideoURN(void)
{
    return [SRGMediaURN mediaURNWithString:@"urn:swi:video:42844052"];
}

static SRGMediaURN *OnDemandLongVideoURN(void)
{
    return [SRGMediaURN mediaURNWithString:@"urn:srf:video:be82935d-2a13-4d67-a546-2e7400821b54"];
}

static SRGMediaURN *OnDemandLongVideoSegmentURN(void)
{
    return [SRGMediaURN mediaURNWithString:@"urn:srf:video:bfa39399-01f8-4fca-bb48-46365eb15426"];
}

static SRGMediaURN *LiveOnlyVideoURN(void)
{
    return [SRGMediaURN mediaURNWithString:@"urn:rsi:video:livestream_La1"];
}

static SRGMediaURN *LiveDVRVideoURN(void)
{
    return [SRGMediaURN mediaURNWithString:@"urn:rts:video:1967124"];
}

static SRGMediaURN *MMFScheduledOnDemandVideoURN(NSDate *startDate, NSDate *endDate)
{
    return [SRGMediaURN mediaURNWithString:[NSString stringWithFormat:@"urn:rts:video:_bipbop_basic_delay_%d_%d", (int)startDate.timeIntervalSince1970, (int)endDate.timeIntervalSince1970]];
}

static NSURL *MMFServiceURL(void)
{
    return [NSURL URLWithString:@"https://play-mmf.herokuapp.com"];
}

@interface LetterboxControllerTestCase : XCTestCase

@property (nonatomic) SRGLetterboxController *controller;

@end

@implementation LetterboxControllerTestCase

#pragma mark Helpers

- (XCTestExpectation *)expectationForElapsedTimeInterval:(NSTimeInterval)timeInterval withHandler:(void (^)(void))handler
{
    XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"Wait for %@ seconds", @(timeInterval)]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
        handler ? handler() : nil;
    });
    return expectation;
}

#pragma mark Setup and tear down

- (void)setUp
{
    self.controller = [[SRGLetterboxController alloc] init];
}

- (void)tearDown
{
    // Always ensure the player gets deallocated between tests
    [self.controller reset];
    self.controller = nil;
}

#pragma mark Tests

- (void)testDeallocation
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-unsafe-retained-assign"
    __weak SRGLetterboxController *letterboxController;
    @autoreleasepool {
        letterboxController = [[SRGLetterboxController alloc] init];
    }
    XCTAssertNil(letterboxController);
#pragma clang diagnostic pop
}

- (void)testPlayURN
{
    // Wait until the stream is playing, at which time we expect the media composition to be available
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    [self expectationForNotification:SRGLetterboxMetadataDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return notification.userInfo[SRGLetterboxMediaCompositionKey] != nil;
    }];
    
    SRGMediaURN *URN = OnDemandVideoURN();
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    // Media information must now be available
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqualObjects(self.controller.mediaComposition.chapterURN, URN);
    XCTAssertNil(self.controller.error);
}

- (void)testPlayMedia
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media retrieved"];
    
    __block SRGMedia *media = nil;
    SRGDataProvider *dataProvider = [[SRGDataProvider alloc] initWithServiceURL:SRGIntegrationLayerProductionServiceURL() businessUnitIdentifier:SRGDataProviderBusinessUnitIdentifierSWI];
    [[dataProvider videosWithUids:@[OnDemandVideoURN().uid] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSError * _Nullable error) {
        media = medias.firstObject;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    XCTAssertNotNil(media);
    
    // Wait until the stream is playing, at which time we expect the media composition to be available
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    [self expectationForNotification:SRGLetterboxMetadataDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return notification.userInfo[SRGLetterboxMediaCompositionKey] != nil;
    }];
    
    [self.controller playMedia:media withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    // Media information must now be available
    XCTAssertEqualObjects(self.controller.URN, media.URN);
    XCTAssertEqualObjects(self.controller.media, media);
    XCTAssertEqualObjects(self.controller.mediaComposition.chapterURN, media.URN);
    XCTAssertNil(self.controller.error);
}

- (void)testReset
{
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    [self.controller reset];
    
    XCTAssertNil(self.controller.URN);
    XCTAssertNil(self.controller.media);
    XCTAssertNil(self.controller.mediaComposition);
    XCTAssertNil(self.controller.error);
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
}

- (void)testPlayAfterStop
{
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    SRGMediaURN *URN = OnDemandVideoURN();
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    [self.controller stop];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller play];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
}

- (void)testPlayAfterReset
{
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    SRGMediaURN *URN = OnDemandVideoURN();
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    [self.controller reset];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"The player cannot be restarted with a play after a reset. No event expected");
    }];
    
    [self.controller play];
    
    [self waitForExpectationsWithTimeout:30. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
}

- (void)testTogglePlayPause
{
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    SRGMediaURN *URN = OnDemandVideoURN();
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePaused;
    }];
    
    [self.controller togglePlayPause];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller togglePlayPause];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
}

- (void)testTogglePlayPauseAfterStop
{
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    SRGMediaURN *URN = OnDemandVideoURN();
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    [self.controller stop];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller togglePlayPause];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
}

- (void)testTogglePlayPauseAfterReset
{
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    SRGMediaURN *URN = OnDemandVideoURN();
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    [self.controller reset];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"The player cannot be restarted with a play after a reset. No event expected");
    }];
    
    [self.controller togglePlayPause];
    
    [self waitForExpectationsWithTimeout:30. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
}

- (void)testPlaybackMetadata
{
    XCTAssertNil(self.controller.URN);
    XCTAssertNil(self.controller.media);
    XCTAssertNil(self.controller.mediaComposition);
    XCTAssertNil(self.controller.error);
    
    // Wait until the stream is playing, at which time we expect the media composition to be available
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    [self expectationForNotification:SRGLetterboxMetadataDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return notification.userInfo[SRGLetterboxMediaCompositionKey] != nil;
    }];
    
    SRGMediaURN *URN = OnDemandVideoURN();
    [self.controller playURN:URN withChaptersOnly:NO];
    
    // Media and composition not immediately available, fetched by the controller
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertNil(self.controller.media);
    XCTAssertNil(self.controller.mediaComposition);
    XCTAssertNil(self.controller.error);
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    // Media information must now be available
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqualObjects(self.controller.mediaComposition.chapterURN, URN);
    XCTAssertNil(self.controller.error);
    
    [self.controller reset];
    
    XCTAssertNil(self.controller.URN);
    XCTAssertNil(self.controller.media);
    XCTAssertNil(self.controller.mediaComposition);
    XCTAssertNil(self.controller.error);
}

- (void)testSameMediaPlaybackWhileAlreadyPlaying
{
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    // Expect no change when trying to play the same media
    id metadataObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxMetadataDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"Expect no metadata update when playing the same media");
    }];
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"Expect no playback state change when playing the same media");
    }];
    
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:metadataObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
}

- (void)testSameMediaPlaybackWhilePaused
{
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    // Pause playback
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePaused;
    }];
    
    [self.controller pause];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    // Expect only a player state change notification, no metadata change notification
    id metadataObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxMetadataDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"Expect no metadata update when playing the same media");
    }];
    
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:metadataObserver];
    }];
}

- (void)testOnDemandStreamSkips
{
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    // TTC
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue([self.controller canSkipBackward]);
    XCTAssertTrue([self.controller canSkipForward]);

    // Seek to near the end
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    SRGMediaPlayerController *mediaPlayerController = self.controller.mediaPlayerController;
    [mediaPlayerController seekPreciselyToTime:CMTimeSubtract(CMTimeRangeGetEnd(mediaPlayerController.timeRange), CMTimeMakeWithSeconds(15., NSEC_PER_SEC)) withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue([self.controller canSkipBackward]);
    XCTAssertFalse([self.controller canSkipForward]);
    
    // Seek far enough from the media end
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller seekPreciselyToTime:CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(60., NSEC_PER_SEC)) withCompletionHandler:^(BOOL finished) {
        XCTAssertTrue(finished);
    }];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue([self.controller canSkipBackward]);
    XCTAssertTrue([self.controller canSkipForward]);
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller seekPreciselyToTime:CMTimeRangeGetEnd(self.controller.timeRange) withCompletionHandler:^(BOOL finished) {
        XCTAssertTrue(finished);
    }];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue([self.controller canSkipBackward]);
    XCTAssertFalse([self.controller canSkipForward]);
}

- (void)testLiveStreamSkips
{
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:LiveOnlyVideoURN() withChaptersOnly:NO];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertFalse([self.controller canSkipBackward]);
    XCTAssertFalse([self.controller canSkipForward]);
    
    // Cannot skip
    [self.controller skipBackwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertFalse(finished);
    }];
    [self.controller skipForwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertFalse(finished);
    }];
}

- (void)testDVRStreamSkips
{
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:LiveDVRVideoURN() withChaptersOnly:NO];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue(self.controller.live);
    
    XCTAssertTrue([self.controller canSkipBackward]);
    XCTAssertFalse([self.controller canSkipForward]);
    
    // Seek far enough from live conditions
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller seekPreciselyToTime:CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(60., NSEC_PER_SEC)) withCompletionHandler:^(BOOL finished) {
        XCTAssertTrue(finished);
    }];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertFalse(self.controller.live);
    
    XCTAssertTrue([self.controller canSkipBackward]);
    XCTAssertTrue([self.controller canSkipForward]);
    
    // Skip forward again
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller seekEfficientlyToTime:CMTimeRangeGetEnd(self.controller.timeRange) withCompletionHandler:^(BOOL finished) {
        XCTAssertTrue(finished);
    }];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue(self.controller.live);
    
    XCTAssertTrue([self.controller canSkipBackward]);
    XCTAssertFalse([self.controller canSkipForward]);
}

- (void)testMultipleSkips
{
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:OnDemandLongVideoURN() withChaptersOnly:NO];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Pile up skips forward
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller skipForwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertFalse(finished);
    }];
    [self.controller skipForwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertTrue(finished);
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue([self.controller canSkipBackward]);
    
    // Pile up skips backward
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller skipBackwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertFalse(finished);
    }];
    [self.controller skipBackwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertTrue(finished);
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue([self.controller canSkipBackward]);
}

- (void)testCurrentAndPreviousPlaybackStateAreDifferent
{
    BOOL (^expectationHandler)(NSNotification * _Nonnull notification) = ^BOOL(NSNotification * _Nonnull notification) {
        SRGMediaPlayerPlaybackState currentState = [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue];
        SRGMediaPlayerPlaybackState previousState = [notification.userInfo[SRGMediaPlayerPreviousPlaybackStateKey] integerValue];
        XCTAssertTrue(currentState != previousState);
        return YES;
    };
    
    SRGMediaURN *URN = OnDemandVideoURN();
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:expectationHandler];
    [self.controller prepareToPlayURN:URN withChaptersOnly:NO completionHandler:NULL];
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:expectationHandler];
    [self.controller play];
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:expectationHandler];
    [self.controller pause];
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:expectationHandler];
    [self.controller reset];
    [self waitForExpectationsWithTimeout:5. handler:nil];
}

- (void)testPlaybackStateKeyValueObserving
{
    [self keyValueObservingExpectationForObject:self.controller keyPath:@"playbackState" expectedValue:@(SRGMediaPlayerPlaybackStatePreparing)];
    
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

 - (void)testContentURLOverriding
{
    NSURL *overridingURL = [NSURL URLWithString:@"https://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"];
    self.controller.streamAvailabilityCheckInterval = 10.f;
    self.controller.contentURLOverridingBlock = ^NSURL * _Nullable(SRGMediaURN * _Nonnull URN) {
        return overridingURL;
    };
    
    SRGMediaURN *URN = OnDemandLongVideoURN();
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:URN withChaptersOnly:NO];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertNil(self.controller.mediaComposition);
    XCTAssertEqualObjects(self.controller.mediaPlayerController.contentURL, overridingURL);
    
    // Play for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:12. withHandler:nil];
    
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change with an overriding url, even if there is a channel update or stream availability check.");
    }];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    // Wait until the stream is pause
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePaused;
    }];
    
    [self.controller pause];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Waiting for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:10. withHandler:nil];

    id eventObserver2 = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change with an overriding url, even if there is a channel update or stream availability check.");
    }];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver2];
    }];
}

- (void)testFullLengthUninterruptedOnDemandPlayback
{
    self.controller.streamAvailabilityCheckInterval = 10.f;
    
    SRGMediaURN *URN = OnDemandLongVideoURN();
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:URN withChaptersOnly:NO];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqualObjects(self.controller.mediaComposition.mainChapter.URN, URN);
    
    // Play for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:12. withHandler:nil];

    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when playing a full length, even if there is a channel update or stream availability check.");
    }];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    // Wait until the stream is paused
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePaused;
    }];
    
    [self.controller pause];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Waiting for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:10. withHandler:nil];

    id eventObserver2 = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when playing a full length, even if there is a channel update or stream availability check.");
    }];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver2];
    }];
}

- (void)testSegmentUninterruptedOnDemandSegmentPlayback
{
    self.controller.streamAvailabilityCheckInterval = 10.f;
    
    SRGMediaURN *URN = OnDemandLongVideoSegmentURN();
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:URN withChaptersOnly:NO];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertNotEqualObjects(self.controller.mediaComposition.mainChapter.URN, URN);
    XCTAssertEqualObjects(self.controller.mediaComposition.mainSegment.URN, URN);
    
    // Play for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:12. withHandler:nil];
    
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when playing a segment, even if there is a channel update or stream availability check.");
    }];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    // Wait until the stream is paused
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePaused;
    }];
    
    [self.controller pause];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Waiting for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:10. withHandler:nil];
    
    id eventObserver2 = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when playing a segment, even if there is a channel update or stream availability check.");
    }];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver2];
    }];
}

- (void)testUninterruptedOnDemandPlaybackAfterSegmentSelection
{
    self.controller.streamAvailabilityCheckInterval = 10.f;
    
    SRGMediaURN *URN = OnDemandLongVideoURN();
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:URN withChaptersOnly:NO];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqualObjects(self.controller.mediaComposition.mainChapter.URN, URN);
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller switchToSubdivision:self.controller.mediaComposition.mainChapter.segments[2]];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Play for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:12. withHandler:nil];

    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when selecting a segment, even if there is a channel update or stream availability check.");
    }];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    // Wait until the stream is paused
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePaused;
    }];
    
    [self.controller pause];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Waiting for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:10. withHandler:nil];

    id eventObserver2 = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when selecting a segment, even if there is a channel update or stream availability check.");
    }];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver2];
    }];
    
}

- (void)testUninterruptedLivePlayback
{
    self.controller.streamAvailabilityCheckInterval = 10.f;
    
    SRGMediaURN *URN = LiveOnlyVideoURN();
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:URN withChaptersOnly:NO];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqualObjects(self.controller.mediaComposition.mainChapter.URN, URN);
    
    // Wait until the stream is stopped
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    [self.controller stop];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Waiting for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:12. withHandler:nil];

    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when stoping playback, even if there is a channel update or stream availability check.");
    }];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
}

- (void)testScheduledMediaNotYetAvailable
{
    self.controller.serviceURL = MMFServiceURL();
    
    // Media starts in 5 seconds and is available 5 seconds
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:5];
    NSDate *endDate = [startDate dateByAddingTimeInterval:5];
    SRGMediaURN *URN = MMFScheduledOnDemandVideoURN(startDate, endDate);
    
    // Waiting for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when media is not available yet.");
    }];
    
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqualObjects(@(self.controller.playbackState), @(SRGMediaPlayerPlaybackStateIdle));
    XCTAssertEqualObjects(@(SRGDataProviderAvailabilityForMediaMetadata(self.controller.media)), @(SRGMediaAvailabilityNotYetAvailable));
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    // Scheduled media starts playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(@(SRGDataProviderAvailabilityForMediaMetadata(self.controller.media)), @(SRGMediaAvailabilityAvailable));
    
    // Wait until the stream is stopped
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // Scheduled media stops playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(@(SRGDataProviderAvailabilityForMediaMetadata(self.controller.media)), @(SRGMediaAvailabilityNotAvailableAnymore));
}

- (void)testScheduledMediaAvailable
{
    self.controller.serviceURL = MMFServiceURL();
    
    // Media started 5 seconds before and is available 10 seconds
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:-5];
    NSDate *endDate = [startDate dateByAddingTimeInterval:10];
    SRGMediaURN *URN = MMFScheduledOnDemandVideoURN(startDate, endDate);
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqualObjects(@(SRGDataProviderAvailabilityForMediaMetadata(self.controller.media)), @(SRGMediaAvailabilityAvailable));
    
    // Wait until the stream is stopped
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // Scheduled media stops playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(@(SRGDataProviderAvailabilityForMediaMetadata(self.controller.media)), @(SRGMediaAvailabilityNotAvailableAnymore));
}

- (void)testScheduledMediaNotAvailableAnymore
{
    self.controller.serviceURL = MMFServiceURL();
    
    // Media started 10 seconds before and finished 5 seconds before
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:-10];
    NSDate *endDate = [startDate dateByAddingTimeInterval:5];
    SRGMediaURN *URN = MMFScheduledOnDemandVideoURN(startDate, endDate);
    
    // Waiting for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when media is not available anymore.");
    }];
    
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqualObjects(@(self.controller.playbackState), @(SRGMediaPlayerPlaybackStateIdle));
    XCTAssertEqualObjects(@(SRGDataProviderAvailabilityForMediaMetadata(self.controller.media)), @(SRGMediaAvailabilityNotAvailableAnymore));
}

- (void)testResourceChangedWhenPlaying
{
    self.controller.serviceURL = MMFServiceURL();
    self.controller.streamAvailabilityCheckInterval = 10.;
    
    // Media changes it resource URL after 5 seconds
    // TODO: Set the good MMF URN
    SRGMediaURN *URN = LiveDVRVideoURN();
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    
    NSURL *firstURL = self.controller.mediaPlayerController.contentURL;
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // Media stops playing.
    
    [self waitForExpectationsWithTimeout:20 handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    // Media starts playing.
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertNotEqualObjects(self.controller.mediaPlayerController.contentURL, firstURL);
}

- (void)testResourceChangedWhenPaused
{
    self.controller.serviceURL = MMFServiceURL();
    self.controller.streamAvailabilityCheckInterval = 10.;
    
    // Media changes it resource URL after 5 seconds
    // TODO: Set the good MMF URN
    SRGMediaURN *URN = LiveDVRVideoURN();
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    
    NSURL *firstURL = self.controller.mediaPlayerController.contentURL;
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePaused;
    }];
    
    [self.controller pause];
    
    [self waitForExpectationsWithTimeout:20 handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // Media stops playback.
    
    [self waitForExpectationsWithTimeout:20 handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePaused;
    }];
    
    // Media starts in paused.
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertNotEqualObjects(self.controller.mediaPlayerController.contentURL, firstURL);
    
    // Waiting for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when starting in paused.");
    }];
    
    // Media won't play.
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
}

- (void)testResourceChangedWhenStopped
{
    self.controller.serviceURL = MMFServiceURL();
    self.controller.streamAvailabilityCheckInterval = 10.;
    
    // Media changes it resource URL after 5 seconds
    // TODO: Set the good MMF URN
    SRGMediaURN *URN = LiveDVRVideoURN();
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    
    NSURL *firstURL = self.controller.mediaPlayerController.contentURL;
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    [self.controller stop];
    
    [self waitForExpectationsWithTimeout:20 handler:nil];
    
    // Waiting for a while. No playback notifications must be received
    [self expectationForElapsedTimeInterval:12. withHandler:nil];
    
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForLetterboxControllerPlaybackStateDidChangeNotificationUsingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when stopped.");
    }];
    
    // Media won't play but the controller removes old URL.
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertNotEqualObjects(self.controller.mediaPlayerController.contentURL, firstURL);
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller play];
    
    [self waitForExpectationsWithTimeout:20 handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertNotEqualObjects(self.controller.mediaPlayerController.contentURL, firstURL);
}

@end
