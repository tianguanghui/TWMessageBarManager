//
//  TWMessageBarManager.m
//
//  Created by Terry Worona on 5/13/13.
//  Copyright (c) 2013 Terry Worona. All rights reserved.
//

#import "TWMessageBarManager.h"

// Quartz
#import <QuartzCore/QuartzCore.h>

// Numerics (TWMessageBarStyleSheet)
CGFloat const kTWMessageBarStyleSheetMessageBarAlpha = 0.96f;

// Strings (TWMessageBarStyleSheet)
NSString * const kTWMessageBarStyleSheetImageIconError = @"icon-error.png";
NSString * const kTWMessageBarStyleSheetImageIconSuccess = @"icon-success.png";
NSString * const kTWMessageBarStyleSheetImageIconInfo = @"icon-info.png";

// Numeric Constants
#define kMessageBarPadding 10
#define kMessageBarIconSize 36
#define kMessageBarDisplayDelay 3.0
#define kMessageBarTextOffset 2.0
#define kMessageBarAnimationDuration 0.25
#define kMessageBariOS7Identifier 7

@interface TWMessageView : UIView

@property (nonatomic, strong) NSString *titleString;
@property (nonatomic, strong) NSString *descriptionString;
@property (nonatomic, assign) TWMessageBarMessageType messageType;

@property (nonatomic, assign) BOOL hasCallback;
@property (nonatomic, strong) NSArray *callbacks;

@property (nonatomic, assign, getter = isHit) BOOL hit;

@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGFloat width;

@property (nonatomic, assign) CGFloat duration;

- (id)initWithTitle:(NSString *)title description:(NSString *)description type:(TWMessageBarMessageType)type;

// Getters
- (CGFloat)height;
- (CGFloat)width;
- (CGFloat)availableWidth;
- (CGSize)titleSize;
- (CGSize)descriptionSize;

// Helpers
- (BOOL)isRunningiOS7OrLater;

@end

@interface TWMessageBarManager ()

@property (nonatomic, strong) NSMutableArray *messageBarQueue;
@property (nonatomic, assign, getter = isMessageVisible) BOOL messageVisible;
@property (nonatomic, assign) CGFloat messageBarOffset;

+ (CGFloat)durationForMessageType:(TWMessageBarMessageType)messageType;

- (void)showNextMessage;
- (void)itemSelected:(UITapGestureRecognizer *)recognizer;

@end

@implementation TWMessageBarManager

#pragma mark - Singleton

+ (TWMessageBarManager *)sharedInstance
{
    static dispatch_once_t pred;
    static TWMessageBarManager *instance = nil;
    dispatch_once(&pred, ^{
        instance = [[self alloc] init];
    });
	return instance;
}

#pragma mark - Static

+ (CGFloat)durationForMessageType:(TWMessageBarMessageType)messageType
{
    return kMessageBarDisplayDelay;
}

#pragma mark - Alloc/Init

- (id)init
{
    if(self = [super init])
    {
        _messageBarQueue = [[NSMutableArray alloc] init];        
        _messageVisible = NO;
        _messageBarOffset = [[UIApplication sharedApplication] statusBarFrame].size.height;
    }
    return self;
}

#pragma mark - Public

- (void)showMessageWithTitle:(NSString *)title description:(NSString *)description type:(TWMessageBarMessageType)type
{
    [self showMessageWithTitle:title description:description type:type duration:[TWMessageBarManager durationForMessageType:type] callback:nil];
}

- (void)showMessageWithTitle:(NSString *)title description:(NSString *)description type:(TWMessageBarMessageType)type callback:(void (^)())callback
{
    [self showMessageWithTitle:title description:description type:type duration:[TWMessageBarManager durationForMessageType:type] callback:callback];
}

- (void)showMessageWithTitle:(NSString *)title description:(NSString *)description type:(TWMessageBarMessageType)type duration:(CGFloat)duration
{
    [self showMessageWithTitle:title description:description type:type duration:duration callback:nil];
}

- (void)showMessageWithTitle:(NSString *)title description:(NSString *)description type:(TWMessageBarMessageType)type duration:(CGFloat)duration callback:(void (^)())callback
{
    TWMessageView *messageView = [[TWMessageView alloc] initWithTitle:title description:description type:type];

    messageView.callbacks = callback ? [NSArray arrayWithObject:callback] : [NSArray array];
    messageView.hasCallback = callback ? YES : NO;
    
    messageView.duration = duration;
    messageView.hidden = YES;
    
    [[[UIApplication sharedApplication] keyWindow] insertSubview:messageView atIndex:1];
    [self.messageBarQueue addObject:messageView];
    
    if (!self.messageVisible)
    {
        [self showNextMessage];
    }
}

