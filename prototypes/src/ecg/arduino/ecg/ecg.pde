/*
* Simple Arduino-based program to read values from the HRMI using the I2C interface
 *
 * Connections
 * Arduino HRMI
 * -----------------------
 * +5 +5 (Power for the HRMI)
 * GND GND
 * Analog In 5 TX (I2C SCL) (recommend 4.7 kOhm pullup)
 * Analog In 4 RX (I2C SDA) (recommend 4.7 kOhm pullup)
 *
 *
 * Note: By default the Arduino Wiring library is limited to a maximum
 * I2C read of 32 bytes. The Get Heartrate command is limited
 * by this code to a maximum of 30 values (for a max I2C packet
 * of 32 bytes).
 *
 */

#include "Wire.h"
#include "hrmi_funcs.h"

/*
* Configuration Information
 *
 * Change these constants to match your specific configuration. These
 * values are the factory default (no OP1-OP7 jumpers installed). Jumper
 * OP1 should be installed and jumper SJ1 removed.
 *
 * HRMI_HOST_BAUDRATE should be set to the baudrate the host will use
 * to communicate with the Arduino over the serial interface.
 *
 * HRMI_I2C_ADDR should be set to the I2C address the HRMI is configured
 * with.
 */

#define HRMI_HOST_BAUDRATE 115200
#define HRMI_I2C_ADDR 0
#define HRMI_HR_ALG 1

/*
* Program constants
 */

#define MAX_IN_BUFFSIZE 16

/*
* Global variables
 */

int numEntries = 0; // Number of HR values to request
int numRspBytes; // Number of Response bytes to read
byte i2cRspArray[34];

// I2C response array, sized to read 32 HR values
byte hrmi_addr = HRMI_I2C_ADDR; // I2C address to use
byte hrmi_alg = HRMI_HR_ALG;      // Selected algorithm

/*
* Arduino initialization code segment
 */
void setup()
{
  // Initialize the I2C communication
  hrmi_open();
  
  // Configure the HRMI with the requested algorithm mode
  hrmiCmdArg(hrmi_addr, 'S', hrmi_alg);

  // Initialize the serial interface
  Serial.begin(HRMI_HOST_BAUDRATE);
}

/*
* Arduino main code loop
 */
void loop()
{
  // Request a set of heart rate values
  hrmiCmdArg(hrmi_addr, 'G', (byte) numEntries);

  // Get the response from the HRMI
  numRspBytes = numEntries + 2;
  if (hrmiGetData(hrmi_addr, numRspBytes, i2cRspArray) != -1) {
    Serial.print("1 "); 
    // send the results back on the serial interface in ASCII form
    Serial.print(numEntries); 
    Serial.print(" ");
    for (int i=0; i<numRspBytes; i++) {
      Serial.print(i2cRspArray[i], DEC);
      if (i<numRspBytes-1){
        Serial.print(" ");
      }
    }
  }
  else {
    Serial.print("0"); 
  }
  Serial.println();

  // Setup to do it again
  if (++numEntries > 30) {
    numEntries = 0;
  }

  delay(1000); // Delay 1 second between commands
}


