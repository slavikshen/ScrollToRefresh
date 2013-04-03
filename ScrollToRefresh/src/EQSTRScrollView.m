//
//  EQSTRScrollView.m
//  ScrollToRefresh
//
// Copyright (C) 2011 by Alex Zielenski.

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "EQSTRScrollView.h"
#import "EQSTRClipView.h"
#import <QuartzCore/QuartzCore.h>

#define REFRESH_HEADER_HEIGHT 44.0f

// code modeled from https://github.com/leah/PullToRefresh/blob/master/Classes/PullRefreshTableViewController.m

@interface EQSTRScrollView ()

@property (nonatomic,readwrite,assign) BOOL isRefreshing;
@property (nonatomic,readwrite,retain) NSView *refreshHeader;

- (BOOL)overRefreshView;
- (void)viewBoundsChanged:(NSNotification*)note;

- (CGFloat)minimumScroll;

@end

@implementation EQSTRScrollView {
    BOOL _overRefreshView;
    CALayer *_arrowLayer;
}

#pragma mark - Private Properties

#pragma mark - Dealloc
- (void)dealloc {

    self.refreshHeader = nil;
	self.refreshBlock = nil;
    
	[super dealloc];
}

#pragma mark - set header view

#pragma mark - Create Header View

- (void)viewDidMoveToSuperview {

    [super viewDidMoveToSuperview];

    NSView* contentView = self.contentView;
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:NSViewBoundsDidChangeNotification object:contentView];
    if( self.superview ) {
        [self _refreshHeaderViews];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                     selector:@selector(viewBoundsChanged:)
                                         name:NSViewBoundsDidChangeNotification
                                       object:contentView];
    }


}

- (NSView*)refreshHeader {

    if( nil == _refreshHeader ) {
        NSClipView* contentView = self.contentView; // create new content view
        // add header view to clipview
        NSRect contentRect = [contentView.documentView frame];
        _refreshHeader = [[NSView alloc] initWithFrame:NSMakeRect(0,
                                                                  0 - REFRESH_HEADER_HEIGHT,
                                                                  contentRect.size.width, 
                                                                  REFRESH_HEADER_HEIGHT)];
        
        // Create Arrow
        NSImage *arrowImage = [NSImage imageNamed:@"arrow"];
        _refreshArrow       = [[NSView alloc] initWithFrame:NSMakeRect(floor(NSMidX(self.refreshHeader.bounds) - arrowImage.size.width / 2), 
                                                                       floor(NSMidY(self.refreshHeader.bounds) - arrowImage.size.height / 2), 
                                                                       arrowImage.size.width,
                                                                       arrowImage.size.height)];
        self.refreshArrow.wantsLayer = YES;
        
        _arrowLayer = [CALayer layer];
        _arrowLayer.contents = (id)[arrowImage CGImageForProposedRect:NULL
                                                                   context:nil
                                                                     hints:nil];
        
        _arrowLayer.frame    = NSRectToCGRect(_refreshArrow.bounds);
        _refreshArrow.layer.frame = NSRectToCGRect(_refreshArrow.bounds);
        
        [self.refreshArrow.layer addSublayer:_arrowLayer];
        
        // Create spinner
        _refreshSpinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(floor(NSMidX(self.refreshHeader.bounds) - 30),
                                                                                floor(NSMidY(self.refreshHeader.bounds) - 20), 
                                                                                60.0f, 
                                                                                40.0f)];
        self.refreshSpinner.style                 = NSProgressIndicatorSpinningStyle;
        self.refreshSpinner.displayedWhenStopped  = NO;
        self.refreshSpinner.usesThreadedAnimation = YES;
        self.refreshSpinner.indeterminate         = YES;
        self.refreshSpinner.bezeled               = NO;
        [self.refreshSpinner sizeToFit];
        
        // Center the spinner in the header
        [self.refreshSpinner setFrame:NSMakeRect(floor(NSMidX(self.refreshHeader.bounds) - self.refreshSpinner.frame.size.width / 2),
                                                 floor(NSMidY(self.refreshHeader.bounds) - self.refreshSpinner.frame.size.height / 2), 
                                                 self.refreshSpinner.frame.size.width, 
                                                 self.refreshSpinner.frame.size.height)];
        
        // set autoresizing masks
        self.refreshSpinner.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin; // center
        self.refreshArrow.autoresizingMask   = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin; // center
        self.refreshHeader.autoresizingMask  = NSViewWidthSizable | NSViewMinXMargin | NSViewMaxXMargin; // stretch/center
        
        // Put everything in place
        [self.refreshHeader addSubview:self.refreshArrow];
        [self.refreshHeader addSubview:self.refreshSpinner];
        
        [contentView addSubview:self.refreshHeader];
        
        [_refreshArrow release];
        [_refreshSpinner release];
    }
    
    return _refreshHeader;

}

