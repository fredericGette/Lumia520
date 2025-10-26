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
       * The first resource is mapped as MmWriteCombined.
       * Subsequent resources are mapped as MmNonCached.

   * Resource Validation: The function performs several checks to ensure the provided resources meet its expectations:
       * It expects at least two memory resources.
       * It validates the size of the second memory resource to be at least 32 bytes.
       * It expects any resources beyond the second one to be exactly 4 bytes in size.

   * Data Structure Initialization: After successfully mapping the resources, the driver initializes its own internal data structures. It allocates memory for these
      structures using a custom function, smem_alloc.
     
IoControlCode `0x42000`  
	Outputbuffer size 52  
	13 pointers (4*13=52) to internal functions  

IoControlCode `0x42004`  
	Inputbuffer size 8  
	Outputbuffer size 8  
	This IOCTL is likely used to translate a bus-relative address to a kernel virtual address. The process is as follows:  
       1. It retrieves an 8-byte input buffer and an 8-byte output buffer from the request.  
       2. It takes the address from the input buffer and searches for it in the list of memory-mapped resources that were previously saved during the EvtWdfDevicePrepareHardware phase.  
       3. If a matching resource is found, it copies the corresponding mapped kernel virtual address into the output buffer and completes the request with success.  
       4. If no match is found, it completes the request with the error code STATUS_INVALID_PARAMETER (0xC0000025).  
