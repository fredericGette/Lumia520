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

# Memory addresses

| Description | Start address | Size | Offset |
|-------------|---------------|------|--------|
| Boot ROM | 0x0 |  | |
| RPM Code RAM | 0x20000 | 0x23FFF | |
| RPM Message RAM | 0x00108000 | 0x5FFF | |
| System IMEM | 0x2A000000 | 0x3FFFF | |  
| MM IMEM | 0x2E000000 | 0x2FFFF | |  
| Graphical Internal Memory (GMEM or GIMEM) | 0x2E030000 | 0x7FFFF | |
| Main Memory (EBI1) | 0x80000000 | 0x1FFFFFFF | |
| Shared memory (SMEM or SMI) | 0x80000000 | 0x200000 | 0x0 | 
| Krait HLOS | 0x80200000 | 0x83FFFFF | |
| Modem memory (Q6SW) | 0x89000000 | 0x4A00000 | 0x9000000 |
| Q6FW | 0x8D400000 |  | |
| LPASS | 0x8DA00000 | 0x1800000 | |



