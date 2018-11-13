//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <libextobjc/libextobjc.h>
#import <SRGLetterbox/SRGLetterbox.h>

#import "LetterboxBaseTestCase.h"
#import "TestPlaylist.h"

static NSString * const MediaURN1 = @"urn:rts:video:9309820";
static NSString * const MediaURN2 = @"urn:rts:video:9314051";

@interface PlaylistsTestCase : LetterboxBaseTestCase

@property (nonatomic) SRGDataProvider *dataProvider;
@property (nonatomic) SRGLetterboxController *controller;
@property (nonatomic) TestPlaylist *playlist;

@end

@implementation PlaylistsTestCase

#pragma mark Setup and tear down

- (void)setUp
{
    self.dataProvider = [[SRGDataProvider alloc] initWithServiceURL:SRGIntegrationLayerProductionServiceURL()];
    self.controller = [[SRGLetterboxController alloc] init];
}

- (void)tearDown
{
    // Always ensure the player gets deallocated between tests
    [self.controller reset];
    self.controller = nil;
}

#pragma mark Tests

- (void)testPlaylistNavigation
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.previousMedia);
    XCTAssertNil(self.controller.URN);
    XCTAssertEqualObjects(self.controller.nextMedia, self.playlist.medias.firstObject);
    
    XCTAssertTrue([self.controller canPlayNextMedia]);
    XCTAssertFalse([self.controller canPlayPreviousMedia]);
    
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertFalse([self.controller playPreviousMedia]);
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.previousMedia);
    XCTAssertEqualObjects(self.controller.media, self.playlist.medias.firstObject);
    XCTAssertEqualObjects(self.controller.nextMedia, self.playlist.medias.lastObject);
    
    XCTAssertFalse([self.controller canPlayPreviousMedia]);
    XCTAssertTrue([self.controller canPlayNextMedia]);
    
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertFalse([self.controller playPreviousMedia]);
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(self.controller.previousMedia, self.playlist.medias.firstObject);
    XCTAssertEqualObjects(self.controller.media, self.playlist.medias.lastObject);
    XCTAssertNil(self.controller.nextMedia);
    
    XCTAssertTrue([self.controller canPlayPreviousMedia]);
    XCTAssertFalse([self.controller canPlayNextMedia]);
    
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertFalse([self.controller playNextMedia]);
    XCTAssertTrue([self.controller playPreviousMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.previousMedia);
    XCTAssertEqualObjects(self.controller.media, self.playlist.medias.firstObject);
    XCTAssertEqualObjects(self.controller.nextMedia, self.playlist.medias.lastObject);
}

- (void)testNoPlaylist
{
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:MediaURN1 atPosition:nil withPreferredSettings:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.previousMedia);
    XCTAssertNil(self.controller.nextMedia);
    
    XCTAssertFalse([self.controller canPlayNextMedia]);
    XCTAssertFalse([self.controller playNextMedia]);
    
    XCTAssertFalse([self.controller canPlayPreviousMedia]);
    XCTAssertFalse([self.controller playPreviousMedia]);
    
    XCTAssertFalse([self.controller prepareToPlayNextMediaWithCompletionHandler:^{
        XCTFail(@"Must not be called");
    }]);
    XCTAssertFalse([self.controller prepareToPlayPreviousMediaWithCompletionHandler:^{
        XCTFail(@"Must not be called");
    }]);
}

- (void)testDefaultDisabledContinuousPlayback
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Start with the first item in the playlist
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    // Seek near the end
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateEnded;
    }];
    
    CMTime seekTime = CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(5., NSEC_PER_SEC));
    [self.controller seekToPosition:[SRGPosition positionAtTime:seekTime] withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    // Wait some time. We don't expect playback to automatically continue with the next item
    id eventObserver1 = [NSNotificationCenter.defaultCenter addObserverForName:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"The player must remain in the current state");
    }];
    
    id eventObserver2 = [NSNotificationCenter.defaultCenter addObserverForName:SRGLetterboxPlaybackDidContinueAutomaticallyNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"The player must not continue automatically");
    }];
    
    [self expectationForElapsedTimeInterval:10. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:eventObserver1];
        [NSNotificationCenter.defaultCenter removeObserver:eventObserver2];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, MediaURN1);
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
}

