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
