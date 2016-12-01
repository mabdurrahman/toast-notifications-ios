/*

iToast.m

MIT LICENSE

Copyright (c) 2011 Guru Software

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/


#import "iToast.h"
#import <QuartzCore/QuartzCore.h>

#define CURRENT_TOAST_TAG 6984678
#define CURRENT_TOAST_LABEL_TAG 6984679
#define CURRENT_TOAST_IMAGE_TAG 6984680

static const CGFloat kComponentPadding = 5;

static iToastSettings *sharedSettings = nil;

@interface iToast(private)

- (iToast *)settings;
- (CGRect)_toastFrameForImageSize:(CGSize)imageSize withLocation:(iToastImageLocation)location andTextSize:(CGSize)textSize;
- (CGRect)_frameForImage:(iToastType)type inToastFrame:(CGRect)toastFrame;

@end

@implementation iToast

- (id)initWithText:(NSString *)txt {
    if (self = [super init]) {
        text = [txt copy];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)show {
    [self show:iToastTypeNone];
}

- (void)show:(iToastType)type {
    
    iToastSettings *theSettings = _settings;
    
    if (!theSettings) {
        theSettings = [iToastSettings getSharedSettings];
    }
    
    UILabel *label = [self createLabel:theSettings];
    
    UIButton *v = [UIButton buttonWithType:UIButtonTypeCustom];
    v.backgroundColor = [UIColor colorWithRed:theSettings.bgRed green:theSettings.bgGreen blue:theSettings.bgBlue alpha:theSettings.bgAlpha];
    v.tag = CURRENT_TOAST_TAG;
    
    [v addSubview:label];
    
    UIImage *image = [theSettings.images valueForKey:[NSString stringWithFormat:@"%i", type]];
    if (image) {
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        imageView.tag = CURRENT_TOAST_IMAGE_TAG;
        [v addSubview:imageView];
    }
    
    UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
    
    [self removePreviousToast];
    [window addSubview:v];
    
    view = v;
    [self adjustToast];
    
    v.alpha = 0;
    [UIView beginAnimations:nil context:nil];
    v.alpha = 1;
    [UIView commitAnimations];
    
    if (timer && [timer isValid]) {
        [timer invalidate];
    }
    timer = [NSTimer timerWithTimeInterval:((float)theSettings.duration) / 1000
                                    target:self selector:@selector(removeToast:)
                                  userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    [v addTarget:self action:@selector(removeToast:) forControlEvents:UIControlEventTouchDown];
}

- (UILabel *)createLabel:(iToastSettings *)toastSettings {
    
    UIFont *font = [self getFont:toastSettings];
    
    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.font = font;
    label.text = text;
    label.numberOfLines = 0;
    [label setTextAlignment:NSTextAlignmentCenter];
    if (toastSettings.useShadow) {
        label.shadowColor = [UIColor darkGrayColor];
        label.shadowOffset = CGSizeMake(1, 1);
    }
    label.tag = CURRENT_TOAST_LABEL_TAG;
    
    return label;
}

- (UIFont *)getFont:(iToastSettings *)toastSettings {
    UIFont *font = nil;
    
    if (toastSettings.fontName) {
        font = [UIFont fontWithName:toastSettings.fontName size:toastSettings.fontSize];
    } else {
        font = [UIFont systemFontOfSize:toastSettings.fontSize];
    }
    return font;
}

- (void)adjustToast {
    if (view == nil || view.alpha == 0) {
        return;
    }
    
    UILabel* label = (UILabel*)[view viewWithTag:CURRENT_TOAST_LABEL_TAG];
    if (label == nil) {
        return;
    }
    
    // imageView and image could be nil, but it's OK in Objective-C
    UIImageView* imageView = (UIImageView*)[view viewWithTag:CURRENT_TOAST_IMAGE_TAG];
    UIImage* image = imageView.image;
    
    UIView* v = view;
    
    iToastSettings *theSettings = _settings;
    if (!theSettings) {
        theSettings = [iToastSettings getSharedSettings];
    }
    
    UIFont *font = [self getFont:theSettings];
    
    UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
    
    CGSize textSize = [self textSizeWithFont:font toastSettings:theSettings nextToImageView:image inWindowSize:window.frame.size];
    
    if (image) {
        switch ([theSettings imageLocation]) {
            case iToastImageLocationLeft: {
                v.frame = CGRectMake(0, 0, window.frame.size.width, textSize.height + kComponentPadding * 2);
                
                [label setTextAlignment:NSTextAlignmentLeft];
                label.center = CGPointMake(image.size.width + kComponentPadding * 2 + textSize.width / 2,
                                           v.frame.size.height / 2);
                
                imageView.frame = [self _getFrameForImage:image inToastFrame:v.frame];
                
                break;
            }
            case iToastImageLocationTop: {
                v.frame = CGRectMake(0, 0, window.frame.size.width, textSize.height + image.size.height + kComponentPadding * 3);
                
                [label setTextAlignment:NSTextAlignmentCenter];
                label.center = CGPointMake(v.frame.size.width / 2,
                                           image.size.height + kComponentPadding * 2 + textSize.height / 2);
                
                imageView.frame = [self _getFrameForImage:image inToastFrame:v.frame];
                
                break;
            }
            default:
                break;
        }
    } else {
        v.frame = CGRectMake(0, 0, window.frame.size.width, textSize.height + kComponentPadding * 2);
        
        label.center = CGPointMake(v.frame.size.width / 2, v.frame.size.height / 2);
    }
    
    CGPoint point = [self centerOfLabel:theSettings toastSize:v.frame.size windowSize:window.frame.size];
    
    v.center = point;
    v.frame = CGRectIntegral(v.frame);
    
    CGRect lbfrm = CGRectMake(label.center.x - textSize.width / 2, label.center.y - textSize.height / 2, textSize.width, textSize.height);
    lbfrm.origin.x = ceil(lbfrm.origin.x);
    lbfrm.origin.y = ceil(lbfrm.origin.y);
    label.frame = lbfrm;
}

- (CGSize)textSizeWithFont:(UIFont *)font toastSettings:(iToastSettings *)toastSettings nextToImageView:(UIImage *)image inWindowSize:(CGSize)windowSize {
    CGSize textSize = CGSizeZero;
    CGFloat maxTextWidth = windowSize.width - image.size.width - kComponentPadding * 3;
    
    if (image) {
        switch ([toastSettings imageLocation]) {
            case iToastImageLocationLeft: {
                maxTextWidth = windowSize.width - image.size.width - kComponentPadding * 3;
                
                break;
            }
            case iToastImageLocationTop: {
                maxTextWidth = windowSize.width - kComponentPadding * 2;
                
                break;
            }
            default:
                break;
        }
    } else {
        maxTextWidth = windowSize.width - image.size.width - kComponentPadding * 3;
    }
    
    textSize = [text boundingRectWithSize:CGSizeMake(maxTextWidth, windowSize.height)
                                  options:NSStringDrawingUsesLineFragmentOrigin
                               attributes:@{NSFontAttributeName:font}
                                  context:nil].size;
    textSize.width = textSize.width > maxTextWidth? maxTextWidth : textSize.width;
    textSize.height = textSize.height > toastSettings.minHeight? textSize.height : toastSettings.minHeight;
    
    return textSize;
}

- (CGPoint)centerOfLabel:(iToastSettings *)toastSettings toastSize:(CGSize)toastSize windowSize:(CGSize)windowSize {
    CGPoint point;
    
    // don't need to set correct orientation/location regarding device orientation
    // see commit logs to retrieve it if needed
    
    if (toastSettings.gravity == iToastGravityTop) {
        point = CGPointMake(windowSize.width / 2, toastSettings.marginTop + toastSize.height / 2);
    } else if (toastSettings.gravity == iToastGravityBottom) {
        point = CGPointMake(windowSize.width / 2, windowSize.height - toastSettings.marginBottom - toastSize.height / 2);
    } else if (toastSettings.gravity == iToastGravityCenter) {
        point = CGPointMake(windowSize.width / 2, windowSize.height / 2);
    } else {
        point = toastSettings.postition;
    }
    point = CGPointMake(point.x + toastSettings.offsetLeft, point.y + toastSettings.offsetTop);
    
    return point;
}

- (void)removePreviousToast {
    UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
    
    UIView *currentToast = [window viewWithTag:CURRENT_TOAST_TAG];
    if (currentToast != nil) {
        // set the alpha to zero to avoid unnecessary adjust calculation when rotating
        currentToast.alpha = 0;
        [currentToast removeFromSuperview];
    }
}

- (void)showToast:(UIView *)toastView {
    
    toastView.alpha = 0;
    [UIView beginAnimations:nil context:nil];
    toastView.alpha = 1;
    [UIView commitAnimations];
}

- (void)orientationChanged:(NSNotification *)notification {
    [self adjustToast];
}

- (CGRect)_toastFrameForImageSize:(CGSize)imageSize withLocation:(iToastImageLocation)location andTextSize:(CGSize)textSize {
    CGRect theRect = CGRectZero;
    switch (location) {
        case iToastImageLocationLeft:
            theRect = CGRectMake(0, 0,
                                 imageSize.width + textSize.width + kComponentPadding * 3,
                                 MAX(textSize.height, imageSize.height) + kComponentPadding * 2);
            break;
        case iToastImageLocationTop:
            theRect = CGRectMake(0, 0,
                                 MAX(textSize.width, imageSize.width) + kComponentPadding * 2,
                                 imageSize.height + textSize.height + kComponentPadding * 3);
            
        default:
            break;
    }
    return theRect;
}

- (CGRect)_getFrameForImage:(UIImage *)image inToastFrame:(CGRect)toastFrame {
    iToastSettings *theSettings = _settings;
    
    if (!image) return CGRectZero;
    
    CGRect imageFrame = CGRectZero;
    
    switch ([theSettings imageLocation]) {
        case iToastImageLocationLeft:
            imageFrame = CGRectMake(kComponentPadding, (toastFrame.size.height - image.size.height) / 2, image.size.width, image.size.height);
            break;
        case iToastImageLocationTop:
            imageFrame = CGRectMake((toastFrame.size.width - image.size.width) / 2, kComponentPadding, image.size.width, image.size.height);
            break;
            
        default:
            break;
    }
    
    return imageFrame;
    
}

- (CGRect)_frameForImage:(iToastType)type inToastFrame:(CGRect)toastFrame {
    iToastSettings *theSettings = _settings;
    UIImage *image = [theSettings.images valueForKey:[NSString stringWithFormat:@"%i", type]];
    
    return [self _getFrameForImage:image inToastFrame:toastFrame];
}

- (void)hideToast:(NSTimer*)theTimer {
    [UIView beginAnimations:nil context:NULL];
    view.alpha = 0;
    [UIView commitAnimations];
}

- (void)removeToast:(NSTimer*)theTimer {
    [view removeFromSuperview];
    if (timer && [timer isValid]) {
        [timer invalidate];
    }
}


+ (iToast *)makeText:(NSString *)txt {
    iToast *toast = [[iToast alloc] initWithText:txt];
    
    return toast;
}


- (iToast *)setDuration:(NSInteger)duration {
    [self theSettings].duration = duration;
    return self;
}

- (iToast *)setGravity:(iToastGravity)gravity
             offsetLeft:(NSInteger)left
              offsetTop:(NSInteger)top {
    [self theSettings].gravity = gravity;
    [self theSettings].offsetLeft = left;
    [self theSettings].offsetTop = top;
    return self;
}

- (iToast *)setGravity:(iToastGravity)gravity {
    [self theSettings].gravity = gravity;
    return self;
}

- (iToast *)setPostion:(CGPoint)_position {
    [self theSettings].postition = CGPointMake(_position.x, _position.y);
    
    return self;
}

- (iToast *)setFontName:(NSString *)fontName {
    [self theSettings].fontName = fontName;
    return self;
}

- (iToast *)setFontSize:(CGFloat)fontSize {
    [self theSettings].fontSize = fontSize;
    return self;
}

- (iToast *)setUseShadow:(BOOL)useShadow {
    [self theSettings].useShadow = useShadow;
    return self;
}

- (iToast *)setCornerRadius:(CGFloat)cornerRadius {
    [self theSettings].cornerRadius = cornerRadius;
    return self;
}

- (iToast *)setBgColor:(UIColor*)bgColor {
    CGFloat red, green, blue, alpha;
    [bgColor getRed:&red green:&green blue:&blue alpha:&alpha];
    [self setBgRed:red];
    [self setBgGreen:green];
    [self setBgBlue:blue];
    [self setBgAlpha:alpha];
    return self;
}

- (iToast *)setBgRed:(CGFloat)bgRed {
    [self theSettings].bgRed = bgRed;
    return self;
}

- (iToast *)setBgGreen:(CGFloat)bgGreen {
    [self theSettings].bgGreen = bgGreen;
    return self;
}

- (iToast *)setBgBlue:(CGFloat)bgBlue {
    [self theSettings].bgBlue = bgBlue;
    return self;
}

- (iToast *)setBgAlpha:(CGFloat)bgAlpha {
    [self theSettings].bgAlpha = bgAlpha;
    return self;
}

- (iToast *)setMinHeight:(CGFloat)minHeight {
    [self theSettings].minHeight = minHeight;
    return self;
}

- (iToast *)setMarginTop:(CGFloat)marginTop {
    [self theSettings].marginTop = marginTop;
    return self;
}

- (iToast *)setMarginBottom:(CGFloat)marginBottom {
    [self theSettings].marginBottom = marginBottom;
    return self;
}

- (iToastSettings *)theSettings {
    if (!_settings) {
        _settings = [[iToastSettings getSharedSettings] copy];
    }
    
    return _settings;
}

@end


@implementation iToastSettings
@synthesize offsetLeft;
@synthesize offsetTop;
@synthesize duration;
@synthesize gravity;
@synthesize postition;
@synthesize fontName;
@synthesize fontSize;
@synthesize useShadow;
@synthesize cornerRadius;
@synthesize bgRed;
@synthesize bgGreen;
@synthesize bgBlue;
@synthesize bgAlpha;
@synthesize images;
@synthesize imageLocation;

@synthesize minHeight;
@synthesize marginTop;
@synthesize marginBottom;

- (void)setImage:(UIImage *)img withLocation:(iToastImageLocation)location forType:(iToastType)type {
    if (type == iToastTypeNone) {
        // This should not be used, internal use only (to force no image)
        return;
    }
    
    if (!images) {
        images = [[NSMutableDictionary alloc] initWithCapacity:4];
    }
    
    if (img) {
        NSString *key = [NSString stringWithFormat:@"%i", type];
        [images setValue:img forKey:key];
    }
    
    [self setImageLocation:location];
}

- (void)setImage:(UIImage *)img forType:(iToastType)type {
    [self setImage:img withLocation:iToastImageLocationLeft forType:type];
}


+ (iToastSettings *)getSharedSettings {
    if (!sharedSettings) {
        sharedSettings = [iToastSettings new];
        sharedSettings.gravity = iToastGravityCenter;
        sharedSettings.duration = iToastDurationShort;
        sharedSettings.fontName = nil;
        sharedSettings.fontSize = 16.0;
        sharedSettings.useShadow = YES;
        sharedSettings.cornerRadius = 5.0;
        sharedSettings.bgRed = 0;
        sharedSettings.bgGreen = 0;
        sharedSettings.bgBlue = 0;
        sharedSettings.bgAlpha = 0.7;
        sharedSettings.offsetLeft = 0;
        sharedSettings.offsetTop = 0;
        sharedSettings.minHeight = 0;
        sharedSettings.marginTop = 0;
        sharedSettings.marginBottom = 0;
    }
    
    return sharedSettings;
    
}

- (id)copyWithZone:(NSZone *)zone {
    iToastSettings *copy = [iToastSettings new];
    copy.gravity = self.gravity;
    copy.duration = self.duration;
    copy.postition = self.postition;
    copy.fontName = self.fontName;
    copy.fontSize = self.fontSize;
    copy.useShadow = self.useShadow;
    copy.cornerRadius = self.cornerRadius;
    copy.bgRed = self.bgRed;
    copy.bgGreen = self.bgGreen;
    copy.bgBlue = self.bgBlue;
    copy.bgAlpha = self.bgAlpha;
    copy.offsetLeft = self.offsetLeft;
    copy.offsetTop = self.offsetTop;
    copy.minHeight = self.minHeight;
    copy.marginTop = self.marginTop;
    copy.marginBottom = self.marginBottom;
    
    NSArray *keys = [self.images allKeys];
    
    for (NSString *key in keys) {
        [copy setImage:[images valueForKey:key] forType:[key intValue]];
    }
    
    [copy setImageLocation:imageLocation];
    
    return copy;
}

@end
