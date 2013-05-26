//
//  VLCDropboxTableViewCell.h
//  VLC for iOS
//
//  Created by Felix Paul Kühne on 24.05.13.
//  Copyright (c) 2013 VideoLAN. All rights reserved.
//

#import <DropboxSDK/DropboxSDK.h>

@interface VLCDropboxTableViewCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, strong) IBOutlet UIImageView *thumbnailView;

@property (nonatomic, retain) DBMetadata *fileMetadata;

+ (VLCDropboxTableViewCell *)cellWithReuseIdentifier:(NSString *)ident;
+ (CGFloat)heightOfCell;

@end
