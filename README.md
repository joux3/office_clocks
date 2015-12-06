# Office clock control

## Clock "protocol"

The clock changes minute display (and hour display if switching from `59` -> `00`)
by toggling a pulse of 24 volts across the lines. The polarity of the voltage
needs to be different every other pulse, so that the solenoid operating the
display moves (otherwise it would just try to stay in the same position on every
pulse instead of generating a movement).

## Schematic

![](schematic.png?raw=true)
