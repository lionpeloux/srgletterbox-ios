//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGLetterbox/SRGLetterbox.h>
#import <XCTest/XCTest.h>

// Imports required to test internals
#import "SRGLetterboxController+Private.h"

static SRGMediaURN *OnDemandVideoURN(void)
{
    return [SRGMediaURN mediaURNWithString:@"urn:swi:video:42844052"];
}

static SRGMediaURN *OnDemandLongVideoURN(void)
{
    return [SRGMediaURN mediaURNWithString:@"urn:srf:video:2c685129-bad8-4ea0-93f5-0d6cff8cb156"];
}

static SRGMediaURN *OnDemandLongVideoSegmentURN(void)
{
    return [SRGMediaURN mediaURNWithString:@"urn:srf:video:5fe1618a-b710-42aa-ac8a-cb9eabf42426"];
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
    return [SRGMediaURN mediaURNWithString:[NSString stringWithFormat:@"urn:rts:video:_bipbop_basic_delay_%@_%@", @((NSInteger)startDate.timeIntervalSince1970), @((NSInteger)endDate.timeIntervalSince1970)]];
}

static SRGMediaURN *MMFCachedScheduledOnDemandVideoURN(NSDate *startDate, NSDate *endDate)
{
    return [SRGMediaURN mediaURNWithString:[NSString stringWithFormat:@"urn:rts:video:_bipbop_basic_cacheddelay_%@_%@", @((NSInteger)startDate.timeIntervalSince1970), @((NSInteger)endDate.timeIntervalSince1970)]];
}

static SRGMediaURN *MMFURLChangeVideoURN(NSDate *startDate, NSDate *endDate)
{
    return [SRGMediaURN mediaURNWithString:[NSString stringWithFormat:@"urn:rts:video:_mediaplayer_dvr_killswitch_%@_%@", @((NSInteger)startDate.timeIntervalSince1970), @((NSInteger)endDate.timeIntervalSince1970)]];
}

static SRGMediaURN *MMFBlockingReasonChangeVideoURN(NSDate *startDate, NSDate *endDate)
{
    return [SRGMediaURN mediaURNWithString:[NSString stringWithFormat:@"urn:rts:video:_mediaplayer_dvr_geoblocked_%@_%@", @((NSInteger)startDate.timeIntervalSince1970), @((NSInteger)endDate.timeIntervalSince1970)]];
}

static SRGMediaURN *MMFSwissTXTFullDVRURN(NSDate *startDate, NSDate *endDate)
{
    return [SRGMediaURN mediaURNWithString:[NSString stringWithFormat:@"urn:rts:video:_rts_info_fulldvr_%@_%@", @((NSInteger)startDate.timeIntervalSince1970), @((NSInteger)endDate.timeIntervalSince1970)]];
}

static SRGMediaURN *MMFSwissTXTLimitedDVRURN(NSDate *startDate, NSDate *endDate)
{
    return [SRGMediaURN mediaURNWithString:[NSString stringWithFormat:@"urn:rts:video:_rts_info_liveonly_limiteddvr_%@_%@", @((NSInteger)startDate.timeIntervalSince1970), @((NSInteger)endDate.timeIntervalSince1970)]];
}

