//
//  Bluetooth.m
//  PhoneGap
//
//  Created by Nikolai Onken on 12/4/09.
//  Copyright 2009 UnitSpectra. All rights reserved.
//

#import "Bluetooth.h"

@implementation Bluetooth

// Control field values      bit no.       1 2 3 4 5   6 7 8
#define BT_RFCOMM_SABM       0x3F       // 1 1 1 1 P/F 1 0 0
#define BT_RFCOMM_UA         0x73       // 1 1 0 0 P/F 1 1 0
#define BT_RFCOMM_DM         0x0F       // 1 1 1 1 P/F 0 0 0
#define BT_RFCOMM_DM_PF      0x1F
#define BT_RFCOMM_DISC       0x53       // 1 1 0 0 P/F 0 1 1
#define BT_RFCOMM_UIH        0xEF       // 1 1 1 1 P/F 1 1 1
#define BT_RFCOMM_UIH_PF     0xFF

// Multiplexer message types
#define BT_RFCOMM_PN_CMD     0x83
#define BT_RFCOMM_PN_RSP     0x81
#define BT_RFCOMM_TEST_CMD   0x23
#define BT_RFCOMM_TEST_RSP   0x21
#define BT_RFCOMM_FCON_CMD   0xA3
#define BT_RFCOMM_FCON_RSP   0xA1
#define BT_RFCOMM_FCOFF_CMD  0x63
#define BT_RFCOMM_FCOFF_RSP  0x61
#define BT_RFCOMM_MSC_CMD    0xE3
#define BT_RFCOMM_MSC_RSP    0xE1
#define BT_RFCOMM_RPN_CMD    0x93
#define BT_RFCOMM_RPN_RSP    0x91
#define BT_RFCOMM_RLS_CMD    0x53
#define BT_RFCOMM_RLS_RSP    0x51
#define BT_RFCOMM_NSC_RSP    0x11

// FCS calc
#define BT_RFCOMM_CODE_WORD         0xE0 // pol = x8+x2+x1+1
#define BT_RFCOMM_CRC_CHECK_LEN     3
#define BT_RFCOMM_UIHCRC_CHECK_LEN  2

bd_addr_t addr = {0x00,0x07,0x80,0x90,0x50,0xC8};  // Arduino BT

#define RFCOMM_CHANNEL_ID 1

hci_con_handle_t con_handle;
uint16_t source_cid;

// used to assemble rfcomm packets
uint8_t rfcomm_out_buffer[1000];

/**
 * @param credits - only used for RFCOMM flow control in UIH wiht P/F = 1
 */
void rfcomm_send_packet(uint16_t source_cid, uint8_t address, uint8_t control, uint8_t credits, uint8_t *data, uint16_t len){

	uint16_t pos = 0;
	uint8_t crc_fields = 3;

	rfcomm_out_buffer[pos++] = address;
	rfcomm_out_buffer[pos++] = control;

	// length field can be 1 or 2 octets
	if (len < 128){
		rfcomm_out_buffer[pos++] = (len << 1)| 1;     // bits 0-6
	} else {
		rfcomm_out_buffer[pos++] = (len & 0x7f) << 1; // bits 0-6
		rfcomm_out_buffer[pos++] = len >> 7;          // bits 7-14
		crc_fields++;
	}

	// add credits for UIH frames when PF bit is set
	if (control == BT_RFCOMM_UIH_PF){
		rfcomm_out_buffer[pos++] = credits;
	}

	// copy actual data
	memcpy(&rfcomm_out_buffer[pos], data, len);
	pos += len;

	// UIH frames only calc FCS over address + control (5.1.1)
	if ((control & 0xef) == BT_RFCOMM_UIH){
		crc_fields = 2;
	}
	rfcomm_out_buffer[pos++] =  crc8_calc(rfcomm_out_buffer, crc_fields); // calc fcs
    bt_send_l2cap( source_cid, rfcomm_out_buffer, pos);
}