- (void)hideAll
{
    TWMessageView *currentMessageView = nil;
    
    for (UIView *subview in [[[UIApplication sharedApplication] keyWindow] subviews])
    {
        if ([subview isKindOfClass:[TWMessageView class]])
        {
            currentMessageView = (TWMessageView *)subview;
            [currentMessageView removeFromSuperview];
        }
    }
    
    self.messageVisible = NO;
    [self.messageBarQueue removeAllObjects];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark - Private

- (void)showNextMessage
{
    if ([self.messageBarQueue count] > 0)
    {
        self.messageVisible = YES;
        
        TWMessageView *messageView = [self.messageBarQueue objectAtIndex:0];
        messageView.frame = CGRectMake(0, -[messageView height], [messageView width], [messageView height]);
        messageView.hidden = NO;
        [messageView setNeedsDisplay];

        UITapGestureRecognizer *gest = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(itemSelected:)];
        [messageView addGestureRecognizer:gest];

        if (messageView)
        {
            [self.messageBarQueue removeObject:messageView];
            
            [UIView animateWithDuration:kMessageBarAnimationDuration animations:^{
                [messageView setFrame:CGRectMake(messageView.frame.origin.x, self.messageBarOffset + messageView.frame.origin.y + [messageView height], [messageView width], [messageView height])]; // slide down
            }];
            
            [self performSelector:@selector(itemSelected:) withObject:messageView afterDelay:messageView.duration];
        }
    }
}

#pragma mark - Gestures

- (void)itemSelected:(id)sender
{
    TWMessageView *messageView = nil;
    BOOL itemHit = NO;
    if ([sender isKindOfClass:[UIGestureRecognizer class]])
    {
        messageView = (TWMessageView *)((UIGestureRecognizer *)sender).view;
        itemHit = YES;
    }
    else if ([sender isKindOfClass:[TWMessageView class]])
    {
        messageView = (TWMessageView *)sender;
    }
    
    if (messageView && ![messageView isHit])
    {
        messageView.hit = YES;
        
        [UIView animateWithDuration:kMessageBarAnimationDuration animations:^{
            [messageView setFrame:CGRectMake(messageView.frame.origin.x, messageView.frame.origin.y - [messageView height] - self.messageBarOffset, [messageView width], [messageView height])]; // slide back up
        } completion:^(BOOL finished) {
            self.messageVisible = NO;
            [messageView removeFromSuperview];
            
            if (itemHit)
            {
                if ([messageView.callbacks count] > 0)
                {
                    id obj = [messageView.callbacks objectAtIndex:0];
                    if (![obj isEqual:[NSNull null]])
                    {
                        ((void (^)())obj)();
                    }
                }
            }
            
            if([self.messageBarQueue count] > 0)
            {
                [self showNextMessage];
            }
        }];
    }
}

@end

static UIFont *titleFont = nil;
static UIColor *titleColor = nil;

static UIFont *descriptionFont = nil;
static UIColor *descriptionColor = nil;

@implementation TWMessageView

#pragma mark - Alloc/Init

- (id)initWithTitle:(NSString *)title description:(NSString *)description type:(TWMessageBarMessageType)type
{
    self = [super initWithFrame:CGRectZero];
    if (self)
    {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;
        self.userInteractionEnabled = YES;
        
        _titleString = title;
        _descriptionString = description;
        _messageType = type;
        
        titleFont = [UIFont boldSystemFontOfSize:16.0];
        titleColor = [UIColor colorWithWhite:1.0 alpha:1.0];
        
        descriptionFont = [UIFont systemFontOfSize:14.0];
        descriptionColor = [UIColor colorWithWhite:1.0 alpha:1.0];
        
        _height = 0.0;
        _width = 0.0;
        
        _hasCallback = NO;
        _hit = NO;
    }
    return self;
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
	CGContextRef context = UIGraphicsGetCurrentContext();
	
    // background fill
    CGContextSaveGState(context);
    {
        [[TWMessageBarStyleSheet backgroundColorForMessageType:self.messageType] set];
        CGContextFillRect(context, rect);
    }
    CGContextRestoreGState(context);

    // bottom stroke
    CGContextSaveGState(context);
    {
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, rect.size.height);
        CGContextSetStrokeColorWithColor(context, [TWMessageBarStyleSheet strokeColorForMessageType:self.messageType].CGColor);
        CGContextSetLineWidth(context, 1.0);
        CGContextAddLineToPoint(context, rect.size.width, rect.size.height);
        CGContextStrokePath(context);
    }
    CGContextRestoreGState(context);

    CGFloat xOffset = kMessageBarPadding;
    CGFloat yOffset = kMessageBarPadding;
    
    // icon
    CGContextSaveGState(context);
    {
        [[TWMessageBarStyleSheet iconImageForMessageType:self.messageType] drawInRect:CGRectMake(xOffset, yOffset, kMessageBarIconSize, kMessageBarIconSize)];
    }
    CGContextRestoreGState(context);
    
    yOffset -= kMessageBarTextOffset;
    xOffset += kMessageBarIconSize + kMessageBarPadding;
    
    CGSize titleLabelSize = [self titleSize];
    if (self.titleString && !self.descriptionString)
    {
        yOffset = ceil(rect.size.height * 0.5) - ceil(titleLabelSize.height * 0.5) - kMessageBarTextOffset;
    }
    [titleColor set];
	[self.titleString drawInRect:CGRectMake(xOffset, yOffset, titleLabelSize.width, titleLabelSize.height) withFont:titleFont lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentLeft];

    yOffset += titleLabelSize.height;
    
    CGSize descriptionLabelSize = [self descriptionSize];
    [descriptionColor set];
	[self.descriptionString drawInRect:CGRectMake(xOffset, yOffset, descriptionLabelSize.width, descriptionLabelSize.height) withFont:descriptionFont lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentLeft];
}

