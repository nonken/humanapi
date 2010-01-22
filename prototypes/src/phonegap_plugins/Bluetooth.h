//
//  Bluetooth.h
//  PhoneGap
//
//  Created by Nikolai Onken on 12/4/09.
//  Copyright 2009 UnitSpectra. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PhoneGapCommand.h"
#import "BluetoothDelegate.h"

#import "btstack/btstack.h"

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

@interface Bluetooth : PhoneGapCommand {

}

//- (void) packet_handler: (uint8_t) packet_type: (uint16_t) channel: (uint8_t*) packet: (uint16_t) size;
void packet_handler(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size);
- (void) evaluateWevView;
- (void) initBlueTooth: (UIWebView*) webView;

@end