- (void)_refreshHeaderViews {

    [self setVerticalScrollElasticity:NSScrollElasticityAllowed];
    
    NSClipView* contentView = self.contentView; // create new content view
    
    NSView* refreshHeader = self.refreshHeader;
    CGRect contentRect = [contentView.documentView frame];
    CGFloat W = contentRect.size.width;
    CGRect refreshHeaderFrame = NSMakeRect(0, 0 - REFRESH_HEADER_HEIGHT, W, REFRESH_HEADER_HEIGHT);

    refreshHeader.frame = refreshHeaderFrame;
    
    if( contentView != refreshHeader.superview ) {
        [contentView addSubview:refreshHeader];
        [contentView scrollToPoint:NSMakePoint(contentRect.origin.x, 0)];
    }
    
    // Scroll to top
	[self reflectScrolledClipView:self.contentView];
}

- (NSClipView *)contentView {
	NSClipView *superClipView = [super contentView];
	if (![superClipView isKindOfClass:[EQSTRClipView class]]) {
		
		// create new clipview
		NSView *documentView     = superClipView.documentView;
		
		EQSTRClipView *clipView  = [[EQSTRClipView alloc] initWithFrame:superClipView.frame];
		clipView.documentView    = documentView;
		clipView.copiesOnScroll  = NO;
		clipView.drawsBackground = NO;
		
		[self setContentView:clipView];
		[clipView release];
		
		superClipView            = [super contentView];
		
	}
	return superClipView;
}

#pragma mark - Detecting Scroll

- (void)scrollWheel:(NSEvent *)event {
	if (event.phase == NSEventPhaseEnded) {
		if (_overRefreshView && ! self.isRefreshing) {
			[self startLoading];
            if([_delegate respondsToSelector:@selector(didRequestRefreshByScrollView:)]) {
                [_delegate performSelector:@selector(didRequestRefreshByScrollView:) withObject:self];
            }
		}
	}
	
	[super scrollWheel:event];
}

- (void)viewBoundsChanged:(NSNotification *)note {
	if (self.isRefreshing)
		return;
	
	BOOL start = [self overRefreshView];
	if (start) {
		
		// point arrow up
		_arrowLayer.transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
		_overRefreshView = YES;
		
	} else {
		
		// point arrow down
		_arrowLayer.transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
		_overRefreshView = NO;
		
	}
	
}

- (BOOL)overRefreshView {
	NSClipView *clipView  = self.contentView;
	NSRect bounds         = clipView.bounds;
	
	CGFloat scrollValue   = bounds.origin.y;
	CGFloat minimumScroll = self.minimumScroll;
	
	return (scrollValue <= minimumScroll);
}

- (CGFloat)minimumScroll {
	return 0 - self.refreshHeader.frame.size.height;
}

#pragma mark - Refresh

- (void)startLoading {
	self.isRefreshing            = YES;
	
	self.refreshArrow.hidden = YES;
	[self.refreshSpinner startAnimation:self];
	
	if (self.refreshBlock) {
		self.refreshBlock(self);
	}
}

- (void)stopLoading {	
	self.refreshArrow.hidden            = NO;	
	
	[self.refreshArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
	[self.refreshSpinner stopAnimation:self];
	
	// now fake an event of scrolling for a natural look
	self.isRefreshing = NO;

    
	CGEventRef cgEvent   = CGEventCreateScrollWheelEvent(NULL,
														 kCGScrollEventUnitLine,
														 2,
														 1,
														 0);
	
	NSEvent *scrollEvent = [NSEvent eventWithCGEvent:cgEvent];
	[self scrollWheel:scrollEvent];
	CFRelease(cgEvent);
}

@end