#pragma mark - Getters

- (CGFloat)height
{
    if (_height == 0)
    {
        CGSize titleLabelSize = [self titleSize];
        CGSize descriptionLabelSize = [self descriptionSize];
        _height = MAX((kMessageBarPadding * 2) + titleLabelSize.height + descriptionLabelSize.height, (kMessageBarPadding * 2) + kMessageBarIconSize);
    }
    return _height;
}

- (CGFloat)width
{
    if (_width == 0)
    {
        _width = [UIScreen mainScreen].bounds.size.width;
    }
    return _width;
}

- (CGFloat)availableWidth
{
    CGFloat maxWidth = ([self width] - (kMessageBarPadding * 3) - kMessageBarIconSize);
    return maxWidth;
}

- (CGSize)titleSize
{
    CGSize boundedSize = CGSizeMake([self availableWidth], CGFLOAT_MAX);
    CGSize titleLabelSize;
    
    if ([self isRunningiOS7OrLater])
    {
        NSDictionary *titleStringAttributes = [NSDictionary dictionaryWithObject:titleFont forKey: NSFontAttributeName];
        titleLabelSize = [self.titleString boundingRectWithSize:boundedSize
                                                        options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin
                                                     attributes:titleStringAttributes
                                                        context:nil].size;
    }
    else
    {
        titleLabelSize = [_titleString sizeWithFont:titleFont constrainedToSize:boundedSize lineBreakMode:NSLineBreakByTruncatingTail];
    }
    
    return titleLabelSize;
}

- (CGSize)descriptionSize
{
    CGSize boundedSize = CGSizeMake([self availableWidth], CGFLOAT_MAX);
    CGSize descriptionLabelSize;
    
    if ([self isRunningiOS7OrLater])
    {
        NSDictionary *descriptionStringAttributes = [NSDictionary dictionaryWithObject:descriptionFont forKey: NSFontAttributeName];
        descriptionLabelSize = [self.descriptionString boundingRectWithSize:boundedSize
                                                                    options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin
                                                                 attributes:descriptionStringAttributes
                                                                    context:nil].size;
    }
    else
    {
        descriptionLabelSize = [_descriptionString sizeWithFont:descriptionFont constrainedToSize:boundedSize lineBreakMode:NSLineBreakByTruncatingTail];
    }
    
    return descriptionLabelSize;
}

#pragma mark - Helpers

- (BOOL)isRunningiOS7OrLater
{
	NSString *systemVersion = [UIDevice currentDevice].systemVersion;
    NSUInteger systemInt = [systemVersion intValue];
    return (systemInt >= kMessageBariOS7Identifier);
}

@end

@implementation TWMessageBarStyleSheet

#pragma mark - Colors

+ (UIColor *)backgroundColorForMessageType:(TWMessageBarMessageType)type
{
    UIColor *backgroundColor = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            backgroundColor = [UIColor colorWithRed:1.0 green:0.611 blue:0.0 alpha:kTWMessageBarStyleSheetMessageBarAlpha]; // orange
            break;
        case TWMessageBarMessageTypeSuccess:
            backgroundColor = [UIColor colorWithRed:0.0f green:0.831f blue:0.176f alpha:kTWMessageBarStyleSheetMessageBarAlpha]; // green
            break;
        case TWMessageBarMessageTypeInfo:
            backgroundColor = [UIColor colorWithRed:0.0 green:0.482 blue:1.0 alpha:kTWMessageBarStyleSheetMessageBarAlpha]; // blue
            break;
        default:
            break;
    }
    return backgroundColor;
}

+ (UIColor *)strokeColorForMessageType:(TWMessageBarMessageType)type
{
    UIColor *strokeColor = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            strokeColor = [UIColor colorWithRed:0.949f green:0.580f blue:0.0f alpha:1.0f]; // orange
            break;
        case TWMessageBarMessageTypeSuccess:
            strokeColor = [UIColor colorWithRed:0.0f green:0.772f blue:0.164f alpha:1.0f]; // green
            break;
        case TWMessageBarMessageTypeInfo:
            strokeColor = [UIColor colorWithRed:0.0f green:0.415f blue:0.803f alpha:1.0f]; // blue
            break;
        default:
            break;
    }
    return strokeColor;
}

+ (UIImage *)iconImageForMessageType:(TWMessageBarMessageType)type
{
    UIImage *iconImage = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            iconImage = [UIImage imageNamed:kTWMessageBarStyleSheetImageIconError];
            break;
        case TWMessageBarMessageTypeSuccess:
            iconImage = [UIImage imageNamed:kTWMessageBarStyleSheetImageIconSuccess];
            break;
        case TWMessageBarMessageTypeInfo:
            iconImage = [UIImage imageNamed:kTWMessageBarStyleSheetImageIconInfo];
            break;
        default:
            break;
    }
    return iconImage;
}

@end
