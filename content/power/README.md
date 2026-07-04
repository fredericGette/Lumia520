# Electrical power

Main source of power is the BL-5J battery.  

![battery](battery.jpg)

The battery can be recharged through the USB port.

When in power off state, the phone can be started by applying the following current to the USB port (Vcc and Gnd pins)

| Voltage | Duration | Current |
|---------|----------|---------|
| min/max 4.3v / 6.0v | min 250ms | 1.5mA |

> [!Note]
> It looks like the RTC of the phone doesn't have an alarm wake function (see [acpitime driver](https://github.com/fredericGette/Lumia520/blob/main/content/drivers/acpitime.md))  
> __But we can use the USB port to periodically start the phone.__  
> See this example of [an electronic pulse generator](https://github.com/fredericGette/Lumia520/blob/main/content/power/pulse_generator/README.md) to start the phone every few hours.

In the power off state, the resistance mesured between Vcc and Gnd at the USB port is ~43K&Omega;
