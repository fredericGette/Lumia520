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
                          │  │ Bootloader│ Increase processor frequency            
                          │  │     3     │ Mass Storage Mode                    
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
The PBL and the SBL1 run on an ARM7TDMI processor because the Krait processor is not ready yet (the first Krait processor is started by the SBL1).  
PBL is executed from the "Boot ROM".  
When the PBL is not able to find or start the SBL1, it enters in Emergency Download Mode (EDL mode). In this mode a host can use USB to push a programmer.  
SBL1 is executed in the Internal MEMory (IMEM) because the main memory (SDRAM) is not ready yet (the SDRAM is initialized by SBL2).  
TZ is also running in IMEM.  
SBL2 is first running in MIMEM (?) and can also use Graphics internal MEMory (GMEM) if needed.  
SBL3, UEFI and MainOS are running in SDRAM.

The addresses of these memories are in [Physical Memory Mapping](../memory/README.md).
