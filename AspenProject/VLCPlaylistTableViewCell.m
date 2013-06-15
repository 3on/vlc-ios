//
//  VLCPlaylistTableViewCell.m
//  AspenProject
//
//  Created by Felix Paul Kühne on 01.04.13.
//  Copyright (c) 2013 VideoLAN. All rights reserved.
//
//  Refer to the COPYING file of the official project for license.
//

#import "VLCPlaylistTableViewCell.h"

#define MAX_CACHE_SIZE 14 // twice the number of items shown on iPhone 5

@implementation VLCPlaylistTableViewCell

+ (VLCPlaylistTableViewCell *)cellWithReuseIdentifier:(NSString *)ident
{
    NSArray *nibContentArray = [[NSBundle mainBundle] loadNibNamed:@"VLCPlaylistTableViewCell" owner:nil options:nil];
    NSAssert([nibContentArray count] == 1, @"meh");
    NSAssert([[nibContentArray lastObject] isKindOfClass:[VLCPlaylistTableViewCell class]], @"meh meh");
    VLCPlaylistTableViewCell *cell = (VLCPlaylistTableViewCell *)[nibContentArray lastObject];

    return cell;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self _updatedDisplayedInformationForKeyPath:keyPath];
}

- (void)setMediaObject:(MLFile *)mediaObject
{
    if (_mediaObject != mediaObject) {
        [_mediaObject removeObserver:self forKeyPath:@"computedThumbnail"];
        [_mediaObject removeObserver:self forKeyPath:@"lastPosition"];
        [_mediaObject removeObserver:self forKeyPath:@"duration"];
        [_mediaObject removeObserver:self forKeyPath:@"fileSizeInBytes"];
        [_mediaObject removeObserver:self forKeyPath:@"title"];
        [_mediaObject removeObserver:self forKeyPath:@"thumbnailTimeouted"];
        [_mediaObject removeObserver:self forKeyPath:@"unread"];
        [_mediaObject didHide];

        _mediaObject = mediaObject;

        [_mediaObject addObserver:self forKeyPath:@"computedThumbnail" options:0 context:nil];
        [_mediaObject addObserver:self forKeyPath:@"lastPosition" options:0 context:nil];
        [_mediaObject addObserver:self forKeyPath:@"duration" options:0 context:nil];
        [_mediaObject addObserver:self forKeyPath:@"fileSizeInBytes" options:0 context:nil];
        [_mediaObject addObserver:self forKeyPath:@"title" options:0 context:nil];
        [_mediaObject addObserver:self forKeyPath:@"thumbnailTimeouted" options:0 context:nil];
        [_mediaObject addObserver:self forKeyPath:@"unread" options:0 context:nil];
        [_mediaObject willDisplay];
    }

    [self _updatedDisplayedInformationForKeyPath:NULL];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self _updatedDisplayedInformationForKeyPath:@"editing"];
}

- (void)_updatedDisplayedInformationForKeyPath:(NSString *)keyPath
{
    self.titleLabel.text = self.mediaObject.title;
    if (self.isEditing)
        self.subtitleLabel.text = [NSString stringWithFormat:@"%@ — %i MB", [VLCTime timeWithNumber:[self.mediaObject duration]], (int)([self.mediaObject fileSizeInBytes] / 1e6)];
    else {
        self.subtitleLabel.text = [NSString stringWithFormat:@"%@", [VLCTime timeWithNumber:[self.mediaObject duration]]];
        if (self.mediaObject.videoTrack)
            self.subtitleLabel.text = [self.subtitleLabel.text stringByAppendingFormat:@" — %@x%@", [[self.mediaObject videoTrack] valueForKey:@"width"], [[self.mediaObject videoTrack] valueForKey:@"height"]];
    }
    if ([keyPath isEqualToString:@"computedThumbnail"] || !keyPath) {
        static NSMutableArray *_thumbnailCacheIndex;
        static NSMutableDictionary *_thumbnailCache;
        if (!_thumbnailCache)
            _thumbnailCache = [[NSMutableDictionary alloc] initWithCapacity:MAX_CACHE_SIZE];
        if (!_thumbnailCacheIndex)
            _thumbnailCacheIndex = [[NSMutableArray alloc] initWithCapacity:MAX_CACHE_SIZE];

        NSManagedObjectID *objID = self.mediaObject.objectID;
        if ([_thumbnailCacheIndex containsObject:objID]) {
            [_thumbnailCacheIndex removeObject:objID];
            [_thumbnailCacheIndex insertObject:objID atIndex:0];
        } else {
            if (_thumbnailCacheIndex.count >= MAX_CACHE_SIZE) {
                [_thumbnailCache removeObjectForKey:[_thumbnailCacheIndex lastObject]];
                [_thumbnailCacheIndex removeLastObject];
            }
            [_thumbnailCache setObject:self.mediaObject.computedThumbnail forKey:objID];
            [_thumbnailCacheIndex insertObject:objID atIndex:0];
        }
        self.thumbnailView.image = [_thumbnailCache objectForKey:objID];
    }
    self.progressIndicator.progress = self.mediaObject.lastPosition.floatValue;

    self.progressIndicator.hidden = ((self.progressIndicator.progress < .1f) || (self.progressIndicator.progress > .95f)) ? YES : NO;
    self.mediaIsUnreadView.hidden = !self.mediaObject.unread.intValue;

    [self setNeedsDisplay];
}

+ (CGFloat)heightOfCell
{
    return 80.;
}

@end
