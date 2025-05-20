# Bluetooth stack

![BluetoothStack](BluetoothStack.png)

## QcBluetooth8930.sys

The _EvtDevicePrepareHardware_ of the driver reads the file C:\DPP\QCOM\BT.PROVISION  
This binary file contains the address of the bluetooth device.  
Example of content (the bluetooth address is 78-92-3E-C7-7B-53):
| BYTE 0 | BYTE 1 | BYTE 2 | BYTE 3 | BYTE 4 | BYTE 5 | BYTE 6 | BYTE 7 |
|--------|--------|--------|--------|--------|--------|--------|--------|
| 01 | 06 | 78 | 92 | 3E | C7 | 7B | 53 |

Then it sends the [HCI Vendor Specific command SET BR_ADDR](#hci-vs-set-bd-addr) to set the bluetooth address of the device.



## HCI Vendor Specific

See  
[hci_qcomm_init/bthci_qcomm.h](https://github.com/ele7enxxh/msm8909w-law-2-0_amss_standard_oem/blob/1710/LINUX/android/vendor/qcom/proprietary/bt/hci_qcomm_init/bthci_qcomm.h)  
[hci_qcomm_init/bthci_qcomm_common.c](https://github.com/ele7enxxh/msm8909w-law-2-0_amss_standard_oem/blob/1710/LINUX/android/vendor/qcom/proprietary/bt/hci_qcomm_init/bthci_qcomm_common.c)  
[hci_qcomm_init/bthci_qcomm_linux.cpp](https://github.com/ele7enxxh/msm8909w-law-2-0_amss_standard_oem/blob/1710/LINUX/android/vendor/qcom/proprietary/bt/hci_qcomm_init/bthci_qcomm_linux.cpp)  
[hci_qcomm_init/btqsocnvmutils.c](https://github.com/ele7enxxh/msm8909w-law-2-0_amss_standard_oem/blob/1710/LINUX/android/vendor/qcom/proprietary/bt/hci_qcomm_init/btqsocnvmutils.c)  

```
BT_QSOC_EDL_CMD_OPCODE             (0xFC00)
BT_QSOC_NVM_ACCESS_OPCODE          (0xFC0B)
BT_QSOC_RIVA_STR_ID                "Release 5.01.0"
BT_QSOC_EDL_CMD_CODE               (0x00)
BT_QSOC_NVM_ACCESS_CODE            (0x0B)
BT_QSOC_VS_EDL_APPVER_RESP   	   (0x02)
```

__Application Get Version__

```
c< 04 00 00 00 01 00 FC 01 06
```
| HCI message length | type _command_ (not counted in the _HCI message length_) | Vendor Specific OpCode (BT_QSOC_EDL_CMD_OPCODE) | Command parameter length | Application Get Version |
|--------------------|----------------------------------------------------------|-------------------------------------------------|--------------------------|-------------------------|
| 04 00 00 00 | 01 | 00 FC | 01 | 06 |


```
e= 5D 00 00 00 04 FF 5B 00 02 58 20 20 20 20 52 65 6C 65 61 73 65 20 35 2E 30 31 2E 30 20 28 42 75 69 6C 64 20 32 30 30 33 29 20 5B 50 46 3D 4D 42 41 41 41 41 4E 41 5A 57 31 31 35 30 30 38 38 20 42 42 3D 32 30 30 33 20 4C 4D 50 3D 32 30 30 33 20 43 46 47 3D 52 41 4D 20 50 48 59 3D 30 32 30 30 5D
```
| HCI message length  | type _event_ (not counted in the _HCI message length_) | Vendor Specific Event | Event parameter length | EDL Vendor specific Cmd (BT_QSOC_EDL_CMD_CODE) | Vendor specific Application version Response (BT_QSOC_VS_EDL_APPVER_RESP) | "Release 5.01.0 (Build 2003) [PF=MBAAAANAZW1150088 BB=2003 LMP=2003 CFG=RAM PHY=0200]" |
|---------------------|--------------------------------------------------------|-----------------------|------------------------|------------------------------------------------|---------------------------------------------------------------------------------|----------------------------------------------------------------------------------------|
| 5D 00 00 00 | 04 | FF | 5B | 00 | 02 | 58 20 20 20 20 52 65 6C 65 61 73 65 20 35 2E 30 31 2E 30 20 28 42 75 69 6C 64 20 32 30 30 33 29 20 5B 50 46 3D 4D 42 41 41 41 41 4E 41 5A 57 31 31 35 30 30 38 38 20 42 42 3D 32 30 30 33 20 4C 4D 50 3D 32 30 30 33 20 43 46 47 3D 52 41 4D 20 50 48 59 3D 30 32 30 30 5D |

```
e= 06 00 00 00 04 0E 04 01 00 00 00
```
| HCI message length  | type _event_ (not counted in the _HCI message length_) | Command Complete Event | Event parameter length | Num_HCI_Command_Packets, ready to receive HCI command (0x01) | Command_Opcode NOP (No OPeration) | Return_Parameters |
|---------------------|--------------------------------------------------------|------------------------|------------------------|--------------------------------------------------------------|-----------------------------------|-------------------|
| 06 00 00 00 | 04 | 0E | 04 | 01 | 00 00 | 00 |


<a name="hci-vs-set-bd-addr">__SET BR_ADDR__</a>  

```
c< 0C 00 00 00 01 0B FC 09 01 02 06 53 7B C7 3E 92 78
```
| HCI message length | type _command_ (not counted in the _HCI message length_) | Vendor Specific OpCode (BT_QSOC_NVM_ACCESS_OPCODE) | Command parameter length | NVM item number (BD_ADDR) | NVM item size | NVM item value |
|--------------------|----------------------------------------------------------|----------------------------------------------------|--------------------------|---------------------------|---------------|----------------|
| 0C 00 00 00 | 01 | 0B FC | 09 | 01 02 | 06 | 53 7B C7 3E 92 78 |

```
e= 0C 00 00 00 04 FF 0A 0B 01 02 06 53 7B C7 3E 92 78
```
| HCI message length  | type _event_ (not counted in the _HCI message length_) | Vendor Specific Event | EDL Vendor specific Cmd (?) | Vendor specific NVM Access Response (BT_QSOC_NVM_ACCESS_CODE) | NVM item number (BD_ADDR) | NVM item size | NVM item value |
|---------------------|--------------------------------------------------------|-----------------------|-----------------------------|---------------------------------------------------------------|---------------------------|---------------|----------------|
| 0C 00 00 00 | 04 | FF | 0A | 0B | 01 02 | 06 | 53 7B C7 3E 92 78 |


```
e= 06 00 00 00 04 0E 04 01 00 00 00
```
| HCI message length  | type _event_ (not counted in the _HCI message length_) | Command Complete Event | Num_HCI_Command_Packets, ready to receive HCI command (0x01) | Command_Opcode NOP (No OPeration) | Return_Parameters |
|---------------------|--------------------------------------------------------|------------------------|--------------------------------------------------------------|-----------------------------------|-------------------|
| 06 00 00 00 | 04 | 0E | 04 | 01 | 00 00 | 00 |
