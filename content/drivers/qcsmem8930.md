## Qcsmem8930.sys

Shared Memory Driver

Device name : `\Device\SMEM`  

There's no parameters in the registry.  

GUID of the ETW provider:  
`{61085ed3-92fb-436b-b828-8a57815e1826}`  

GUID of the device interfaces:  
InterfaceClassGUID_00       : `{54415e20-5fc4-4938-8958-31966f441c63}`  

The function EvtWdfDevicePrepareHardware is a standard callback in the Windows Driver Framework (WDF) that is responsible for preparing a device's hardware
  resources for operation. Here's a breakdown of its functionality:

   * Resource Parsing: The function iterates through a list of translated hardware resources provided by the Plug and Play (PnP) manager. It specifically looks for
     memory-mapped I/O resources (CmResourceTypeMemory).

   * Memory Mapping: For each memory resource, it uses MmMapIoSpace to map the physical hardware addresses into the kernel's virtual address space, making them
     accessible to the driver. It uses different caching types for different resources:
       * The first resource is mapped as MmWriteCombined. This is the "heap" shared memory. Its physical addresse starts at 0x80000000 with a length of 0x200000 bytes. It contains a list of fixed memory buffers at the beginning. Then each subsequent request allocate another memory buffer. 
       * Subsequent resources are mapped as MmNonCached. The second memory resource seems to contains an array of 32 DWORD set to 0 when the corresponding spinlock is acquired. It starts at the physical address 0x01200604 with a length of 0x80 bytes. Then there are 3 other additional memory resources of 4 bytes each. Their physicial addresses are 0x2011008, 0x12104080 and 0x12104094
    
IoControlCode `0x42000`  
	Outputbuffer size 52  
	13 pointers (4*13=52) to internal functions  

| Function signature |
|--------------------|
| void *smem_alloc(smem_mem_type smem_type, int buf_size); |
| void *smem_get_addr(smem_mem_type smem_type, ULONG *size); |
| void nullsub_1(); |
| BOOLEAN smem_version_set(smem_mem_type type, int version, int mask); |
| void smem_spin_lock(int lock); |
| void smem_spin_unlock(int lock); |
| unsigned int smem_read_log_events(unsigned int a1, unsigned int a2, char *a3, _DWORD *a4, _DWORD *a5); |
| int smem_init_log_buffer(unsigned int a1); |
| void smem_write_log_event3(unsigned int a1, int eventId, int a3, int data1, int data2, int data3); |
| void smem_write_log_event6(unsigned int a1, int a2, int a3, int a4, int a5, int a6, int a7, int a8, int a9); |
| void smem_set_lock0(int lock); |
| int smem_get_firstMemoryResourcePhysicalStart(); |
|int smem_get_firstMemoryResourceLength(); |

IoControlCode `0x42004`  
	Inputbuffer size 8  
	Outputbuffer size 8  
	This IOCTL is likely used to translate a bus-relative address to a kernel virtual address. 
	It retrieves the 4 lower bytes of the Inputbuffer (this is a physical address) and look for it in the arrayAdditionalMemoryResources initialised during EvtWdfDevicePrepareHardware. This arrays contains 3 entries: each entries correspond to an "additional memory resource" and contains its physical address (first DWORD) and its virtual address (second DWORD).
    If a matching entry is found, it copies the corresponding mapped kernel virtual address into the 4 upper bytes of the Outputbuffer.  