- (void)testContinuousPlaybackWithDelay
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    static NSTimeInterval kContinuousPlaybackTransitionDuration = 5.;
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.playlist.continuousPlaybackTransitionDuration = kContinuousPlaybackTransitionDuration;
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Start with the first item in the playlist
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    // Seek near the end
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateEnded;
    }];
    
    CMTime seekTime = CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(5., NSEC_PER_SEC));
    [self.controller seekToPosition:[SRGPosition positionAtTime:seekTime] withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSDate *playbackEndDate1 = NSDate.date;
    
    XCTAssertNotNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNotNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertEqualObjects(self.controller.continuousPlaybackUpcomingMedia.URN, MediaURN2);
    
    // Wait until the next media is played automatically
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePreparing;
    }];
    
    [self expectationForNotification:SRGLetterboxPlaybackDidContinueAutomaticallyNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGLetterboxURNKey] isEqual:MediaURN2];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, MediaURN2);
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    XCTAssertTrue([NSDate.date timeIntervalSinceDate:playbackEndDate1] - kContinuousPlaybackTransitionDuration < 1);
}

- (void)testImmediateContinuousPlayback
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.playlist.continuousPlaybackTransitionDuration = 0.;
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Start with the first item in the playlist
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    // Seek near the end
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateEnded;
    }];
    
    [self expectationForNotification:SRGLetterboxPlaybackDidContinueAutomaticallyNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGLetterboxURNKey] isEqual:MediaURN2];
    }];
    
    CMTime seekTime = CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(5., NSEC_PER_SEC));
    [self.controller seekToPosition:[SRGPosition positionAtTime:seekTime] withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSDate *playbackEndDate1 = NSDate.date;
    
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    // Wait until the next media is played automatically
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePreparing;
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, MediaURN2);
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    XCTAssertTrue([NSDate.date timeIntervalSinceDate:playbackEndDate1] < 1);
}

- (void)testContinuousPlaybackCancellation
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.playlist.continuousPlaybackTransitionDuration = 5.;
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // No effect, no pending continuation
    [self.controller cancelContinuousPlayback];
    
    // Start with the first item in the playlist
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    // No effect, no pending continuation
    [self.controller cancelContinuousPlayback];
    
    // Seek near the end
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateEnded;
    }];
    
    CMTime seekTime = CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(5., NSEC_PER_SEC));
    [self.controller seekToPosition:[SRGPosition positionAtTime:seekTime] withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Cancel pending continuation. The second media will not be played automatically
    XCTAssertNotNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNotNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertEqualObjects(self.controller.continuousPlaybackUpcomingMedia.URN, MediaURN2);
    
    [self.controller cancelContinuousPlayback];
    
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    // Wait some time. We don't expect playback to automatically continue with the next item
    id eventObserver1 = [NSNotificationCenter.defaultCenter addObserverForName:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"The player must remain in the current state");
    }];
    
    id eventObserver2 = [NSNotificationCenter.defaultCenter addObserverForName:SRGLetterboxPlaybackDidContinueAutomaticallyNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"The player must not continue automatically");
    }];
    
    [self expectationForElapsedTimeInterval:10. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:eventObserver1];
        [NSNotificationCenter.defaultCenter removeObserver:eventObserver2];
    }];
    
    XCTAssertEqualObjects(self.controller.URN, MediaURN1);
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
}

- (void)testPlaylistChangesDuringContinuousPlaybackTransition
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    static NSTimeInterval kContinuousPlaybackTransitionDuration = 5.;
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.playlist.continuousPlaybackTransitionDuration = kContinuousPlaybackTransitionDuration;
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Start with the first item in the playlist
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    // Seek near the end
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateEnded;
    }];
    
    CMTime seekTime = CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(5., NSEC_PER_SEC));
    [self.controller seekToPosition:[SRGPosition positionAtTime:seekTime] withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSDate *playbackEndDate1 = NSDate.date;
    
    XCTAssertNotNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNotNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertEqualObjects(self.controller.continuousPlaybackUpcomingMedia.URN, MediaURN2);
    
    // Change the playlist (e.g. clear it)
    self.playlist = nil;
    
    // The media to be played next is not affected by the playlist update
    XCTAssertNotNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNotNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertEqualObjects(self.controller.continuousPlaybackUpcomingMedia.URN, MediaURN2);
    
    // The next media which was previously found will still be played
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePreparing;
    }];
    
    [self expectationForNotification:SRGLetterboxPlaybackDidContinueAutomaticallyNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGLetterboxURNKey] isEqual:MediaURN2];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(self.controller.URN, MediaURN2);
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    XCTAssertTrue([NSDate.date timeIntervalSinceDate:playbackEndDate1] - kContinuousPlaybackTransitionDuration < 1);
}

