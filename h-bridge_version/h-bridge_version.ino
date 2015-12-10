#include <Time.h>

int BRIDGE_ENABLE_PORT = 7;
int BRIDGE_CONTROL1_PORT = 9;
int BRIDGE_CONTROL2_PORT = 10;

int PULSE_TRIGGER_PORT  = 4;

int lastMinute = -1;
int lastWasLow = 1;

void setup() {
  pinMode(BRIDGE_ENABLE_PORT, OUTPUT);
  pinMode(BRIDGE_CONTROL1_PORT, OUTPUT);
  pinMode(BRIDGE_CONTROL2_PORT, OUTPUT);
  pinMode(PULSE_TRIGGER_PORT, INPUT_PULLUP);

  digitalWrite(BRIDGE_ENABLE_PORT, LOW);
  lastWasLow = 1;
}

void sendSwitchPulse() {
  // the clock expects every second pulse with polarity inverted
  lastWasLow = !lastWasLow;
  // set the H-bridge to reverse from last
  digitalWrite(BRIDGE_CONTROL1_PORT, lastWasLow ? LOW : HIGH);
  digitalWrite(BRIDGE_CONTROL2_PORT, lastWasLow ? HIGH : LOW);
  // send the pulse
  digitalWrite(BRIDGE_ENABLE_PORT, HIGH);
  delay(500);
  digitalWrite(BRIDGE_ENABLE_PORT, LOW);
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