void _bt_rfcomm_send_sabm(uint16_t source_cid, uint8_t initiator, uint8_t channel)
{
	uint8_t address = (1 << 0) | (initiator << 1) |  (initiator << 1) | (channel << 3);
	rfcomm_send_packet(source_cid, address, BT_RFCOMM_SABM, 0, NULL, 0);
}

void _bt_rfcomm_send_uih_data(uint16_t source_cid, uint8_t initiator, uint8_t channel, uint8_t *data, uint16_t len) {
	uint8_t address = (1 << 0) | (initiator << 1) |  (initiator << 1) | (channel << 3);
	rfcomm_send_packet(source_cid, address, BT_RFCOMM_UIH, 0, data, len);
}

void _bt_rfcomm_send_uih_msc_cmd(uint16_t source_cid, uint8_t initiator, uint8_t channel, uint8_t signals)
{
	uint8_t address = (1 << 0) | (initiator << 1); // EA and C/R bit set - always server channel 0
	uint8_t payload[4];
	uint8_t pos = 0;
	payload[pos++] = BT_RFCOMM_MSC_CMD;
	payload[pos++] = 2 << 1 | 1;  // len
	payload[pos++] = (1 << 0) | (1 << 1) | (0 << 2) | (channel << 3); // shouldn't D = initiator = 1 ?
	payload[pos++] = signals;
	rfcomm_send_packet(source_cid, address, BT_RFCOMM_UIH, 0, (uint8_t *) payload, pos);
}

void _bt_rfcomm_send_uih_pn_command(uint16_t source_cid, uint8_t initiator, uint8_t channel, uint16_t max_frame_size){
	uint8_t payload[10];
	uint8_t address = (1 << 0) | (initiator << 1); // EA and C/R bit set - always server channel 0
	uint8_t pos = 0;
	payload[pos++] = BT_RFCOMM_PN_CMD;
	payload[pos++] = 8 << 1 | 1;  // len
	payload[pos++] = channel << 1;
	payload[pos++] = 0xf0; // pre defined for Bluetooth, see 5.5.3 of TS 07.10 Adaption for RFCOMM
	payload[pos++] = 0; // priority
	payload[pos++] = 0; // max 60 seconds ack
	payload[pos++] = max_frame_size & 0xff; // max framesize low
	payload[pos++] = max_frame_size >> 8;   // max framesize high
	payload[pos++] = 0x00; // number of retransmissions
	payload[pos++] = 0x00; // unused error recovery window
	rfcomm_send_packet(source_cid, address, BT_RFCOMM_UIH, 0, (uint8_t *) payload, pos);
}

static void hex_dump(void *data, int size)
{
    /* dumps size bytes of *data to stdout. Looks like:
     * [0000] 75 6E 6B 6E 6F 77 6E 20
     *                  30 FF 00 00 00 00 39 00 unknown 0.....9.
     * (in a single line of course)
     */

    unsigned char *p = data;
    unsigned char c;
    int n;
    char bytestr[4] = {0};
    char addrstr[10] = {0};
    char hexstr[ 16*3 + 5] = {0};
    char charstr[16*1 + 5] = {0};
    for(n=1;n<=size;n++) {
        if (n%16 == 1) {
            /* store address for this line */
            snprintf(addrstr, sizeof(addrstr), "%.4x",
					 ((unsigned int)p-(unsigned int)data) );
        }

        c = *p;
        if (isalnum(c) == 0) {
            c = '.';
        }

        /* store hex str (for left side) */
        snprintf(bytestr, sizeof(bytestr), "%02X ", *p);
        strncat(hexstr, bytestr, sizeof(hexstr)-strlen(hexstr)-1);

        /* store char str (for right side) */
        snprintf(bytestr, sizeof(bytestr), "%c", c);
        strncat(charstr, bytestr, sizeof(charstr)-strlen(charstr)-1);

        if(n%16 == 0) {
            /* line completed */
            printf("[%4.4s]   %-50.50s  %s\n", addrstr, hexstr, charstr);
            hexstr[0] = 0;
            charstr[0] = 0;
        } else if(n%8 == 0) {
            /* half line: add whitespaces */
            strncat(hexstr, "  ", sizeof(hexstr)-strlen(hexstr)-1);
            strncat(charstr, " ", sizeof(charstr)-strlen(charstr)-1);
        }
        p++; /* next byte */
    }

    if (strlen(hexstr) > 0) {
        /* print rest of buffer if not empty */
        printf("[%4.4s]   %-50.50s  %s\n", addrstr, hexstr, charstr);
    }
}