- (void)testSwitchToSegmentDuringContinuousPlaybackTransition
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    static NSTimeInterval kContinuousPlaybackTransitionDuration = 5.;
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.playlist.continuousPlaybackTransitionDuration = kContinuousPlaybackTransitionDuration;
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Start with the first item in the playlist
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    // Seek near the end
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateEnded;
    }];
    
    CMTime seekTime = CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(5., NSEC_PER_SEC));
    [self.controller seekToPosition:[SRGPosition positionAtTime:seekTime] withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Switch to another segment. Continuous playback must be cancelled
    id eventObserver1 = [NSNotificationCenter.defaultCenter addObserverForName:SRGLetterboxPlaybackDidContinueAutomaticallyNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"Playback must not continue automatically");
    }];
    
    [self expectationForElapsedTimeInterval:8. withHandler:nil];
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller switchToURN:@"urn:rts:video:9309816" withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:eventObserver1];
    }];
}

// FIXME: -playNextMedia use previous values, but here it can be incorrectly used to initiate playlist playback with the
//        first media (and therefore starts with standalone = NO). A few options:
//          1. Prevent -playNextMedia from being used for initial item playback
//          2. Make all parameters configurable by the playlist data source
//          3. Add all parameters to the -playNext / previous / upcoming media calls.
//        1 is probably simple but confusing. We already have part of 2 (start time), but we should probably wrap all
//        parameters in a single configuration class to avoid data source methods for each and every parameter. 3 is
//        not possible since the calls might be made automatically (especially -playUpcomingMedia).
- (void)testSwitchToChapterDuringContinuousPlaybackTransition
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    static NSTimeInterval kContinuousPlaybackTransitionDuration = 5.;
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.playlist.continuousPlaybackTransitionDuration = kContinuousPlaybackTransitionDuration;
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Start with the first item in the playlist
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    // Seek near the end
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateEnded;
    }];
    
    CMTime seekTime = CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(5., NSEC_PER_SEC));
    [self.controller seekToPosition:[SRGPosition positionAtTime:seekTime] withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // TODO:
}

- (void)testSeekWithinMediaDuringContinuousPlaybackTransition
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    static NSTimeInterval kContinuousPlaybackTransitionDuration = 5.;
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.playlist.continuousPlaybackTransitionDuration = kContinuousPlaybackTransitionDuration;
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Start with the first item in the playlist
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    // Seek near the end
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateEnded;
    }];
    
    CMTime seekTime = CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(5., NSEC_PER_SEC));
    [self.controller seekToPosition:[SRGPosition positionAtTime:seekTime] withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Restart playback of the current media at its default position. Continuous playback must be cancelled
    id eventObserver1 = [NSNotificationCenter.defaultCenter addObserverForName:SRGLetterboxPlaybackDidContinueAutomaticallyNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"Playback must not continue automatically");
    }];
    
    [self expectationForElapsedTimeInterval:8. withHandler:nil];
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller seekToPosition:SRGPosition.defaultPosition withCompletionHandler:^(BOOL finished) {
        [self.controller play];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:eventObserver1];
    }];
}

- (void)testOtherMediaPlaybackDuringContinuousPlaybackTransition
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    static NSTimeInterval kContinuousPlaybackTransitionDuration = 5.;
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.playlist.continuousPlaybackTransitionDuration = kContinuousPlaybackTransitionDuration;
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Start with the first item in the playlist
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertNil(self.controller.continuousPlaybackTransitionStartDate);
    XCTAssertNil(self.controller.continuousPlaybackTransitionEndDate);
    XCTAssertNil(self.controller.continuousPlaybackUpcomingMedia);
    
    // Seek near the end
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateEnded;
    }];
    
    CMTime seekTime = CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(5., NSEC_PER_SEC));
    [self.controller seekToPosition:[SRGPosition positionAtTime:seekTime] withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Restart playback of the current media at its default position. Continuous playback must be cancelled
    id eventObserver1 = [NSNotificationCenter.defaultCenter addObserverForName:SRGLetterboxPlaybackDidContinueAutomaticallyNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"Playback must not continue automatically");
    }];
    
    [self expectationForElapsedTimeInterval:8. withHandler:nil];
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playURN:@"urn:rts:video:9943299" standalone:NO];
    
    [self waitForExpectationsWithTimeout:30. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:eventObserver1];
    }];
}

