//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSTextField.h"

#import <SessionUIKit/SessionUIKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSTextField

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self ows_applyTheme];
    }

    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self ows_applyTheme];
    }

    return self;
}

- (void)ows_applyTheme
{
    self.keyboardAppearance = LKAppModeUtilities.isLightMode ? UIKeyboardAppearanceDefault : UIKeyboardAppearanceDark;
}

@end

NS_ASSUME_NONNULL_END
