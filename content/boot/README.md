# Boot

```
        Resource Power    │                                        
        Manager (RPM)     │                                        
        ARM7 processor    │    Krait processor                     
                          │                                        
                          │                                        
                          │                                        
           ┌─────────┐    │                                        
           │  Power  │    │                                        
           │   on    │    │                                        
           └────┬────┘    │                                        
                │         │                                        
                ▼         │                                        
          ┌───────────┐   │                                        
          │ Primary   │   │                                        
          │ Bootloader│   │                                        
          │ Loader    │   │                                        
          │   (PBL)   │   │                                        
          └─────┬─────┘   │                                        
                │         │                                        
                ▼         │                                        
          ┌───────────┐   │  ┌───────────┐                         
          │ Secondary │   │  │ Secondary │                         
  Start   │ Bootloader├───┼─►│ Bootloader│ Start                   
1st Krait │     1     │   │  │     2     │ ARM TrustZone           
processor │  (SBL1)   │   │  │  (SBL2)   │ (TZ)                    
          └───────────┘   │  └─────┬─────┘                         
                          │        │                               
                          │        ▼                               
                          │  ┌───────────┐                         
                          │  │ Secondary │                         
                          │  │ Bootloader│ Mass Storage            
                          │  │     3     │ Mode                    
                          │  │  (SBL3)   │                         
                          │  └─────┬─────┘                         
                          │        │                               
                          │        ▼                               
                          │    ┌──────┐                            
                          │    │ UEFI │    Choose MainOS           
                          │    └───┬──┘    Flash Application       
                          │        │                               
                          │        ▼                               
                          │   ┌────────┐                           
                          │   │ MainOS │   Start 2nd Krait         
                          │   └────────┘   Start other subsystems  
                          │                (modem, Bluetooth, etc.)
```

Made with [asciiflow.com](https://asciiflow.com)

## Notes
The PBL and the SBL1 run on an ARM7 processor because the Krait processor is not ready yet (the first Krait processor is started by the SBL1).  
PBL is executed from the "Boot ROM".  
SBL1 is executed in the Internal Memory (IMEM) because the main memory (SDRAM) is not reay yet (the SDRAM is initialized by SBL2).  
TZ is also running in IMEM.  
SBL2 is first running in MIMEM (?) and can also use GMEM (?) if needed.  
SBL3, UEFI and MainOS are running in SDRAM.  

# Memory addresses

Boot ROM : 0x0  
IMEM : 0x2A000000  
MIMEM/GMEM : 0x2E000000  