- (void)testContinuousPlaybackTransitionKeyValueObserving
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.playlist.continuousPlaybackTransitionDuration = 5.;
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Start with the first item in the playlist
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Seek near the end end wait for the transition to start
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateEnded;
    }];
    [self keyValueObservingExpectationForObject:self.controller keyPath:@keypath(SRGLetterboxController.new, continuousPlaybackTransitionStartDate) handler:^BOOL(SRGLetterboxController * _Nonnull controller, NSDictionary * _Nonnull change) {
        return controller.continuousPlaybackTransitionStartDate != nil;
    }];
    [self keyValueObservingExpectationForObject:self.controller keyPath:@keypath(SRGLetterboxController.new, continuousPlaybackTransitionEndDate) handler:^BOOL(SRGLetterboxController * _Nonnull controller, NSDictionary * _Nonnull change) {
        return controller.continuousPlaybackTransitionEndDate != nil;
    }];
    [self keyValueObservingExpectationForObject:self.controller keyPath:@keypath(SRGLetterboxController.new, continuousPlaybackUpcomingMedia) handler:^BOOL(SRGLetterboxController * _Nonnull controller, NSDictionary * _Nonnull change) {
        return [controller.continuousPlaybackUpcomingMedia.URN isEqual:MediaURN2];
    }];
    
    CMTime seekTime = CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(5., NSEC_PER_SEC));
    [self.controller seekToPosition:[SRGPosition positionAtTime:seekTime] withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Wait for the transition to end
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePreparing;
    }];
    [self keyValueObservingExpectationForObject:self.controller keyPath:@keypath(SRGLetterboxController.new, continuousPlaybackTransitionStartDate) handler:^BOOL(SRGLetterboxController * _Nonnull controller, NSDictionary * _Nonnull change) {
        return controller.continuousPlaybackTransitionStartDate == nil;
    }];
    [self keyValueObservingExpectationForObject:self.controller keyPath:@keypath(SRGLetterboxController.new, continuousPlaybackTransitionEndDate) handler:^BOOL(SRGLetterboxController * _Nonnull controller, NSDictionary * _Nonnull change) {
        return controller.continuousPlaybackTransitionEndDate == nil;
    }];
    [self keyValueObservingExpectationForObject:self.controller keyPath:@keypath(SRGLetterboxController.new, continuousPlaybackUpcomingMedia) handler:^BOOL(SRGLetterboxController * _Nonnull controller, NSDictionary * _Nonnull change) {
        return controller.continuousPlaybackUpcomingMedia.URN == nil;
    }];
    [self expectationForNotification:SRGLetterboxPlaybackDidContinueAutomaticallyNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGLetterboxURNKey] isEqual:MediaURN2];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testTogglePlayPauseDuringContinuousPlaybackTransition
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.playlist.continuousPlaybackTransitionDuration = 5.;
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Start with the first item in the playlist
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Seek near the end end wait for the transition to start
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateEnded;
    }];
    
    CMTime seekTime = CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(5., NSEC_PER_SEC));
    [self.controller seekToPosition:[SRGPosition positionAtTime:seekTime] withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Wait for longer than the transition duration. -togglePlayPause must interrupt continuous playback.
    id eventObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGLetterboxPlaybackDidContinueAutomaticallyNotification object:self.controller queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"The player must not continue automatically");
    }];
    
    [self expectationForElapsedTimeInterval:10. withHandler:nil];
    
    [self.controller togglePlayPause];
    
    [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:eventObserver];
    }];
}

- (void)testPlaylistWithStartTime
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.playlist.startTime = CMTimeMakeWithSeconds(10., NSEC_PER_SEC);
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqual(CMTimeGetSeconds(self.controller.currentTime), 10.);
}

- (void)testContinuousPlaybackWithStartTime
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Media request"];
    
    [[self.dataProvider mediasWithURNs:@[MediaURN1, MediaURN2] completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        self.playlist = [[TestPlaylist alloc] initWithMedias:medias];
        self.playlist.continuousPlaybackTransitionDuration = 1.;
        self.playlist.startTime = CMTimeMakeWithSeconds(10., NSEC_PER_SEC);
        self.controller.playlistDataSource = self.playlist;
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    XCTAssertTrue([self.controller playNextMedia]);
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Seek near the end
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStateEnded;
    }];
    
    CMTime seekTime = CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(5., NSEC_PER_SEC));
    [self.controller seekToPosition:[SRGPosition positionAtTime:seekTime] withCompletionHandler:nil];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self expectationForNotification:SRGLetterboxPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    // Wait until continuous playback starts playback of the next media
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqual(CMTimeGetSeconds(self.controller.currentTime), 10.);
}

@end