//- (void) packet_handler: (uint8_t) packet_type: (uint16_t) channel: (uint8_t*) packet: (uint16_t) size{
void packet_handler(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size){
	bd_addr_t event_addr;

	static uint8_t msc_resp_send = 0;
	static uint8_t msc_resp_received = 0;
	static uint8_t credits_used = 0;
	static uint8_t credits_free = 0;
	uint8_t packet_processed = 0;

	switch (packet_type) {

		case L2CAP_DATA_PACKET:
			// rfcomm: data[8] = addr
			// rfcomm: data[9] = command

			// 	received 1. message BT_RF_COMM_UA
			if (size == 4 && packet[1] == BT_RFCOMM_UA && packet[0] == 0x03){
				packet_processed++;
				printf("Received RFCOMM unnumbered acknowledgement for channel 0 - multiplexer working\n");
				printf("Sending UIH Parameter Negotiation Command\n");
				_bt_rfcomm_send_uih_pn_command(source_cid, 1, RFCOMM_CHANNEL_ID, 100);
			}

			//  received UIH Parameter Negotiation Response
			if (size == 14 && packet[1] == BT_RFCOMM_UIH && packet[3] == BT_RFCOMM_PN_RSP){
				packet_processed++;
				printf("UIH Parameter Negotiation Response\n");
				printf("Sending SABM #1\n");
				_bt_rfcomm_send_sabm(source_cid, 1, 1);
			}

			// 	received 2. message BT_RF_COMM_UA
			if (size == 4 && packet[1] == BT_RFCOMM_UA && packet[0] == ((RFCOMM_CHANNEL_ID << 3) | 3) ){
				packet_processed++;
				printf("Received RFCOMM unnumbered acknowledgement for channel 1 - channel opened\n");
				printf("Sending MSC  'I'm ready'\n");
				_bt_rfcomm_send_uih_msc_cmd(source_cid, 1, 1, 0x8d);  // ea=1,fc=0,rtc=1,rtr=1,ic=0,dv=1
			}

			// received BT_RFCOMM_MSC_CMD
			if (size == 8 && packet[1] == BT_RFCOMM_UIH && packet[3] == BT_RFCOMM_MSC_CMD){
				packet_processed++;
				printf("Received BT_RFCOMM_MSC_CMD\n");
				printf("Responding to 'I'm ready'\n");
				// fine with this
				uint8_t address = packet[0] | 2; // set response
				packet[3]  = BT_RFCOMM_MSC_RSP;  //  "      "
				rfcomm_send_packet(source_cid, address, BT_RFCOMM_UIH, 0x30, (uint8_t*)&packet[3], 4);
				msc_resp_send = 1;
			}

			// received BT_RFCOMM_MSC_RSP
			if (size == 8 && packet[1] == BT_RFCOMM_UIH && packet[3] == BT_RFCOMM_MSC_RSP){
				packet_processed++;
				msc_resp_received = 1;
			}

			if (packet[1] == BT_RFCOMM_UIH && packet[0] == ((RFCOMM_CHANNEL_ID<<3)|1)){
				packet_processed++;
				credits_used++;

				// Create a hex string of the serial packet
				unsigned char *p = &packet[3];
				int n;
				char buff[size-4];
				char hex_dump[32] = ""; // What does this have to be?
				char delim[4] = ":";
				for(n=1;n<=size-4;n++) {
					sprintf(buff, "%02x", *p);
					strcat(hex_dump, buff);
					if (n<size-4){
						strcat(hex_dump, delim);
					}
					p++;
				}

				NSLog(@"Hex dump BT_RFCOMM_UIH: %s", hex_dump);

				UIWebView * viewer = nil;
				viewer = [BluetoothDelegate webView];
				NSLog(@"%@", viewer);
				NSString * jsCallBack = nil;
				jsCallBack = [[NSString alloc] initWithFormat:@"setHexData('%s');", hex_dump];
				[viewer stringByEvaluatingJavaScriptFromString:jsCallBack];
				[jsCallBack release];

				//NSLog(@"RX: address %02x, control %02x: ", packet[0], packet[1]);
				//hexdump( (uint8_t*) &packet[3], size-4);
			}

			if (packet[1] == BT_RFCOMM_UIH_PF && packet[0] == ((RFCOMM_CHANNEL_ID<<3)|1)){
				packet_processed++;
				credits_used++;
				if (!credits_free) {
					printf("Got %u credits, can send!\n", packet[2]);
				}
				credits_free = packet[2];

				// Create a hex string of the serial packet
				unsigned char *p = &packet[3];
				int n;
				char buff[size-5];
				char hex_dump[500] = ""; // What does this have to be?
				char delim[4] = ":";
				for(n=1;n<=size-5;n++) {
					sprintf(buff, "%02x", *p);
					strcat(hex_dump, buff);
					if (n<size-4){
						strcat(hex_dump, delim);
					}
					p++;
				}

				NSLog(@"Hex dump BT_RFCOMM_UIH_PF: %s", hex_dump);

				/*
				UIWebView * viewer = nil;
				viewer = [BluetoothDelegate webView];

				NSString * jsCallBack = nil;
				jsCallBack = [[NSString alloc] initWithFormat:@"setHexData('%s');", hex_dump];
				[viewer stringByEvaluatingJavaScriptFromString:jsCallBack];
				[jsCallBack release];
				*/

				//NSLog(@"RX: address %02x, control %02x: ", packet[0], packet[1]);
				//hexdump( (uint8_t *) &packet[4], size-5);
			}

			uint8_t send_credits_packet = 0;


			if (credits_used > 40 ) {
				send_credits_packet = 1;
				credits_used = 0;
			}

			if (msc_resp_send && msc_resp_received) {
				send_credits_packet = 1;
				msc_resp_send = msc_resp_received = 0;

				NSLog(@"RFCOMM up and running!\n");
				printf("RFCOMM up and running!\n");
			}

			if (send_credits_packet) {
				// send 0x30 credits
				uint8_t initiator = 1;
				uint8_t address = (1 << 0) | (initiator << 1) |  (initiator << 1) | (RFCOMM_CHANNEL_ID << 3);
				rfcomm_send_packet(source_cid, address, BT_RFCOMM_UIH_PF, 0x30, NULL, 0);
			}

			if (!packet_processed){
				// just dump data for now
				printf("??: address %02x, control %02x: ", packet[0], packet[1]);
				hexdump( packet, size );
			}

			break;

		case HCI_EVENT_PACKET:

			switch (packet[0]) {

				case BTSTACK_EVENT_POWERON_FAILED:
					// handle HCI init failure
					printf("HCI Init failed - make sure you have turned off Bluetooth in the System Settings\n");
					NSLog(@"HCI Init failed - make sure you have turned off Bluetooth in the System Settings\n");
					exit(1);
					break;

				case BTSTACK_EVENT_STATE:
					// bt stack activated, get started - set local name
					if (packet[2] == HCI_STATE_WORKING) {
						bt_send_cmd(&hci_write_local_name, "BTstack-Test");
					}
					break;

				case HCI_EVENT_PIN_CODE_REQUEST:
					// inform about pin code request
					bt_flip_addr(event_addr, &packet[2]);
					bt_send_cmd(&hci_pin_code_request_reply, &event_addr, 5, "12345");
					NSLog(@"Please enter PIN 12345 on remote device\n");
					break;

				case L2CAP_EVENT_CHANNEL_OPENED:
					// inform about new l2cap connection
					bt_flip_addr(event_addr, &packet[3]);
					uint16_t psm = READ_BT_16(packet, 11);
					source_cid = READ_BT_16(packet, 13);
					con_handle = READ_BT_16(packet, 9);
					if (packet[2] == 0) {
						printf("Channel successfully opened: ");
						NSLog(@"Channel successfully opened: ");
						print_bd_addr(event_addr);
						printf(", handle 0x%02x, psm 0x%02x, source cid 0x%02x, dest cid 0x%02x\n",
							   con_handle, psm, source_cid,  READ_BT_16(packet, 15));

						// send SABM command on dlci 0
						printf("Sending SABM #0\n");
						_bt_rfcomm_send_sabm(source_cid, 1, 0);
					} else {
						printf("L2CAP connection to device ");
						print_bd_addr(event_addr);
						printf(" failed. status code %u\n", packet[2]);
						exit(1);
					}
					break;

				case HCI_EVENT_DISCONNECTION_COMPLETE:
					// connection closed -> quit test app
					printf("Basebank connection closed, exit.\n");
					NSLog(@"Basebank connection closed, exit.\n");
					exit(0);
					break;

				case HCI_EVENT_COMMAND_COMPLETE:
					// use pairing yes/no
					if ( COMMAND_COMPLETE_EVENT(packet, hci_write_local_name) ) {
						bt_send_cmd(&hci_write_authentication_enable, 1);
					}

					// connect to RFCOMM device (PSM 0x03) at addr
					if ( COMMAND_COMPLETE_EVENT(packet, hci_write_authentication_enable) ) {
						bt_send_cmd(&l2cap_create_channel, addr, 0x03);
						NSLog(@"Turn on the Arduino BT\n");
						printf("Turn on the Arduino BT\n");
					}
					break;

				default:
					// unhandled event
					break;
			}
		default:
			// unhandled packet type
			break;
	}
}

