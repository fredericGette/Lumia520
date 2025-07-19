## Qcsmsm8930.sys

Shared Memory State Machine Driver  
Read, write and watch a memory region containing the state of the subsystems.  
It calls qcmem8930.sys to get the address of this memory region, and provides some IOCTL to read and write in it. Moreover, it sets a interrupt handler to be notified when a state is updated by a subsystem.  
When the state of a subsystem changes, it notifies the RPE client listening to this subsystem.  