static SRGMediaURN *MMFSwissTXTLiveOnlyURN(NSDate *startDate, NSDate *endDate)
{
    return [SRGMediaURN mediaURNWithString:[NSString stringWithFormat:@"urn:rts:video:_rts_info_liveonly_delay_%@_%@", @((NSInteger)startDate.timeIntervalSince1970), @((NSInteger)endDate.timeIntervalSince1970)]];
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
    
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    
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
    
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    
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
    
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    
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
    
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    
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
    
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    
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

- (void)testLivestreamSkips
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

- (void)testPlaybackStateTransitions
{
    BOOL (^expectationHandler)(NSNotification * _Nonnull notification) = ^BOOL(NSNotification * _Nonnull notification) {
        SRGMediaPlayerPlaybackState currentState = [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue];
        SRGMediaPlayerPlaybackState previousState = [notification.userInfo[SRGMediaPlayerPreviousPlaybackStateKey] integerValue];
        XCTAssertTrue(currentState != previousState);
        return YES;
    };
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:expectationHandler];
    [self.controller prepareToPlayURN:OnDemandVideoURN() withChaptersOnly:NO completionHandler:NULL];
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
    NSURL *overridingURL = [NSURL URLWithString:@"http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"];
    self.controller.updateInterval = 10.f;
    self.controller.contentURLOverridingBlock = ^NSURL * _Nullable(SRGMediaURN * _Nonnull URN) {
        return overridingURL;
    };
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    SRGMediaURN *URN = OnDemandLongVideoURN();
    [self.controller playURN:URN withChaptersOnly:NO];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertNil(self.controller.mediaComposition);
    XCTAssertEqualObjects(self.controller.mediaPlayerController.contentURL, overridingURL);
    
    // Play for a while. No playback notifications must be received
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change with an overriding URL, even if there is a channel or controller update.");
    }];
    
    [self expectationForElapsedTimeInterval:12. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    // Wait until the stream is paused
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePaused;
    }];
    
    [self.controller pause];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Wait for a while. No playback notifications must be received
    id eventObserver2 = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change with an overriding URL, even if there is a channel or controller update.");
    }];
    
    [self expectationForElapsedTimeInterval:10. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver2];
    }];
}

- (void)testUninterruptedOnDemandFullLengthPlayback
{
    self.controller.updateInterval = 10.f;
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    SRGMediaURN *URN = OnDemandLongVideoURN();
    [self.controller playURN:URN withChaptersOnly:NO];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqualObjects(self.controller.mediaComposition.mainChapter.URN, URN);
    
    // Play for a while. No playback notifications must be received
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when playing a full length, even if there is a channel or controller update.");
    }];
    
    [self expectationForElapsedTimeInterval:12. withHandler:nil];
    
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
    id eventObserver2 = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when playing a full length, even if there is a channel or controller update.");
    }];
    
    [self expectationForElapsedTimeInterval:10. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver2];
    }];
}

- (void)testUninterruptedOnDemandSegmentPlayback
{
    self.controller.updateInterval = 10.f;
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    SRGMediaURN *URN = OnDemandLongVideoSegmentURN();
    [self.controller playURN:URN withChaptersOnly:NO];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertNotEqualObjects(self.controller.mediaComposition.mainChapter.URN, URN);
    XCTAssertEqualObjects(self.controller.mediaComposition.mainSegment.URN, URN);
    
    // Play for a while. No playback notifications must be received
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when playing a segment, even if there is a channel or controller update.");
    }];
    
    [self expectationForElapsedTimeInterval:12. withHandler:nil];
    
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
    id eventObserver2 = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when playing a segment, even if there is a channel or controller update.");
    }];
    
    [self expectationForElapsedTimeInterval:10. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver2];
    }];
}

- (void)testUninterruptedOnDemandPlaybackAfterSegmentSelection
{
    self.controller.updateInterval = 10.f;
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    SRGMediaURN *URN = OnDemandLongVideoURN();
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
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when selecting a segment, even if there is a channel or controller update.");
    }];
    
    [self expectationForElapsedTimeInterval:12. withHandler:nil];
    
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
    id eventObserver2 = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when selecting a segment, even if there is a channel or controller update.");
    }];
    
    [self expectationForElapsedTimeInterval:10. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver2];
    }];
}

- (void)testUninterruptedLivePlayback
{
    self.controller.updateInterval = 10.f;
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    SRGMediaURN *URN = LiveOnlyVideoURN();
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
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when stoping playback, even if there is a channel or controller update.");
    }];
    
    [self expectationForElapsedTimeInterval:12. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
}

- (void)testMediaNotYetAvailable
{
    self.controller.serviceURL = MMFServiceURL();
    
    // Waiting for a while. No playback notifications must be received
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when media is not available yet.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    // Media starts in 7 seconds and is available 7 seconds
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:7];
    NSDate *endDate = [startDate dateByAddingTimeInterval:7];
    SRGMediaURN *URN = MMFScheduledOnDemandVideoURN(startDate, endDate);
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqual(self.controller.playbackState, SRGMediaPlayerPlaybackStateIdle);
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonStartDate);
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    // Media starts playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonNone);
    
    // Wait until the stream stops
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // Media stops playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonEndDate);
    
    // Attempt to play again and wait for a while. No playback notifications must be received
    id eventObserver1 = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when a block reason is here.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self.controller play];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver1];
    }];
}

