//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGLetterbox/SRGLetterbox.h>
#import <XCTest/XCTest.h>

static NSURL *ServiceTestURL(void)
{
    return SRGIntegrationLayerTestServiceURL();
}

@interface LetterboxControllerTestCase : XCTestCase

@property (nonatomic) SRGLetterboxController *controller;

@end

@implementation LetterboxControllerTestCase

#pragma mark Setup and teardown

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

- (void)testOnDemandStreamSeeks
{
    XCTestExpectation *mediaCompositionExpectation = [self expectationWithDescription:@"Request succeeded"];
    
    // TTC
    __block SRGMediaComposition *mediaComposition = nil;
    SRGDataProvider *dataProvider = [[SRGDataProvider alloc] initWithServiceURL:ServiceTestURL() businessUnitIdentifier:SRGDataProviderBusinessUnitIdentifierRTS];
    [[dataProvider mediaCompositionForVideoWithUid:@"8297891" completionBlock:^(SRGMediaComposition * _Nullable retrievedMediaComposition, NSError * _Nullable error) {
        XCTAssertNotNil(retrievedMediaComposition);
        mediaComposition = retrievedMediaComposition;
        [mediaCompositionExpectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGMediaPlayerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playMediaComposition:mediaComposition withPreferredProtocol:SRGProtocolNone preferredQuality:SRGQualityNone userInfo:nil resume:YES completionHandler:nil];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue([self.controller canSeekBackward]);
    XCTAssertTrue([self.controller canSeekForward]);

    // Seek to near the end
    [self expectationForNotification:SRGMediaPlayerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller seekPreciselyToTime:CMTimeSubtract(CMTimeRangeGetEnd(self.controller.timeRange), CMTimeMakeWithSeconds(15., NSEC_PER_SEC)) withCompletionHandler:nil];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue([self.controller canSeekBackward]);
    XCTAssertFalse([self.controller canSeekForward]);
    
    // Use standard seeks
    [self expectationForNotification:SRGMediaPlayerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller seekBackwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertTrue(finished);
    }];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue([self.controller canSeekBackward]);
    XCTAssertTrue([self.controller canSeekForward]);
    
    [self expectationForNotification:SRGMediaPlayerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller seekForwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertTrue(finished);
    }];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue([self.controller canSeekBackward]);
    XCTAssertFalse([self.controller canSeekForward]);
}

- (void)testLiveStreamSeeks
{
    XCTestExpectation *mediaCompositionExpectation = [self expectationWithDescription:@"Request succeeded"];
    
    // RSI 1
    __block SRGMediaComposition *mediaComposition = nil;
    SRGDataProvider *dataProvider = [[SRGDataProvider alloc] initWithServiceURL:ServiceTestURL() businessUnitIdentifier:SRGDataProviderBusinessUnitIdentifierRSI];
    [[dataProvider mediaCompositionForVideoWithUid:@"livestream_La1" completionBlock:^(SRGMediaComposition * _Nullable retrievedMediaComposition, NSError * _Nullable error) {
        XCTAssertNotNil(retrievedMediaComposition);
        mediaComposition = retrievedMediaComposition;
        [mediaCompositionExpectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGMediaPlayerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playMediaComposition:mediaComposition withPreferredProtocol:SRGProtocolNone preferredQuality:SRGQualityNone userInfo:nil resume:YES completionHandler:nil];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertFalse([self.controller canSeekBackward]);
    XCTAssertFalse([self.controller canSeekForward]);
    
    // Cannot seek
    [self.controller seekBackwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertFalse(finished);
    }];
    [self.controller seekForwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertFalse(finished);
    }];
}

- (void)testDVRStreamSeeks
{
    XCTestExpectation *mediaCompositionExpectation = [self expectationWithDescription:@"Request succeeded"];
    
    // RTS 1
    __block SRGMediaComposition *mediaComposition = nil;
    SRGDataProvider *dataProvider = [[SRGDataProvider alloc] initWithServiceURL:ServiceTestURL() businessUnitIdentifier:SRGDataProviderBusinessUnitIdentifierRTS];
    [[dataProvider mediaCompositionForVideoWithUid:@"1967124" completionBlock:^(SRGMediaComposition * _Nullable retrievedMediaComposition, NSError * _Nullable error) {
        XCTAssertNotNil(retrievedMediaComposition);
        mediaComposition = retrievedMediaComposition;
        [mediaCompositionExpectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGMediaPlayerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playMediaComposition:mediaComposition withPreferredProtocol:SRGProtocolNone preferredQuality:SRGQualityNone userInfo:nil resume:YES completionHandler:nil];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue(self.controller.live);
    
    XCTAssertTrue([self.controller canSeekBackward]);
    XCTAssertFalse([self.controller canSeekForward]);
    
    // Seek in the past
    [self expectationForNotification:SRGMediaPlayerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller seekBackwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertTrue(finished);
    }];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertFalse(self.controller.live);
    
    XCTAssertTrue([self.controller canSeekBackward]);
    XCTAssertTrue([self.controller canSeekForward]);
    
    // Seek forward again
    [self expectationForNotification:SRGMediaPlayerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller seekForwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertTrue(finished);
    }];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue(self.controller.live);
    
    XCTAssertTrue([self.controller canSeekBackward]);
    XCTAssertFalse([self.controller canSeekForward]);
}

- (void)testMultipleSeeks
{
    XCTestExpectation *mediaCompositionExpectation = [self expectationWithDescription:@"Request succeeded"];
    
    __block SRGMediaComposition *mediaComposition = nil;
    SRGDataProvider *dataProvider = [[SRGDataProvider alloc] initWithServiceURL:ServiceTestURL() businessUnitIdentifier:SRGDataProviderBusinessUnitIdentifierRTS];
    [[dataProvider mediaCompositionForVideoWithUid:@"8297891" completionBlock:^(SRGMediaComposition * _Nullable retrievedMediaComposition, NSError * _Nullable error) {
        XCTAssertNotNil(retrievedMediaComposition);
        mediaComposition = retrievedMediaComposition;
        [mediaCompositionExpectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    // Wait until the stream is playing
    [self expectationForNotification:SRGMediaPlayerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller playMediaComposition:mediaComposition withPreferredProtocol:SRGProtocolNone preferredQuality:SRGQualityNone userInfo:nil resume:YES completionHandler:nil];
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Pile up seeks forwards
    [self expectationForNotification:SRGMediaPlayerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller seekForwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertFalse(finished);
    }];
    [self.controller seekForwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertTrue(finished);
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue([self.controller canSeekBackward]);
    
    // Pile up seeks backwards
    [self expectationForNotification:SRGMediaPlayerPlaybackStateDidChangeNotification object:self.controller handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying;
    }];
    
    [self.controller seekBackwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertFalse(finished);
    }];
    [self.controller seekBackwardWithCompletionHandler:^(BOOL finished) {
        XCTAssertTrue(finished);
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertTrue([self.controller canSeekBackward]);
}

@end