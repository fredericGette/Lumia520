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

The oscillator delivers a periodic signal in the second range; to get a period in the hour range, we use one or two binary counters in series.  
For example, when the oscillator has a frequency of 4Hz (0.25s) then we have to divide it by 16,384 ($2^{14}$) to get a period of 4,096s (~ 1hour and 8 minutes).

![counter](counter.png)

## The edge detector

The oscillator gives us a square signal : the duration of the _high_ pulse is equals to the duration of the _low_ pause. As we want a short pulse (~400ms) compared to the long pause (~1 hour) we have to detect the begining of an oscillation and use it as the signal to start our own pulse.  
We can do that with a simple edge detector wich generate a short positive spike (~100µs) no the rising edge of the oscillation and another spike - but negative - on the falling edge.  

![edge_detector](edge_detector.png)

## The monostable multivibrator

In my opinion, this is the most difficult part of the circuit to understand.  
The monostable multivibrator is responsible for transforming a previously generated positive spike into a square pulse of several hundred milliseconds.

- Two inverted Schmitt triggers
- One resistor
- One capacitor
- One diod