- (void)testMediaAvailable
{
    self.controller.serviceURL = MMFServiceURL();
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:-7];
    NSDate *endDate = [startDate dateByAddingTimeInterval:15];
    SRGMediaURN *URN = MMFScheduledOnDemandVideoURN(startDate, endDate);
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonNone);
    
    // Wait until the stream stops
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // Media stops playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonEndDate);
}

- (void)testMediaNotAvailableAnymore
{
    self.controller.serviceURL = MMFServiceURL();
    
    // Wait for a while. No playback notifications must be received
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when media is not available anymore.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:-15];
    NSDate *endDate = [startDate dateByAddingTimeInterval:7];
    SRGMediaURN *URN = MMFScheduledOnDemandVideoURN(startDate, endDate);
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqual(self.controller.playbackState, SRGMediaPlayerPlaybackStateIdle);
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonEndDate);
}

- (void)testMediaAvailableWithServerCacheInconsistency
{
    self.controller.updateInterval = 10.f;
    self.controller.serviceURL = MMFServiceURL();
    
    // Waiting for a while. No playback notifications must be received
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when media is not available yet.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    // Media started 1 second before and is available 20 seconds, but the server doesn't remove the blocking reason
    // STARTDATE on time.
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:-1];
    NSDate *endDate = [startDate dateByAddingTimeInterval:20];
    SRGMediaURN *URN = MMFCachedScheduledOnDemandVideoURN(startDate, endDate);
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqual(self.controller.playbackState, SRGMediaPlayerPlaybackStateIdle);
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonStartDate);
    
    [self expectationForNotification:SRGLetterboxMetadataDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        SRGMediaComposition *mediaComposition = notification.userInfo[SRGLetterboxMediaCompositionKey];
        return mediaComposition && mediaComposition.mainChapter.blockingReason == SRGBlockingReasonNone;
    }];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];

    // Media starts playing after a metadata udpate

    [self waitForExpectationsWithTimeout:30. handler:nil];

    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonNone);
}

- (void)testMediaWithOverriddenURLNotYetAvailable
{
    self.controller.serviceURL = MMFServiceURL();
    
    self.controller.contentURLOverridingBlock = ^NSURL * _Nullable(SRGMediaURN * _Nonnull URN) {
        return [NSURL URLWithString:@"http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"];
    };
    
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:7];
    NSDate *endDate = [startDate dateByAddingTimeInterval:7];
    SRGMediaURN *URN = MMFScheduledOnDemandVideoURN(startDate, endDate);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request succeeded"];
    
    __block SRGMedia *media = nil;
    SRGDataProvider *dataProvider = [[SRGDataProvider alloc] initWithServiceURL:self.controller.serviceURL businessUnitIdentifier:SRGDataProviderBusinessUnitIdentifierRTS];
    [[dataProvider mediaCompositionWithURN:URN chaptersOnly:NO completionBlock:^(SRGMediaComposition * _Nullable mediaComposition, NSError * _Nullable error) {
        XCTAssertNotNil(mediaComposition);
        media = mediaComposition.fullLengthMedia;
        
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Wait for a while. No playback notifications must be received
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when media is not available yet.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self.controller playMedia:media withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqual(self.controller.playbackState, SRGMediaPlayerPlaybackStateIdle);
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonStartDate);
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    // Media starts playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonNone);
    
    // Wait until the stream is stopped
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // Media stops playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonEndDate);
    
    id eventObserver1 = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when a block reason has been received.");
    }];
    
    // Attempt to play again and wait for a while. No playback notifications must be received since the media is not
    // available anymore
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self.controller play];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver1];
    }];
}

- (void)testResourceChangedWhenPlaying
{
    self.controller.serviceURL = MMFServiceURL();
    self.controller.updateInterval = 10.;
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:7];
    NSDate *endDate = [startDate dateByAddingTimeInterval:60];
    SRGMediaURN *URN = MMFURLChangeVideoURN(startDate, endDate);
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // A URL change occurs.
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertNil(self.controller.mediaPlayerController.contentURL);
    
    // Playback must not restart automatically. Wait for a while to ensure no playback notifications are received anymore.
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change anymore after URL change.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
}

