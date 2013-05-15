//
//  VLCDetailViewController.h
//  AspenProject
//
//  Created by Felix Paul Kühne on 27.02.13.
//  Copyright (c) 2013 VideoLAN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VLCMovieViewController : UIViewController <VLCMediaPlayerDelegate, UIActionSheetDelegate>
{
    VLCMediaPlayer *_mediaPlayer;

    BOOL _controlsHidden;
    BOOL _videoFiltersHidden;
    BOOL _playbackViewHidden;

    UIActionSheet *_subtitleActionSheet;
    UIActionSheet *_audiotrackActionSheet;
    UIActionSheet *_aspectRatioActionSheet;
    UIActionSheet *_cropActionSheet;

    float _currentPlaybackRate;

    NSTimer *_idleTimer;
}

@property (nonatomic, strong) IBOutlet UIView *movieView;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *backButton;
@property (nonatomic, strong) IBOutlet UISlider *positionSlider;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *timeDisplay;
@property (nonatomic, strong) IBOutlet UIButton *playPauseButton;
@property (nonatomic, strong) IBOutlet UIButton *bwdButton;
@property (nonatomic, strong) IBOutlet UIButton *fwdButton;
@property (nonatomic, strong) IBOutlet UIButton *subtitleSwitcherButton;
@property (nonatomic, strong) IBOutlet UIButton *audioSwitcherButton;
@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;
@property (nonatomic, strong) IBOutlet UIView *controllerPanel;

@property (nonatomic, strong) IBOutlet UIView *playingExternallyView;
@property (nonatomic, strong) IBOutlet UILabel *playingExternallyTitle;
@property (nonatomic, strong) IBOutlet UILabel *playingExternallyDescription;

@property (nonatomic, strong) IBOutlet UIView *videoFilterView;
@property (nonatomic, strong) IBOutlet UIButton *videoFilterButton;
@property (nonatomic, strong) IBOutlet UILabel *hueLabel;
@property (nonatomic, strong) IBOutlet UISlider *hueSlider;
@property (nonatomic, strong) IBOutlet UILabel *contrastLabel;
@property (nonatomic, strong) IBOutlet UISlider *contrastSlider;
@property (nonatomic, strong) IBOutlet UILabel *brightnessLabel;
@property (nonatomic, strong) IBOutlet UISlider *brightnessSlider;
@property (nonatomic, strong) IBOutlet UILabel *saturationLabel;
@property (nonatomic, strong) IBOutlet UISlider *saturationSlider;
@property (nonatomic, strong) IBOutlet UILabel *gammaLabel;
@property (nonatomic, strong) IBOutlet UISlider *gammaSlider;
@property (nonatomic, strong) IBOutlet UIButton *resetVideoFilterButton;

@property (nonatomic, strong) IBOutlet UIView *playbackView;
@property (nonatomic, strong) IBOutlet UIButton *playbackButton;
@property (nonatomic, strong) IBOutlet UISlider *playbackSpeedSlider;
@property (nonatomic, strong) IBOutlet UILabel *playbackSpeedLabel;
@property (nonatomic, strong) IBOutlet UILabel *playbackSpeedIndicator;
@property (nonatomic, strong) IBOutlet UIButton *aspectRatioButton;
@property (nonatomic, strong) IBOutlet UIButton *cropButton;

@property (nonatomic, strong) MLFile *mediaItem;
@property (nonatomic, strong) NSURL *url;

- (IBAction)closePlayback:(id)sender;
- (IBAction)positionSliderAction:(id)sender;

- (IBAction)play:(id)sender;
- (IBAction)backward:(id)sender;
- (IBAction)forward:(id)sender;
- (IBAction)switchAudioTrack:(id)sender;
- (IBAction)switchSubtitleTrack:(id)sender;

- (IBAction)videoFilterToggle:(id)sender;
- (IBAction)videoFilterSliderAction:(id)sender;

- (IBAction)playbackSpeedSliderAction:(id)sender;
- (IBAction)videoDimensionAction:(id)sender;

@end
