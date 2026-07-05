# Pulse Generator

The circuit is composed of 5 stages:

- an oscillator
- a binary counter to decrease the frequency of the oscillator
- an edge detector to detect the rising and falling edges of the oscillations
- a monostable multivibrator to generate the pulse
- an output buffer to avoid disturbation on the monostable multivibrator caused by the load (the Lumia 520)

The power source of the circuit must be anything able to generate between 4.5v and 6v and deliver a 1.5mA current.  


## The oscillator

To keep the circuit at my low electronic skill, I selected the solution of a _relaxation oscillator_.  
This is not the most efficient solution, because it's not perfectly stable and it consumes _a lot of_ current (around 0.20 mA) but it's very easy to build.  

![oscillator](oscillator.png)
