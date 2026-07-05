# Pulse Generator

The circuit is composed of 5 stages:

- An oscillator
- A binary counter to decrease the frequency of the oscillator
- An edge detector to detect the rising and falling edges of the oscillations
- A monostable multivibrator to generate the pulse
- An output buffer is used to avoid disturbance to the monostable multivibrator caused by the load (the Lumia 520).

The power source of the circuit can be anything able to generate between 4.5v and 6v and deliver a 1.5mA current.  
For example: two CR2032 coin cells in series.


## The oscillator

To keep the circuit at my low electronic skill, I selected the solution of a _relaxation oscillator_.  
This is not the most efficient solution, because it's not perfectly stable and it consumes _a lot of_ current (around 0.20 mA) but it's very easy to build.  

- One inverted Schmitt trigger
- One resistor
- One capacitor

![oscillator](oscillator.png)

The capacitor is slowy charged and discharged through the resistor. The charge and the discharge phases are piloted by the inverted Schmitt trigger.  

## The binary counter

The oscillator deliver a periodic signal in the second range, to get a period in the hour range we use one or two binary counter in series.  
For example, when the oscillator has a frequency of 4Hz (0.25s) then we have to divide it by 16384 (2^14) to get a period of 4096s (~ 1hour and 8 minutes).

![counter](counter.png)
