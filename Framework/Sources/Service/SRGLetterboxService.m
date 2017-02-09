//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGLetterboxService.h"

#import "SRGLetterboxController+Private.h"
#import "UIDevice+SRGLetterbox.h"

#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <MediaPlayer/MediaPlayer.h>
#import <SRGMediaPlayer/SRGMediaPlayer.h>
#import <YYWebImage/YYWebImage.h>

@interface SRGLetterboxService ()

@property (nonatomic, weak) id periodicTimeObserver;

@property (nonatomic, weak) id<SRGLetterboxPictureInPictureDelegate> pictureInPictureDelegate;
@property (nonatomic, getter=isMirroredOnExternalScreen) BOOL mirroredOnExternalScreen;

@property (nonatomic) YYWebImageOperation *imageOperation;

@end

@implementation SRGLetterboxService

#pragma mark Class methods

+ (SRGLetterboxService *)sharedService
{
    static SRGLetterboxService *s_sharedService;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_sharedService = [SRGLetterboxService new];
    });
    return s_sharedService;
}

#pragma mark Object lifecycle

- (instancetype)init
{
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        [self setupRemoteCommandCenter];
    }
    return self;
}

- (void)dealloc
{
    self.controller = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Getters and setters

- (void)setController:(SRGLetterboxController *)controller
{
    if (_controller) {
        SRGMediaPlayerController *previousMediaPlayerController = _controller.mediaPlayerController;
        previousMediaPlayerController.pictureInPictureController.delegate = nil;
        
        previousMediaPlayerController.playerConfigurationBlock = ^(AVPlayer *player) {
            player.allowsExternalPlayback = NO;
        };
        [previousMediaPlayerController reloadPlayerConfiguration];
        
        [previousMediaPlayerController removeObserver:self keyPath:@keypath(previousMediaPlayerController.pictureInPictureController.pictureInPictureActive)];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:SRGMediaPlayerPlaybackStateDidChangeNotification
                                                      object:previousMediaPlayerController];
        
        [previousMediaPlayerController removePeriodicTimeObserver:self.periodicTimeObserver];
    }
    
    [self willChangeValueForKey:@keypath(self.controller)];
    _controller = controller;
    [self didChangeValueForKey:@keypath(self.controller)];
    
    [self updateRemoteCommandCenter];
    [self updateNowPlayingInformation];
    [self updateNowPlayingPlaybackInformation];
    
    if (controller) {
        SRGMediaPlayerController *mediaPlayerController = controller.mediaPlayerController;
        
        mediaPlayerController.playerConfigurationBlock = ^(AVPlayer *player) {
            player.allowsExternalPlayback = YES;
            player.usesExternalPlaybackWhileExternalScreenIsActive = ! self.mirroredOnExternalScreen;
            
            // Only update the audio session if needed to avoid audio hiccups
            NSString *mode = (self.controller.media.mediaType == SRGMediaTypeVideo) ? AVAudioSessionModeMoviePlayback : AVAudioSessionModeDefault;
            if (! [[AVAudioSession sharedInstance].mode isEqualToString:mode]) {
                [[AVAudioSession sharedInstance] setMode:mode error:NULL];
            }
        };
        
        @weakify(self)
        @weakify(mediaPlayerController)
        [mediaPlayerController addObserver:self keyPath:@keypath(mediaPlayerController.pictureInPictureController.pictureInPictureActive) options:0 block:^(MAKVONotification *notification) {
            @strongify(self)
            @strongify(mediaPlayerController)
            
            // When enabling Airplay from the control center while picture in picture is active, picture in picture will be
            // stopped without the usual restoration and stop delegate methods being called. KVO observe changes and call
            // those methods manually
            if (mediaPlayerController.player.externalPlaybackActive) {
                [self pictureInPictureController:mediaPlayerController.pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:^(BOOL restored) {}];
                [self pictureInPictureControllerDidStopPictureInPicture:mediaPlayerController.pictureInPictureController];
            }
        }];
        
        if (mediaPlayerController.pictureInPictureController) {
            mediaPlayerController.pictureInPictureController.delegate = self;
        }
        else {
            @weakify(self)
            mediaPlayerController.pictureInPictureControllerCreationBlock = ^(AVPictureInPictureController *pictureInPictureController) {
                @strongify(self)
                
                pictureInPictureController.delegate = self;
            };
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playbackStateDidChange:)
                                                     name:SRGMediaPlayerPlaybackStateDidChangeNotification
                                                   object:mediaPlayerController];
        
        self.periodicTimeObserver = [mediaPlayerController addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1., NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
            [self updateNowPlayingPlaybackInformation];
            [self updateRemoteCommandCenter];
        }];
    }
}

