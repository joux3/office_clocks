#include <Time.h>

int RELAY_POWER_PORT    = 7;
int RELAY_BRIDGE_1_PORT = 9;
int RELAY_BRIDGE_2_PORT = 10;

int PULSE_TRIGGER_PORT  = 4;

int lastMinute = -1;
int lastWasLow = 1;

void setup() {
  pinMode(RELAY_POWER_PORT, OUTPUT);
  pinMode(RELAY_BRIDGE_1_PORT, OUTPUT);
  pinMode(RELAY_BRIDGE_2_PORT, OUTPUT);
  pinMode(PULSE_TRIGGER_PORT, INPUT_PULLUP);
  // set all the relays to known state
  digitalWrite(RELAY_POWER_PORT, LOW);
  lastWasLow = 1;
  digitalWrite(RELAY_BRIDGE_1_PORT, LOW);
  digitalWrite(RELAY_BRIDGE_2_PORT, LOW);
}

void sendSwitchPulse() {
  // the clock expects every second pulse as with polarity inverted
  int toSend = lastWasLow ? HIGH : LOW;
  lastWasLow = !lastWasLow;
  // set the bridge relays to correct
  digitalWrite(RELAY_BRIDGE_1_PORT, toSend);
  digitalWrite(RELAY_BRIDGE_2_PORT, toSend);
  // allow the bridge relays to change
  delay(200);
  // send the pulse
  digitalWrite(RELAY_POWER_PORT, HIGH);
  delay(500);
  digitalWrite(RELAY_POWER_PORT, LOW);
  delay(2500); // allow the clocks to change properly before sending another pulse
}

void loop() {
  if (lastMinute != minute()) {
    lastMinute = minute();
    sendSwitchPulse();
  } else if (digitalRead(PULSE_TRIGGER_PORT) == LOW) {
    sendSwitchPulse();
  }
}