- (void)testResourceChangedWhenPaused
{
    self.controller.serviceURL = MMFServiceURL();
    self.controller.updateInterval = 10.;
    
    // Wait until the stream has been prepared
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePaused;
    }];
    
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:7];
    NSDate *endDate = [startDate dateByAddingTimeInterval:60];
    SRGMediaURN *URN = MMFURLChangeVideoURN(startDate, endDate);
    [self.controller prepareToPlayURN:URN withChaptersOnly:NO completionHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
        
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // A URL change occurs.
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertNil(self.controller.mediaPlayerController.contentURL);
    
    // Playback must not restart automatically. Wait for a while to ensure no playback notifications are received anymore.
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change anymore after URL change.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
}

- (void)testResourceChangedWhenStopped
{
    self.controller.serviceURL = MMFServiceURL();
    self.controller.updateInterval = 10.;
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:7];
    NSDate *endDate = [startDate dateByAddingTimeInterval:60];
    SRGMediaURN *URN = MMFURLChangeVideoURN(startDate, endDate);
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    
    NSURL *firstURL = self.controller.mediaPlayerController.contentURL;
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    [self.controller stop];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    // URL changes while idle must not lead to playback state changes.
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when stopped.");
    }];
    
    [self expectationForElapsedTimeInterval:12. withHandler:nil];
    
    // A URL change occurs while the player is idle.
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertNil(self.controller.mediaPlayerController.contentURL);
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller play];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertNotEqualObjects(self.controller.mediaPlayerController.contentURL, firstURL);
}

- (void)testBlockingReasonChange
{
    self.controller.serviceURL = MMFServiceURL();
    self.controller.updateInterval = 10.;
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:7];
    NSDate *endDate = [startDate dateByAddingTimeInterval:60];
    SRGMediaURN *URN = MMFBlockingReasonChangeVideoURN(startDate, endDate);
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    
    // A blocking reason appearing while playing must stop playback
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // A blocking reason appears.
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertNotEqual(@(self.controller.media.blockingReason), @(SRGBlockingReasonNone));
    
    // Waiting for a while. No playback notifications must be received
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when a block reason is here.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self.controller play];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
}

- (void)testPeriodicUpdatesForLivestream
{
    self.controller.updateInterval = 10.;
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:LiveOnlyVideoURN() withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForNotification:SRGLetterboxMetadataDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    // An update must occur automatically
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
}

- (void)testPeriodicUpdatesForOnDemandStream
{
    self.controller.updateInterval = 10.;
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:OnDemandVideoURN() withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self expectationForNotification:SRGLetterboxMetadataDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    // An update must occur automatically
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
}