- (void)setMirroredOnExternalScreen:(BOOL)mirroredOnExternalScreen
{
    if (_mirroredOnExternalScreen == mirroredOnExternalScreen) {
        return;
    }
    
    _mirroredOnExternalScreen = mirroredOnExternalScreen;
    [self.controller.mediaPlayerController reloadPlayerConfiguration];
}

#pragma mark Control center and lock screen integration

- (void)setupRemoteCommandCenter
{
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    
    MPRemoteCommand *playCommand = commandCenter.playCommand;
    [playCommand addTarget:self action:@selector(play:)];
    
    MPRemoteCommand *pauseCommand = commandCenter.pauseCommand;
    [pauseCommand addTarget:self action:@selector(pause:)];
    
    MPRemoteCommand *togglePlayPauseCommand = commandCenter.togglePlayPauseCommand;
    [togglePlayPauseCommand addTarget:self action:@selector(togglePlayPause:)];
    
    MPSkipIntervalCommand *skipForwardIntervalCommand = commandCenter.skipForwardCommand;
    skipForwardIntervalCommand.preferredIntervals = @[@(SRGLetterboxForwardSeekInterval)];
    [skipForwardIntervalCommand addTarget:self action:@selector(seekForward:)];
    
    MPSkipIntervalCommand *skipBackwardIntervalCommand = commandCenter.skipBackwardCommand;
    skipBackwardIntervalCommand.preferredIntervals = @[@(SRGLetterboxBackwardSeekInterval)];
    [skipBackwardIntervalCommand addTarget:self action:@selector(seekBackward:)];
}

- (void)updateRemoteCommandCenter
{
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    SRGMediaPlayerController *mediaPlayerController = self.controller.mediaPlayerController;
    
    // Videos can only be controlled when the device has been locked (mostly for Airplay playback). We don't allow
    // video playback while the app is fully in background for the moment (except if Airplay is enabled)
    if (mediaPlayerController.playbackState != SRGMediaPlayerPlaybackStateIdle
            && (mediaPlayerController.mediaType == SRGMediaTypeAudio
                    || [UIApplication sharedApplication].applicationState != UIApplicationStateBackground
                    || [AVAudioSession srg_isAirplayActive]
                    || [UIDevice srg_isLocked])) {
        commandCenter.playCommand.enabled = YES;
        commandCenter.pauseCommand.enabled = YES;
        commandCenter.togglePlayPauseCommand.enabled = YES;
        commandCenter.skipForwardCommand.enabled = [self.controller canSeekForward];
        commandCenter.skipBackwardCommand.enabled = [self.controller canSeekBackward];
    }
    else {
        commandCenter.playCommand.enabled = NO;
        commandCenter.pauseCommand.enabled = NO;
        commandCenter.togglePlayPauseCommand.enabled = NO;
        commandCenter.skipForwardCommand.enabled = NO;
        commandCenter.skipBackwardCommand.enabled = NO;
    }
}