- (void) evaluateWevView
{
	NSString * jsCallBack = nil;
	//jsCallBack = [[NSString alloc] initWithFormat:@"test({x:%f,y:%f});", packet[0], packet[1]];
	jsCallBack = [[NSString alloc] initWithFormat:@"test({x:2,y:3});"];
	[webView stringByEvaluatingJavaScriptFromString:jsCallBack];
	[jsCallBack release];
}

- (void) initBlueTooth: (UIWebView*) webView
{
	bool btOK = false;

	run_loop_init(RUN_LOOP_COCOA);
	if ( bt_open() ){
		UIAlertView* alertView = [[UIAlertView alloc] init];
		alertView.title = @"Bluetooth not accessible!";
		alertView.message = @"Connection to BTstack failed!\n"
		"Please make sure that BTstack is installed correctly.";
		NSLog(@"Alert: %@ - %@", alertView.title, alertView.message);
		[alertView addButtonWithTitle:@"Dismiss"];
		[alertView show];
	} else {
		UIAlertView* alertView = [[UIAlertView alloc] init];
		alertView.title = @"Bluetooth conection established, cool!!!";
		alertView.message = @"Connection to BTstack established!\n"
		"This is pretty damn cool.";
		NSLog(@"Alert: %@ - %@", alertView.title, alertView.message);
		[alertView addButtonWithTitle:@"Dismiss"];
		[alertView show];

		bt_register_packet_handler(packet_handler);
		bt_send_cmd(&btstack_set_power_mode, HCI_POWER_ON);

		//run_loop_execute();
		//bt_close();

		btOK = true;
	}

	UIWebView * newWebView = webView;
	[BluetoothDelegate setWebView:newWebView];
	//[foo release]; Do I need to release this? If its a reference I shouldn't right?
}

@end
