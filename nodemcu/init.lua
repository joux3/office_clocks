TIMER_POLL_TIME_AND_SWITCH = 0
TIMER_PULSE_CONTROL = 1

PIN_H_BRIDGE_ENABLE = 5
PIN_H_BRIDGE_A = 6
PIN_H_BRIDGE_B = 7
PIN_INPUT_SWITCH = 0

last_was_low = false

-- init
gpio.mode(PIN_H_BRIDGE_ENABLE, gpio.OUTPUT)
gpio.mode(PIN_H_BRIDGE_A, gpio.OUTPUT)
gpio.mode(PIN_H_BRIDGE_B, gpio.OUTPUT)
gpio.mode(PIN_INPUT_SWITCH, gpio.INPUT, gpio.PULLUP)

-- pulse sending

pulse_in_progress = false
function send_pulse()
  if (pulse_in_progress) then
    return
  end
  pulse_in_progress = true
  -- the clock expects every second pulse with polarity inverted
  last_was_low = not last_was_low
  -- set the H-bridge to reverse from last
  gpio.write(PIN_H_BRIDGE_A, last_was_low and gpio.LOW or gpio.HIGH)
  gpio.write(PIN_H_BRIDGE_B, last_was_low and gpio.HIGH or gpio.LOW)
  -- send the pulse
  gpio.write(PIN_H_BRIDGE_ENABLE, gpio.HIGH)
  tmr.alarm(TIMER_PULSE_CONTROL, 1000, 0, function()
    gpio.write(PIN_H_BRIDGE_ENABLE, gpio.LOW)
    tmr.alarm(TIMER_PULSE_CONTROL, 2500, 0, function()
      -- allow the clocks to change properly before sending another pulse
      pulse_in_progress = false
    end)
  end)
end

-- time and switch polling

tmr.alarm(TIMER_POLL_TIME_AND_SWITCH, 100, 1, function() 
  if (gpio.read(PIN_INPUT_SWITCH) == gpio.LOW) then
    send_pulse()
  end
end)
