-- the timing logic operates in two modes:
-- 1. fallback mode, where a chip timer is used (tmr.now())
-- 2. synced mode, where the sntp is used to sync the time
--
-- when booted, the mode will first be fallback. the logic pretty much
-- repeats calculating tmr.now() / 60 000 000. overflows are also handled
--
-- once sntp connection has been established once, the mode is changed.
-- initial sntp time fix is stored, and later (rtctime.get() - initial) / 60
-- is calculated for changes

MICROSECONDS_IN_MINUTE = 60000000
SNTP_HOST = "fi.pool.ntp.org"

TIMER_POLL_TIME_AND_SWITCH = 0
TIMER_PULSE_CONTROL = 1
TIMER_TIME_SYNC_LOOP = 2
TIMER_TIME_SYNC_ONCE = 3

PIN_H_BRIDGE_ENABLE = 5
PIN_H_BRIDGE_A = 6
PIN_H_BRIDGE_B = 7
PIN_INPUT_SWITCH = 0

last_was_low = false
has_time_synced = false
initial_synced_time = 0
fallback_seconds_over = 0

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
  print("sending pulse")
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

-- time utils

tmr_now_overflow_count = 0
tmr_now_last = 0
function tmr_now_with_overflows()
  local now = tmr.now()
  if (now < tmr_now_last) then
    tmr_now_overflow_count = tmr_now_overflow_count + 1
  end
  tmr_now_last = now
  return tmr_now_overflow_count * (2^31 - 1) + now
end

last_minute_count = 0
last_synced_minute_count = 0
function minute_has_changed()
  if (not has_time_synced) then
    local new_minute_count = math.floor(tmr_now_with_overflows() / MICROSECONDS_IN_MINUTE)
    if (last_minute_count ~= new_minute_count) then
      print("minute has changed")
      last_minute_count = new_minute_count
      return true
    end
    return false
  else
    local time_elapsed = rtctime.get() - initial_synced_time + fallback_seconds_over
    local new_minute_count = math.floor(time_elapsed / 60)
    if (last_synced_minute_count ~= new_minute_count) then
      print("minute has changed")
      last_synced_minute_count = new_minute_count
      return true
    end
    return false
  end
end

-- time syncing

time_sync_in_progress = false
function sync_time()
  if (time_sync_in_progress) then
    return
  end
  print("syncing time...")
  -- sntp.sync acecpts a DNS name, but work around issue #889 by manually resolving DNS name
  net.dns.resolve(SNTP_HOST, function(sk, ip)
    if (ip == nil) then
      print("sntp dns resolve failed")
      time_sync_in_progress = false
    else
      print("sntp dns resolved: " .. ip)
      sntp.sync(ip, function(sec, usec, server)
        -- sntp sync automatically updates rtctime when successful
        print("sntp sync successful, cur time "..sec)
        time_sync_in_progress = false
        if (has_time_synced == false) then
          has_time_synced = true
          initial_synced_time = sec

          -- FIXME: tmr_now_with_overflows might be over (fallback_minute_count + 1) * MICROSECONDS_IN_MINUTE
          --        if the minute has just changed
          local microseconds_over = tmr_now_with_overflows() % MICROSECONDS_IN_MINUTE
          fallback_seconds_over = (microseconds_over / MICROSECONDS_IN_MINUTE) * 60
        end
      end, function()
        print("sntp sync failed")
        time_sync_in_progress = false
      end)
    end
  end)
end

-- time and switch polling

tmr.alarm(TIMER_POLL_TIME_AND_SWITCH, 100, 1, function() 
  if (gpio.read(PIN_INPUT_SWITCH) == gpio.LOW or minute_has_changed()) then
    send_pulse()
  end
end)

-- run sync_time once after 10 seconds
tmr.alarm(TIMER_TIME_SYNC_ONCE, 10000, 0, sync_time)
-- also sync the time once an hour
tmr.alarm(TIMER_TIME_SYNC_LOOP, 1000 * 3600, 1, sync_time)
