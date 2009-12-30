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

@interface Bluetooth : PhoneGapCommand {

}

//- (void) packet_handler: (uint8_t) packet_type: (uint16_t) channel: (uint8_t*) packet: (uint16_t) size;
void packet_handler(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size);
- (void) evaluateWevView;
- (void) initBlueTooth: (UIWebView*) webView;

@end