- (void)updateNowPlayingInformation
{
    NSMutableDictionary *nowPlayingInfo = [NSMutableDictionary dictionary];
    
    SRGMedia *media = self.controller.media;
    switch (media.mediaType) {
        case SRGMediaTypeAudio: {
            nowPlayingInfo[MPMediaItemPropertyMediaType] = @(MPMediaTypeAnyAudio);
            break;
        }
            
        case SRGMediaTypeVideo: {
            nowPlayingInfo[MPMediaItemPropertyMediaType] = @(MPMediaTypeAnyVideo);
            break;
        }
            
        default: {
            nowPlayingInfo[MPMediaItemPropertyMediaType] = @(MPMediaTypeAny);
            break;
        }
    }
    
    nowPlayingInfo[MPMediaItemPropertyTitle] = media.title;
    nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = media.lead;
    
    NSURL *imageURL = [media imageURLForDimension:SRGImageDimensionWidth withValue:256.f * [UIScreen mainScreen].scale];
    self.imageOperation = [[YYWebImageManager sharedManager] requestImageWithURL:imageURL options:0 progress:nil transform:nil completion:^(UIImage * _Nullable image, NSURL * _Nonnull url, YYWebImageFromType from, YYWebImageStage stage, NSError * _Nullable error) {
        if (image) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = [[MPMediaItemArtwork alloc] initWithImage:image];
        }
        
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [nowPlayingInfo copy];
    }];
    
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [nowPlayingInfo copy];
}

// Playback information which requires more frequent updates
- (void)updateNowPlayingPlaybackInformation
{
    SRGMediaPlayerController *mediaPlayerController = self.controller.mediaPlayerController;
    NSMutableDictionary *nowPlayingInfo = [[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo mutableCopy];
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(CMTimeGetSeconds(mediaPlayerController.player.currentTime));
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = @(CMTimeGetSeconds(mediaPlayerController.player.currentItem.duration));
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [nowPlayingInfo copy];
}

- (void)play:(id)sender
{
    [self.controller.mediaPlayerController play];
}

- (void)pause:(id)sender
{
    [self.controller.mediaPlayerController pause];
}

- (void)togglePlayPause:(id)sender
{
    [self.controller.mediaPlayerController togglePlayPause];
}

- (void)seekForward:(id)sender
{
    [self.controller seekForwardWithCompletionHandler:nil];
}

- (void)seekBackward:(id)sender
{
    [self.controller seekBackwardWithCompletionHandler:nil];
}

#pragma mark AVPictureInPictureControllerDelegate protocol

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    if ([self.pictureInPictureDelegate respondsToSelector:@selector(letterboxDidStartPictureInPicture)]) {
        [self.pictureInPictureDelegate letterboxDidStartPictureInPicture];
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    // It is very important that the completion handler is called at the very end of the process, otherwise silly
    // things might happen during the restoration (most notably player rate set to 0)
    
    // If stopping picture in picture because of a reset, don't restore anything
    if (self.controller.mediaPlayerController.playbackState == SRGMediaPlayerPlaybackStateIdle) {
        completionHandler(YES);
        return;
    }
    
    if ([self.pictureInPictureDelegate letterboxShouldRestoreUserInterfaceForPictureInPicture]) {
        [self.pictureInPictureDelegate letterboxRestoreUserInterfaceForPictureInPictureWithCompletionHandler:^(BOOL restored) {
            completionHandler(restored);
        }];
    }
    else {
        completionHandler(YES);
    }
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    if ([self.pictureInPictureDelegate respondsToSelector:@selector(letterboxDidStopPictureInPicture)]) {
        [self.pictureInPictureDelegate letterboxDidStopPictureInPicture];
    }
}

#pragma mark Notifications

- (void)playbackStateDidChange:(NSNotification *)notification
{
    if (self.controller.mediaPlayerController.playbackState == SRGMediaPlayerPlaybackStatePreparing) {
        [self updateNowPlayingInformation];
    }
}

// Update commands while transitioning from / to the background (since control availability might be affected)
- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self updateRemoteCommandCenter];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self updateRemoteCommandCenter];
}

#pragma mark KVO

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if ([key isEqualToString:@keypath(SRGLetterboxService.new, controller)]) {
        return NO;
    }
    else {
        return [super automaticallyNotifiesObserversForKey:key];
    }
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; controller: %@>",
            [self class],
            self,
            self.controller];
}

@end
