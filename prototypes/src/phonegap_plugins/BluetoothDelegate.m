//
//  BluetoothDelegate.m
//  PhoneGap
//
//  Created by Nikolai Onken on 12/4/09.
//  Copyright 2009 UnitSpectra. All rights reserved.
//

#import "BluetoothDelegate.h"

static UIWebView* currentWebView = nil;

@implementation BluetoothDelegate

+ (UIWebView*) webView
{
	return currentWebView;
}

+ (void) setWebView: (UIWebView*) newWebView
{
    if(currentWebView != newWebView) {
		[currentWebView release];
        currentWebView = newWebView;
    }
}

@end