- (void)testSwissTXTFullDVRNotYetAvailable
{
    self.controller.updateInterval = 10.f;
    self.controller.serviceURL = MMFServiceURL();
    
    // Waiting for a while. No playback notifications must be received
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when media is not available yet.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    // Media starts in 7 seconds and is available 7 seconds
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:7];
    NSDate *endDate = [startDate dateByAddingTimeInterval:7];
    SRGMediaURN *URN = MMFSwissTXTFullDVRURN(startDate, endDate);
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqual(self.controller.playbackState, SRGMediaPlayerPlaybackStateIdle);
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonStartDate);
    XCTAssertEqual(self.controller.media.contentType, SRGContentTypeScheduledLivestream);
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    // Media starts playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonNone);
    XCTAssertEqual(self.controller.mediaComposition.mainChapter.segments.count, 0);
    XCTAssertEqual(self.controller.mediaComposition.chapters.count, 1);
    
    // Wait until the stream stops
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // Media stops playing
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonNone);
    XCTAssertNotEqual(self.controller.mediaComposition.mainChapter.segments.count, 0);
    XCTAssertEqual(self.controller.mediaComposition.chapters.count, 1);
    
    // Wait until the stream is playing the VOD
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqual(self.controller.media.contentType, SRGContentTypeEpisode);
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller play];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testSwissTXTLimitedDVRNotYetAvailable
{
    self.controller.updateInterval = 10.f;
    self.controller.serviceURL = MMFServiceURL();
    
    // Waiting for a while. No playback notifications must be received
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when media is not available yet.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    // Media starts in 7 seconds and is available 7 seconds
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:7];
    NSDate *endDate = [startDate dateByAddingTimeInterval:7];
    SRGMediaURN *URN = MMFSwissTXTLimitedDVRURN(startDate, endDate);
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqual(self.controller.playbackState, SRGMediaPlayerPlaybackStateIdle);
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonStartDate);
    XCTAssertEqual(self.controller.media.contentType, SRGContentTypeScheduledLivestream);
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    // Media starts playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonNone);
    XCTAssertEqual(self.controller.mediaComposition.mainChapter.segments.count, 0);
    XCTAssertEqual(self.controller.mediaComposition.chapters.count, 1);
    
    // Wait until the stream stops
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // Media stops playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonEndDate);
    XCTAssertEqual(self.controller.media.contentType, SRGContentTypeScheduledLivestream);
    XCTAssertEqual(self.controller.mediaComposition.mainChapter.segments.count, 0);
    XCTAssertTrue(self.controller.mediaComposition.chapters.count > 1);
    
    // Attempt to play again and wait for a while. No playback notifications must be received
    id eventObserver1 = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when a block reason is here.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self.controller play];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver1];
    }];
    
    // Wait until the stream is playing a highlight
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqual(self.controller.media.contentType, SRGContentTypeEpisode);
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller switchToSubdivision:self.controller.mediaComposition.chapters[1]];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testSwissTXTLiveOnlyNotYetAvailable
{
    self.controller.updateInterval = 10.f;
    self.controller.serviceURL = MMFServiceURL();
    
    // Waiting for a while. No playback notifications must be received
    id eventObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when media is not available yet.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    // Media starts in 7 seconds and is available 7 seconds
    NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:7];
    NSDate *endDate = [startDate dateByAddingTimeInterval:7];
    SRGMediaURN *URN = MMFSwissTXTLiveOnlyURN(startDate, endDate);
    [self.controller playURN:URN withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, URN);
    XCTAssertEqualObjects(self.controller.media.URN, URN);
    XCTAssertEqual(self.controller.playbackState, SRGMediaPlayerPlaybackStateIdle);
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonStartDate);
    XCTAssertEqual(self.controller.media.contentType, SRGContentTypeScheduledLivestream);
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    // Media starts playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonNone);
    XCTAssertEqual(self.controller.mediaComposition.mainChapter.segments.count, 0);
    XCTAssertEqual(self.controller.mediaComposition.chapters.count, 1);
    
    // Wait until the stream stops
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateIdle;
    }];
    
    // Media stops playing
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertEqual(self.controller.media.blockingReason, SRGBlockingReasonEndDate);
    XCTAssertEqual(self.controller.media.contentType, SRGContentTypeScheduledLivestream);
    XCTAssertEqual(self.controller.mediaComposition.mainChapter.segments.count, 0);
    XCTAssertEqual(self.controller.mediaComposition.chapters.count, 1);
    
    // Attempt to play again and wait for a while. No playback notifications must be received
    id eventObserver1 = [[NSNotificationCenter defaultCenter] addObserverForName:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playback state must not change when a block reason is here.");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self.controller play];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [[NSNotificationCenter defaultCenter] removeObserver:eventObserver1];
    }];
}

- (void)testSwitchToSubdivisionForSegment
{
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:OnDemandLongVideoSegmentURN() withChaptersOnly:NO];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self expectationForNotification:SRGLetterboxControllerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateSeeking;
    }];
    [self expectationForNotification:SRGMediaPlayerSegmentDidStartNotification object:self.controller.mediaPlayerController handler:nil];
    
    NSArray<SRGSegment *> *segments = self.controller.mediaComposition.mainChapter.segments;
    XCTAssertTrue(segments.count >= 3);
    [self.controller switchToSubdivision:segments[2]];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testSwitchToSubdivisionForChapter
{
    
}

- (void)testSwitchToUnrelatedSubdivision
{
    
}

@end
