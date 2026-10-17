/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20260408 (32-bit version)
 * Copyright (c) 2000 - 2026 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of C:/Users/frede/Projects/Lumia520/dsdt.aml
 *
 * Original Table Header:
 *     Signature        "DSDT"
 *     Length           0x0001149D (70813)
 *     Revision         0x02
 *     Checksum         0x01
 *     OEM ID           "QCOMM "
 *     OEM Table ID     "MSM8930 "
 *     OEM Revision     0x00000004 (4)
 *     Compiler ID      "MSFT"
 *     Compiler Version 0x04000000 (67108864)
 */
DefinitionBlock ("", "DSDT", 2, "QCOMM ", "MSM8930 ", 0x00000004)
{
    Scope (\_SB)
    {
        Device (ABD)
        {
            Name (_HID, "QCOM1200")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            OperationRegion (ROP1, GenericSerialBus, Zero, 0x0100)
            Name (AVBL, Zero)
            Method (_REG, 2, NotSerialized)  // _REG: Region Availability
            {
                If ((Arg0 == 0x09))
                {
                    AVBL = Arg1
                }
            }
        }

        Device (PMIC)
        {
            Name (_HID, "QCOM0A00")  // _HID: Hardware ID
            Method (PMCF, 0, NotSerialized)
            {
                Name (CFG0, Package (0x09)
                {
                    One, 
                    0x00300000, 
                    0x0200, 
                    0x00500000, 
                    0x40, 
                    Zero, 
                    Zero, 
                    Zero, 
                    Zero
                })
                Return (CFG0) /* \_SB_.PMIC.PMCF.CFG0 */
            }
        }

        Device (PM01)
        {
            Name (_HID, "QCOM05C0")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.PMIC, 
            })
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0xB1)
                {
                    /* 0000 */  0x8C, 0x20, 0x00, 0x01, 0x00, 0x01, 0x00, 0x0A,  // . ......
                    /* 0008 */  0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00,  // ........
                    /* 0010 */  0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x68,  // ...#...h
                    /* 0018 */  0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x47, 0x49,  // .\_SB.GI
                    /* 0020 */  0x4F, 0x30, 0x00, 0x8C, 0x20, 0x00, 0x01, 0x00,  // O0.. ...
                    /* 0028 */  0x01, 0x00, 0x0A, 0x00, 0x01, 0x00, 0x00, 0x00,  // ........
                    /* 0030 */  0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23, 0x00,  // ......#.
                    /* 0038 */  0x00, 0x00, 0x68, 0x00, 0x5C, 0x5F, 0x53, 0x42,  // ..h.\_SB
                    /* 0040 */  0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x8C, 0x20,  // .GIO0.. 
                    /* 0048 */  0x00, 0x01, 0x00, 0x01, 0x00, 0x0A, 0x00, 0x01,  // ........
                    /* 0050 */  0x00, 0x00, 0x00, 0x00, 0x17, 0x00, 0x00, 0x19,  // ........
                    /* 0058 */  0x00, 0x23, 0x00, 0x00, 0x00, 0x68, 0x00, 0x5C,  // .#...h.\
                    /* 0060 */  0x5F, 0x53, 0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30,  // _SB.GIO0
                    /* 0068 */  0x00, 0x8C, 0x20, 0x00, 0x01, 0x00, 0x01, 0x00,  // .. .....
                    /* 0070 */  0x0A, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x17,  // ........
                    /* 0078 */  0x00, 0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00,  // ....#...
                    /* 0080 */  0x68, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x47,  // h.\_SB.G
                    /* 0088 */  0x49, 0x4F, 0x30, 0x00, 0x8C, 0x20, 0x00, 0x01,  // IO0.. ..
                    /* 0090 */  0x00, 0x01, 0x00, 0x0A, 0x00, 0x01, 0x00, 0x00,  // ........
                    /* 0098 */  0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // .......#
                    /* 00A0 */  0x00, 0x00, 0x00, 0x68, 0x00, 0x5C, 0x5F, 0x53,  // ...h.\_S
                    /* 00A8 */  0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x79,  // B.GIO0.y
                    /* 00B0 */  0x00                                             // .
                })
                Return (RBUF) /* \_SB_.PM01._CRS.RBUF */
            }

            Method (PMIO, 0, NotSerialized)
            {
                Name (CFG0, Package (0x11)
                {
                    Zero, 
                    0x1F66, 
                    0x0C, 
                    0xC0, 
                    Zero, 
                    Zero, 
                    0x0110, 
                    0x40, 
                    Zero, 
                    0x0100, 
                    Zero, 
                    Zero, 
                    Zero, 
                    0x06, 
                    0x80, 
                    Zero, 
                    Zero
                })
                Return (CFG0) /* \_SB_.PM01.PMIO.CFG0 */
            }

            Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
            {
                While (One)
                {
                    Name (_T_0, Buffer (0x01)  // _T_x: Emitted by ASL Compiler, x=0-9, A-Z
                    {
                         0x00                                             // .
                    })
                    CopyObject (ToBuffer (Arg0), _T_0) /* \_SB_.PM01._DSM._T_0 */
                    If ((_T_0 == ToUUID ("4f248f40-d5e2-499f-834c-27758ea1cd3f") /* GPIO Controller */))
                    {
                        While (One)
                        {
                            Name (_T_1, 0x00)  // _T_x: Emitted by ASL Compiler, x=0-9, A-Z
                            _T_1 = ToInteger (Arg2)
                            If ((_T_1 == Zero))
                            {
                                Return (Buffer (One)
                                {
                                     0x03                                             // .
                                })
                            }
                            ElseIf ((_T_1 == One))
                            {
                                Return (Package (0x01)
                                {
                                    0x33
                                })
                            }
                            Else
                            {
                            }

                            Break
                        }
                    }
                    Else
                    {
                        Return (Buffer (One)
                        {
                             0x00                                             // .
                        })
                    }

                    Break
                }
            }
        }

        Device (PBMS)
        {
            Name (_DEP, Package (0x02)  // _DEP: Dependencies
            {
                \_SB.PMIC, , 
                \_SB.SCM0, 
            })
            Name (_HID, "QCOM0A02")  // _HID: Hardware ID
            Method (PMCF, 0, NotSerialized)
            {
                Name (CFG0, Package (0x07)
                {
                    0x2710, 
                    0x012C, 
                    0x0C1C, 
                    Zero, 
                    0x64, 
                    0x05DC, 
                    Zero
                })
                Return (CFG0) /* \_SB_.PBMS.PMCF.CFG0 */
            }
        }

        Device (PMAP)
        {
            Name (_DEP, Package (0x03)  // _DEP: Dependencies
            {
                \_SB.ABD, , 
                \_SB.PMIC, , 
                \_SB.SCM0, 
            })
            Name (_HID, "QCOM0B20")  // _HID: Hardware ID
            Method (GEPT, 0, NotSerialized)
            {
                Name (BUFF, Buffer (0x04){})
                CreateByteField (BUFF, Zero, STAT)
                CreateWordField (BUFF, 0x02, DATA)
                DATA = 0x02
                Return (DATA) /* \_SB_.PMAP.GEPT.DATA */
            }

            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x02)
                {
                     0x79, 0x00                                       // y.
                })
                Return (RBUF) /* \_SB_.PMAP._CRS.RBUF */
            }
        }

        Device (PRTC)
        {
            Name (_HID, "ACPI000E" /* Time and Alarm Device */)  // _HID: Hardware ID
            Name (_DEP, Package (0x01)  // _DEP: Dependencies
            {
                "\\_SB.PMAP"
            })
            Method (_GCP, 0, NotSerialized)  // _GCP: Get Capabilities
            {
                Return (0x04)
            }

            Field (\_SB.ABD.ROP1, BufferAcc, NoLock, Preserve)
            {
                Connection (
                    I2cSerialBusV2 (0x0002, ControllerInitiated, 0x00000000,
                        AddressingMode7Bit, "\\_SB.ABD",
                        0x00, ResourceConsumer, , Exclusive,
                        )
                ), 
                AccessAs (BufferAcc, AttribRawBytes (0x10)), 
                FLD0,   128
            }

            Method (_GRT, 0, NotSerialized)  // _GRT: Get Real Time
            {
                Name (BUFF, Buffer (0x12){})
                CreateField (BUFF, 0x10, 0x80, TME1)
                BUFF = FLD0 /* \_SB_.PRTC.FLD0 */
                Return (TME1) /* \_SB_.PRTC._GRT.TME1 */
            }

            Method (_SRT, 1, NotSerialized)  // _SRT: Set Real Time
            {
                Name (BUFF, Buffer (0x12){})
                CreateByteField (BUFF, Zero, STAT)
                CreateField (BUFF, 0x10, 0x80, TME1)
                TME1 = Arg0
                BUFF = FLD0 = BUFF /* \_SB_.PRTC._SRT.BUFF */
                If ((STAT != Zero))
                {
                    Return (One)
                }

                Return (Zero)
            }
        }

        Device (PEP0)
        {
            Name (_HID, "QCOM0811")  // _HID: Hardware ID
            Name (_CID, "PNP0D80" /* Windows-compatible System Power Management Controller */)  // _CID: Compatible ID
            Name (_CRS, Buffer (0x2F)  // _CRS: Current Resource Settings
            {
                /* 0000 */  0x89, 0x06, 0x00, 0x03, 0x01, 0x33, 0x00, 0x00,  // .....3..
                /* 0008 */  0x00, 0x89, 0x06, 0x00, 0x03, 0x01, 0x34, 0x00,  // ......4.
                /* 0010 */  0x00, 0x00, 0x89, 0x06, 0x00, 0x03, 0x01, 0x35,  // .......5
                /* 0018 */  0x00, 0x00, 0x00, 0x89, 0x06, 0x00, 0x03, 0x01,  // ........
                /* 0020 */  0x36, 0x00, 0x00, 0x00, 0x89, 0x06, 0x00, 0x03,  // 6.......
                /* 0028 */  0x01, 0xD2, 0x00, 0x00, 0x00, 0x79, 0x00         // .....y.
            })
            Name (ROST, Zero)
            Method (NPUR, 1, NotSerialized)
            {
                \_SB.AGR0._PUR [One] = Arg0
                Notify (\_SB.AGR0, 0x80) // Status Change
            }

            Name (DCFG, Package (0x1C)
            {
                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.ADC1", 
                    Package (0x05)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_CLOCK", 
                                    0x07, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_CLOCK", 
                                    0x07, 
                                    Zero
                                }
                            }
                        }
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.PRXY", 
                    Package (0x03)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.SDF1", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x08)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x5F)
                            {
                                "TLMMGPIO", 
                                Package (0x06)
                                {
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x03, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x04, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x06, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x07, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x08, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x09, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x0A, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x0C, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x0D, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x0E, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x0F, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x12, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x13, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x16, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x17, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x18, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x19, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x21, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x22, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x23, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x24, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x25, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x26, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x27, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x28, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x29, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x2F, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x30, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x32, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x33, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x35, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x36, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x37, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x38, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x3F, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x40, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x41, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x42, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x44, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x45, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x46, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x47, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x48, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x49, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x4A, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x4B, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x4C, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x4D, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x4E, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x4F, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x50, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x51, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x52, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x59, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x5A, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x5B, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x5C, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x5D, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x5E, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x5F, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x60, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x61, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x63, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x64, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x65, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x66, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x6A, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x6B, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x6D, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x6E, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x6F, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x70, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x71, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x72, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x78, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x79, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x7C, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x80, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x81, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x82, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x83, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x84, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x87, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x8A, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x8B, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x8C, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x8D, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x90, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x91, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x95, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x96, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x97, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }
                            }, 

                            Package (0x07)
                            {
                                "PMICGPIO", 
                                Package (0x07)
                                {
                                    "IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT", 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x07)
                                {
                                    "IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT", 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x07)
                                {
                                    "IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT", 
                                    Zero, 
                                    0x04, 
                                    Zero, 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x07)
                                {
                                    "IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT", 
                                    Zero, 
                                    0x05, 
                                    Zero, 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x07)
                                {
                                    "IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT", 
                                    Zero, 
                                    0x06, 
                                    Zero, 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x07)
                                {
                                    "IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT", 
                                    Zero, 
                                    0x0B, 
                                    Zero, 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x07)
                            {
                                "PMICGPIO", 
                                Package (0x06)
                                {
                                    "IOCTL_PM_GPIO_CONFIG_DIGITAL_INPUT", 
                                    Zero, 
                                    Zero, 
                                    0x04, 
                                    0x02, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    "IOCTL_PM_GPIO_CONFIG_DIGITAL_INPUT", 
                                    Zero, 
                                    One, 
                                    0x04, 
                                    0x02, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    "IOCTL_PM_GPIO_CONFIG_DIGITAL_INPUT", 
                                    Zero, 
                                    0x04, 
                                    0x04, 
                                    0x02, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    "IOCTL_PM_GPIO_CONFIG_DIGITAL_INPUT", 
                                    Zero, 
                                    0x05, 
                                    0x04, 
                                    0x02, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    "IOCTL_PM_GPIO_CONFIG_DIGITAL_INPUT", 
                                    Zero, 
                                    0x06, 
                                    0x04, 
                                    0x02, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    "IOCTL_PM_GPIO_CONFIG_DIGITAL_INPUT", 
                                    Zero, 
                                    0x0B, 
                                    0x04, 
                                    0x02, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICMPP", 
                                Package (0x05)
                                {
                                    "IOCTL_PM_MPP_CONFIG_I_SINK", 
                                    Zero, 
                                    0x04, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICMPP", 
                                Package (0x05)
                                {
                                    "IOCTL_PM_MPP_CONFIG_I_SINK", 
                                    Zero, 
                                    0x05, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x09)
                            {
                                "PMICVREGVOTE", 
                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_VDDCX_CORNER", 
                                    0x08, 
                                    0x02
                                }, 

                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS2", 
                                    0x02, 
                                    0x0013A54C, 
                                    0x00061A80, 
                                    0x00061A80, 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }, 

                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS4", 
                                    0x02, 
                                    0x001B7740, 
                                    0x000186A0, 
                                    0x000186A0, 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO4", 
                                    One, 
                                    0x001B7740, 
                                    0x07D0, 
                                    0x07D0, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO11", 
                                    One, 
                                    0x001B7740, 
                                    0x9C40, 
                                    0x9C40, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO14", 
                                    One, 
                                    0x001B7740, 
                                    0x1388, 
                                    0x1388, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO20", 
                                    One, 
                                    0x0012B128, 
                                    0x00061A80, 
                                    0x00061A80, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO23", 
                                    One, 
                                    0x001B7740, 
                                    0x07D0, 
                                    0x07D0, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "FSTATE", 
                            One
                        }
                    }
                }, 

                Package (0x05)
                {
                    "DEVICE", 
                    "\\_SB.SDC1", 
                    Package (0x1A)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x02)
                        {
                            "FSTATE", 
                            One
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc1_apps_clk", 
                                    0x03, 
                                    0x00061A80, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc1_apps_clk", 
                                    0x03, 
                                    0x017D7840, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc1_apps_clk", 
                                    0x03, 
                                    0x017D7840, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc1_apps_clk", 
                                    0x03, 
                                    0x018CBA80, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc1_apps_clk", 
                                    0x03, 
                                    0x02FAF080, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc1_apps_clk", 
                                    0x03, 
                                    0x02FAF080, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc1_apps_clk", 
                                    0x03, 
                                    0x05F5E100, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x07, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc1_apps_clk", 
                                    0x03, 
                                    0x03197500, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x08, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc1_apps_clk", 
                                    0x03, 
                                    0x0632EA00, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x09, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc1_apps_clk", 
                                    0x03, 
                                    0x05F5E100, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0A, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc1_apps_clk", 
                                    0x03, 
                                    0x0BEBC200, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0B, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc1_apps_clk", 
                                    0x03, 
                                    0x0C65D400, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0C, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0D, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0E, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0F, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x10, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x11, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x12, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x13, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x14, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x15, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x03)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO5", 
                                One, 
                                0x002B7CD0, 
                                0x00061A80, 
                                0x00061A80, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }, 

                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO11", 
                                One, 
                                0x001B7740, 
                                0x00030D40, 
                                0x00030D40, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "TLMMPORT", 
                            Package (0x03)
                            {
                                0x20A0, 
                                0x7FFF, 
                                0x1F49
                            }
                        }, 

                        Package (0x02)
                        {
                            "BUSARB", 
                            Package (0x05)
                            {
                                0x03, 
                                "ICBID_MASTER_SPS", 
                                "ICBID_SLAVE_EBI1", 
                                0x3C000000, 
                                0x03C00000
                            }
                        }, 

                        Package (0x02)
                        {
                            "REQUIRED_RESOURCE", 
                            Package (0x03)
                            {
                                One, 
                                "/clk/bus/dfab", 
                                0xFFFFFFFF
                            }
                        }, 

                        Package (0x02)
                        {
                            "DELAY", 
                            Package (0x01)
                            {
                                0x32
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_sdc1_hclk", 
                                One, 
                                0x03D09000, 
                                0x04
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_sdc1_apps_clk", 
                                0x08, 
                                0x00061A80, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x08)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_sdc1_apps_clk", 
                                0x02, 
                                0x00061A80, 
                                0x02
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_sdc1_hclk", 
                                0x02, 
                                0x03D09000, 
                                0x04
                            }
                        }, 

                        Package (0x02)
                        {
                            "REQUIRED_RESOURCE", 
                            Package (0x03)
                            {
                                Zero, 
                                "/clk/bus/dfab", 
                                0xFFFFFFFF
                            }
                        }, 

                        Package (0x02)
                        {
                            "BUSARB", 
                            Package (0x05)
                            {
                                0x03, 
                                "ICBID_MASTER_SPS", 
                                "ICBID_SLAVE_EBI1", 
                                0x1F40, 
                                Zero
                            }
                        }, 

                        Package (0x02)
                        {
                            "TLMMPORT", 
                            Package (0x03)
                            {
                                0x20A0, 
                                0x7FFF, 
                                0x1E00
                            }
                        }, 

                        Package (0x03)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO5", 
                                One, 
                                0x002B7CD0, 
                                0x00061A80, 
                                0x00061A80, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }, 

                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO11", 
                                One, 
                                0x001B7740, 
                                0x00030D40, 
                                0x00030D40, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }
                    }
                }, 

                Package (0x05)
                {
                    "DEVICE", 
                    "\\_SB.SDC3", 
                    Package (0x1A)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x02)
                        {
                            "FSTATE", 
                            One
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc3_apps_clk", 
                                    0x03, 
                                    0x00061A80, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc3_apps_clk", 
                                    0x03, 
                                    0x017D7840, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc3_apps_clk", 
                                    0x03, 
                                    0x017D7840, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc3_apps_clk", 
                                    0x03, 
                                    0x018CBA80, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc3_apps_clk", 
                                    0x03, 
                                    0x02FAF080, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc3_apps_clk", 
                                    0x03, 
                                    0x02FAF080, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc3_apps_clk", 
                                    0x03, 
                                    0x05F5E100, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x07, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc3_apps_clk", 
                                    0x03, 
                                    0x03197500, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x08, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc3_apps_clk", 
                                    0x03, 
                                    0x0632EA00, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x09, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc3_apps_clk", 
                                    0x03, 
                                    0x05F5E100, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0A, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc3_apps_clk", 
                                    0x03, 
                                    0x0BEBC200, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0B, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_sdc3_apps_clk", 
                                    0x03, 
                                    0x0C65D400, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0C, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0D, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0E, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0F, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x10, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x11, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x12, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x13, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }
                        }, 

                        Package (0x06)
                        {
                            "PSTATE", 
                            0x14, 
                            Package (0x03)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO6", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO22", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    0x32
                                }
                            }, 

                            Package (0x03)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO22", 
                                    One, 
                                    0x002B7CD0, 
                                    0x3E80, 
                                    0x3E80, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO6", 
                                    One, 
                                    0x002B7CD0, 
                                    0x00030D40, 
                                    0x00030D40, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    0x23
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x15, 
                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO22", 
                                    One, 
                                    0x001C3A90, 
                                    0x3E80, 
                                    0x3E80, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    0x23
                                }
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x03)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO22", 
                                One, 
                                0x002B7CD0, 
                                0x3E80, 
                                0x3E80, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }, 

                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO6", 
                                One, 
                                0x002B7CD0, 
                                0x00030D40, 
                                0x00030D40, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "TLMMPORT", 
                            Package (0x03)
                            {
                                0x20A4, 
                                0x7FFF, 
                                0x1FE4
                            }
                        }, 

                        Package (0x02)
                        {
                            "BUSARB", 
                            Package (0x05)
                            {
                                0x03, 
                                "ICBID_MASTER_SPS", 
                                "ICBID_SLAVE_EBI1", 
                                0x3C000000, 
                                0x03C00000
                            }
                        }, 

                        Package (0x02)
                        {
                            "REQUIRED_RESOURCE", 
                            Package (0x03)
                            {
                                One, 
                                "/clk/bus/dfab", 
                                0xFFFFFFFF
                            }
                        }, 

                        Package (0x02)
                        {
                            "DELAY", 
                            Package (0x01)
                            {
                                0x32
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_sdc3_hclk", 
                                One, 
                                0x03D09000, 
                                0x04
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_sdc3_apps_clk", 
                                0x08, 
                                0x00061A80, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x08)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_sdc3_hclk", 
                                0x02, 
                                0x03D09000, 
                                0x04
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_sdc3_apps_clk", 
                                0x02, 
                                0x00061A80, 
                                0x02
                            }
                        }, 

                        Package (0x02)
                        {
                            "REQUIRED_RESOURCE", 
                            Package (0x03)
                            {
                                Zero, 
                                "/clk/bus/dfab", 
                                0xFFFFFFFF
                            }
                        }, 

                        Package (0x02)
                        {
                            "BUSARB", 
                            Package (0x05)
                            {
                                0x03, 
                                "ICBID_MASTER_SPS", 
                                "ICBID_SLAVE_EBI1", 
                                0x1F40, 
                                Zero
                            }
                        }, 

                        Package (0x02)
                        {
                            "TLMMPORT", 
                            Package (0x03)
                            {
                                0x20A4, 
                                0x7FFF, 
                                0x0A00
                            }
                        }, 

                        Package (0x03)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO6", 
                                One, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }, 

                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO22", 
                                One, 
                                0x001C3A90, 
                                0x07D0, 
                                0x07D0, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }
                    }
                }, 

                Package (0x07)
                {
                    "DEVICE", 
                    "\\_SB.GSBI", 
                    Package (0x03)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi3_hclk", 
                                One, 
                                0x03938700, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi9_hclk", 
                                One, 
                                0x03938700, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi12_hclk", 
                                One, 
                                0x03938700, 
                                One
                            }
                        }
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        One
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x02
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi3_hclk", 
                                0x02, 
                                0x03938700, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi9_hclk", 
                                0x02, 
                                0x03938700, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi12_hclk", 
                                0x02, 
                                0x03938700, 
                                One
                            }
                        }
                    }
                }, 

                Package (0x07)
                {
                    "DEVICE", 
                    "\\_SB.I2C3", 
                    Package (0x03)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi3_hclk", 
                                One, 
                                0x03938700, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi3_qup_apps_clk", 
                                0x08, 
                                0x016E3600, 
                                0x04
                            }
                        }, 

                        Package (0x03)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x10, 
                                One, 
                                One, 
                                Zero, 
                                Zero, 
                                Zero
                            }, 

                            Package (0x06)
                            {
                                0x11, 
                                One, 
                                One, 
                                Zero, 
                                Zero, 
                                Zero
                            }
                        }
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        One
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x02
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi3_hclk", 
                                0x02, 
                                0x03938700, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi3_qup_apps_clk", 
                                0x02, 
                                0x016E3600, 
                                One
                            }
                        }, 

                        Package (0x03)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x11, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero
                            }, 

                            Package (0x06)
                            {
                                0x10, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero
                            }
                        }
                    }
                }, 

                Package (0x07)
                {
                    "DEVICE", 
                    "\\_SB.I2C9", 
                    Package (0x03)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi9_hclk", 
                                One, 
                                0x03938700, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi9_qup_apps_clk", 
                                0x08, 
                                0x016E3600, 
                                0x04
                            }
                        }, 

                        Package (0x03)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x5F, 
                                One, 
                                0x02, 
                                Zero, 
                                Zero, 
                                Zero
                            }, 

                            Package (0x06)
                            {
                                0x60, 
                                One, 
                                0x02, 
                                Zero, 
                                Zero, 
                                Zero
                            }
                        }
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        One
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x02
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi9_hclk", 
                                0x02, 
                                0x03938700, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi9_qup_apps_clk", 
                                0x02, 
                                0x016E3600, 
                                One
                            }
                        }, 

                        Package (0x03)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x60, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero
                            }, 

                            Package (0x06)
                            {
                                0x5F, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero
                            }
                        }
                    }
                }, 

                Package (0x07)
                {
                    "DEVICE", 
                    "\\_SB.IC12", 
                    Package (0x03)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi12_hclk", 
                                One, 
                                0x03938700, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi12_qup_apps_clk", 
                                0x08, 
                                0x016E3600, 
                                0x04
                            }
                        }, 

                        Package (0x03)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x2C, 
                                One, 
                                One, 
                                Zero, 
                                Zero, 
                                Zero
                            }, 

                            Package (0x06)
                            {
                                0x2D, 
                                One, 
                                One, 
                                Zero, 
                                Zero, 
                                Zero
                            }
                        }
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        One
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x02
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi12_hclk", 
                                0x02, 
                                0x03938700, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "cc_gsbi12_qup_apps_clk", 
                                0x02, 
                                0x016E3600, 
                                One
                            }
                        }, 

                        Package (0x03)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x2D, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero
                            }, 

                            Package (0x06)
                            {
                                0x2C, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero
                            }
                        }
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.CAMS", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x1C)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0xFA00
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO9", 
                                    One, 
                                    0x002AB980, 
                                    0xEA60, 
                                    0xEA60, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }, 

                            Package (0x03)
                            {
                                "PMICVREGVOTE", 
                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS4", 
                                    0x02, 
                                    0x002191C0, 
                                    0x0016E360, 
                                    0x0016E360, 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO11", 
                                    One, 
                                    0x001B7740, 
                                    0xEA60, 
                                    0xEA60, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi0_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi0_clk", 
                                    0x03, 
                                    0x0A98B520, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csiphy0_timer_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csiphy0_timer_clk", 
                                    0x03, 
                                    0x0A98B520, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi0_phy_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_cam0clk_po", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_cam0clk_po", 
                                    0x03, 
                                    0x00927C00, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_ahb_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x05)
                                {
                                    "cc_csi_pix_clk", 
                                    0x09, 
                                    0x0B, 
                                    0x0C, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_pix_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x05)
                                {
                                    "cc_csi_rdi_clk", 
                                    0x09, 
                                    0x0B, 
                                    0x0C, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_rdi_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x05)
                                {
                                    "cc_csi_pix1_clk", 
                                    0x09, 
                                    0x0B, 
                                    0x0C, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_pix1_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x05)
                                {
                                    "cc_csi_rdi1_clk", 
                                    0x09, 
                                    0x0B, 
                                    0x0C, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_rdi1_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x05)
                                {
                                    "cc_csi_rdi2_clk", 
                                    0x09, 
                                    0x0B, 
                                    0x0C, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_rdi2_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "TLMMGPIO", 
                                Package (0x06)
                                {
                                    0x05, 
                                    One, 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    0x02
                                }
                            }
                        }, 

                        Package (0x15)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "TLMMGPIO", 
                                Package (0x06)
                                {
                                    0x05, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_rdi2_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_rdi1_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_pix1_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_rdi_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_pix_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_cam0clk_po", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi0_phy_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csiphy0_timer_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi0_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    0x05
                                }
                            }, 

                            Package (0x03)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO11", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS4", 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO9", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    0x0A
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    Zero, 
                                    "/clk/bus/mmfpb", 
                                    Zero
                                }
                            }
                        }
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.CAMP", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x08)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x03)
                            {
                                "PMICVREGVOTE", 
                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS2", 
                                    0x02, 
                                    0x00149970, 
                                    0x00040B28, 
                                    0x00040B28, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO2", 
                                    One, 
                                    0x00124F80, 
                                    0x4E20, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    0x0A
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gsbi4_qup_apps_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gsbi4_qup_apps_clk", 
                                    0x03, 
                                    0x016E3600, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gsbi4_hclk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x04)
                            {
                                "TLMMGPIO", 
                                Package (0x06)
                                {
                                    0x14, 
                                    One, 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x15, 
                                    One, 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x02, 
                                    One, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }
                        }, 

                        Package (0x07)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x04)
                            {
                                "TLMMGPIO", 
                                Package (0x06)
                                {
                                    0x15, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x14, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x06)
                                {
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x03)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO2", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS2", 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    0x0A
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gsbi4_qup_apps_clk", 
                                    0x02, 
                                    0x016E3600, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gsbi4_hclk", 
                                    0x02, 
                                    0x016E3600, 
                                    0x03
                                }
                            }
                        }
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.CAMG", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x0B)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_JPEG_ENC", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x09896800, 
                                    0x09896800
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_axi_s3_fclk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_imem_axi_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ijpeg_axi_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ijpeg_axi_clk", 
                                    0x03, 
                                    0x07A12000, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ijpeg_ahb_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ijpeg_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ijpeg_clk", 
                                    0x03, 
                                    0x0E000000, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_JPEG", 
                                    One
                                }
                            }
                        }, 

                        Package (0x09)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_JPEG", 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ijpeg_clk", 
                                    0x02, 
                                    0x0E000000, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ijpeg_ahb_clk", 
                                    0x02, 
                                    0x03D09000, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ijpeg_axi_clk", 
                                    0x02, 
                                    0x07A12000, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_imem_axi_clk", 
                                    0x02, 
                                    0x0A500000, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_axi_s3_fclk", 
                                    0x02, 
                                    0x0A500000, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_JPEG_ENC", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    Zero, 
                                    Zero
                                }
                            }
                        }
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.VFE0", 
                    Package (0x0B)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x0A)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_VFE", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x77359400, 
                                    0x3B9ACA00
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0xFA00
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_clk", 
                                    0x03, 
                                    0x0FE502AB, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_ahb_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_axi_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_vfe_clk", 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_VFE", 
                                    One
                                }
                            }
                        }, 

                        Package (0x09)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_VFE", 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_csi_vfe_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_clk", 
                                    0x02, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    Zero, 
                                    "/clk/bus/mmfpb", 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_VFE", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    Zero, 
                                    Zero
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_clk", 
                                    0x03, 
                                    0x1312D000, 
                                    0x03
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_clk", 
                                    0x03, 
                                    0x0FE50FB0, 
                                    0x03
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_clk", 
                                    0x03, 
                                    0x0BEBC200, 
                                    0x03
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_clk", 
                                    0x03, 
                                    0x0927C000, 
                                    0x03
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_clk", 
                                    0x03, 
                                    0x05B8D800, 
                                    0x03
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_clk", 
                                    0x03, 
                                    0x02DC6C00, 
                                    0x03
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_clk", 
                                    0x03, 
                                    0x00D50340, 
                                    0x03
                                }
                            }
                        }
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.VPE", 
                    Package (0x07)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x06)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_VPE", 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vpe_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vpe_axi_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vpe_ahb_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x06)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vpe_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vpe_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vpe_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_VPE", 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vpe_clk", 
                                    0x03, 
                                    0x03A98000, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_VPE", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x02649000, 
                                    0x02649000
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vpe_clk", 
                                    0x03, 
                                    0x0927C000, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_VPE", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0711D800, 
                                    0x0711D800
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vpe_clk", 
                                    0x03, 
                                    0x09896800, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_VPE", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x1026CC00, 
                                    0x1026CC00
                                }
                            }
                        }
                    }
                }, 

                Package (0x05)
                {
                    "DEVICE", 
                    "\\_SB.TCH1", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x02)
                        {
                            "FSTATE", 
                            One
                        }
                    }, 

                    Package (0x04)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x03)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x0B, 
                                One, 
                                Zero, 
                                Zero, 
                                0x03, 
                                Zero
                            }, 

                            Package (0x06)
                            {
                                0x34, 
                                One, 
                                Zero, 
                                One, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x04)
                        {
                            "PMICVREGVOTE", 
                            Package (0x0C)
                            {
                                "PM_VREG_RESOURCE_ID_SMPS4", 
                                0x02, 
                                0x002191C0, 
                                0x0016E360, 
                                0x0016E360, 
                                0x02, 
                                Zero, 
                                Zero, 
                                One, 
                                Zero, 
                                0x06, 
                                Zero
                            }, 

                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO17", 
                                One, 
                                0x002AB980, 
                                0x000249F0, 
                                0x000249F0, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }, 

                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO11", 
                                One, 
                                0x001B7740, 
                                0x7530, 
                                0x7530, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }
                    }, 

                    Package (0x03)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO17", 
                                One, 
                                0x002AB980, 
                                0x1388, 
                                0x1388, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }
                    }
                }, 

                Package (0x08)
                {
                    "DEVICE", 
                    0x02, 
                    "\\_SB.UFN1", 
                    Package (0x09)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x03)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/dfab", 
                                    0xFFFFFFFF
                                }
                            }
                        }, 

                        Package (0x06)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/dfab", 
                                    0xFFFFFFFF
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_usb_hs1_hclk", 
                                    One, 
                                    0x03938700, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    0x3C000000, 
                                    0x03C00000
                                }
                            }, 

                            Package (0x05)
                            {
                                "PMICVREGVOTE", 
                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_CLOCK", 
                                    0x07, 
                                    One
                                }, 

                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_VDDCX_CORNER", 
                                    0x08, 
                                    0x02
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO3", 
                                    One, 
                                    0x002EEBB8, 
                                    0xC350, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO4", 
                                    One, 
                                    0x001B7740, 
                                    0x9470, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "PSTATE", 
                            One
                        }, 

                        Package (0x06)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    Zero, 
                                    "/clk/bus/dfab", 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_usb_hs1_hclk", 
                                    0x02, 
                                    0x03938700, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x04)
                            {
                                "PMICVREGVOTE", 
                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_CLOCK", 
                                    0x07, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO3", 
                                    One, 
                                    0x002EEBB8, 
                                    0x0FA0, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO4", 
                                    One, 
                                    0x001B7740, 
                                    0x03E8, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x06)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    Zero, 
                                    "/clk/bus/dfab", 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_usb_hs1_hclk", 
                                    0x02, 
                                    0x03938700, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x04)
                            {
                                "PMICVREGVOTE", 
                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_CLOCK", 
                                    0x07, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO3", 
                                    One, 
                                    0x002EEBB8, 
                                    0x0FA0, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO4", 
                                    One, 
                                    0x001B7740, 
                                    0x03E8, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x06)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    Zero, 
                                    "/clk/bus/dfab", 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_usb_hs1_hclk", 
                                    0x02, 
                                    0x03938700, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x05)
                            {
                                "PMICVREGVOTE", 
                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_CLOCK", 
                                    0x07, 
                                    One
                                }, 

                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_VDDCX_CORNER", 
                                    0x08, 
                                    0x02
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO3", 
                                    One, 
                                    0x002EEBB8, 
                                    0x0FA0, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO4", 
                                    One, 
                                    0x001B7740, 
                                    0x03E8, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x06)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    Zero, 
                                    "/clk/bus/dfab", 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_usb_hs1_hclk", 
                                    0x02, 
                                    0x03938700, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x05)
                            {
                                "PMICVREGVOTE", 
                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_CLOCK", 
                                    0x07, 
                                    Zero
                                }, 

                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_VDDCX_CORNER", 
                                    0x08, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO3", 
                                    One, 
                                    0x002EEBB8, 
                                    0x0FA0, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO4", 
                                    One, 
                                    0x001B7740, 
                                    0x03E8, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }
                        }
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        Zero
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        One
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x02
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x03
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.ACHW", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x06)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "lcc_cdc_i2s_spkr_osr_clk", 
                                    One, 
                                    0x00BB87D0, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "lcc_cdc_i2s_spkr_osr_clk", 
                                    0x03, 
                                    0x00BB87D0, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "TLMMGPIO", 
                                Package (0x06)
                                {
                                    0x3B, 
                                    One, 
                                    One, 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x04)
                            {
                                "PMICVREGVOTE", 
                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS4", 
                                    0x02, 
                                    0x002191C0, 
                                    0x00086470, 
                                    0x00086470, 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO20", 
                                    One, 
                                    0x0012B128, 
                                    0x2710, 
                                    0x2710, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO11", 
                                    One, 
                                    0x001B7740, 
                                    0x2710, 
                                    0x2710, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x05)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "lcc_cdc_i2s_spkr_osr_clk", 
                                    0x02, 
                                    0x00BB87D0, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "TLMMGPIO", 
                                Package (0x06)
                                {
                                    0x3B, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }
                            }, 

                            Package (0x04)
                            {
                                "PMICVREGVOTE", 
                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS4", 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO20", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO11", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero
                                }
                            }
                        }
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.MBHC", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x06)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "lcc_cdc_i2s_spkr_osr_clk", 
                                    One, 
                                    0x00BB87D0, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "lcc_cdc_i2s_spkr_osr_clk", 
                                    0x03, 
                                    0x00BB87D0, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "TLMMGPIO", 
                                Package (0x06)
                                {
                                    0x3B, 
                                    One, 
                                    One, 
                                    One, 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x03)
                            {
                                "PMICVREGVOTE", 
                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS4", 
                                    0x02, 
                                    0x002191C0, 
                                    0x00086470, 
                                    0x00086470, 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO20", 
                                    One, 
                                    0x0012B128, 
                                    0x2710, 
                                    0x2710, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "lcc_cdc_i2s_spkr_osr_clk", 
                                    0x02, 
                                    0x00BB87D0, 
                                    0x03
                                }
                            }
                        }
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.MBGP", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x03)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x03)
                            {
                                "PMICVREGVOTE", 
                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS2", 
                                    0x02, 
                                    0x00155CC0, 
                                    0x00086470, 
                                    0x00086470, 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO20", 
                                    One, 
                                    0x0012B128, 
                                    0x2710, 
                                    0x2710, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x03)
                            {
                                "PMICVREGVOTE", 
                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS2", 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO20", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero
                                }
                            }
                        }
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.ADSP", 
                    Package (0x08)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x02)
                        {
                            "FSTATE", 
                            One
                        }, 

                        Package (0x0A)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    0x3C000000, 
                                    0x03C00000
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ADM0_PORT1", 
                                    "ICBID_SLAVE_SPS", 
                                    0x3C000000, 
                                    0x03C00000
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/dfab", 
                                    0xFFFFFFFF
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_aclk", 
                                    One, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_pbus_hclk", 
                                    One, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS3", 
                                    0x02, 
                                    0x00118C30, 
                                    0x00043620, 
                                    0x00043620, 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "DELAY", 
                                Package (0x01)
                                {
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO27", 
                                    One, 
                                    0x00100590, 
                                    0x00043620, 
                                    0x00043620, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x07)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    0x1F40, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ADM0_PORT1", 
                                    "ICBID_SLAVE_SPS", 
                                    0x1F40, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    Zero, 
                                    "/clk/bus/dfab", 
                                    0xFFFFFFFF
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_aclk", 
                                    0x02, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_pbus_hclk", 
                                    0x02, 
                                    Zero, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "DSTATE", 
                            Zero
                        }, 

                        Package (0x02)
                        {
                            "DSTATE", 
                            0x03
                        }
                    }
                }, 

                Package (0x05)
                {
                    "DEVICE", 
                    "\\_SB.RIVA", 
                    Package (0x05)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x09)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    0x3C000000, 
                                    0x03C00000
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ADM0_PORT1", 
                                    "ICBID_SLAVE_SPS", 
                                    0x3C000000, 
                                    0x03C00000
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/dfab", 
                                    0xFFFFFFFF
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_aclk", 
                                    One, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_pbus_hclk", 
                                    One, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x07)
                            {
                                "PMICVREGVOTE", 
                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_CLOCK", 
                                    0x07, 
                                    One
                                }, 

                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_VDDCX_CORNER", 
                                    0x08, 
                                    0x02
                                }, 

                                Package (0x08)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_BUFFERS", 
                                    0x06, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    0x02, 
                                    0x02
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO4", 
                                    One, 
                                    0x001B7740, 
                                    0x03E8, 
                                    0x03E8, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO1", 
                                    One, 
                                    0x0013D620, 
                                    0x0003F7A0, 
                                    0x0003F7A0, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO10", 
                                    One, 
                                    0x002C4020, 
                                    0x0007DBB8, 
                                    0x0007DBB8, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x06)
                            {
                                "TLMMGPIO", 
                                Package (0x06)
                                {
                                    0x54, 
                                    One, 
                                    One, 
                                    One, 
                                    One, 
                                    One
                                }, 

                                Package (0x06)
                                {
                                    0x55, 
                                    One, 
                                    One, 
                                    One, 
                                    0x03, 
                                    One
                                }, 

                                Package (0x06)
                                {
                                    0x56, 
                                    One, 
                                    One, 
                                    One, 
                                    0x03, 
                                    One
                                }, 

                                Package (0x06)
                                {
                                    0x57, 
                                    One, 
                                    One, 
                                    One, 
                                    0x03, 
                                    One
                                }, 

                                Package (0x06)
                                {
                                    0x58, 
                                    One, 
                                    One, 
                                    One, 
                                    0x03, 
                                    One
                                }
                            }
                        }, 

                        Package (0x08)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    0x1F40, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ADM0_PORT1", 
                                    "ICBID_SLAVE_SPS", 
                                    0x1F40, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    Zero, 
                                    "/clk/bus/dfab", 
                                    0xFFFFFFFF
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_aclk", 
                                    0x02, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_pbus_hclk", 
                                    0x02, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x07)
                            {
                                "PMICVREGVOTE", 
                                Package (0x08)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_BUFFERS", 
                                    0x06, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero
                                }, 

                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_CLOCK", 
                                    0x07, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO10", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO1", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO4", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_VDDCX_CORNER", 
                                    0x08, 
                                    Zero
                                }
                            }
                        }
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        Zero
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x03
                    }
                }, 

                Package (0x05)
                {
                    "DEVICE", 
                    "\\_SB.AMSS", 
                    Package (0x06)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x02)
                        {
                            "FSTATE", 
                            One
                        }, 

                        Package (0x0A)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    0x3C000000, 
                                    0x03C00000
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ADM0_PORT1", 
                                    "ICBID_SLAVE_SPS", 
                                    0x3C000000, 
                                    0x03C00000
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/dfab", 
                                    0xFFFFFFFF
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_aclk", 
                                    One, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_pbus_hclk", 
                                    One, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x05)
                            {
                                "PMICVREGVOTE", 
                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_CLOCK", 
                                    0x07, 
                                    One
                                }, 

                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS3", 
                                    0x02, 
                                    0x00118C30, 
                                    0x000BCF70, 
                                    0x000BCF70, 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }, 

                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS2", 
                                    0x02, 
                                    0x00155CC0, 
                                    0x000493E0, 
                                    0x000493E0, 
                                    0x02, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO16", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO16", 
                                    One, 
                                    0x00100590, 
                                    0x0007EB58, 
                                    0x0007EB58, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x03)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO19", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }, 

                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO19", 
                                    One, 
                                    0x00100590, 
                                    0x0007EB58, 
                                    0x0007EB58, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x08)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    0x1F40, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ADM0_PORT1", 
                                    "ICBID_SLAVE_SPS", 
                                    0x1F40, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    Zero, 
                                    "/clk/bus/dfab", 
                                    0xFFFFFFFF
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_aclk", 
                                    0x02, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_pbus_hclk", 
                                    0x02, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x03)
                                {
                                    "PM_VREG_RESOURCE_ID_CXO_CLOCK", 
                                    0x07, 
                                    Zero
                                }
                            }
                        }
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        Zero
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x03
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.QQCE", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x07)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_CRYPTO", 
                                    "ICBID_SLAVE_EBI1", 
                                    0x3C000000, 
                                    0x05000000
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ce1_hclk", 
                                    One, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ce1_core_clk", 
                                    One, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_aclk", 
                                    One, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_pbus_hclk", 
                                    One, 
                                    Zero, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x07)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_CRYPTO", 
                                    "ICBID_SLAVE_EBI1", 
                                    0x1F40, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ce1_hclk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ce1_core_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_aclk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_pbus_hclk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }
                        }
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.QCE2", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x07)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    0x3C000000, 
                                    0x03C00000
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ADM0_PORT1", 
                                    "ICBID_SLAVE_SPS", 
                                    0x3C000000, 
                                    0x03C00000
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/dfab", 
                                    0xFFFFFFFF
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_aclk", 
                                    One, 
                                    Zero, 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_pbus_hclk", 
                                    One, 
                                    Zero, 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x07)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_SPS", 
                                    "ICBID_SLAVE_EBI1", 
                                    0x1F40, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ADM0_PORT1", 
                                    "ICBID_SLAVE_SPS", 
                                    0x1F40, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    Zero, 
                                    "/clk/bus/dfab", 
                                    0xFFFFFFFF
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_aclk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_adm0_pbus_hclk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }
                        }
                    }
                }, 

                Package (0x07)
                {
                    "DEVICE", 
                    "\\_SB.SLM1", 
                    Package (0x03)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "lcc_lpass_sb_ref_clk", 
                                0x03, 
                                0x01770000, 
                                0x04
                            }
                        }, 

                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "lcc_lpass_sb_ref_clk", 
                                One, 
                                0x01770000, 
                                0x04
                            }
                        }, 

                        Package (0x03)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x3C, 
                                One, 
                                One, 
                                Zero, 
                                0x02, 
                                0x03
                            }, 

                            Package (0x06)
                            {
                                0x3D, 
                                One, 
                                One, 
                                Zero, 
                                0x02, 
                                0x03
                            }
                        }
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        One
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x02
                    }, 

                    Package (0x04)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "CLOCK", 
                            Package (0x04)
                            {
                                "lcc_lpass_sb_ref_clk", 
                                0x02, 
                                0x01770000, 
                                0x04
                            }
                        }, 

                        Package (0x03)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x3C, 
                                One, 
                                One, 
                                Zero, 
                                0x02, 
                                Zero
                            }, 

                            Package (0x06)
                            {
                                0x3D, 
                                One, 
                                One, 
                                Zero, 
                                0x02, 
                                Zero
                            }
                        }
                    }
                }, 

                Package (0x03)
                {
                    "DEVICE", 
                    "\\_SB.SMMU", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x0A)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_axi_clk", 
                                    One, 
                                    Zero, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_clk", 
                                    One, 
                                    0x09D5B340, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_A_clk", 
                                    One, 
                                    0x09D5B340, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_B_clk", 
                                    One, 
                                    0x09D5B340, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ijpeg_axi_clk", 
                                    One, 
                                    0x07A12000, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vpe_axi_clk", 
                                    One, 
                                    0x09D5B340, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_axi_clk", 
                                    One, 
                                    0x09D5B340, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_axi_clk", 
                                    One, 
                                    0x09D5B340, 
                                    0x03
                                }
                            }
                        }, 

                        Package (0x0A)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_axi_clk", 
                                    0x02, 
                                    0x0FDAD680, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_clk", 
                                    0x02, 
                                    0x09D5B340, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_A_clk", 
                                    0x02, 
                                    0x09D5B340, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_B_clk", 
                                    0x02, 
                                    0x09D5B340, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_ijpeg_axi_clk", 
                                    0x02, 
                                    0x07A12000, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vpe_axi_clk", 
                                    0x02, 
                                    0x09D5B340, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vfe_axi_clk", 
                                    0x02, 
                                    0x09D5B340, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_axi_clk", 
                                    0x02, 
                                    0x09D5B340, 
                                    0x03
                                }
                            }
                        }
                    }
                }, 

                Package (0x1C)
                {
                    "DEVICE", 
                    "\\_SB.GPU0", 
                    Package (0x06)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x06)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gmem_axi_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_ahb_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_axi_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x06)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gmem_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x06)
                        {
                            "FSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gmem_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_FSTATE", 
                            0x02
                        }
                    }, 

                    Package (0x06)
                    {
                        "COMPONENT", 
                        One, 
                        Package (0x06)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_ahb_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_axi_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_lut_mdp_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x06)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_lut_mdp_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x06)
                        {
                            "FSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_lut_mdp_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_FSTATE", 
                            Zero
                        }
                    }, 

                    Package (0x06)
                    {
                        "COMPONENT", 
                        0x02, 
                        Package (0x05)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_ahb_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_axi_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x05)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x05)
                        {
                            "FSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_FSTATE", 
                            0x02
                        }
                    }, 

                    Package (0x06)
                    {
                        "COMPONENT", 
                        0x03, 
                        Package (0x08)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_pclk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_ahb_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_A_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_B_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x08)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_B_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_A_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_pclk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x08)
                        {
                            "FSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_B_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_A_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_pclk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_FSTATE", 
                            0x02
                        }
                    }, 

                    Package (0x05)
                    {
                        "COMPONENT", 
                        0x04, 
                        Package (0x14)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS4", 
                                    0x02, 
                                    0x001B7740, 
                                    0x9088, 
                                    0x9088, 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x0C)
                                {
                                    "PM_VREG_RESOURCE_ID_SMPS2", 
                                    0x02, 
                                    0x00155CC0, 
                                    0x07D0, 
                                    0x07D0, 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero, 
                                    0x06, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO8", 
                                    One, 
                                    0x002AB980, 
                                    0x0001ADB0, 
                                    0x0001ADB0, 
                                    0x03, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO23", 
                                    One, 
                                    0x001B7740, 
                                    0x07D0, 
                                    0x07D0, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO2", 
                                    One, 
                                    0x00124F80, 
                                    0x4E20, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_ahb_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_axi_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_lut_mdp_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_vsync_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_m_ahb_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_s_ahb_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_byte_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_esc_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_pixel_clk", 
                                    One, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_esc_clk", 
                                    0x03, 
                                    0x00CDFE60, 
                                    0x03
                                }
                            }, 

                            Package (0x02)
                            {
                                "TLMMGPIO", 
                                Package (0x06)
                                {
                                    Zero, 
                                    One, 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero
                                }
                            }
                        }, 

                        Package (0x10)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_pixel_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_esc_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_byte_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_s_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_m_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_vsync_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_axi_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_lut_mdp_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_ahb_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x02, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO2", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "PMICVREGVOTE", 
                                Package (0x09)
                                {
                                    "PM_VREG_RESOURCE_ID_LDO8", 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "TLMMGPIO", 
                                Package (0x06)
                                {
                                    Zero, 
                                    One, 
                                    Zero, 
                                    Zero, 
                                    One, 
                                    Zero
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_FSTATE", 
                            Zero
                        }
                    }, 

                    Package (0x04)
                    {
                        "COMPONENT", 
                        0x05, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x02)
                        {
                            "FSTATE", 
                            One
                        }
                    }, 

                    Package (0x06)
                    {
                        "COMPONENT", 
                        0x06, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_GRP3D", 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_GRP3D", 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            One
                        }
                    }, 

                    Package (0x06)
                    {
                        "COMPONENT", 
                        0x07, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x07)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_MDP", 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_vsync_clk", 
                                    0x0B, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_clk", 
                                    0x0B, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_m_ahb_clk", 
                                    0x0B, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_s_ahb_clk", 
                                    0x0B, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x07)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_s_ahb_clk", 
                                    0x0A, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_m_ahb_clk", 
                                    0x0A, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_dsi1_clk", 
                                    0x0A, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_vsync_clk", 
                                    0x0A, 
                                    Zero, 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_MDP", 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            Zero
                        }
                    }, 

                    Package (0x06)
                    {
                        "COMPONENT", 
                        0x08, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_ROT", 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_ROT", 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            One
                        }
                    }, 

                    Package (0x06)
                    {
                        "COMPONENT", 
                        0x09, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_VDC", 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_VDC", 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            One
                        }
                    }, 

                    Package (0x06)
                    {
                        "COMPONENT", 
                        0x0A, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x05, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "PSTATE", 
                            One
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            One
                        }
                    }, 

                    Package (0x06)
                    {
                        "COMPONENT", 
                        0x0B, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x05, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "PSTATE", 
                            One
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            One
                        }
                    }, 

                    Package (0x06)
                    {
                        "COMPONENT", 
                        0x0C, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x05, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "PSTATE", 
                            One
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            One
                        }
                    }, 

                    Package (0x06)
                    {
                        "COMPONENT", 
                        0x0D, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_clk", 
                                    0x05, 
                                    Zero, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "PSTATE", 
                            One
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            One
                        }
                    }, 

                    Package (0x11)
                    {
                        "COMPONENT", 
                        0x0E, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x1DCD6500, 
                                    0x03
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x17D78400, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x1312D000, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x0FE50010, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x0D9FB925, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x0BEBC200, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x0B71B000, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x07, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x0A98AC72, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x08, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x09896800, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x09, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x08AB795F, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0A, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x07A12000, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0B, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x05B8D800, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0C, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_gfx3d_clk", 
                                    0x03, 
                                    0x0493E000, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            0x04
                        }
                    }, 

                    Package (0x03)
                    {
                        "COMPONENT", 
                        0x0F, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }
                    }, 

                    Package (0x12)
                    {
                        "COMPONENT", 
                        0x10, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xFFFFFFFF, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x00012C00
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xD3B73800, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x00012C00
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xBEBC2000, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x00012C00
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x9EC96A00, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x00012C00
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x7F047AC0, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x00012C00
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x5F5E1000, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x9600
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x5B8D8000, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x9600
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x07, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x3F9920C0, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x9600
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x08, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x3D090000, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x9600
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x09, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x2FAF0800, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x9600
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x0A, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x2625A000, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x9600
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x0B, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x1FCA0FC0, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x9600
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x0C, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x17D78400, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x9600
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x0D, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0CDFE600, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    One, 
                                    "/clk/bus/mmfpb", 
                                    0x9600
                                }
                            }
                        }, 

                        Package (0x04)
                        {
                            "PSTATE", 
                            0x0E, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_GFX3D_C0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    Zero, 
                                    Zero
                                }
                            }, 

                            Package (0x02)
                            {
                                "REQUIRED_RESOURCE", 
                                Package (0x03)
                                {
                                    Zero, 
                                    "/clk/bus/mmfpb", 
                                    Zero
                                }
                            }
                        }
                    }, 

                    Package (0x11)
                    {
                        "COMPONENT", 
                        0x11, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x0BEBC200, 
                                    0x03
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x0A98AC72, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x09896800, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x07A12000, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x05B8D800, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x05161555, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x0493E000, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x07, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x0385713B, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x08, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x0249F000, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x09, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x0214ABA3, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0A, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x01C2B89E, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0B, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x00D1436E, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0C, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_mdp_clk", 
                                    0x03, 
                                    0x00927C00, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            One
                        }
                    }, 

                    Package (0x25)
                    {
                        "COMPONENT", 
                        0x12, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x66104C79, 
                                    0x5CC8FFB4
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x5CC8FFB4, 
                                    0x5459A2A4
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x5459A2A4, 
                                    0x4CAE93DA
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x4CAE93DA, 
                                    0x45B5FAC7
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x45B5FAC7, 
                                    0x3F5F9E29
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x3F5F9E29, 
                                    0x399CBE54
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x399CBE54, 
                                    0x345FF2D8
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x07, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x345FF2D8, 
                                    0x2F9D0B50
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x08, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x2F9D0B50, 
                                    0x2B48F303
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x09, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x2B48F303, 
                                    0x2759971A
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0A, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x2759971A, 
                                    0x23C5CF2F
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0B, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x23C5CF2F, 
                                    0x208547FC
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0C, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x208547FC, 
                                    0x1D906FFC
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0D, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x1D906FFC, 
                                    0x1AE065CE
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0E, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x1AE065CE, 
                                    0x186EE830
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0F, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x186EE830, 
                                    0x16364771
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x10, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x16364771, 
                                    0x14315838
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x11, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x14315838, 
                                    0x125B6779
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x12, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x125B6779, 
                                    0x10B02F85
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x13, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x10B02F85, 
                                    0x0F2BCE1C
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x14, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0F2BCE1C, 
                                    0x0DCABB5F
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x15, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0DCABB5F, 
                                    0x0C89C19D
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x16, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0C89C19D, 
                                    0x0B65F5D4
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x17, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0B65F5D4, 
                                    0x0A5CB0EF
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x18, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0A5CB0EF, 
                                    0x096B8994
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x19, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x096B8994, 
                                    0x08904E86
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x1A, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x08904E86, 
                                    0x07C90191
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x1B, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x07C90191, 
                                    0x0713D2E1
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x1C, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0713D2E1, 
                                    0x066F1CCD
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x1D, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x066F1CCD, 
                                    0x05D96000
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x1E, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x05D96000, 
                                    0x05514000
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x1F, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x05514000, 
                                    0x04D58000
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x20, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    Zero, 
                                    Zero
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            0x0B
                        }
                    }, 

                    Package (0x12)
                    {
                        "COMPONENT", 
                        0x13, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xEA9A9800, 
                                    0xEA9A9800
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xD3B73800, 
                                    0xD3B73800
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xBEBC2000, 
                                    0xBEBC2000
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x9EC96A00, 
                                    0x9EC96A00
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x7F281FC0, 
                                    0x7F281FC0
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x5F5E1000, 
                                    0x5F5E1000
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x5B8D8000, 
                                    0x5B8D8000
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x07, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x3F940040, 
                                    0x3F940040
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x08, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x2FAF0800, 
                                    0x2FAF0800
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x09, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x2625A000, 
                                    0x2625A000
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0A, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x1FCA0FC0, 
                                    0x1FCA0FC0
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0B, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x17D78400, 
                                    0x17D78400
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0C, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0CDFE600, 
                                    0x0CDFE600
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0D, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x066FF300, 
                                    0x066FF300
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0E, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_MDP_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    Zero, 
                                    Zero
                                }
                            }
                        }
                    }, 

                    Package (0x12)
                    {
                        "COMPONENT", 
                        0x14, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x0BEBC200, 
                                    0x03
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x09896800, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x07F28155, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x06CFDC92, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x05F5E100, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x05B8D800, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x0493E000, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x07, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x03D09000, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x08, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x03450DB7, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x09, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x02DC6C00, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0A, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x0249F000, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0B, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x01E84800, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0C, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x01C2B89E, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0D, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_rot_clk", 
                                    0x03, 
                                    0x019BFCC0, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            0x0D
                        }
                    }, 

                    Package (0x12)
                    {
                        "COMPONENT", 
                        0x15, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xEA9A9800, 
                                    0xEA9A9800
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xD3B73800, 
                                    0xD3B73800
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xBEBC2000, 
                                    0xBEBC2000
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x9EC96A00, 
                                    0x9EC96A00
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x7F281FC0, 
                                    0x7F281FC0
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x5F5E1000, 
                                    0x5F5E1000
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x5B8D8000, 
                                    0x5B8D8000
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x07, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x3F940040, 
                                    0x3F940040
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x08, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x2FAF0800, 
                                    0x2FAF0800
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x09, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x2625A000, 
                                    0x2625A000
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0A, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x1FCA0FC0, 
                                    0x1FCA0FC0
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0B, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x17D78400, 
                                    0x17D78400
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0C, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0CDFE600, 
                                    0x0CDFE600
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0D, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x066FF300, 
                                    0x066FF300
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0E, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_ROTATOR", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    Zero, 
                                    Zero
                                }
                            }
                        }
                    }, 

                    Package (0x0B)
                    {
                        "COMPONENT", 
                        0x16, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_clk", 
                                    0x03, 
                                    0x0BEBC200, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_clk", 
                                    0x03, 
                                    0x07F28155, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_clk", 
                                    0x03, 
                                    0x05B8D800, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_clk", 
                                    0x03, 
                                    0x03450DB7, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_clk", 
                                    0x03, 
                                    0x02DC6C00, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_clk", 
                                    0x03, 
                                    0x01E84800, 
                                    One
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "CLOCK", 
                                Package (0x04)
                                {
                                    "cc_vcodec_clk", 
                                    0x03, 
                                    0x019BFCC0, 
                                    One
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_PSTATE", 
                            0x06
                        }
                    }, 

                    Package (0x13)
                    {
                        "COMPONENT", 
                        0x17, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xF163E600, 
                                    0x1E2C7CC0
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xDEBDF900, 
                                    0x1BD7BF20
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xCC180C00, 
                                    0x19830180
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xBB82A300, 
                                    0x17705460
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0xAAED3A00, 
                                    0x155DA740
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x9A57D100, 
                                    0x134AFA20
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x89C26800, 
                                    0x11384D00
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x07, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x792CFF00, 
                                    0x0F259FE0
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x08, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x696B8C80, 
                                    0x0D2D7190
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x09, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x59AA1A00, 
                                    0x0B354340
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0A, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x48885C00, 
                                    0x09110B80
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0B, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x37669E00, 
                                    0x06ECD3C0
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0C, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x2A877380, 
                                    0x0550EE70
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0D, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x1DA84900, 
                                    0x03B50920
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0E, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x12A5ED00, 
                                    0x0254BDA0
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0F, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT0", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    Zero, 
                                    Zero
                                }
                            }
                        }
                    }, 

                    Package (0x16)
                    {
                        "COMPONENT", 
                        0x18, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x8E3334A0, 
                                    0x238CCD28
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x834E24A0, 
                                    0x20D38928
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x02, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x786914A0, 
                                    0x1E1A4528
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x03, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x6E52E5D0, 
                                    0x1B94B974
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x04, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x64447228, 
                                    0x19111C8A
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x05, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x5A35FE80, 
                                    0x168D7FA0
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x06, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x57259200, 
                                    0x15C96480
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x07, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x4E85FBA8, 
                                    0x13A17EEA
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x08, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x45E66550, 
                                    0x11799954
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x09, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x3D46CEF8, 
                                    0x0F51B3BE
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0A, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x34A738A0, 
                                    0x0D29CE28
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0B, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x2D79B5D0, 
                                    0x0B5E6D74
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0C, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x264C3300, 
                                    0x09930CC0
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0D, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x2330CA00, 
                                    0x08CC3280
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0E, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x18F3BE80, 
                                    0x063CEFA0
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x0F, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0EB6B300, 
                                    0x03ADACC0
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x10, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0CB3F400, 
                                    0x032CFD00
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x11, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    0x0AE51000, 
                                    0x02B94400
                                }
                            }
                        }, 

                        Package (0x03)
                        {
                            "PSTATE", 
                            0x12, 
                            Package (0x02)
                            {
                                "BUSARB", 
                                Package (0x05)
                                {
                                    0x03, 
                                    "ICBID_MASTER_HD_CODEC_PORT1", 
                                    "ICBID_SLAVE_EBI1_CH0", 
                                    Zero, 
                                    Zero
                                }
                            }
                        }
                    }, 

                    Package (0x05)
                    {
                        "COMPONENT", 
                        0x19, 
                        Package (0x05)
                        {
                            "FSTATE", 
                            Zero, 
                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_GRP3D", 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_ROT", 
                                    One
                                }
                            }, 

                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_VDC", 
                                    One
                                }
                            }
                        }, 

                        Package (0x05)
                        {
                            "FSTATE", 
                            One, 
                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_GRP3D", 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_ROT", 
                                    0x02
                                }
                            }, 

                            Package (0x02)
                            {
                                "FOOTSWITCH", 
                                Package (0x02)
                                {
                                    "VDD_VDC", 
                                    0x02
                                }
                            }
                        }, 

                        Package (0x02)
                        {
                            "STOP_FSTATE", 
                            One
                        }
                    }
                }, 

                Package (0x06)
                {
                    "DEVICE", 
                    0x81, 
                    "\\_SB.GIO0", 
                    Package (0x03)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }
                    }, 

                    Package (0x03)
                    {
                        "COMPONENT", 
                        One, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }
                    }, 

                    Package (0x03)
                    {
                        "COMPONENT", 
                        0x02, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }
                    }
                }
            })
            Name (ECFG, Package (0x06)
            {
                Package (0x05)
                {
                    "DEVICE", 
                    "\\_SB.ACC1", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x02)
                        {
                            "FSTATE", 
                            One
                        }
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x03)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x2E, 
                                One, 
                                Zero, 
                                Zero, 
                                One, 
                                Zero
                            }, 

                            Package (0x06)
                            {
                                0x43, 
                                One, 
                                Zero, 
                                Zero, 
                                One, 
                                Zero
                            }
                        }, 

                        Package (0x02)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO17", 
                                One, 
                                0x002AB980, 
                                0x03E8, 
                                0x03E8, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "DELAY", 
                            Package (0x01)
                            {
                                0x32
                            }
                        }
                    }, 

                    Package (0x03)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO17", 
                                One, 
                                0x002AB980, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }
                    }
                }, 

                Package (0x07)
                {
                    "DEVICE", 
                    "\\_SB.ALS1", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x02)
                        {
                            "FSTATE", 
                            One
                        }
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x02)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x31, 
                                One, 
                                Zero, 
                                Zero, 
                                0x03, 
                                Zero
                            }
                        }, 

                        Package (0x02)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO17", 
                                One, 
                                0x002AB980, 
                                0x03E8, 
                                0x03E8, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "DELAY", 
                            Package (0x01)
                            {
                                0x05
                            }
                        }
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        One
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x02
                    }, 

                    Package (0x03)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO17", 
                                One, 
                                0x002AB980, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }
                    }
                }, 

                Package (0x07)
                {
                    "DEVICE", 
                    "\\_SB.PRX1", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x02)
                        {
                            "FSTATE", 
                            One
                        }
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x02)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x31, 
                                One, 
                                Zero, 
                                Zero, 
                                0x03, 
                                Zero
                            }
                        }, 

                        Package (0x02)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO17", 
                                One, 
                                0x002AB980, 
                                0x03E8, 
                                0x03E8, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "DELAY", 
                            Package (0x01)
                            {
                                0x05
                            }
                        }
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        One
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x02
                    }, 

                    Package (0x03)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO17", 
                                One, 
                                0x002AB980, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }
                    }
                }, 

                Package (0x07)
                {
                    "DEVICE", 
                    "\\_SB.ALS2", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x02)
                        {
                            "FSTATE", 
                            One
                        }
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x02)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x31, 
                                One, 
                                Zero, 
                                Zero, 
                                0x03, 
                                Zero
                            }
                        }, 

                        Package (0x02)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO17", 
                                One, 
                                0x002AB980, 
                                0x03E8, 
                                0x03E8, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "DELAY", 
                            Package (0x01)
                            {
                                0x0B
                            }
                        }
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        One
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x02
                    }, 

                    Package (0x03)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO17", 
                                One, 
                                0x002AB980, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }
                    }
                }, 

                Package (0x07)
                {
                    "DEVICE", 
                    "\\_SB.PRX2", 
                    Package (0x04)
                    {
                        "COMPONENT", 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE", 
                            Zero
                        }, 

                        Package (0x02)
                        {
                            "FSTATE", 
                            One
                        }
                    }, 

                    Package (0x05)
                    {
                        "DSTATE", 
                        Zero, 
                        Package (0x02)
                        {
                            "TLMMGPIO", 
                            Package (0x06)
                            {
                                0x31, 
                                One, 
                                Zero, 
                                Zero, 
                                0x03, 
                                Zero
                            }
                        }, 

                        Package (0x02)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO17", 
                                One, 
                                0x002AB980, 
                                0x03E8, 
                                0x03E8, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x02)
                        {
                            "DELAY", 
                            Package (0x01)
                            {
                                0x0B
                            }
                        }
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        One
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x02
                    }, 

                    Package (0x03)
                    {
                        "DSTATE", 
                        0x03, 
                        Package (0x02)
                        {
                            "PMICVREGVOTE", 
                            Package (0x09)
                            {
                                "PM_VREG_RESOURCE_ID_LDO17", 
                                One, 
                                0x002AB980, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                Zero, 
                                One
                            }
                        }
                    }
                }, 

                Package (0x04)
                {
                    "DEVICE", 
                    "\\_SB.NRSD", 
                    Package (0x02)
                    {
                        "DSTATE", 
                        Zero
                    }, 

                    Package (0x02)
                    {
                        "DSTATE", 
                        0x03
                    }
                }
            })
            Name (CCFG, Package (0x05)
            {
                Package (0x02)
                {
                    "ACPI\\Q_-_ARM_Family_7_Model_2D_Revision___2\\0", 
                    0x10
                }, 

                Package (0x02)
                {
                    "ACPI\\Q_-_ARM_Family_7_Model_2D_Revision___2\\1", 
                    0x11
                }, 

                Package (0x02)
                {
                    "\\_SB.CPU0", 
                    0x10
                }, 

                Package (0x02)
                {
                    "\\_SB.CPU1", 
                    0x11
                }, 

                Package (0x02)
                {
                    "VEN_QCOM&DEV_1001&SUBDEV_0000&REV_0000&UID_00000001", 
                    One
                }
            })
            Method (PGDC, 0, NotSerialized)
            {
                Return (DCFG) /* \_SB_.PEP0.DCFG */
            }

            Method (PGCC, 0, NotSerialized)
            {
                Return (CCFG) /* \_SB_.PEP0.CCFG */
            }

            Method (PGEC, 0, NotSerialized)
            {
                Return (ECFG) /* \_SB_.PEP0.ECFG */
            }

            Name (DCVS, Package (0x03)
            {
                Package (0x02)
                {
                    "CPU0", 
                    Zero
                }, 

                Package (0x02)
                {
                    "CPU1", 
                    Zero
                }, 

                Package (0x02)
                {
                    "L2", 
                    Zero
                }
            })
            Method (PGDS, 0, NotSerialized)
            {
                Return (DCVS) /* \_SB_.PEP0.DCVS */
            }

            Name (FPDP, Package (0x00){})
            Method (FPMD, 0, NotSerialized)
            {
                Return (FPDP) /* \_SB_.PEP0.FPDP */
            }

            Name (PPPC, Package (0x02)
            {
                Package (0x02)
                {
                    "EnablePCE", 
                    One
                }, 

                Package (0x02)
                {
                    "EnableAVS", 
                    Zero
                }
            })
            Method (PGPC, 0, NotSerialized)
            {
                Return (PPPC) /* \_SB_.PEP0.PPPC */
            }
        }

        Device (PRXY)
        {
            Name (_HID, "QCOM0812")  // _HID: Hardware ID
            Name (_DEP, Package (0x01)  // _DEP: Dependencies
            {
                "\\_SB.ABD"
            })
            Field (\_SB.ABD.ROP1, BufferAcc, NoLock, Preserve)
            {
                Connection (
                    I2cSerialBusV2 (0x0001, ControllerInitiated, 0x00000000,
                        AddressingMode7Bit, "\\_SB.ABD",
                        0x00, ResourceConsumer, , Exclusive,
                        )
                ), 
                AccessAs (BufferAcc, AttribRawBytes (0x0B)), 
                FLD0,   88
            }

            Method (GEPT, 0, NotSerialized)
            {
                Name (BUFF, Buffer (0x04){})
                CreateByteField (BUFF, Zero, STAT)
                CreateWordField (BUFF, 0x02, DATA)
                DATA = One
                Return (DATA) /* \_SB_.PRXY.GEPT.DATA */
            }
        }

        Device (SDF1)
        {
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.PMIC, 
            })
            Name (_HID, "QCOM2134")  // _HID: Hardware ID
        }

        Device (AGR0)
        {
            Name (_HID, "ACPI000C" /* Processor Aggregator Device */)  // _HID: Hardware ID
            Name (_PUR, Package (0x02)  // _PUR: Processor Utilization Request
            {
                One, 
                Zero
            })
            Method (_OST, 3, NotSerialized)  // _OST: OSPM Status Indication
            {
                \_SB.PEP0.ROST = Arg2
            }
        }

        ThermalZone (TZ0)
        {
            Name (_HID, "QCOM2400")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Name (_TZD, Package (0x01)  // _TZD: Thermal Zone Devices
            {
                \_SB.CPU0, 
            })
            Method (_PSV, 0, NotSerialized)  // _PSV: Passive Temperature
            {
                Return (0x0E60)
            }

            Method (_CRT, 0, NotSerialized)  // _CRT: Critical Temperature
            {
                Return (0x0EF6)
            }

            Name (_TC1, 0x04)  // _TC1: Thermal Constant 1
            Name (_TC2, 0x03)  // _TC2: Thermal Constant 2
            Name (_TSP, 0x32)  // _TSP: Thermal Sampling Period
            Name (_TZP, Zero)  // _TZP: Thermal Zone Polling
        }

        ThermalZone (TZ2)
        {
            Name (_HID, "QCOM2402")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Name (_TZD, Package (0x02)  // _TZD: Thermal Zone Devices
            {
                \_SB.CPU0, , 
                \_SB.CPU1, 
            })
            Method (_PSV, 0, NotSerialized)  // _PSV: Passive Temperature
            {
                Return (0x0E60)
            }

            Method (_CRT, 0, NotSerialized)  // _CRT: Critical Temperature
            {
                Return (0x0EF6)
            }

            Name (_TC1, 0x04)  // _TC1: Thermal Constant 1
            Name (_TC2, 0x03)  // _TC2: Thermal Constant 2
            Name (_TSP, 0x32)  // _TSP: Thermal Sampling Period
            Name (_TZP, Zero)  // _TZP: Thermal Zone Polling
        }

        ThermalZone (TZ3)
        {
            Name (_HID, "QCOM2403")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Name (_TZD, Package (0x02)  // _TZD: Thermal Zone Devices
            {
                \_SB.CPU0, , 
                \_SB.CPU1, 
            })
            Method (_PSV, 0, NotSerialized)  // _PSV: Passive Temperature
            {
                Return (0x0E4C)
            }

            Method (_CRT, 0, NotSerialized)  // _CRT: Critical Temperature
            {
                Return (0x0EC4)
            }

            Name (_TC1, 0x04)  // _TC1: Thermal Constant 1
            Name (_TC2, 0x03)  // _TC2: Thermal Constant 2
            Name (_TSP, 0x0A)  // _TSP: Thermal Sampling Period
            Name (_TZP, Zero)  // _TZP: Thermal Zone Polling
        }

        ThermalZone (TZ6)
        {
            Name (_HID, "QCOM2406")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Name (_TZD, Package (0x01)  // _TZD: Thermal Zone Devices
            {
                \_SB.CPU1, 
            })
            Method (_PSV, 0, NotSerialized)  // _PSV: Passive Temperature
            {
                Return (0x0E60)
            }

            Method (_CRT, 0, NotSerialized)  // _CRT: Critical Temperature
            {
                Return (0x0EF6)
            }

            Name (_TC1, 0x04)  // _TC1: Thermal Constant 1
            Name (_TC2, 0x03)  // _TC2: Thermal Constant 2
            Name (_TSP, 0x32)  // _TSP: Thermal Sampling Period
            Name (_TZP, Zero)  // _TZP: Thermal Zone Polling
        }

        ThermalZone (TZ8)
        {
            Name (_HID, "QCOM2408")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Name (_TZD, Package (0x02)  // _TZD: Thermal Zone Devices
            {
                \_SB.CPU0, , 
                \_SB.CPU1, 
            })
            Method (_PSV, 0, NotSerialized)  // _PSV: Passive Temperature
            {
                Return (0x0E60)
            }

            Method (_CRT, 0, NotSerialized)  // _CRT: Critical Temperature
            {
                Return (0x0EF6)
            }

            Name (_TC1, 0x04)  // _TC1: Thermal Constant 1
            Name (_TC2, 0x03)  // _TC2: Thermal Constant 2
            Name (_TSP, 0x32)  // _TSP: Thermal Sampling Period
            Name (_TZP, Zero)  // _TZP: Thermal Zone Polling
        }

        ThermalZone (TZ9)
        {
            Name (_HID, "QCOM2409")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Name (_TZD, Package (0x01)  // _TZD: Thermal Zone Devices
            {
                \_SB.CPU0, 
            })
            Method (_PSV, 0, NotSerialized)  // _PSV: Passive Temperature
            {
                Return (0x0E60)
            }

            Method (_CRT, 0, NotSerialized)  // _CRT: Critical Temperature
            {
                Return (0x0EF6)
            }

            Name (_TC1, 0x04)  // _TC1: Thermal Constant 1
            Name (_TC2, 0x03)  // _TC2: Thermal Constant 2
            Name (_TSP, 0x32)  // _TSP: Thermal Sampling Period
            Name (_TZP, Zero)  // _TZP: Thermal Zone Polling
        }

        ThermalZone (TZ10)
        {
            Name (_HID, "NOKIA_THERMAL")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Name (_TZD, Package (0x02)  // _TZD: Thermal Zone Devices
            {
                \_SB.CPU0, , 
                \_SB.CPU1, 
            })
            Method (_PSV, 0, NotSerialized)  // _PSV: Passive Temperature
            {
                Return (0x0EC4)
            }

            Method (_CRT, 0, NotSerialized)  // _CRT: Critical Temperature
            {
                Return (0x0EF6)
            }

            Name (_TC1, 0x04)  // _TC1: Thermal Constant 1
            Name (_TC2, 0x03)  // _TC2: Thermal Constant 2
            Name (_TSP, 0x32)  // _TSP: Thermal Sampling Period
            Name (_TZP, Zero)  // _TZP: Thermal Zone Polling
        }

        ThermalZone (TZ11)
        {
            Name (_HID, "QCOM2154")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Name (_TZD, Package (0x02)  // _TZD: Thermal Zone Devices
            {
                \_SB.CPU0, , 
                \_SB.CPU1, 
            })
            Method (_PSV, 0, NotSerialized)  // _PSV: Passive Temperature
            {
                Return (0x0D66)
            }

            Method (_CRT, 0, NotSerialized)  // _CRT: Critical Temperature
            {
                Return (0x0DA2)
            }

            Name (_TC1, 0x04)  // _TC1: Thermal Constant 1
            Name (_TC2, 0x03)  // _TC2: Thermal Constant 2
            Name (_TSP, 0x32)  // _TSP: Thermal Sampling Period
            Name (_TZP, Zero)  // _TZP: Thermal Zone Polling
        }

        Device (SMMU)
        {
            Name (_HID, "QCOM0200")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0xBF)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x40, 0x07,  // ......@.
                    /* 0008 */  0x00, 0x00, 0x10, 0x00, 0x86, 0x09, 0x00, 0x01,  // ........
                    /* 0010 */  0x00, 0x00, 0x50, 0x07, 0x00, 0x00, 0x10, 0x00,  // ..P.....
                    /* 0018 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x60, 0x07,  // ......`.
                    /* 0020 */  0x00, 0x00, 0x10, 0x00, 0x86, 0x09, 0x00, 0x01,  // ........
                    /* 0028 */  0x00, 0x00, 0x70, 0x07, 0x00, 0x00, 0x10, 0x00,  // ..p.....
                    /* 0030 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x80, 0x07,  // ........
                    /* 0038 */  0x00, 0x00, 0x10, 0x00, 0x86, 0x09, 0x00, 0x01,  // ........
                    /* 0040 */  0x00, 0x00, 0x90, 0x07, 0x00, 0x00, 0x10, 0x00,  // ........
                    /* 0048 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0xA0, 0x07,  // ........
                    /* 0050 */  0x00, 0x00, 0x10, 0x00, 0x86, 0x09, 0x00, 0x01,  // ........
                    /* 0058 */  0x00, 0x00, 0xB0, 0x07, 0x00, 0x00, 0x10, 0x00,  // ........
                    /* 0060 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0xC0, 0x07,  // ........
                    /* 0068 */  0x00, 0x00, 0x10, 0x00, 0x89, 0x06, 0x00, 0x03,  // ........
                    /* 0070 */  0x01, 0x54, 0x00, 0x00, 0x00, 0x89, 0x06, 0x00,  // .T......
                    /* 0078 */  0x03, 0x01, 0x60, 0x00, 0x00, 0x00, 0x89, 0x06,  // ..`.....
                    /* 0080 */  0x00, 0x03, 0x01, 0x5E, 0x00, 0x00, 0x00, 0x89,  // ...^....
                    /* 0088 */  0x06, 0x00, 0x03, 0x01, 0x5C, 0x00, 0x00, 0x00,  // ....\...
                    /* 0090 */  0x89, 0x06, 0x00, 0x03, 0x01, 0x64, 0x00, 0x00,  // .....d..
                    /* 0098 */  0x00, 0x89, 0x06, 0x00, 0x03, 0x01, 0x56, 0x00,  // ......V.
                    /* 00A0 */  0x00, 0x00, 0x89, 0x06, 0x00, 0x03, 0x01, 0x5A,  // .......Z
                    /* 00A8 */  0x00, 0x00, 0x00, 0x89, 0x06, 0x00, 0x03, 0x01,  // ........
                    /* 00B0 */  0x58, 0x00, 0x00, 0x00, 0x89, 0x06, 0x00, 0x03,  // X.......
                    /* 00B8 */  0x01, 0x66, 0x00, 0x00, 0x00, 0x79, 0x00         // .f...y.
                })
                Return (RBUF) /* \_SB_.SMMU._CRS.RBUF */
            }

            Method (BCDE, 0, NotSerialized)
            {
                Name (XBUF, Buffer (0x04)
                {
                     0x03, 0x00, 0x01, 0x10                           // ....
                })
                Return (XBUF) /* \_SB_.SMMU.BCDE.XBUF */
            }

            Method (CORE, 0, NotSerialized)
            {
                Name (YBUF, Buffer (0x24)
                {
                    /* 0000 */  0x09, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,  // ........
                    /* 0008 */  0x08, 0x09, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,  // ........
                    /* 0010 */  0x02, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,  // ........
                    /* 0018 */  0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,  // ........
                    /* 0020 */  0x10, 0x11, 0x13, 0x14                           // ....
                })
                Return (YBUF) /* \_SB_.SMMU.CORE.YBUF */
            }

            Method (AGPA, 0, NotSerialized)
            {
                Name (BUFF, Buffer (One)
                {
                     0x01                                             // .
                })
                Return (BUFF) /* \_SB_.SMMU.AGPA.BUFF */
            }

            Method (PTCA, 0, NotSerialized)
            {
                Name (BUFF, Buffer (One)
                {
                     0x00                                             // .
                })
                Return (BUFF) /* \_SB_.SMMU.PTCA.BUFF */
            }
        }

        Device (GPU0)
        {
            Name (_HID, "QCOM0300")  // _HID: Hardware ID
            Name (_CID, "ACPIQCOM0300")  // _CID: Compatible ID
            Name (_UID, Zero)  // _UID: Unique ID
            Name (_CLS, 0x0003000000000000)  // _CLS: Class Code
            Device (MON0)
            {
                Method (_ADR, 0, NotSerialized)  // _ADR: Address
                {
                    Return (Zero)
                }
            }

            Name (_DEP, Package (0x04)  // _DEP: Dependencies
            {
                \_SB.SMMU, , 
                \_SB.PEP0, , 
                \_SB.PMIC, , 
                \_SB.CIN0, 
            })
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0xC1)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x10, 0x05,  // ........
                    /* 0008 */  0x00, 0x00, 0x10, 0x00, 0x86, 0x09, 0x00, 0x01,  // ........
                    /* 0010 */  0x00, 0x00, 0x70, 0x04, 0x00, 0x10, 0x00, 0x00,  // ..p.....
                    /* 0018 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0xA0, 0x04,  // ........
                    /* 0020 */  0x00, 0x10, 0x00, 0x00, 0x86, 0x09, 0x00, 0x01,  // ........
                    /* 0028 */  0x00, 0x00, 0xF0, 0x04, 0x00, 0x20, 0x00, 0x00,  // ..... ..
                    /* 0030 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x70, 0x00,  // ......p.
                    /* 0038 */  0x00, 0x80, 0x00, 0x00, 0x86, 0x09, 0x00, 0x01,  // ........
                    /* 0040 */  0x58, 0x00, 0x70, 0x05, 0x04, 0x00, 0x00, 0x00,  // X.p.....
                    /* 0048 */  0x89, 0x06, 0x00, 0x01, 0x01, 0x6B, 0x00, 0x00,  // .....k..
                    /* 0050 */  0x00, 0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x30,  // .......0
                    /* 0058 */  0x04, 0x00, 0x00, 0x02, 0x00, 0x89, 0x06, 0x00,  // ........
                    /* 0060 */  0x01, 0x01, 0x70, 0x00, 0x00, 0x00, 0x86, 0x09,  // ..p.....
                    /* 0068 */  0x00, 0x01, 0x00, 0x00, 0xE0, 0x04, 0x00, 0x00,  // ........
                    /* 0070 */  0x01, 0x00, 0x89, 0x06, 0x00, 0x01, 0x01, 0x69,  // .......i
                    /* 0078 */  0x00, 0x00, 0x00, 0x86, 0x09, 0x00, 0x01, 0x00,  // ........
                    /* 0080 */  0x00, 0x40, 0x04, 0x00, 0x00, 0x10, 0x00, 0x89,  // .@......
                    /* 0088 */  0x06, 0x00, 0x01, 0x01, 0x51, 0x00, 0x00, 0x00,  // ....Q...
                    /* 0090 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x40, 0x80,  // ......@.
                    /* 0098 */  0x00, 0x00, 0x40, 0x00, 0x8C, 0x20, 0x00, 0x01,  // ..@.. ..
                    /* 00A0 */  0x01, 0x01, 0x00, 0x08, 0x00, 0x01, 0x00, 0x00,  // ........
                    /* 00A8 */  0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // .......#
                    /* 00B0 */  0x00, 0x00, 0x00, 0x3A, 0x00, 0x5C, 0x5F, 0x53,  // ...:.\_S
                    /* 00B8 */  0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x79,  // B.GIO0.y
                    /* 00C0 */  0x00                                             // .
                })
                Return (RBUF) /* \_SB_.GPU0._CRS.RBUF */
            }

            Method (RESI, 0, NotSerialized)
            {
                Name (RINF, Package (0x11)
                {
                    0x02, 
                    Zero, 
                    Package (0x03)
                    {
                        "RESOURCE", 
                        "MDP_REGS", 
                        "DISPLAY"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "MIPI_DSI_REGS", 
                        "DISPLAY"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "HDMI_REGS", 
                        "DISPLAY"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "TV_ENC_REGS", 
                        "DISPLAY"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "SE_CTRL_REGS", 
                        "DISPLAY"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "MMSS_SFPB_GPREG", 
                        "DISPLAY"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "VSYNC_INTERRUPT", 
                        "DISPLAY"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "GFX_REGS", 
                        "GRAPHICS"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "GFX_INTERRUPT", 
                        "GRAPHICS"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "ROTATOR_REGS", 
                        "ROTATOR"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "ROTATOR_INTERRUPT", 
                        "ROTATOR"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "VIDEO_REGS", 
                        "VIDEO"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "VIDC_INTERRUPT", 
                        "VIDEO"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "UEFI_FRAME_BUFFER", 
                        "UEFI"
                    }, 

                    Package (0x03)
                    {
                        "RESOURCE", 
                        "DSI_PANEL_RESET", 
                        "DISPLAY"
                    }
                })
                Return (RINF) /* \_SB_.GPU0.RESI.RINF */
            }

            Method (ENGS, 0, NotSerialized)
            {
                Name (EBUF, Package (0x05)
                {
                    0x02, 
                    Zero, 
                    0x002E0005, 
                    Package (0x06)
                    {
                        "ENGINES", 
                        0x04, 
                        Package (0x0A)
                        {
                            "ENGINE", 
                            "GRAPHICS", 
                            "Adreno3XX", 
                            Zero, 
                            0x06, 
                            0x0A, 
                            Package (0x03)
                            {
                                "MMUIDS", 
                                "VCM_GFX_3D_USER", 
                                "VCM_GFX_3D_PRIV"
                            }, 

                            Package (0x03)
                            {
                                "PERF_CONTROLS", 
                                Package (0x03)
                                {
                                    0x0E, 
                                    Package (0x02)
                                    {
                                        "ReleaseVoteOnPowerCollapse", 
                                        Zero
                                    }, 

                                    Package (0x02)
                                    {
                                        "LimitForPassiveCooling", 
                                        One
                                    }
                                }, 

                                Package (0x03)
                                {
                                    0x10, 
                                    Package (0x02)
                                    {
                                        "ReleaseVoteOnPowerCollapse", 
                                        One
                                    }, 

                                    Package (0x02)
                                    {
                                        "LimitForPassiveCooling", 
                                        One
                                    }
                                }
                            }, 

                            Package (0x04)
                            {
                                "POWER_SETTINGS", 
                                Package (0x02)
                                {
                                    "ForceMaxPerf", 
                                    Zero
                                }, 

                                Package (0x02)
                                {
                                    "ForceActive", 
                                    Zero
                                }, 

                                Package (0x02)
                                {
                                    "PreventPowerCollapse", 
                                    Zero
                                }
                            }, 

                            Package (0x05)
                            {
                                "PROPERTIES", 
                                0x03, 
                                Package (0x02)
                                {
                                    "GmemBaseAddr", 
                                    Zero
                                }, 

                                Package (0x02)
                                {
                                    "GmemSize", 
                                    0x00040000
                                }, 

                                Package (0x02)
                                {
                                    "SMMUCount", 
                                    One
                                }
                            }
                        }, 

                        Package (0x08)
                        {
                            "ENGINE", 
                            "MDPBLT", 
                            "MDP4.x", 
                            One, 
                            0x07, 
                            0x0B, 
                            Package (0x03)
                            {
                                "PERF_CONTROLS", 
                                Package (0x02)
                                {
                                    0x11, 
                                    Package (0x02)
                                    {
                                        "ReleaseVoteOnPowerCollapse", 
                                        One
                                    }
                                }, 

                                Package (0x02)
                                {
                                    0x13, 
                                    Package (0x02)
                                    {
                                        "ReleaseVoteOnPowerCollapse", 
                                        One
                                    }
                                }
                            }, 

                            Package (0x04)
                            {
                                "POWER_SETTINGS", 
                                Package (0x02)
                                {
                                    "ForceMaxPerf", 
                                    Zero
                                }, 

                                Package (0x02)
                                {
                                    "ForceActive", 
                                    Zero
                                }, 

                                Package (0x02)
                                {
                                    "PreventPowerCollapse", 
                                    Zero
                                }
                            }
                        }, 

                        Package (0x09)
                        {
                            "ENGINE", 
                            "ROTATOR", 
                            "Rotator1.0", 
                            0x02, 
                            0x08, 
                            0x0C, 
                            Package (0x03)
                            {
                                "MMUIDS", 
                                "VCM_ROT_SRC", 
                                "VCM_ROT_DST"
                            }, 

                            Package (0x03)
                            {
                                "PERF_CONTROLS", 
                                Package (0x02)
                                {
                                    0x14, 
                                    Package (0x02)
                                    {
                                        "ReleaseVoteOnPowerCollapse", 
                                        Zero
                                    }
                                }, 

                                Package (0x02)
                                {
                                    0x15, 
                                    Package (0x02)
                                    {
                                        "ReleaseVoteOnPowerCollapse", 
                                        One
                                    }
                                }
                            }, 

                            Package (0x04)
                            {
                                "POWER_SETTINGS", 
                                Package (0x02)
                                {
                                    "ForceMaxPerf", 
                                    Zero
                                }, 

                                Package (0x02)
                                {
                                    "ForceActive", 
                                    Zero
                                }, 

                                Package (0x02)
                                {
                                    "PreventPowerCollapse", 
                                    Zero
                                }
                            }
                        }, 

                        Package (0x09)
                        {
                            "ENGINE", 
                            "VIDEO", 
                            "MFC1080p", 
                            0x03, 
                            0x09, 
                            0x0D, 
                            Package (0x04)
                            {
                                "PERF_CONTROLS", 
                                Package (0x02)
                                {
                                    0x16, 
                                    Package (0x02)
                                    {
                                        "ReleaseVoteOnPowerCollapse", 
                                        Zero
                                    }
                                }, 

                                Package (0x02)
                                {
                                    0x17, 
                                    Package (0x02)
                                    {
                                        "ReleaseVoteOnPowerCollapse", 
                                        One
                                    }
                                }, 

                                Package (0x02)
                                {
                                    0x18, 
                                    Package (0x02)
                                    {
                                        "ReleaseVoteOnPowerCollapse", 
                                        One
                                    }
                                }
                            }, 

                            Package (0x04)
                            {
                                "POWER_SETTINGS", 
                                Package (0x02)
                                {
                                    "ForceMaxPerf", 
                                    Zero
                                }, 

                                Package (0x02)
                                {
                                    "ForceActive", 
                                    Zero
                                }, 

                                Package (0x02)
                                {
                                    "PreventPowerCollapse", 
                                    Zero
                                }
                            }, 

                            Package (0x0F)
                            {
                                "PROPERTIES", 
                                0x0D, 
                                Package (0x02)
                                {
                                    "DecMaxWidth", 
                                    0x0780
                                }, 

                                Package (0x02)
                                {
                                    "DecMaxHeight", 
                                    0x0440
                                }, 

                                Package (0x02)
                                {
                                    "DecMaxMB", 
                                    0x1FE0
                                }, 

                                Package (0x02)
                                {
                                    "DecMaxBitRate", 
                                    0xC350
                                }, 

                                Package (0x02)
                                {
                                    "DecGUIDs", 
                                    0x1F
                                }, 

                                Package (0x02)
                                {
                                    "DecOutputFormats", 
                                    One
                                }, 

                                Package (0x02)
                                {
                                    "DecMaxFps", 
                                    0x1E
                                }, 

                                Package (0x02)
                                {
                                    "EncMaxWidth", 
                                    0x0780
                                }, 

                                Package (0x02)
                                {
                                    "EncMaxHeight", 
                                    0x0440
                                }, 

                                Package (0x02)
                                {
                                    "EncMaxMB", 
                                    0x1FE0
                                }, 

                                Package (0x02)
                                {
                                    "EncMaxBitRate", 
                                    0xC350
                                }, 

                                Package (0x02)
                                {
                                    "EncGUIDs", 
                                    0x43
                                }, 

                                Package (0x02)
                                {
                                    "EncInputFormats", 
                                    0x03
                                }
                            }
                        }
                    }, 

                    Package (0x07)
                    {
                        "DISPLAY", 
                        "MDP4.x", 
                        0x04, 
                        0x05, 
                        0x07, 
                        0x0B, 
                        Package (0x05)
                        {
                            "RESOURCES", 
                            Package (0x05)
                            {
                                "MMUIDS", 
                                "VCM_MDP_VG1", 
                                "VCM_MDP_RGB1", 
                                "VCM_MDP_VG2", 
                                "VCM_MDP_RGB2"
                            }, 

                            Package (0x03)
                            {
                                "PERF_CONTROLS", 
                                Package (0x02)
                                {
                                    0x11, 
                                    Package (0x02)
                                    {
                                        "ReleaseVoteOnPowerCollapse", 
                                        Zero
                                    }
                                }, 

                                Package (0x02)
                                {
                                    0x12, 
                                    Package (0x02)
                                    {
                                        "ReleaseVoteOnPowerCollapse", 
                                        Zero
                                    }
                                }
                            }, 

                            Package (0x04)
                            {
                                "POWER_SETTINGS", 
                                Package (0x02)
                                {
                                    "ForceMaxPerf", 
                                    Zero
                                }, 

                                Package (0x02)
                                {
                                    "ForceActive", 
                                    Zero
                                }, 

                                Package (0x02)
                                {
                                    "PreventPowerCollapse", 
                                    Zero
                                }
                            }, 

                            Package (0x06)
                            {
                                "PROPERTIES", 
                                0x04, 
                                Package (0x02)
                                {
                                    "MultiplaneSupport", 
                                    One
                                }, 

                                Package (0x02)
                                {
                                    "HotplugSupport", 
                                    Zero
                                }, 

                                Package (0x02)
                                {
                                    "DisableHDMI", 
                                    One
                                }, 

                                Package (0x02)
                                {
                                    "LimitScalingModes", 
                                    0x02
                                }
                            }
                        }
                    }
                })
                Return (EBUF) /* \_SB_.GPU0.ENGS.EBUF */
            }

            Method (PMCL, 0, NotSerialized)
            {
                Name (RBUF, Package (0x1D)
                {
                    0x02, 
                    Zero, 
                    0x1A, 
                    Package (0x08)
                    {
                        "COMPONENT", 
                        Zero, 
                        ToUUID ("30bdf1b5-28f7-4c0c-ac47-273dd1401e11") /* Unknown UUID */, 
                        "GRAPHICS_F_STATES", 
                        Package (0x02)
                        {
                            "ENGINE", 
                            "GRAPHICS"
                        }, 

                        0x03, 
                        Zero, 
                        Package (0x04)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                0x03
                            }, 

                            Package (0x06)
                            {
                                "FSTATE", 
                                One, 
                                "CLK_OFF", 
                                0x00013880, 
                                Zero, 
                                0x02
                            }, 

                            Package (0x06)
                            {
                                "FSTATE", 
                                0x02, 
                                "PWR_OFF", 
                                0x000186A0, 
                                Zero, 
                                One
                            }
                        }
                    }, 

                    Package (0x08)
                    {
                        "COMPONENT", 
                        One, 
                        ToUUID ("07ca2add-df87-49e1-8583-08687dc81c8e") /* Unknown UUID */, 
                        "MDPBLT_F_STATES", 
                        Package (0x02)
                        {
                            "ENGINE", 
                            "MDPBLT"
                        }, 

                        0x03, 
                        Zero, 
                        Package (0x04)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                0x03
                            }, 

                            Package (0x06)
                            {
                                "FSTATE", 
                                One, 
                                "CLK_OFF", 
                                0x00013880, 
                                Zero, 
                                0x02
                            }, 

                            Package (0x06)
                            {
                                "FSTATE", 
                                0x02, 
                                "PWR_OFF", 
                                0x000186A0, 
                                Zero, 
                                One
                            }
                        }
                    }, 

                    Package (0x08)
                    {
                        "COMPONENT", 
                        0x02, 
                        ToUUID ("4d5ffbf5-d791-41cd-89cb-0154129ba607") /* Unknown UUID */, 
                        "ROTATOR_F_STATES", 
                        Package (0x02)
                        {
                            "ENGINE", 
                            "ROTATOR"
                        }, 

                        0x03, 
                        Zero, 
                        Package (0x04)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                0x03
                            }, 

                            Package (0x06)
                            {
                                "FSTATE", 
                                One, 
                                "CLK_OFF", 
                                0x00013880, 
                                Zero, 
                                0x02
                            }, 

                            Package (0x06)
                            {
                                "FSTATE", 
                                0x02, 
                                "PWR_OFF", 
                                0x000186A0, 
                                Zero, 
                                One
                            }
                        }
                    }, 

                    Package (0x08)
                    {
                        "COMPONENT", 
                        0x03, 
                        ToUUID ("d0e1bb1a-703d-4be8-b450-64a4fbfca6a8") /* Unknown UUID */, 
                        "VIDEO_F_STATES", 
                        Package (0x02)
                        {
                            "ENGINE", 
                            "VIDEO"
                        }, 

                        0x03, 
                        Zero, 
                        Package (0x04)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                0x03
                            }, 

                            Package (0x06)
                            {
                                "FSTATE", 
                                One, 
                                "CLK_OFF", 
                                0x00013880, 
                                Zero, 
                                0x02
                            }, 

                            Package (0x06)
                            {
                                "FSTATE", 
                                0x02, 
                                "PWR_OFF", 
                                0x000186A0, 
                                Zero, 
                                One
                            }
                        }
                    }, 

                    Package (0x08)
                    {
                        "COMPONENT", 
                        0x04, 
                        ToUUID ("2c135991-4391-4633-90b1-fa96f2e2cc04") /* Unknown UUID */, 
                        "PRIMDISPLAY_F_STATES", 
                        Package (0x02)
                        {
                            "DISPLAY", 
                            "PRIMARY"
                        }, 

                        0x02, 
                        Zero, 
                        Package (0x03)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                0x02
                            }, 

                            Package (0x06)
                            {
                                "FSTATE", 
                                One, 
                                "PWR_OFF", 
                                One, 
                                One, 
                                One
                            }
                        }
                    }, 

                    Package (0x08)
                    {
                        "COMPONENT", 
                        0x05, 
                        ToUUID ("1a134877-a115-49b8-bda1-382b78bba62d") /* Unknown UUID */, 
                        "HDMI_F_STATES", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        0x02, 
                        Zero, 
                        Package (0x03)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                0x02
                            }, 

                            Package (0x06)
                            {
                                "FSTATE", 
                                One, 
                                "PWR_OFF", 
                                One, 
                                One, 
                                One
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x06, 
                        ToUUID ("2f519166-33e4-48c7-90c1-febf9b743ce2") /* Unknown UUID */, 
                        "GRAPHICS_FOOTSWITCH_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x02, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x05)
                        {
                            "PSTATE_SET", 
                            "BOOLEAN", 
                            One, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                One, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x07, 
                        ToUUID ("d50ccda5-25fa-4dfa-9455-9b8ea9961f4d") /* Unknown UUID */, 
                        "MDP_FOOTSWITCH_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x02, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x05)
                        {
                            "PSTATE_SET", 
                            "BOOLEAN", 
                            Zero, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                One, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x08, 
                        ToUUID ("a1a38e95-8974-455d-b61d-9e474164b378") /* Unknown UUID */, 
                        "ROTATOR_FOOTSWITCH_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x02, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x05)
                        {
                            "PSTATE_SET", 
                            "BOOLEAN", 
                            One, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                One, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x09, 
                        ToUUID ("b76a8386-4607-4c5f-bcd8-bf79ca53dbd1") /* Unknown UUID */, 
                        "VIDEO_FOOTSWITCH_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x02, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x05)
                        {
                            "PSTATE_SET", 
                            "BOOLEAN", 
                            One, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                One, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x0A, 
                        ToUUID ("667d4184-17d7-4d99-b245-c74c25fb19ff") /* Unknown UUID */, 
                        "GRAPHICS_RESET", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x02, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x05)
                        {
                            "PSTATE_SET", 
                            "BOOLEAN", 
                            One, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                One, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x0B, 
                        ToUUID ("ae763fbd-23dd-4415-861e-024b98da5249") /* Unknown UUID */, 
                        "MDP_RESET", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x02, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x05)
                        {
                            "PSTATE_SET", 
                            "BOOLEAN", 
                            One, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                One, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x0C, 
                        ToUUID ("2080c177-dbff-4aa0-83ee-a050feee1884") /* Unknown UUID */, 
                        "ROTATOR_RESET", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x02, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x05)
                        {
                            "PSTATE_SET", 
                            "BOOLEAN", 
                            One, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                One, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x0D, 
                        ToUUID ("ebc53022-a46f-4ad8-a9c8-24674f697892") /* Unknown UUID */, 
                        "VIDEO_RESET", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x02, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x05)
                        {
                            "PSTATE_SET", 
                            "BOOLEAN", 
                            One, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                One, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x0E, 
                        ToUUID ("528c3780-61be-4ff9-898d-ac42dc22d7c1") /* Unknown UUID */, 
                        "GRAPHICS_CORE_CLOCK_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x0D, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x10)
                        {
                            "PSTATE_SET", 
                            "CORE_CLOCK", 
                            0x04, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                0x1DCD6500, 
                                Zero
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                0x17D78400, 
                                Zero
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x02, 
                                0x1312D000, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x03, 
                                0x0FE50010, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x04, 
                                0x0D9FB925, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x05, 
                                0x0BEBC200, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x06, 
                                0x0B71B000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x07, 
                                0x0A98AC72, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x08, 
                                0x09896800, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x09, 
                                0x08AB795F, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0A, 
                                0x07A12000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0B, 
                                0x05B8D800, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0C, 
                                0x0493E000, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x08)
                    {
                        "COMPONENT", 
                        0x0F, 
                        ToUUID ("bf4311ad-34dd-4857-8f06-69e80f7895db") /* Unknown UUID */, 
                        "GRAPHICS_GMEM_FREQ_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        Zero, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x10, 
                        ToUUID ("087b6af0-a5d2-4c4f-a0da-33b36f38f8e7") /* Unknown UUID */, 
                        "GRAPHICS_AXI_BANDWIDTH_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x0F, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x12)
                        {
                            "PSTATE_SET", 
                            "BANDWIDTH", 
                            0xFFFFFFFF, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                0xFFFFFFFF, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                0xD3B73800, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x02, 
                                0xBEBC2000, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x03, 
                                0x9EC96A00, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x04, 
                                0x7F047AC0, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x05, 
                                0x5F5E1000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x06, 
                                0x5B8D8000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x07, 
                                0x3F9920C0, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x08, 
                                0x3D090000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x09, 
                                0x2FAF0800, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0A, 
                                0x2625A000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0B, 
                                0x1FCA0FC0, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0C, 
                                0x17D78400, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0D, 
                                0x0CDFE600, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0E, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x11, 
                        ToUUID ("6355038a-70e7-412d-8574-f45398d5e909") /* Unknown UUID */, 
                        "MDP_CORE_CLOCK_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x0D, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x10)
                        {
                            "PSTATE_SET", 
                            "CORE_CLOCK", 
                            One, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                0x0BEBC200, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                0x0A98AC72, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x02, 
                                0x09896800, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x03, 
                                0x07A12000, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x04, 
                                0x05B8D800, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x05, 
                                0x05161555, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x06, 
                                0x0493E000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x07, 
                                0x0385713B, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x08, 
                                0x0249F000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x09, 
                                0x0214ABA3, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0A, 
                                0x01C2B89E, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0B, 
                                0x00D1436E, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0C, 
                                0x00927C00, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x12, 
                        ToUUID ("99db40f3-d6bb-494a-9664-dcdd0c50bfb6") /* Unknown UUID */, 
                        "MDP_AXI_PORT0_BANDWIDTH_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x21, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x24)
                        {
                            "PSTATE_SET", 
                            "BANDWIDTH", 
                            0x0B, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                0x5CC8FFB4, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                0x5459A2A4, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x02, 
                                0x4CAE93DA, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x03, 
                                0x45B5FAC7, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x04, 
                                0x3F5F9E29, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x05, 
                                0x399CBE54, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x06, 
                                0x345FF2D8, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x07, 
                                0x2F9D0B50, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x08, 
                                0x2B48F303, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x09, 
                                0x2759971A, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0A, 
                                0x23C5CF2F, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0B, 
                                0x208547FC, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0C, 
                                0x1D906FFC, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0D, 
                                0x1AE065CE, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0E, 
                                0x186EE830, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0F, 
                                0x16364771, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x10, 
                                0x14315838, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x11, 
                                0x125B6779, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x12, 
                                0x10B02F85, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x13, 
                                0x0F2BCE1C, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x14, 
                                0x0DCABB5F, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x15, 
                                0x0C89C19D, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x16, 
                                0x0B65F5D4, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x17, 
                                0x0A5CB0EF, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x18, 
                                0x096B8994, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x19, 
                                0x08904E86, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x1A, 
                                0x07C90191, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x1B, 
                                0x0713D2E1, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x1C, 
                                0x066F1CCD, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x1D, 
                                0x05D96000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x1E, 
                                0x05514000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x1F, 
                                0x04D58000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x20, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x13, 
                        ToUUID ("2328ffd6-092e-4619-958e-c0262e7d2c16") /* Unknown UUID */, 
                        "MDP_AXI_PORT1_BANDWIDTH_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x0F, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x12)
                        {
                            "PSTATE_SET", 
                            "BANDWIDTH", 
                            0xFFFFFFFF, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                0xEA9A9800, 
                                Zero
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                0xD3B73800, 
                                Zero
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x02, 
                                0xBEBC2000, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x03, 
                                0x9EC96A00, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x04, 
                                0x7F281FC0, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x05, 
                                0x5F5E1000, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x06, 
                                0x5B8D8000, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x07, 
                                0x3F940040, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x08, 
                                0x2FAF0800, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x09, 
                                0x2625A000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0A, 
                                0x1FCA0FC0, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0B, 
                                0x17D78400, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0C, 
                                0x0CDFE600, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0D, 
                                0x066FF300, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0E, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x14, 
                        ToUUID ("17488db9-ea23-4183-8f39-0b4382ebdf03") /* Unknown UUID */, 
                        "ROTATOR_CORE_CLOCK_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x0E, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x11)
                        {
                            "PSTATE_SET", 
                            "CORE_CLOCK", 
                            0x0D, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                0x0BEBC200, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                0x09896800, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x02, 
                                0x07F28155, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x03, 
                                0x06CFDC92, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x04, 
                                0x05F5E100, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x05, 
                                0x05B8D800, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x06, 
                                0x0493E000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x07, 
                                0x03D09000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x08, 
                                0x03450DB7, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x09, 
                                0x02DC6C00, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0A, 
                                0x0249F000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0B, 
                                0x01E84800, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0C, 
                                0x01C2B89E, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0D, 
                                0x019BFCC0, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x15, 
                        ToUUID ("e32d4048-92e7-42e8-8355-bf54c65478c9") /* Unknown UUID */, 
                        "ROTATOR_AXI_BANDWIDTH_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x0F, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x12)
                        {
                            "PSTATE_SET", 
                            "BANDWIDTH", 
                            0xFFFFFFFF, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                0xEA9A9800, 
                                Zero
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                0xD3B73800, 
                                Zero
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x02, 
                                0xBEBC2000, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x03, 
                                0x9EC96A00, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x04, 
                                0x7F281FC0, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x05, 
                                0x5F5E1000, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x06, 
                                0x5B8D8000, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x07, 
                                0x3F940040, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x08, 
                                0x2FAF0800, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x09, 
                                0x2625A000, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0A, 
                                0x1FCA0FC0, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0B, 
                                0x17D78400, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0C, 
                                0x0CDFE600, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0D, 
                                0x066FF300, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0E, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x16, 
                        ToUUID ("725746f2-be16-4588-b0f6-346099abb8e4") /* Unknown UUID */, 
                        "VIDEO_CORE_CLOCK_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x07, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x0A)
                        {
                            "PSTATE_SET", 
                            "CORE_CLOCK", 
                            0x06, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                0x0BEBC200, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                0x07F28155, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x02, 
                                0x05B8D800, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x03, 
                                0x03450DB7, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x04, 
                                0x02DC6C00, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x05, 
                                0x01E84800, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x06, 
                                0x019BFCC0, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x17, 
                        ToUUID ("306ca75e-c401-47f9-8538-aa1440eecadb") /* Unknown UUID */, 
                        "VIDEO_AXI_PORT0_BANDWIDTH_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x10, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x13)
                        {
                            "PSTATE_SET", 
                            "BANDWIDTH", 
                            0xFFFFFFFF, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                0x1E2C7CC0, 
                                Zero
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                0x1BD7BF20, 
                                Zero
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x02, 
                                0x19830180, 
                                Zero
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x03, 
                                0x17705460, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x04, 
                                0x155DA740, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x05, 
                                0x134AFA20, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x06, 
                                0x11384D00, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x07, 
                                0x0F259FE0, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x08, 
                                0x0D2D7190, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x09, 
                                0x0B354340, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0A, 
                                0x09110B80, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0B, 
                                0x06ECD3C0, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0C, 
                                0x0550EE70, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0D, 
                                0x03B50920, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0E, 
                                0x0254BDA0, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0F, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x09)
                    {
                        "COMPONENT", 
                        0x18, 
                        ToUUID ("7c8c7a36-5ccc-407e-8956-30de50d7f8d9") /* Unknown UUID */, 
                        "VIDEO_AXI_PORT1_BANDWIDTH_CONTROL", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        One, 
                        0x13, 
                        Package (0x02)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                One
                            }
                        }, 

                        Package (0x16)
                        {
                            "PSTATE_SET", 
                            "BANDWIDTH", 
                            0xFFFFFFFF, 
                            Package (0x04)
                            {
                                "PSTATE", 
                                Zero, 
                                0x238CCD28, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                One, 
                                0x20D38928, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x02, 
                                0x1E1A4528, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x03, 
                                0x1B94B974, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x04, 
                                0x19111C8A, 
                                One
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x05, 
                                0x168D7FA0, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x06, 
                                0x15C96480, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x07, 
                                0x13A17EEA, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x08, 
                                0x11799954, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x09, 
                                0x0F51B3BE, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0A, 
                                0x0D29CE28, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0B, 
                                0x0B5E6D74, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0C, 
                                0x09930CC0, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0D, 
                                0x08CC3280, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0E, 
                                0x063CEFA0, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x0F, 
                                0x03ADACC0, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x10, 
                                0x032CFD00, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x11, 
                                0x02B94400, 
                                0x02
                            }, 

                            Package (0x04)
                            {
                                "PSTATE", 
                                0x12, 
                                Zero, 
                                0x02
                            }
                        }
                    }, 

                    Package (0x08)
                    {
                        "COMPONENT", 
                        0x19, 
                        ToUUID ("c150018b-1ed0-4d0d-9776-2a72fe3b6c13") /* Unknown UUID */, 
                        "FOOTSWITCH_OVERRIDE_F_STATES", 
                        Package (0x01)
                        {
                            "UNMANAGED"
                        }, 

                        0x02, 
                        Zero, 
                        Package (0x03)
                        {
                            "FSTATE_SET", 
                            Package (0x06)
                            {
                                "FSTATE", 
                                Zero, 
                                "ALL_ON", 
                                Zero, 
                                Zero, 
                                0x02
                            }, 

                            Package (0x06)
                            {
                                "FSTATE", 
                                One, 
                                "PWR_OFF", 
                                0x000186A0, 
                                One, 
                                One
                            }
                        }
                    }
                })
                Return (RBUF) /* \_SB_.GPU0.PMCL.RBUF */
            }

            Method (_ROM, 2, NotSerialized)  // _ROM: Read-Only Memory
            {
                Name (PCFG, Buffer (0x1334)
                {
                    /* 0000 */  0x3C, 0x3F, 0x78, 0x6D, 0x6C, 0x20, 0x76, 0x65,  // <?xml ve
                    /* 0008 */  0x72, 0x73, 0x69, 0x6F, 0x6E, 0x3D, 0x22, 0x31,  // rsion="1
                    /* 0010 */  0x2E, 0x30, 0x22, 0x20, 0x65, 0x6E, 0x63, 0x6F,  // .0" enco
                    /* 0018 */  0x64, 0x69, 0x6E, 0x67, 0x3D, 0x22, 0x75, 0x74,  // ding="ut
                    /* 0020 */  0x66, 0x2D, 0x38, 0x22, 0x3F, 0x3E, 0x0A, 0x20,  // f-8"?>. 
                    /* 0028 */  0x20, 0x20, 0x20, 0x3C, 0x50, 0x61, 0x6E, 0x65,  //    <Pane
                    /* 0030 */  0x6C, 0x4E, 0x61, 0x6D, 0x65, 0x3E, 0x54, 0x65,  // lName>Te
                    /* 0038 */  0x69, 0x73, 0x6B, 0x6F, 0x3C, 0x2F, 0x50, 0x61,  // isko</Pa
                    /* 0040 */  0x6E, 0x65, 0x6C, 0x4E, 0x61, 0x6D, 0x65, 0x3E,  // nelName>
                    /* 0048 */  0x0A, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x50, 0x61,  // .    <Pa
                    /* 0050 */  0x6E, 0x65, 0x6C, 0x44, 0x65, 0x73, 0x63, 0x72,  // nelDescr
                    /* 0058 */  0x69, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x3E, 0x54,  // iption>T
                    /* 0060 */  0x65, 0x69, 0x73, 0x6B, 0x6F, 0x20, 0x44, 0x53,  // eisko DS
                    /* 0068 */  0x49, 0x20, 0x50, 0x61, 0x6E, 0x65, 0x6C, 0x20,  // I Panel 
                    /* 0070 */  0x28, 0x34, 0x38, 0x30, 0x78, 0x38, 0x30, 0x30,  // (480x800
                    /* 0078 */  0x20, 0x32, 0x34, 0x62, 0x70, 0x70, 0x29, 0x3C,  //  24bpp)<
                    /* 0080 */  0x2F, 0x50, 0x61, 0x6E, 0x65, 0x6C, 0x44, 0x65,  // /PanelDe
                    /* 0088 */  0x73, 0x63, 0x72, 0x69, 0x70, 0x74, 0x69, 0x6F,  // scriptio
                    /* 0090 */  0x6E, 0x3E, 0x0A, 0x0A, 0x20, 0x20, 0x20, 0x20,  // n>..    
                    /* 0098 */  0x3C, 0x47, 0x72, 0x6F, 0x75, 0x70, 0x20, 0x69,  // <Group i
                    /* 00A0 */  0x64, 0x3D, 0x22, 0x45, 0x44, 0x49, 0x44, 0x20,  // d="EDID 
                    /* 00A8 */  0x43, 0x6F, 0x6E, 0x66, 0x69, 0x67, 0x75, 0x72,  // Configur
                    /* 00B0 */  0x61, 0x74, 0x69, 0x6F, 0x6E, 0x22, 0x3E, 0x0A,  // ation">.
                    /* 00B8 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 00C0 */  0x3C, 0x4D, 0x61, 0x6E, 0x75, 0x66, 0x61, 0x63,  // <Manufac
                    /* 00C8 */  0x74, 0x75, 0x72, 0x65, 0x49, 0x44, 0x3E, 0x30,  // tureID>0
                    /* 00D0 */  0x78, 0x42, 0x41, 0x44, 0x42, 0x41, 0x44, 0x3C,  // xBADBAD<
                    /* 00D8 */  0x2F, 0x4D, 0x61, 0x6E, 0x75, 0x66, 0x61, 0x63,  // /Manufac
                    /* 00E0 */  0x74, 0x75, 0x72, 0x65, 0x49, 0x44, 0x3E, 0x0A,  // tureID>.
                    /* 00E8 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 00F0 */  0x3C, 0x50, 0x72, 0x6F, 0x64, 0x75, 0x63, 0x74,  // <Product
                    /* 00F8 */  0x43, 0x6F, 0x64, 0x65, 0x3E, 0x30, 0x78, 0x36,  // Code>0x6
                    /* 0100 */  0x31, 0x30, 0x30, 0x3C, 0x2F, 0x50, 0x72, 0x6F,  // 100</Pro
                    /* 0108 */  0x64, 0x75, 0x63, 0x74, 0x43, 0x6F, 0x64, 0x65,  // ductCode
                    /* 0110 */  0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // >.      
                    /* 0118 */  0x20, 0x20, 0x3C, 0x53, 0x65, 0x72, 0x69, 0x61,  //   <Seria
                    /* 0120 */  0x6C, 0x4E, 0x75, 0x6D, 0x62, 0x65, 0x72, 0x3E,  // lNumber>
                    /* 0128 */  0x30, 0x78, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30,  // 0x000000
                    /* 0130 */  0x3C, 0x2F, 0x53, 0x65, 0x72, 0x69, 0x61, 0x6C,  // </Serial
                    /* 0138 */  0x4E, 0x75, 0x6D, 0x62, 0x65, 0x72, 0x3E, 0x0A,  // Number>.
                    /* 0140 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 0148 */  0x3C, 0x57, 0x65, 0x65, 0x6B, 0x6F, 0x66, 0x4D,  // <WeekofM
                    /* 0150 */  0x61, 0x6E, 0x75, 0x66, 0x61, 0x63, 0x74, 0x75,  // anufactu
                    /* 0158 */  0x72, 0x65, 0x3E, 0x30, 0x78, 0x30, 0x39, 0x3C,  // re>0x09<
                    /* 0160 */  0x2F, 0x57, 0x65, 0x65, 0x6B, 0x6F, 0x66, 0x4D,  // /WeekofM
                    /* 0168 */  0x61, 0x6E, 0x75, 0x66, 0x61, 0x63, 0x74, 0x75,  // anufactu
                    /* 0170 */  0x72, 0x65, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20,  // re>.    
                    /* 0178 */  0x20, 0x20, 0x20, 0x20, 0x3C, 0x59, 0x65, 0x61,  //     <Yea
                    /* 0180 */  0x72, 0x6F, 0x66, 0x4D, 0x61, 0x6E, 0x75, 0x66,  // rofManuf
                    /* 0188 */  0x61, 0x63, 0x74, 0x75, 0x72, 0x65, 0x3E, 0x30,  // acture>0
                    /* 0190 */  0x78, 0x31, 0x33, 0x3C, 0x2F, 0x59, 0x65, 0x61,  // x13</Yea
                    /* 0198 */  0x72, 0x6F, 0x66, 0x4D, 0x61, 0x6E, 0x75, 0x66,  // rofManuf
                    /* 01A0 */  0x61, 0x63, 0x74, 0x75, 0x72, 0x65, 0x3E, 0x0A,  // acture>.
                    /* 01A8 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 01B0 */  0x3C, 0x45, 0x44, 0x49, 0x44, 0x56, 0x65, 0x72,  // <EDIDVer
                    /* 01B8 */  0x73, 0x69, 0x6F, 0x6E, 0x3E, 0x31, 0x3C, 0x2F,  // sion>1</
                    /* 01C0 */  0x45, 0x44, 0x49, 0x44, 0x56, 0x65, 0x72, 0x73,  // EDIDVers
                    /* 01C8 */  0x69, 0x6F, 0x6E, 0x3E, 0x0A, 0x20, 0x20, 0x20,  // ion>.   
                    /* 01D0 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x45, 0x44,  //      <ED
                    /* 01D8 */  0x49, 0x44, 0x52, 0x65, 0x76, 0x69, 0x73, 0x69,  // IDRevisi
                    /* 01E0 */  0x6F, 0x6E, 0x3E, 0x33, 0x3C, 0x2F, 0x45, 0x44,  // on>3</ED
                    /* 01E8 */  0x49, 0x44, 0x52, 0x65, 0x76, 0x69, 0x73, 0x69,  // IDRevisi
                    /* 01F0 */  0x6F, 0x6E, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20,  // on>.    
                    /* 01F8 */  0x20, 0x20, 0x20, 0x20, 0x3C, 0x56, 0x69, 0x64,  //     <Vid
                    /* 0200 */  0x65, 0x6F, 0x49, 0x6E, 0x70, 0x75, 0x74, 0x44,  // eoInputD
                    /* 0208 */  0x65, 0x66, 0x69, 0x6E, 0x69, 0x74, 0x69, 0x6F,  // efinitio
                    /* 0210 */  0x6E, 0x3E, 0x30, 0x78, 0x38, 0x30, 0x3C, 0x2F,  // n>0x80</
                    /* 0218 */  0x56, 0x69, 0x64, 0x65, 0x6F, 0x49, 0x6E, 0x70,  // VideoInp
                    /* 0220 */  0x75, 0x74, 0x44, 0x65, 0x66, 0x69, 0x6E, 0x69,  // utDefini
                    /* 0228 */  0x74, 0x69, 0x6F, 0x6E, 0x3E, 0x0A, 0x20, 0x20,  // tion>.  
                    /* 0230 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x48,  //       <H
                    /* 0238 */  0x6F, 0x72, 0x69, 0x7A, 0x6F, 0x6E, 0x74, 0x61,  // orizonta
                    /* 0240 */  0x6C, 0x53, 0x63, 0x72, 0x65, 0x65, 0x6E, 0x53,  // lScreenS
                    /* 0248 */  0x69, 0x7A, 0x65, 0x3E, 0x30, 0x78, 0x35, 0x3C,  // ize>0x5<
                    /* 0250 */  0x2F, 0x48, 0x6F, 0x72, 0x69, 0x7A, 0x6F, 0x6E,  // /Horizon
                    /* 0258 */  0x74, 0x61, 0x6C, 0x53, 0x63, 0x72, 0x65, 0x65,  // talScree
                    /* 0260 */  0x6E, 0x53, 0x69, 0x7A, 0x65, 0x3E, 0x0A, 0x20,  // nSize>. 
                    /* 0268 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C,  //        <
                    /* 0270 */  0x56, 0x65, 0x72, 0x74, 0x69, 0x63, 0x61, 0x6C,  // Vertical
                    /* 0278 */  0x53, 0x63, 0x72, 0x65, 0x65, 0x6E, 0x53, 0x69,  // ScreenSi
                    /* 0280 */  0x7A, 0x65, 0x3E, 0x30, 0x78, 0x30, 0x39, 0x3C,  // ze>0x09<
                    /* 0288 */  0x2F, 0x56, 0x65, 0x72, 0x74, 0x69, 0x63, 0x61,  // /Vertica
                    /* 0290 */  0x6C, 0x53, 0x63, 0x72, 0x65, 0x65, 0x6E, 0x53,  // lScreenS
                    /* 0298 */  0x69, 0x7A, 0x65, 0x3E, 0x0A, 0x20, 0x20, 0x20,  // ize>.   
                    /* 02A0 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x44, 0x69,  //      <Di
                    /* 02A8 */  0x73, 0x70, 0x6C, 0x61, 0x79, 0x54, 0x72, 0x61,  // splayTra
                    /* 02B0 */  0x6E, 0x73, 0x66, 0x65, 0x72, 0x43, 0x68, 0x61,  // nsferCha
                    /* 02B8 */  0x72, 0x61, 0x63, 0x74, 0x65, 0x72, 0x69, 0x73,  // racteris
                    /* 02C0 */  0x74, 0x69, 0x63, 0x73, 0x3E, 0x30, 0x78, 0x37,  // tics>0x7
                    /* 02C8 */  0x38, 0x3C, 0x2F, 0x44, 0x69, 0x73, 0x70, 0x6C,  // 8</Displ
                    /* 02D0 */  0x61, 0x79, 0x54, 0x72, 0x61, 0x6E, 0x73, 0x66,  // ayTransf
                    /* 02D8 */  0x65, 0x72, 0x43, 0x68, 0x61, 0x72, 0x61, 0x63,  // erCharac
                    /* 02E0 */  0x74, 0x65, 0x72, 0x69, 0x73, 0x74, 0x69, 0x63,  // teristic
                    /* 02E8 */  0x73, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // s>.     
                    /* 02F0 */  0x20, 0x20, 0x20, 0x3C, 0x46, 0x65, 0x61, 0x74,  //    <Feat
                    /* 02F8 */  0x75, 0x72, 0x65, 0x53, 0x75, 0x70, 0x70, 0x6F,  // ureSuppo
                    /* 0300 */  0x72, 0x74, 0x3E, 0x30, 0x78, 0x41, 0x3C, 0x2F,  // rt>0xA</
                    /* 0308 */  0x46, 0x65, 0x61, 0x74, 0x75, 0x72, 0x65, 0x53,  // FeatureS
                    /* 0310 */  0x75, 0x70, 0x70, 0x6F, 0x72, 0x74, 0x3E, 0x0A,  // upport>.
                    /* 0318 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 0320 */  0x3C, 0x52, 0x65, 0x64, 0x2E, 0x47, 0x72, 0x65,  // <Red.Gre
                    /* 0328 */  0x65, 0x6E, 0x42, 0x69, 0x74, 0x73, 0x3E, 0x30,  // enBits>0
                    /* 0330 */  0x78, 0x43, 0x46, 0x3C, 0x2F, 0x52, 0x65, 0x64,  // xCF</Red
                    /* 0338 */  0x2E, 0x47, 0x72, 0x65, 0x65, 0x6E, 0x42, 0x69,  // .GreenBi
                    /* 0340 */  0x74, 0x73, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20,  // ts>.    
                    /* 0348 */  0x20, 0x20, 0x20, 0x20, 0x3C, 0x42, 0x6C, 0x75,  //     <Blu
                    /* 0350 */  0x65, 0x2E, 0x57, 0x68, 0x69, 0x74, 0x65, 0x42,  // e.WhiteB
                    /* 0358 */  0x69, 0x74, 0x73, 0x3E, 0x30, 0x78, 0x34, 0x35,  // its>0x45
                    /* 0360 */  0x3C, 0x2F, 0x42, 0x6C, 0x75, 0x65, 0x2E, 0x57,  // </Blue.W
                    /* 0368 */  0x68, 0x69, 0x74, 0x65, 0x42, 0x69, 0x74, 0x73,  // hiteBits
                    /* 0370 */  0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // >.      
                    /* 0378 */  0x20, 0x20, 0x3C, 0x52, 0x65, 0x64, 0x58, 0x3E,  //   <RedX>
                    /* 0380 */  0x30, 0x78, 0x39, 0x30, 0x3C, 0x2F, 0x52, 0x65,  // 0x90</Re
                    /* 0388 */  0x64, 0x58, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20,  // dX>.    
                    /* 0390 */  0x20, 0x20, 0x20, 0x20, 0x3C, 0x52, 0x65, 0x64,  //     <Red
                    /* 0398 */  0x59, 0x3E, 0x30, 0x78, 0x35, 0x39, 0x3C, 0x2F,  // Y>0x59</
                    /* 03A0 */  0x52, 0x65, 0x64, 0x59, 0x3E, 0x0A, 0x20, 0x20,  // RedY>.  
                    /* 03A8 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x47,  //       <G
                    /* 03B0 */  0x72, 0x65, 0x65, 0x6E, 0x58, 0x3E, 0x30, 0x78,  // reenX>0x
                    /* 03B8 */  0x35, 0x37, 0x3C, 0x2F, 0x47, 0x72, 0x65, 0x65,  // 57</Gree
                    /* 03C0 */  0x6E, 0x58, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20,  // nX>.    
                    /* 03C8 */  0x20, 0x20, 0x20, 0x20, 0x3C, 0x47, 0x72, 0x65,  //     <Gre
                    /* 03D0 */  0x65, 0x6E, 0x59, 0x3E, 0x30, 0x78, 0x39, 0x35,  // enY>0x95
                    /* 03D8 */  0x3C, 0x2F, 0x47, 0x72, 0x65, 0x65, 0x6E, 0x59,  // </GreenY
                    /* 03E0 */  0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // >.      
                    /* 03E8 */  0x20, 0x20, 0x3C, 0x42, 0x6C, 0x75, 0x65, 0x58,  //   <BlueX
                    /* 03F0 */  0x3E, 0x30, 0x78, 0x32, 0x39, 0x3C, 0x2F, 0x42,  // >0x29</B
                    /* 03F8 */  0x6C, 0x75, 0x65, 0x58, 0x3E, 0x0A, 0x20, 0x20,  // lueX>.  
                    /* 0400 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x42,  //       <B
                    /* 0408 */  0x6C, 0x75, 0x65, 0x59, 0x3E, 0x30, 0x78, 0x31,  // lueY>0x1
                    /* 0410 */  0x66, 0x3C, 0x2F, 0x42, 0x6C, 0x75, 0x65, 0x59,  // f</BlueY
                    /* 0418 */  0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // >.      
                    /* 0420 */  0x20, 0x20, 0x3C, 0x57, 0x68, 0x69, 0x74, 0x65,  //   <White
                    /* 0428 */  0x58, 0x3E, 0x30, 0x78, 0x35, 0x30, 0x3C, 0x2F,  // X>0x50</
                    /* 0430 */  0x57, 0x68, 0x69, 0x74, 0x65, 0x58, 0x3E, 0x0A,  // WhiteX>.
                    /* 0438 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 0440 */  0x3C, 0x57, 0x68, 0x69, 0x74, 0x65, 0x59, 0x3E,  // <WhiteY>
                    /* 0448 */  0x30, 0x78, 0x35, 0x34, 0x3C, 0x2F, 0x57, 0x68,  // 0x54</Wh
                    /* 0450 */  0x69, 0x74, 0x65, 0x59, 0x3E, 0x0A, 0x20, 0x20,  // iteY>.  
                    /* 0458 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x45,  //       <E
                    /* 0460 */  0x73, 0x74, 0x61, 0x62, 0x6C, 0x69, 0x73, 0x68,  // stablish
                    /* 0468 */  0x65, 0x64, 0x54, 0x69, 0x6D, 0x69, 0x6E, 0x67,  // edTiming
                    /* 0470 */  0x73, 0x49, 0x3E, 0x30, 0x78, 0x30, 0x3C, 0x2F,  // sI>0x0</
                    /* 0478 */  0x45, 0x73, 0x74, 0x61, 0x62, 0x6C, 0x69, 0x73,  // Establis
                    /* 0480 */  0x68, 0x65, 0x64, 0x54, 0x69, 0x6D, 0x69, 0x6E,  // hedTimin
                    /* 0488 */  0x67, 0x73, 0x49, 0x3E, 0x0A, 0x20, 0x20, 0x20,  // gsI>.   
                    /* 0490 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x45, 0x73,  //      <Es
                    /* 0498 */  0x74, 0x61, 0x62, 0x6C, 0x69, 0x73, 0x68, 0x65,  // tablishe
                    /* 04A0 */  0x64, 0x54, 0x69, 0x6D, 0x69, 0x6E, 0x67, 0x73,  // dTimings
                    /* 04A8 */  0x49, 0x49, 0x3E, 0x30, 0x78, 0x30, 0x3C, 0x2F,  // II>0x0</
                    /* 04B0 */  0x45, 0x73, 0x74, 0x61, 0x62, 0x6C, 0x69, 0x73,  // Establis
                    /* 04B8 */  0x68, 0x65, 0x64, 0x54, 0x69, 0x6D, 0x69, 0x6E,  // hedTimin
                    /* 04C0 */  0x67, 0x73, 0x49, 0x49, 0x3E, 0x0A, 0x20, 0x20,  // gsII>.  
                    /* 04C8 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x4D,  //       <M
                    /* 04D0 */  0x61, 0x6E, 0x75, 0x66, 0x61, 0x63, 0x74, 0x75,  // anufactu
                    /* 04D8 */  0x72, 0x65, 0x73, 0x54, 0x69, 0x6D, 0x69, 0x6E,  // resTimin
                    /* 04E0 */  0x67, 0x3E, 0x30, 0x78, 0x30, 0x3C, 0x2F, 0x4D,  // g>0x0</M
                    /* 04E8 */  0x61, 0x6E, 0x75, 0x66, 0x61, 0x63, 0x74, 0x75,  // anufactu
                    /* 04F0 */  0x72, 0x65, 0x73, 0x54, 0x69, 0x6D, 0x69, 0x6E,  // resTimin
                    /* 04F8 */  0x67, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // g>.     
                    /* 0500 */  0x20, 0x20, 0x20, 0x3C, 0x53, 0x74, 0x61, 0x6E,  //    <Stan
                    /* 0508 */  0x64, 0x61, 0x72, 0x64, 0x54, 0x69, 0x6D, 0x69,  // dardTimi
                    /* 0510 */  0x6E, 0x67, 0x73, 0x31, 0x2F, 0x3E, 0x0A, 0x20,  // ngs1/>. 
                    /* 0518 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C,  //        <
                    /* 0520 */  0x53, 0x74, 0x61, 0x6E, 0x64, 0x61, 0x72, 0x64,  // Standard
                    /* 0528 */  0x54, 0x69, 0x6D, 0x69, 0x6E, 0x67, 0x73, 0x32,  // Timings2
                    /* 0530 */  0x2F, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // />.     
                    /* 0538 */  0x20, 0x20, 0x20, 0x3C, 0x53, 0x74, 0x61, 0x6E,  //    <Stan
                    /* 0540 */  0x64, 0x61, 0x72, 0x64, 0x54, 0x69, 0x6D, 0x69,  // dardTimi
                    /* 0548 */  0x6E, 0x67, 0x73, 0x33, 0x2F, 0x3E, 0x0A, 0x20,  // ngs3/>. 
                    /* 0550 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C,  //        <
                    /* 0558 */  0x53, 0x74, 0x61, 0x6E, 0x64, 0x61, 0x72, 0x64,  // Standard
                    /* 0560 */  0x54, 0x69, 0x6D, 0x69, 0x6E, 0x67, 0x73, 0x34,  // Timings4
                    /* 0568 */  0x2F, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // />.     
                    /* 0570 */  0x20, 0x20, 0x20, 0x3C, 0x53, 0x74, 0x61, 0x6E,  //    <Stan
                    /* 0578 */  0x64, 0x61, 0x72, 0x64, 0x54, 0x69, 0x6D, 0x69,  // dardTimi
                    /* 0580 */  0x6E, 0x67, 0x73, 0x35, 0x2F, 0x3E, 0x0A, 0x20,  // ngs5/>. 
                    /* 0588 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C,  //        <
                    /* 0590 */  0x53, 0x74, 0x61, 0x6E, 0x64, 0x61, 0x72, 0x64,  // Standard
                    /* 0598 */  0x54, 0x69, 0x6D, 0x69, 0x6E, 0x67, 0x73, 0x36,  // Timings6
                    /* 05A0 */  0x2F, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // />.     
                    /* 05A8 */  0x20, 0x20, 0x20, 0x3C, 0x53, 0x74, 0x61, 0x6E,  //    <Stan
                    /* 05B0 */  0x64, 0x61, 0x72, 0x64, 0x54, 0x69, 0x6D, 0x69,  // dardTimi
                    /* 05B8 */  0x6E, 0x67, 0x73, 0x37, 0x2F, 0x3E, 0x0A, 0x20,  // ngs7/>. 
                    /* 05C0 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C,  //        <
                    /* 05C8 */  0x53, 0x69, 0x67, 0x6E, 0x61, 0x6C, 0x54, 0x69,  // SignalTi
                    /* 05D0 */  0x6D, 0x69, 0x6E, 0x67, 0x49, 0x6E, 0x74, 0x65,  // mingInte
                    /* 05D8 */  0x72, 0x66, 0x61, 0x63, 0x65, 0x2F, 0x3E, 0x0A,  // rface/>.
                    /* 05E0 */  0x20, 0x20, 0x20, 0x20, 0x3C, 0x2F, 0x47, 0x72,  //     </Gr
                    /* 05E8 */  0x6F, 0x75, 0x70, 0x3E, 0x0A, 0x0A, 0x20, 0x20,  // oup>..  
                    /* 05F0 */  0x20, 0x20, 0x3C, 0x47, 0x72, 0x6F, 0x75, 0x70,  //   <Group
                    /* 05F8 */  0x20, 0x69, 0x64, 0x3D, 0x22, 0x41, 0x63, 0x74,  //  id="Act
                    /* 0600 */  0x69, 0x76, 0x65, 0x20, 0x54, 0x69, 0x6D, 0x69,  // ive Timi
                    /* 0608 */  0x6E, 0x67, 0x22, 0x3E, 0x0A, 0x20, 0x20, 0x20,  // ng">.   
                    /* 0610 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x52, 0x65,  //      <Re
                    /* 0618 */  0x70, 0x6F, 0x72, 0x74, 0x65, 0x64, 0x50, 0x69,  // portedPi
                    /* 0620 */  0x78, 0x65, 0x6C, 0x43, 0x6C, 0x6F, 0x63, 0x6B,  // xelClock
                    /* 0628 */  0x46, 0x72, 0x65, 0x71, 0x75, 0x65, 0x6E, 0x63,  // Frequenc
                    /* 0630 */  0x79, 0x20, 0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D,  // y units=
                    /* 0638 */  0x22, 0x48, 0x7A, 0x22, 0x3E, 0x35, 0x32, 0x35,  // "Hz">525
                    /* 0640 */  0x39, 0x38, 0x37, 0x30, 0x30, 0x3C, 0x2F, 0x52,  // 98700</R
                    /* 0648 */  0x65, 0x70, 0x6F, 0x72, 0x74, 0x65, 0x64, 0x50,  // eportedP
                    /* 0650 */  0x69, 0x78, 0x65, 0x6C, 0x43, 0x6C, 0x6F, 0x63,  // ixelCloc
                    /* 0658 */  0x6B, 0x46, 0x72, 0x65, 0x71, 0x75, 0x65, 0x6E,  // kFrequen
                    /* 0660 */  0x63, 0x79, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20,  // cy>.    
                    /* 0668 */  0x20, 0x20, 0x20, 0x20, 0x3C, 0x50, 0x69, 0x78,  //     <Pix
                    /* 0670 */  0x65, 0x6C, 0x43, 0x6C, 0x6F, 0x63, 0x6B, 0x46,  // elClockF
                    /* 0678 */  0x72, 0x65, 0x71, 0x75, 0x65, 0x6E, 0x63, 0x79,  // requency
                    /* 0680 */  0x20, 0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22,  //  units="
                    /* 0688 */  0x48, 0x7A, 0x22, 0x3E, 0x35, 0x32, 0x35, 0x39,  // Hz">5259
                    /* 0690 */  0x38, 0x37, 0x30, 0x30, 0x3C, 0x2F, 0x50, 0x69,  // 8700</Pi
                    /* 0698 */  0x78, 0x65, 0x6C, 0x43, 0x6C, 0x6F, 0x63, 0x6B,  // xelClock
                    /* 06A0 */  0x46, 0x72, 0x65, 0x71, 0x75, 0x65, 0x6E, 0x63,  // Frequenc
                    /* 06A8 */  0x79, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // y>.     
                    /* 06B0 */  0x20, 0x20, 0x20, 0x3C, 0x48, 0x6F, 0x72, 0x69,  //    <Hori
                    /* 06B8 */  0x7A, 0x6F, 0x6E, 0x74, 0x61, 0x6C, 0x41, 0x63,  // zontalAc
                    /* 06C0 */  0x74, 0x69, 0x76, 0x65, 0x20, 0x75, 0x6E, 0x69,  // tive uni
                    /* 06C8 */  0x74, 0x73, 0x3D, 0x22, 0x44, 0x6F, 0x74, 0x20,  // ts="Dot 
                    /* 06D0 */  0x43, 0x6C, 0x6F, 0x63, 0x6B, 0x73, 0x22, 0x3E,  // Clocks">
                    /* 06D8 */  0x34, 0x38, 0x30, 0x3C, 0x2F, 0x48, 0x6F, 0x72,  // 480</Hor
                    /* 06E0 */  0x69, 0x7A, 0x6F, 0x6E, 0x74, 0x61, 0x6C, 0x41,  // izontalA
                    /* 06E8 */  0x63, 0x74, 0x69, 0x76, 0x65, 0x3E, 0x0A, 0x20,  // ctive>. 
                    /* 06F0 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C,  //        <
                    /* 06F8 */  0x48, 0x6F, 0x72, 0x69, 0x7A, 0x6F, 0x6E, 0x74,  // Horizont
                    /* 0700 */  0x61, 0x6C, 0x46, 0x72, 0x6F, 0x6E, 0x74, 0x50,  // alFrontP
                    /* 0708 */  0x6F, 0x72, 0x63, 0x68, 0x20, 0x75, 0x6E, 0x69,  // orch uni
                    /* 0710 */  0x74, 0x73, 0x3D, 0x22, 0x44, 0x6F, 0x74, 0x20,  // ts="Dot 
                    /* 0718 */  0x43, 0x6C, 0x6F, 0x63, 0x6B, 0x73, 0x22, 0x3E,  // Clocks">
                    /* 0720 */  0x32, 0x33, 0x3C, 0x2F, 0x48, 0x6F, 0x72, 0x69,  // 23</Hori
                    /* 0728 */  0x7A, 0x6F, 0x6E, 0x74, 0x61, 0x6C, 0x46, 0x72,  // zontalFr
                    /* 0730 */  0x6F, 0x6E, 0x74, 0x50, 0x6F, 0x72, 0x63, 0x68,  // ontPorch
                    /* 0738 */  0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // >.      
                    /* 0740 */  0x20, 0x20, 0x3C, 0x48, 0x6F, 0x72, 0x69, 0x7A,  //   <Horiz
                    /* 0748 */  0x6F, 0x6E, 0x74, 0x61, 0x6C, 0x42, 0x61, 0x63,  // ontalBac
                    /* 0750 */  0x6B, 0x50, 0x6F, 0x72, 0x63, 0x68, 0x20, 0x75,  // kPorch u
                    /* 0758 */  0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x44, 0x6F,  // nits="Do
                    /* 0760 */  0x74, 0x20, 0x43, 0x6C, 0x6F, 0x63, 0x6B, 0x73,  // t Clocks
                    /* 0768 */  0x22, 0x3E, 0x31, 0x36, 0x3C, 0x2F, 0x48, 0x6F,  // ">16</Ho
                    /* 0770 */  0x72, 0x69, 0x7A, 0x6F, 0x6E, 0x74, 0x61, 0x6C,  // rizontal
                    /* 0778 */  0x42, 0x61, 0x63, 0x6B, 0x50, 0x6F, 0x72, 0x63,  // BackPorc
                    /* 0780 */  0x68, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // h>.     
                    /* 0788 */  0x20, 0x20, 0x20, 0x3C, 0x48, 0x6F, 0x72, 0x69,  //    <Hori
                    /* 0790 */  0x7A, 0x6F, 0x6E, 0x74, 0x61, 0x6C, 0x53, 0x79,  // zontalSy
                    /* 0798 */  0x6E, 0x63, 0x50, 0x75, 0x6C, 0x73, 0x65, 0x20,  // ncPulse 
                    /* 07A0 */  0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x44,  // units="D
                    /* 07A8 */  0x6F, 0x74, 0x20, 0x43, 0x6C, 0x6F, 0x63, 0x6B,  // ot Clock
                    /* 07B0 */  0x73, 0x22, 0x3E, 0x38, 0x3C, 0x2F, 0x48, 0x6F,  // s">8</Ho
                    /* 07B8 */  0x72, 0x69, 0x7A, 0x6F, 0x6E, 0x74, 0x61, 0x6C,  // rizontal
                    /* 07C0 */  0x53, 0x79, 0x6E, 0x63, 0x50, 0x75, 0x6C, 0x73,  // SyncPuls
                    /* 07C8 */  0x65, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // e>.     
                    /* 07D0 */  0x20, 0x20, 0x20, 0x3C, 0x48, 0x6F, 0x72, 0x69,  //    <Hori
                    /* 07D8 */  0x7A, 0x6F, 0x6E, 0x74, 0x61, 0x6C, 0x53, 0x79,  // zontalSy
                    /* 07E0 */  0x6E, 0x63, 0x53, 0x6B, 0x65, 0x77, 0x20, 0x75,  // ncSkew u
                    /* 07E8 */  0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x44, 0x6F,  // nits="Do
                    /* 07F0 */  0x74, 0x20, 0x43, 0x6C, 0x6F, 0x63, 0x6B, 0x73,  // t Clocks
                    /* 07F8 */  0x22, 0x3E, 0x30, 0x3C, 0x2F, 0x48, 0x6F, 0x72,  // ">0</Hor
                    /* 0800 */  0x69, 0x7A, 0x6F, 0x6E, 0x74, 0x61, 0x6C, 0x53,  // izontalS
                    /* 0808 */  0x79, 0x6E, 0x63, 0x53, 0x6B, 0x65, 0x77, 0x3E,  // yncSkew>
                    /* 0810 */  0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // .       
                    /* 0818 */  0x20, 0x3C, 0x48, 0x6F, 0x72, 0x69, 0x7A, 0x6F,  //  <Horizo
                    /* 0820 */  0x6E, 0x74, 0x61, 0x6C, 0x4C, 0x65, 0x66, 0x74,  // ntalLeft
                    /* 0828 */  0x42, 0x6F, 0x72, 0x64, 0x65, 0x72, 0x20, 0x75,  // Border u
                    /* 0830 */  0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x44, 0x6F,  // nits="Do
                    /* 0838 */  0x74, 0x20, 0x43, 0x6C, 0x6F, 0x63, 0x6B, 0x73,  // t Clocks
                    /* 0840 */  0x22, 0x3E, 0x30, 0x3C, 0x2F, 0x48, 0x6F, 0x72,  // ">0</Hor
                    /* 0848 */  0x69, 0x7A, 0x6F, 0x6E, 0x74, 0x61, 0x6C, 0x4C,  // izontalL
                    /* 0850 */  0x65, 0x66, 0x74, 0x42, 0x6F, 0x72, 0x64, 0x65,  // eftBorde
                    /* 0858 */  0x72, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // r>.     
                    /* 0860 */  0x20, 0x20, 0x20, 0x3C, 0x48, 0x6F, 0x72, 0x69,  //    <Hori
                    /* 0868 */  0x7A, 0x6F, 0x6E, 0x74, 0x61, 0x6C, 0x52, 0x69,  // zontalRi
                    /* 0870 */  0x67, 0x68, 0x74, 0x42, 0x6F, 0x72, 0x64, 0x65,  // ghtBorde
                    /* 0878 */  0x72, 0x20, 0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D,  // r units=
                    /* 0880 */  0x22, 0x44, 0x6F, 0x74, 0x20, 0x43, 0x6C, 0x6F,  // "Dot Clo
                    /* 0888 */  0x63, 0x6B, 0x73, 0x22, 0x3E, 0x30, 0x3C, 0x2F,  // cks">0</
                    /* 0890 */  0x48, 0x6F, 0x72, 0x69, 0x7A, 0x6F, 0x6E, 0x74,  // Horizont
                    /* 0898 */  0x61, 0x6C, 0x52, 0x69, 0x67, 0x68, 0x74, 0x42,  // alRightB
                    /* 08A0 */  0x6F, 0x72, 0x64, 0x65, 0x72, 0x3E, 0x0A, 0x20,  // order>. 
                    /* 08A8 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C,  //        <
                    /* 08B0 */  0x56, 0x65, 0x72, 0x74, 0x69, 0x63, 0x61, 0x6C,  // Vertical
                    /* 08B8 */  0x41, 0x63, 0x74, 0x69, 0x76, 0x65, 0x20, 0x75,  // Active u
                    /* 08C0 */  0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x44, 0x6F,  // nits="Do
                    /* 08C8 */  0x74, 0x20, 0x43, 0x6C, 0x6F, 0x63, 0x6B, 0x73,  // t Clocks
                    /* 08D0 */  0x22, 0x3E, 0x38, 0x30, 0x30, 0x3C, 0x2F, 0x56,  // ">800</V
                    /* 08D8 */  0x65, 0x72, 0x74, 0x69, 0x63, 0x61, 0x6C, 0x41,  // erticalA
                    /* 08E0 */  0x63, 0x74, 0x69, 0x76, 0x65, 0x3E, 0x0A, 0x20,  // ctive>. 
                    /* 08E8 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C,  //        <
                    /* 08F0 */  0x56, 0x65, 0x72, 0x74, 0x69, 0x63, 0x61, 0x6C,  // Vertical
                    /* 08F8 */  0x46, 0x72, 0x6F, 0x6E, 0x74, 0x50, 0x6F, 0x72,  // FrontPor
                    /* 0900 */  0x63, 0x68, 0x20, 0x75, 0x6E, 0x69, 0x74, 0x73,  // ch units
                    /* 0908 */  0x3D, 0x22, 0x4C, 0x69, 0x6E, 0x65, 0x73, 0x22,  // ="Lines"
                    /* 0910 */  0x3E, 0x37, 0x3C, 0x2F, 0x56, 0x65, 0x72, 0x74,  // >7</Vert
                    /* 0918 */  0x69, 0x63, 0x61, 0x6C, 0x46, 0x72, 0x6F, 0x6E,  // icalFron
                    /* 0920 */  0x74, 0x50, 0x6F, 0x72, 0x63, 0x68, 0x3E, 0x0A,  // tPorch>.
                    /* 0928 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 0930 */  0x3C, 0x56, 0x65, 0x72, 0x74, 0x69, 0x63, 0x61,  // <Vertica
                    /* 0938 */  0x6C, 0x42, 0x61, 0x63, 0x6B, 0x50, 0x6F, 0x72,  // lBackPor
                    /* 0940 */  0x63, 0x68, 0x20, 0x75, 0x6E, 0x69, 0x74, 0x73,  // ch units
                    /* 0948 */  0x3D, 0x22, 0x4C, 0x69, 0x6E, 0x65, 0x73, 0x22,  // ="Lines"
                    /* 0950 */  0x3E, 0x32, 0x3C, 0x2F, 0x56, 0x65, 0x72, 0x74,  // >2</Vert
                    /* 0958 */  0x69, 0x63, 0x61, 0x6C, 0x42, 0x61, 0x63, 0x6B,  // icalBack
                    /* 0960 */  0x50, 0x6F, 0x72, 0x63, 0x68, 0x3E, 0x0A, 0x20,  // Porch>. 
                    /* 0968 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C,  //        <
                    /* 0970 */  0x56, 0x65, 0x72, 0x74, 0x69, 0x63, 0x61, 0x6C,  // Vertical
                    /* 0978 */  0x53, 0x79, 0x6E, 0x63, 0x50, 0x75, 0x6C, 0x73,  // SyncPuls
                    /* 0980 */  0x65, 0x20, 0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D,  // e units=
                    /* 0988 */  0x22, 0x4C, 0x69, 0x6E, 0x65, 0x73, 0x22, 0x3E,  // "Lines">
                    /* 0990 */  0x32, 0x3C, 0x2F, 0x56, 0x65, 0x72, 0x74, 0x69,  // 2</Verti
                    /* 0998 */  0x63, 0x61, 0x6C, 0x53, 0x79, 0x6E, 0x63, 0x50,  // calSyncP
                    /* 09A0 */  0x75, 0x6C, 0x73, 0x65, 0x3E, 0x0A, 0x20, 0x20,  // ulse>.  
                    /* 09A8 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x56,  //       <V
                    /* 09B0 */  0x65, 0x72, 0x74, 0x69, 0x63, 0x61, 0x6C, 0x53,  // erticalS
                    /* 09B8 */  0x79, 0x6E, 0x63, 0x53, 0x6B, 0x65, 0x77, 0x20,  // yncSkew 
                    /* 09C0 */  0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x4C,  // units="L
                    /* 09C8 */  0x69, 0x6E, 0x65, 0x73, 0x22, 0x3E, 0x30, 0x3C,  // ines">0<
                    /* 09D0 */  0x2F, 0x56, 0x65, 0x72, 0x74, 0x69, 0x63, 0x61,  // /Vertica
                    /* 09D8 */  0x6C, 0x53, 0x79, 0x6E, 0x63, 0x53, 0x6B, 0x65,  // lSyncSke
                    /* 09E0 */  0x77, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // w>.     
                    /* 09E8 */  0x20, 0x20, 0x20, 0x3C, 0x56, 0x65, 0x72, 0x74,  //    <Vert
                    /* 09F0 */  0x69, 0x63, 0x61, 0x6C, 0x54, 0x6F, 0x70, 0x42,  // icalTopB
                    /* 09F8 */  0x6F, 0x72, 0x64, 0x65, 0x72, 0x20, 0x75, 0x6E,  // order un
                    /* 0A00 */  0x69, 0x74, 0x73, 0x3D, 0x22, 0x4C, 0x69, 0x6E,  // its="Lin
                    /* 0A08 */  0x65, 0x73, 0x22, 0x3E, 0x30, 0x3C, 0x2F, 0x56,  // es">0</V
                    /* 0A10 */  0x65, 0x72, 0x74, 0x69, 0x63, 0x61, 0x6C, 0x54,  // erticalT
                    /* 0A18 */  0x6F, 0x70, 0x42, 0x6F, 0x72, 0x64, 0x65, 0x72,  // opBorder
                    /* 0A20 */  0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // >.      
                    /* 0A28 */  0x20, 0x20, 0x3C, 0x56, 0x65, 0x72, 0x74, 0x69,  //   <Verti
                    /* 0A30 */  0x63, 0x61, 0x6C, 0x42, 0x6F, 0x74, 0x74, 0x6F,  // calBotto
                    /* 0A38 */  0x6D, 0x42, 0x6F, 0x72, 0x64, 0x65, 0x72, 0x20,  // mBorder 
                    /* 0A40 */  0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x4C,  // units="L
                    /* 0A48 */  0x69, 0x6E, 0x65, 0x73, 0x22, 0x3E, 0x30, 0x3C,  // ines">0<
                    /* 0A50 */  0x2F, 0x56, 0x65, 0x72, 0x74, 0x69, 0x63, 0x61,  // /Vertica
                    /* 0A58 */  0x6C, 0x42, 0x6F, 0x74, 0x74, 0x6F, 0x6D, 0x42,  // lBottomB
                    /* 0A60 */  0x6F, 0x72, 0x64, 0x65, 0x72, 0x3E, 0x0A, 0x20,  // order>. 
                    /* 0A68 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C,  //        <
                    /* 0A70 */  0x49, 0x6E, 0x76, 0x65, 0x72, 0x74, 0x44, 0x61,  // InvertDa
                    /* 0A78 */  0x74, 0x61, 0x50, 0x6F, 0x6C, 0x61, 0x72, 0x69,  // taPolari
                    /* 0A80 */  0x74, 0x79, 0x3E, 0x46, 0x61, 0x6C, 0x73, 0x65,  // ty>False
                    /* 0A88 */  0x3C, 0x2F, 0x49, 0x6E, 0x76, 0x65, 0x72, 0x74,  // </Invert
                    /* 0A90 */  0x44, 0x61, 0x74, 0x61, 0x50, 0x6F, 0x6C, 0x61,  // DataPola
                    /* 0A98 */  0x72, 0x69, 0x74, 0x79, 0x3E, 0x0A, 0x20, 0x20,  // rity>.  
                    /* 0AA0 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x49,  //       <I
                    /* 0AA8 */  0x6E, 0x76, 0x65, 0x72, 0x74, 0x56, 0x73, 0x79,  // nvertVsy
                    /* 0AB0 */  0x6E, 0x63, 0x50, 0x6F, 0x6C, 0x61, 0x69, 0x72,  // ncPolair
                    /* 0AB8 */  0x74, 0x79, 0x3E, 0x46, 0x61, 0x6C, 0x73, 0x65,  // ty>False
                    /* 0AC0 */  0x3C, 0x2F, 0x49, 0x6E, 0x76, 0x65, 0x72, 0x74,  // </Invert
                    /* 0AC8 */  0x56, 0x73, 0x79, 0x6E, 0x63, 0x50, 0x6F, 0x6C,  // VsyncPol
                    /* 0AD0 */  0x61, 0x69, 0x72, 0x74, 0x79, 0x3E, 0x0A, 0x20,  // airty>. 
                    /* 0AD8 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C,  //        <
                    /* 0AE0 */  0x49, 0x6E, 0x76, 0x65, 0x72, 0x74, 0x48, 0x73,  // InvertHs
                    /* 0AE8 */  0x79, 0x6E, 0x63, 0x50, 0x6F, 0x6C, 0x61, 0x72,  // yncPolar
                    /* 0AF0 */  0x69, 0x74, 0x79, 0x3E, 0x46, 0x61, 0x6C, 0x73,  // ity>Fals
                    /* 0AF8 */  0x65, 0x3C, 0x2F, 0x49, 0x6E, 0x76, 0x65, 0x72,  // e</Inver
                    /* 0B00 */  0x74, 0x48, 0x73, 0x79, 0x6E, 0x63, 0x50, 0x6F,  // tHsyncPo
                    /* 0B08 */  0x6C, 0x61, 0x72, 0x69, 0x74, 0x79, 0x3E, 0x0A,  // larity>.
                    /* 0B10 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 0B18 */  0x3C, 0x42, 0x6F, 0x72, 0x64, 0x65, 0x72, 0x43,  // <BorderC
                    /* 0B20 */  0x6F, 0x6C, 0x6F, 0x72, 0x3E, 0x30, 0x78, 0x30,  // olor>0x0
                    /* 0B28 */  0x3C, 0x2F, 0x42, 0x6F, 0x72, 0x64, 0x65, 0x72,  // </Border
                    /* 0B30 */  0x43, 0x6F, 0x6C, 0x6F, 0x72, 0x3E, 0x0A, 0x20,  // Color>. 
                    /* 0B38 */  0x20, 0x20, 0x20, 0x3C, 0x2F, 0x47, 0x72, 0x6F,  //    </Gro
                    /* 0B40 */  0x75, 0x70, 0x3E, 0x0A, 0x0A, 0x0A, 0x20, 0x20,  // up>...  
                    /* 0B48 */  0x20, 0x20, 0x3C, 0x47, 0x72, 0x6F, 0x75, 0x70,  //   <Group
                    /* 0B50 */  0x20, 0x69, 0x64, 0x3D, 0x22, 0x44, 0x69, 0x73,  //  id="Dis
                    /* 0B58 */  0x70, 0x6C, 0x61, 0x79, 0x20, 0x49, 0x6E, 0x74,  // play Int
                    /* 0B60 */  0x65, 0x72, 0x66, 0x61, 0x63, 0x65, 0x22, 0x3E,  // erface">
                    /* 0B68 */  0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // .       
                    /* 0B70 */  0x20, 0x3C, 0x49, 0x6E, 0x74, 0x65, 0x72, 0x66,  //  <Interf
                    /* 0B78 */  0x61, 0x63, 0x65, 0x54, 0x79, 0x70, 0x65, 0x20,  // aceType 
                    /* 0B80 */  0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x51,  // units="Q
                    /* 0B88 */  0x44, 0x49, 0x5F, 0x44, 0x69, 0x73, 0x70, 0x6C,  // DI_Displ
                    /* 0B90 */  0x61, 0x79, 0x43, 0x6F, 0x6E, 0x6E, 0x65, 0x63,  // ayConnec
                    /* 0B98 */  0x74, 0x54, 0x79, 0x70, 0x65, 0x22, 0x3E, 0x39,  // tType">9
                    /* 0BA0 */  0x3C, 0x2F, 0x49, 0x6E, 0x74, 0x65, 0x72, 0x66,  // </Interf
                    /* 0BA8 */  0x61, 0x63, 0x65, 0x54, 0x79, 0x70, 0x65, 0x3E,  // aceType>
                    /* 0BB0 */  0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // .       
                    /* 0BB8 */  0x20, 0x3C, 0x49, 0x6E, 0x74, 0x65, 0x72, 0x66,  //  <Interf
                    /* 0BC0 */  0x61, 0x63, 0x65, 0x43, 0x6F, 0x6C, 0x6F, 0x72,  // aceColor
                    /* 0BC8 */  0x46, 0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x75,  // Format u
                    /* 0BD0 */  0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x51, 0x44,  // nits="QD
                    /* 0BD8 */  0x49, 0x5F, 0x50, 0x69, 0x78, 0x65, 0x6C, 0x46,  // I_PixelF
                    /* 0BE0 */  0x6F, 0x72, 0x6D, 0x61, 0x74, 0x54, 0x79, 0x70,  // ormatTyp
                    /* 0BE8 */  0x65, 0x22, 0x3E, 0x33, 0x3C, 0x2F, 0x49, 0x6E,  // e">3</In
                    /* 0BF0 */  0x74, 0x65, 0x72, 0x66, 0x61, 0x63, 0x65, 0x43,  // terfaceC
                    /* 0BF8 */  0x6F, 0x6C, 0x6F, 0x72, 0x46, 0x6F, 0x72, 0x6D,  // olorForm
                    /* 0C00 */  0x61, 0x74, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20,  // at>.    
                    /* 0C08 */  0x3C, 0x2F, 0x47, 0x72, 0x6F, 0x75, 0x70, 0x3E,  // </Group>
                    /* 0C10 */  0x0A, 0x0A, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x3C,  // ...    <
                    /* 0C18 */  0x47, 0x72, 0x6F, 0x75, 0x70, 0x20, 0x69, 0x64,  // Group id
                    /* 0C20 */  0x3D, 0x22, 0x44, 0x53, 0x49, 0x20, 0x49, 0x6E,  // ="DSI In
                    /* 0C28 */  0x74, 0x65, 0x72, 0x66, 0x61, 0x63, 0x65, 0x22,  // terface"
                    /* 0C30 */  0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // >.      
                    /* 0C38 */  0x20, 0x20, 0x3C, 0x44, 0x53, 0x49, 0x43, 0x68,  //   <DSICh
                    /* 0C40 */  0x61, 0x6E, 0x6E, 0x65, 0x6C, 0x49, 0x64, 0x20,  // annelId 
                    /* 0C48 */  0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x44,  // units="D
                    /* 0C50 */  0x53, 0x49, 0x5F, 0x43, 0x68, 0x61, 0x6E, 0x6E,  // SI_Chann
                    /* 0C58 */  0x65, 0x6C, 0x5F, 0x49, 0x44, 0x54, 0x79, 0x70,  // el_IDTyp
                    /* 0C60 */  0x65, 0x22, 0x3E, 0x32, 0x3C, 0x2F, 0x44, 0x53,  // e">2</DS
                    /* 0C68 */  0x49, 0x43, 0x68, 0x61, 0x6E, 0x6E, 0x65, 0x6C,  // IChannel
                    /* 0C70 */  0x49, 0x64, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20,  // Id>.    
                    /* 0C78 */  0x20, 0x20, 0x20, 0x20, 0x3C, 0x44, 0x53, 0x49,  //     <DSI
                    /* 0C80 */  0x56, 0x69, 0x72, 0x74, 0x75, 0x61, 0x6C, 0x49,  // VirtualI
                    /* 0C88 */  0x64, 0x20, 0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D,  // d units=
                    /* 0C90 */  0x22, 0x44, 0x53, 0x49, 0x5F, 0x44, 0x69, 0x73,  // "DSI_Dis
                    /* 0C98 */  0x70, 0x6C, 0x61, 0x79, 0x5F, 0x56, 0x43, 0x54,  // play_VCT
                    /* 0CA0 */  0x79, 0x70, 0x65, 0x22, 0x3E, 0x30, 0x3C, 0x2F,  // ype">0</
                    /* 0CA8 */  0x44, 0x53, 0x49, 0x56, 0x69, 0x72, 0x74, 0x75,  // DSIVirtu
                    /* 0CB0 */  0x61, 0x6C, 0x49, 0x64, 0x3E, 0x0A, 0x20, 0x20,  // alId>.  
                    /* 0CB8 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x44,  //       <D
                    /* 0CC0 */  0x53, 0x49, 0x43, 0x6F, 0x6C, 0x6F, 0x72, 0x46,  // SIColorF
                    /* 0CC8 */  0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x75, 0x6E,  // ormat un
                    /* 0CD0 */  0x69, 0x74, 0x73, 0x3D, 0x22, 0x44, 0x53, 0x49,  // its="DSI
                    /* 0CD8 */  0x5F, 0x43, 0x6F, 0x6C, 0x6F, 0x72, 0x46, 0x6F,  // _ColorFo
                    /* 0CE0 */  0x72, 0x6D, 0x61, 0x74, 0x54, 0x79, 0x70, 0x65,  // rmatType
                    /* 0CE8 */  0x22, 0x3E, 0x33, 0x36, 0x3C, 0x2F, 0x44, 0x53,  // ">36</DS
                    /* 0CF0 */  0x49, 0x43, 0x6F, 0x6C, 0x6F, 0x72, 0x46, 0x6F,  // IColorFo
                    /* 0CF8 */  0x72, 0x6D, 0x61, 0x74, 0x3E, 0x0A, 0x20, 0x20,  // rmat>.  
                    /* 0D00 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x44,  //       <D
                    /* 0D08 */  0x53, 0x49, 0x54, 0x72, 0x61, 0x66, 0x66, 0x69,  // SITraffi
                    /* 0D10 */  0x63, 0x4D, 0x6F, 0x64, 0x65, 0x20, 0x75, 0x6E,  // cMode un
                    /* 0D18 */  0x69, 0x74, 0x73, 0x3D, 0x22, 0x44, 0x53, 0x49,  // its="DSI
                    /* 0D20 */  0x5F, 0x54, 0x72, 0x61, 0x66, 0x66, 0x69, 0x63,  // _Traffic
                    /* 0D28 */  0x4D, 0x6F, 0x64, 0x65, 0x54, 0x79, 0x70, 0x65,  // ModeType
                    /* 0D30 */  0x22, 0x3E, 0x31, 0x3C, 0x2F, 0x44, 0x53, 0x49,  // ">1</DSI
                    /* 0D38 */  0x54, 0x72, 0x61, 0x66, 0x66, 0x69, 0x63, 0x4D,  // TrafficM
                    /* 0D40 */  0x6F, 0x64, 0x65, 0x3E, 0x0A, 0x20, 0x20, 0x20,  // ode>.   
                    /* 0D48 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x44, 0x53,  //      <DS
                    /* 0D50 */  0x49, 0x4C, 0x61, 0x6E, 0x65, 0x73, 0x20, 0x75,  // ILanes u
                    /* 0D58 */  0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x69, 0x6E,  // nits="in
                    /* 0D60 */  0x74, 0x65, 0x67, 0x65, 0x72, 0x22, 0x3E, 0x32,  // teger">2
                    /* 0D68 */  0x3C, 0x2F, 0x44, 0x53, 0x49, 0x4C, 0x61, 0x6E,  // </DSILan
                    /* 0D70 */  0x65, 0x73, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20,  // es>.    
                    /* 0D78 */  0x20, 0x20, 0x20, 0x20, 0x3C, 0x44, 0x53, 0x49,  //     <DSI
                    /* 0D80 */  0x48, 0x73, 0x61, 0x48, 0x73, 0x65, 0x41, 0x66,  // HsaHseAf
                    /* 0D88 */  0x74, 0x65, 0x72, 0x56, 0x73, 0x56, 0x65, 0x20,  // terVsVe 
                    /* 0D90 */  0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x42,  // units="B
                    /* 0D98 */  0x6F, 0x6F, 0x6C, 0x22, 0x3E, 0x46, 0x61, 0x6C,  // ool">Fal
                    /* 0DA0 */  0x73, 0x65, 0x3C, 0x2F, 0x44, 0x53, 0x49, 0x48,  // se</DSIH
                    /* 0DA8 */  0x73, 0x61, 0x48, 0x73, 0x65, 0x41, 0x66, 0x74,  // saHseAft
                    /* 0DB0 */  0x65, 0x72, 0x56, 0x73, 0x56, 0x65, 0x3E, 0x0A,  // erVsVe>.
                    /* 0DB8 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 0DC0 */  0x3C, 0x44, 0x53, 0x49, 0x4C, 0x6F, 0x77, 0x50,  // <DSILowP
                    /* 0DC8 */  0x6F, 0x77, 0x65, 0x72, 0x4D, 0x6F, 0x64, 0x65,  // owerMode
                    /* 0DD0 */  0x49, 0x6E, 0x48, 0x46, 0x50, 0x20, 0x75, 0x6E,  // InHFP un
                    /* 0DD8 */  0x69, 0x74, 0x73, 0x3D, 0x22, 0x42, 0x6F, 0x6F,  // its="Boo
                    /* 0DE0 */  0x6C, 0x22, 0x3E, 0x46, 0x61, 0x6C, 0x73, 0x65,  // l">False
                    /* 0DE8 */  0x3C, 0x2F, 0x44, 0x53, 0x49, 0x4C, 0x6F, 0x77,  // </DSILow
                    /* 0DF0 */  0x50, 0x6F, 0x77, 0x65, 0x72, 0x4D, 0x6F, 0x64,  // PowerMod
                    /* 0DF8 */  0x65, 0x49, 0x6E, 0x48, 0x46, 0x50, 0x3E, 0x0A,  // eInHFP>.
                    /* 0E00 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 0E08 */  0x3C, 0x44, 0x53, 0x49, 0x4C, 0x6F, 0x77, 0x50,  // <DSILowP
                    /* 0E10 */  0x6F, 0x77, 0x65, 0x72, 0x4D, 0x6F, 0x64, 0x65,  // owerMode
                    /* 0E18 */  0x49, 0x6E, 0x48, 0x42, 0x50, 0x20, 0x75, 0x6E,  // InHBP un
                    /* 0E20 */  0x69, 0x74, 0x73, 0x3D, 0x22, 0x42, 0x6F, 0x6F,  // its="Boo
                    /* 0E28 */  0x6C, 0x22, 0x3E, 0x46, 0x61, 0x6C, 0x73, 0x65,  // l">False
                    /* 0E30 */  0x3C, 0x2F, 0x44, 0x53, 0x49, 0x4C, 0x6F, 0x77,  // </DSILow
                    /* 0E38 */  0x50, 0x6F, 0x77, 0x65, 0x72, 0x4D, 0x6F, 0x64,  // PowerMod
                    /* 0E40 */  0x65, 0x49, 0x6E, 0x48, 0x42, 0x50, 0x3E, 0x0A,  // eInHBP>.
                    /* 0E48 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 0E50 */  0x3C, 0x44, 0x53, 0x49, 0x4C, 0x6F, 0x77, 0x50,  // <DSILowP
                    /* 0E58 */  0x6F, 0x77, 0x65, 0x72, 0x4D, 0x6F, 0x64, 0x65,  // owerMode
                    /* 0E60 */  0x49, 0x6E, 0x48, 0x53, 0x41, 0x20, 0x75, 0x6E,  // InHSA un
                    /* 0E68 */  0x69, 0x74, 0x73, 0x3D, 0x22, 0x42, 0x6F, 0x6F,  // its="Boo
                    /* 0E70 */  0x6C, 0x22, 0x3E, 0x46, 0x61, 0x6C, 0x73, 0x65,  // l">False
                    /* 0E78 */  0x3C, 0x2F, 0x44, 0x53, 0x49, 0x4C, 0x6F, 0x77,  // </DSILow
                    /* 0E80 */  0x50, 0x6F, 0x77, 0x65, 0x72, 0x4D, 0x6F, 0x64,  // PowerMod
                    /* 0E88 */  0x65, 0x49, 0x6E, 0x48, 0x53, 0x41, 0x3E, 0x0A,  // eInHSA>.
                    /* 0E90 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 0E98 */  0x3C, 0x44, 0x53, 0x49, 0x4C, 0x6F, 0x77, 0x50,  // <DSILowP
                    /* 0EA0 */  0x6F, 0x77, 0x65, 0x72, 0x4D, 0x6F, 0x64, 0x65,  // owerMode
                    /* 0EA8 */  0x49, 0x6E, 0x42, 0x4C, 0x4C, 0x50, 0x45, 0x4F,  // InBLLPEO
                    /* 0EB0 */  0x46, 0x20, 0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D,  // F units=
                    /* 0EB8 */  0x22, 0x42, 0x6F, 0x6F, 0x6C, 0x22, 0x3E, 0x54,  // "Bool">T
                    /* 0EC0 */  0x72, 0x75, 0x65, 0x3C, 0x2F, 0x44, 0x53, 0x49,  // rue</DSI
                    /* 0EC8 */  0x4C, 0x6F, 0x77, 0x50, 0x6F, 0x77, 0x65, 0x72,  // LowPower
                    /* 0ED0 */  0x4D, 0x6F, 0x64, 0x65, 0x49, 0x6E, 0x42, 0x4C,  // ModeInBL
                    /* 0ED8 */  0x4C, 0x50, 0x45, 0x4F, 0x46, 0x3E, 0x0A, 0x20,  // LPEOF>. 
                    /* 0EE0 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C,  //        <
                    /* 0EE8 */  0x44, 0x53, 0x49, 0x4C, 0x6F, 0x77, 0x50, 0x6F,  // DSILowPo
                    /* 0EF0 */  0x77, 0x65, 0x72, 0x4D, 0x6F, 0x64, 0x65, 0x49,  // werModeI
                    /* 0EF8 */  0x6E, 0x42, 0x4C, 0x4C, 0x50, 0x20, 0x75, 0x6E,  // nBLLP un
                    /* 0F00 */  0x69, 0x74, 0x73, 0x3D, 0x22, 0x42, 0x6F, 0x6F,  // its="Boo
                    /* 0F08 */  0x6C, 0x22, 0x3E, 0x54, 0x72, 0x75, 0x65, 0x3C,  // l">True<
                    /* 0F10 */  0x2F, 0x44, 0x53, 0x49, 0x4C, 0x6F, 0x77, 0x50,  // /DSILowP
                    /* 0F18 */  0x6F, 0x77, 0x65, 0x72, 0x4D, 0x6F, 0x64, 0x65,  // owerMode
                    /* 0F20 */  0x49, 0x6E, 0x42, 0x4C, 0x4C, 0x50, 0x3E, 0x0A,  // InBLLP>.
                    /* 0F28 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  //         
                    /* 0F30 */  0x3C, 0x44, 0x53, 0x49, 0x43, 0x4D, 0x44, 0x53,  // <DSICMDS
                    /* 0F38 */  0x77, 0x61, 0x70, 0x49, 0x6E, 0x74, 0x65, 0x72,  // wapInter
                    /* 0F40 */  0x66, 0x61, 0x63, 0x65, 0x20, 0x75, 0x6E, 0x69,  // face uni
                    /* 0F48 */  0x74, 0x73, 0x3D, 0x22, 0x42, 0x6F, 0x6F, 0x6C,  // ts="Bool
                    /* 0F50 */  0x22, 0x3E, 0x46, 0x61, 0x6C, 0x73, 0x65, 0x3C,  // ">False<
                    /* 0F58 */  0x2F, 0x44, 0x53, 0x49, 0x43, 0x4D, 0x44, 0x53,  // /DSICMDS
                    /* 0F60 */  0x77, 0x61, 0x70, 0x49, 0x6E, 0x74, 0x65, 0x72,  // wapInter
                    /* 0F68 */  0x66, 0x61, 0x63, 0x65, 0x3E, 0x0A, 0x20, 0x20,  // face>.  
                    /* 0F70 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x44,  //       <D
                    /* 0F78 */  0x53, 0x49, 0x43, 0x4D, 0x44, 0x55, 0x73, 0x69,  // SICMDUsi
                    /* 0F80 */  0x6E, 0x67, 0x54, 0x72, 0x69, 0x67, 0x67, 0x65,  // ngTrigge
                    /* 0F88 */  0x72, 0x20, 0x20, 0x75, 0x6E, 0x69, 0x74, 0x73,  // r  units
                    /* 0F90 */  0x3D, 0x22, 0x42, 0x6F, 0x6F, 0x6C, 0x22, 0x3E,  // ="Bool">
                    /* 0F98 */  0x46, 0x61, 0x6C, 0x73, 0x65, 0x3C, 0x2F, 0x44,  // False</D
                    /* 0FA0 */  0x53, 0x49, 0x43, 0x4D, 0x44, 0x55, 0x73, 0x69,  // SICMDUsi
                    /* 0FA8 */  0x6E, 0x67, 0x54, 0x72, 0x69, 0x67, 0x67, 0x65,  // ngTrigge
                    /* 0FB0 */  0x72, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // r>.     
                    /* 0FB8 */  0x20, 0x20, 0x20, 0x3C, 0x44, 0x53, 0x49, 0x52,  //    <DSIR
                    /* 0FC0 */  0x65, 0x66, 0x72, 0x65, 0x73, 0x68, 0x52, 0x61,  // efreshRa
                    /* 0FC8 */  0x74, 0x65, 0x3E, 0x30, 0x78, 0x33, 0x43, 0x30,  // te>0x3C0
                    /* 0FD0 */  0x30, 0x30, 0x30, 0x3C, 0x2F, 0x44, 0x53, 0x49,  // 000</DSI
                    /* 0FD8 */  0x52, 0x65, 0x66, 0x72, 0x65, 0x73, 0x68, 0x52,  // RefreshR
                    /* 0FE0 */  0x61, 0x74, 0x65, 0x3E, 0x0A, 0x20, 0x20, 0x20,  // ate>.   
                    /* 0FE8 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x44, 0x53,  //      <DS
                    /* 0FF0 */  0x49, 0x48, 0x6F, 0x73, 0x74, 0x4C, 0x61, 0x6E,  // IHostLan
                    /* 0FF8 */  0x65, 0x4D, 0x61, 0x70, 0x70, 0x69, 0x6E, 0x67,  // eMapping
                    /* 1000 */  0x3E, 0x31, 0x3C, 0x2F, 0x44, 0x53, 0x49, 0x48,  // >1</DSIH
                    /* 1008 */  0x6F, 0x73, 0x74, 0x4C, 0x61, 0x6E, 0x65, 0x4D,  // ostLaneM
                    /* 1010 */  0x61, 0x70, 0x70, 0x69, 0x6E, 0x67, 0x3E, 0x0A,  // apping>.
                    /* 1018 */  0x20, 0x20, 0x20, 0x20, 0x3C, 0x2F, 0x47, 0x72,  //     </Gr
                    /* 1020 */  0x6F, 0x75, 0x70, 0x3E, 0x0A, 0x3C, 0x21, 0x2D,  // oup>.<!-
                    /* 1028 */  0x2D, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x44,  // -.    <D
                    /* 1030 */  0x53, 0x49, 0x49, 0x6E, 0x69, 0x74, 0x53, 0x65,  // SIInitSe
                    /* 1038 */  0x71, 0x75, 0x65, 0x6E, 0x63, 0x65, 0x3E, 0x0A,  // quence>.
                    /* 1040 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x30, 0x35,  //       05
                    /* 1048 */  0x20, 0x31, 0x31, 0x20, 0x30, 0x30, 0x0A, 0x20,  //  11 00. 
                    /* 1050 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x66, 0x66, 0x20,  //      ff 
                    /* 1058 */  0x37, 0x38, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // 78.     
                    /* 1060 */  0x20, 0x31, 0x35, 0x20, 0x33, 0x36, 0x20, 0x30,  //  15 36 0
                    /* 1068 */  0x30, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // 0.      
                    /* 1070 */  0x31, 0x35, 0x20, 0x35, 0x33, 0x20, 0x32, 0x34,  // 15 53 24
                    /* 1078 */  0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x31,  // .      1
                    /* 1080 */  0x35, 0x20, 0x35, 0x31, 0x20, 0x66, 0x66, 0x0A,  // 5 51 ff.
                    /* 1088 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x31, 0x35,  //       15
                    /* 1090 */  0x20, 0x35, 0x35, 0x20, 0x30, 0x30, 0x0A, 0x20,  //  55 00. 
                    /* 1098 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x30, 0x35, 0x20,  //      05 
                    /* 10A0 */  0x32, 0x39, 0x20, 0x30, 0x30, 0x0A, 0x20, 0x20,  // 29 00.  
                    /* 10A8 */  0x20, 0x20, 0x3C, 0x2F, 0x44, 0x53, 0x49, 0x49,  //   </DSII
                    /* 10B0 */  0x6E, 0x69, 0x74, 0x53, 0x65, 0x71, 0x75, 0x65,  // nitSeque
                    /* 10B8 */  0x6E, 0x63, 0x65, 0x3E, 0x0A, 0x0A, 0x20, 0x20,  // nce>..  
                    /* 10C0 */  0x20, 0x3C, 0x44, 0x53, 0x49, 0x54, 0x65, 0x72,  //  <DSITer
                    /* 10C8 */  0x6D, 0x53, 0x65, 0x71, 0x75, 0x65, 0x6E, 0x63,  // mSequenc
                    /* 10D0 */  0x65, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // e>.     
                    /* 10D8 */  0x20, 0x20, 0x30, 0x35, 0x20, 0x31, 0x30, 0x20,  //   05 10 
                    /* 10E0 */  0x30, 0x30, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // 00.     
                    /* 10E8 */  0x20, 0x20, 0x46, 0x46, 0x20, 0x37, 0x38, 0x0A,  //   FF 78.
                    /* 10F0 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x30,  //        0
                    /* 10F8 */  0x35, 0x20, 0x32, 0x38, 0x20, 0x30, 0x30, 0x0A,  // 5 28 00.
                    /* 1100 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x31,  //        1
                    /* 1108 */  0x35, 0x20, 0x35, 0x33, 0x20, 0x30, 0x30, 0x0A,  // 5 53 00.
                    /* 1110 */  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x31,  //        1
                    /* 1118 */  0x35, 0x20, 0x35, 0x31, 0x20, 0x30, 0x30, 0x0A,  // 5 51 00.
                    /* 1120 */  0x20, 0x20, 0x20, 0x3C, 0x2F, 0x44, 0x53, 0x49,  //    </DSI
                    /* 1128 */  0x54, 0x65, 0x72, 0x6D, 0x53, 0x65, 0x71, 0x75,  // TermSequ
                    /* 1130 */  0x65, 0x6E, 0x63, 0x65, 0x3E, 0x20, 0x20, 0x0A,  // ence>  .
                    /* 1138 */  0x0A, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x47,  // ..    <G
                    /* 1140 */  0x72, 0x6F, 0x75, 0x70, 0x20, 0x69, 0x64, 0x3D,  // roup id=
                    /* 1148 */  0x22, 0x47, 0x50, 0x49, 0x4F, 0x20, 0x43, 0x6F,  // "GPIO Co
                    /* 1150 */  0x6E, 0x66, 0x69, 0x67, 0x75, 0x72, 0x61, 0x74,  // nfigurat
                    /* 1158 */  0x69, 0x6F, 0x6E, 0x22, 0x3E, 0x0A, 0x20, 0x20,  // ion">.  
                    /* 1160 */  0x20, 0x20, 0x20, 0x20, 0x3C, 0x52, 0x65, 0x73,  //     <Res
                    /* 1168 */  0x65, 0x74, 0x50, 0x69, 0x6E, 0x49, 0x6E, 0x66,  // etPinInf
                    /* 1170 */  0x6F, 0x20, 0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D,  // o units=
                    /* 1178 */  0x22, 0x51, 0x44, 0x49, 0x5F, 0x50, 0x61, 0x6E,  // "QDI_Pan
                    /* 1180 */  0x65, 0x6C, 0x5F, 0x47, 0x50, 0x49, 0x4F, 0x5F,  // el_GPIO_
                    /* 1188 */  0x53, 0x74, 0x61, 0x74, 0x65, 0x54, 0x79, 0x70,  // StateTyp
                    /* 1190 */  0x65, 0x22, 0x3E, 0x31, 0x3C, 0x2F, 0x52, 0x65,  // e">1</Re
                    /* 1198 */  0x73, 0x65, 0x74, 0x50, 0x69, 0x6E, 0x49, 0x6E,  // setPinIn
                    /* 11A0 */  0x66, 0x6F, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20,  // fo>.    
                    /* 11A8 */  0x20, 0x20, 0x3C, 0x52, 0x65, 0x73, 0x65, 0x74,  //   <Reset
                    /* 11B0 */  0x50, 0x69, 0x6E, 0x57, 0x69, 0x64, 0x74, 0x68,  // PinWidth
                    /* 11B8 */  0x20, 0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22,  //  units="
                    /* 11C0 */  0x49, 0x6E, 0x74, 0x65, 0x67, 0x65, 0x72, 0x20,  // Integer 
                    /* 11C8 */  0x28, 0x6D, 0x73, 0x29, 0x22, 0x3E, 0x35, 0x3C,  // (ms)">5<
                    /* 11D0 */  0x2F, 0x52, 0x65, 0x73, 0x65, 0x74, 0x50, 0x69,  // /ResetPi
                    /* 11D8 */  0x6E, 0x57, 0x69, 0x64, 0x74, 0x68, 0x3E, 0x0A,  // nWidth>.
                    /* 11E0 */  0x20, 0x20, 0x20, 0x20, 0x3C, 0x2F, 0x47, 0x72,  //     </Gr
                    /* 11E8 */  0x6F, 0x75, 0x70, 0x3E, 0x0A, 0x2D, 0x2D, 0x3E,  // oup>.-->
                    /* 11F0 */  0x0A, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x47, 0x72,  // .    <Gr
                    /* 11F8 */  0x6F, 0x75, 0x70, 0x20, 0x69, 0x64, 0x3D, 0x22,  // oup id="
                    /* 1200 */  0x42, 0x61, 0x63, 0x6B, 0x6C, 0x69, 0x67, 0x68,  // Backligh
                    /* 1208 */  0x74, 0x20, 0x43, 0x6F, 0x6E, 0x66, 0x69, 0x67,  // t Config
                    /* 1210 */  0x75, 0x72, 0x61, 0x74, 0x69, 0x6F, 0x6E, 0x22,  // uration"
                    /* 1218 */  0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // >.      
                    /* 1220 */  0x20, 0x3C, 0x42, 0x61, 0x63, 0x6B, 0x6C, 0x69,  //  <Backli
                    /* 1228 */  0x67, 0x68, 0x74, 0x54, 0x79, 0x70, 0x65, 0x20,  // ghtType 
                    /* 1230 */  0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22, 0x51,  // units="Q
                    /* 1238 */  0x44, 0x49, 0x5F, 0x50, 0x61, 0x6E, 0x65, 0x6C,  // DI_Panel
                    /* 1240 */  0x5F, 0x42, 0x61, 0x63, 0x6B, 0x6C, 0x69, 0x67,  // _Backlig
                    /* 1248 */  0x68, 0x74, 0x54, 0x79, 0x70, 0x65, 0x22, 0x3E,  // htType">
                    /* 1250 */  0x33, 0x3C, 0x2F, 0x42, 0x61, 0x63, 0x6B, 0x6C,  // 3</Backl
                    /* 1258 */  0x69, 0x67, 0x68, 0x74, 0x54, 0x79, 0x70, 0x65,  // ightType
                    /* 1260 */  0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // >.      
                    /* 1268 */  0x20, 0x3C, 0x42, 0x61, 0x63, 0x6B, 0x6C, 0x69,  //  <Backli
                    /* 1270 */  0x67, 0x68, 0x74, 0x53, 0x74, 0x65, 0x70, 0x73,  // ghtSteps
                    /* 1278 */  0x20, 0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D, 0x22,  //  units="
                    /* 1280 */  0x50, 0x65, 0x72, 0x63, 0x65, 0x6E, 0x74, 0x61,  // Percenta
                    /* 1288 */  0x67, 0x65, 0x22, 0x3E, 0x31, 0x30, 0x30, 0x3C,  // ge">100<
                    /* 1290 */  0x2F, 0x42, 0x61, 0x63, 0x6B, 0x6C, 0x69, 0x67,  // /Backlig
                    /* 1298 */  0x68, 0x74, 0x53, 0x74, 0x65, 0x70, 0x73, 0x3E,  // htSteps>
                    /* 12A0 */  0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,  // .       
                    /* 12A8 */  0x3C, 0x42, 0x61, 0x63, 0x6B, 0x6C, 0x69, 0x67,  // <Backlig
                    /* 12B0 */  0x68, 0x74, 0x44, 0x65, 0x66, 0x61, 0x75, 0x6C,  // htDefaul
                    /* 12B8 */  0x74, 0x20, 0x75, 0x6E, 0x69, 0x74, 0x73, 0x3D,  // t units=
                    /* 12C0 */  0x22, 0x50, 0x65, 0x72, 0x63, 0x65, 0x6E, 0x74,  // "Percent
                    /* 12C8 */  0x61, 0x67, 0x65, 0x22, 0x3E, 0x38, 0x30, 0x3C,  // age">80<
                    /* 12D0 */  0x2F, 0x42, 0x61, 0x63, 0x6B, 0x6C, 0x69, 0x67,  // /Backlig
                    /* 12D8 */  0x68, 0x74, 0x44, 0x65, 0x66, 0x61, 0x75, 0x6C,  // htDefaul
                    /* 12E0 */  0x74, 0x3E, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20,  // t>.     
                    /* 12E8 */  0x20, 0x20, 0x3C, 0x42, 0x61, 0x63, 0x6B, 0x6C,  //   <Backl
                    /* 12F0 */  0x69, 0x67, 0x68, 0x74, 0x4C, 0x6F, 0x77, 0x50,  // ightLowP
                    /* 12F8 */  0x6F, 0x77, 0x65, 0x72, 0x20, 0x75, 0x6E, 0x69,  // ower uni
                    /* 1300 */  0x74, 0x73, 0x3D, 0x22, 0x50, 0x65, 0x72, 0x63,  // ts="Perc
                    /* 1308 */  0x65, 0x6E, 0x74, 0x61, 0x67, 0x65, 0x22, 0x3E,  // entage">
                    /* 1310 */  0x34, 0x30, 0x3C, 0x2F, 0x42, 0x61, 0x63, 0x6B,  // 40</Back
                    /* 1318 */  0x6C, 0x69, 0x67, 0x68, 0x74, 0x4C, 0x6F, 0x77,  // lightLow
                    /* 1320 */  0x50, 0x6F, 0x77, 0x65, 0x72, 0x3E, 0x0A, 0x20,  // Power>. 
                    /* 1328 */  0x20, 0x20, 0x20, 0x3C, 0x2F, 0x47, 0x72, 0x6F,  //    </Gro
                    /* 1330 */  0x75, 0x70, 0x3E, 0x0A                           // up>.
                })
                If ((Arg0 >= SizeOf (PCFG)))
                {
                    Return (Buffer (One)
                    {
                         0x00                                             // .
                    })
                }
                Else
                {
                    Local0 = Arg0
                }

                If ((Arg1 > 0x1000))
                {
                    Local1 = 0x1000
                }
                Else
                {
                    Local1 = Arg1
                }

                If (((Local0 + Local1) > SizeOf (PCFG)))
                {
                    Local1 = (SizeOf (PCFG) - Local0)
                }

                CreateField (PCFG, (0x08 * Local0), (0x08 * Local1), RBUF)
                Return (RBUF) /* \_SB_.GPU0._ROM.RBUF */
            }

            Method (PIGC, 1, NotSerialized)
            {
                Name (RBUF, Buffer (One)
                {
                     0x00                                             // .
                })
                Return (RBUF) /* \_SB_.GPU0.PIGC.RBUF */
            }

            Method (PPCC, 1, NotSerialized)
            {
                Name (RBUF, Buffer (One)
                {
                     0x00                                             // .
                })
                Return (RBUF) /* \_SB_.GPU0.PPCC.RBUF */
            }

            Method (PGCT, 1, NotSerialized)
            {
                Name (RBUF, Buffer (One)
                {
                     0x00                                             // .
                })
                Return (RBUF) /* \_SB_.GPU0.PGCT.RBUF */
            }

            Method (PGRT, 2, NotSerialized)
            {
                Name (RBUF, Buffer (One)
                {
                     0x00                                             // .
                })
                Return (RBUF) /* \_SB_.GPU0.PGRT.RBUF */
            }

            Method (PBRT, 2, NotSerialized)
            {
                Name (RBUF, Buffer (One)
                {
                     0x00                                             // .
                })
                Return (RBUF) /* \_SB_.GPU0.PBRT.RBUF */
            }

            Method (BLCP, 1, NotSerialized)
            {
                Name (RBUF, Buffer (0x0100){})
                Return (RBUF) /* \_SB_.GPU0.BLCP.RBUF */
            }

            Name (_DOD, Package (0x01)  // _DOD: Display Output Devices
            {
                0x00024321
            })
            Device (AVS0)
            {
                Name (_ADR, 0x00024321)  // _ADR: Address
                Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
                {
                    Name (RBUF, Buffer (0x02)
                    {
                         0x79, 0x00                                       // y.
                    })
                    Return (RBUF) /* \_SB_.GPU0.AVS0._CRS.RBUF */
                }

                Name (_DEP, Package (0x02)  // _DEP: Dependencies
                {
                    \_SB.VPE, , 
                    \_SB.VFE0, 
                })
            }
        }

        Device (SGPU)
        {
            Name (_HID, "QCOM_GPU")  // _HID: Hardware ID
            Name (_CID, "ACPIQCOM_GPU")  // _CID: Compatible ID
            Name (_UID, Zero)  // _UID: Unique ID
        }

        Device (AMSS)
        {
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.PMIC, 
            })
            Name (_HID, "QCOM0E80")  // _HID: Hardware ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x14)
                {
                    /* 0000 */  0x89, 0x06, 0x00, 0x03, 0x01, 0x43, 0x00, 0x00,  // .....C..
                    /* 0008 */  0x00, 0x89, 0x06, 0x00, 0x03, 0x01, 0x44, 0x00,  // ......D.
                    /* 0010 */  0x00, 0x00, 0x79, 0x00                           // ..y.
                })
                Return (RBUF) /* \_SB_.AMSS._CRS.RBUF */
            }

            Name (RMEM, Package (0x0C)
            {
                Package (0x02)
                {
                    0x89000000, 
                    0x4400
                }, 

                Package (0x02)
                {
                    0x8D400000, 
                    0x0600
                }, 

                Package (0x02)
                {
                    0x2A000000, 
                    0x10
                }, 

                Package (0x02)
                {
                    0x2A03F000, 
                    One
                }, 

                Package (0x02)
                {
                    0x2E000000, 
                    0x30
                }, 

                Package (0x02)
                {
                    0x09000000, 
                    0x08
                }, 

                Package (0x02)
                {
                    0x09200000, 
                    0x08
                }, 

                Package (0x02)
                {
                    0x09400000, 
                    0x10
                }, 

                Package (0x02)
                {
                    0x00020000, 
                    0x24
                }, 

                Package (0x02)
                {
                    0x00108000, 
                    0x06
                }, 

                Package (0x02)
                {
                    0x8FF00000, 
                    0x0100
                }, 

                Package (0x02)
                {
                    0x01A01000, 
                    One
                }
            })
            Method (CONF, 0, NotSerialized)
            {
                Return (RMEM) /* \_SB_.AMSS.RMEM */
            }

            Method (VLMT, 0, NotSerialized)
            {
                Name (RBUF, Package (0x04)
                {
                    Package (0x02)
                    {
                        0x21, 
                        0x03
                    }, 

                    Package (0x02)
                    {
                        0x42, 
                        0x02
                    }, 

                    Package (0x02)
                    {
                        0x63, 
                        One
                    }, 

                    Package (0x02)
                    {
                        0x64, 
                        Zero
                    }
                })
                Return (RBUF) /* \_SB_.AMSS.VLMT.RBUF */
            }
        }

        Device (ADSP)
        {
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.PMIC, 
            })
            Name (_HID, "QCOM0E10")  // _HID: Hardware ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x0B)
                {
                    /* 0000 */  0x89, 0x06, 0x00, 0x03, 0x01, 0x77, 0x00, 0x00,  // .....w..
                    /* 0008 */  0x00, 0x79, 0x00                                 // .y.
                })
                Return (RBUF) /* \_SB_.ADSP._CRS.RBUF */
            }

            Method (MANU, 0, NotSerialized)
            {
                Name (RBUF, Package (0x01)
                {
                    0x3551ED9D
                })
                Return (RBUF) /* \_SB_.ADSP.MANU.RBUF */
            }

            Name (RMEM, Package (0x02)
            {
                Package (0x02)
                {
                    0x8DA00000, 
                    0x1800
                }, 

                Package (0x02)
                {
                    0x28400000, 
                    0x20
                }
            })
            Method (CONF, 0, NotSerialized)
            {
                Return (RMEM) /* \_SB_.ADSP.RMEM */
            }
        }

        Device (CAMP)
        {
            Name (_DEP, Package (0x02)  // _DEP: Dependencies
            {
                \_SB.PEP0, , 
                \_SB.PMIC, 
            })
            Name (_HID, "QCOM0775")  // _HID: Hardware ID
            Name (_UID, 0x1B)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x6C)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x30, 0x16,  // ......0.
                    /* 0008 */  0x20, 0x00, 0x00, 0x00, 0x86, 0x09, 0x00, 0x01,  //  .......
                    /* 0010 */  0x00, 0x00, 0x38, 0x16, 0x08, 0x04, 0x00, 0x00,  // ..8.....
                    /* 0018 */  0x86, 0x09, 0x00, 0x01, 0xB8, 0x20, 0x80, 0x00,  // ..... ..
                    /* 0020 */  0x04, 0x00, 0x00, 0x00, 0x8C, 0x20, 0x00, 0x01,  // ..... ..
                    /* 0028 */  0x01, 0x01, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00,  // ........
                    /* 0030 */  0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // .......#
                    /* 0038 */  0x00, 0x00, 0x00, 0x6B, 0x00, 0x5C, 0x5F, 0x53,  // ...k.\_S
                    /* 0040 */  0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x8C,  // B.GIO0..
                    /* 0048 */  0x20, 0x00, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00,  //  .......
                    /* 0050 */  0x03, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00, 0x00,  // ........
                    /* 0058 */  0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x4C, 0x00,  // ..#...L.
                    /* 0060 */  0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x47, 0x49, 0x4F,  // \_SB.GIO
                    /* 0068 */  0x30, 0x00, 0x79, 0x00                           // 0.y.
                })
                Return (RBUF) /* \_SB_.CAMP._CRS.RBUF */
            }
        }

        Device (CAMS)
        {
            Name (_DEP, Package (0x02)  // _DEP: Dependencies
            {
                \_SB.CAMP, , 
                \_SB.PEP0, 
            })
            Name (_HID, "QCOM0710")  // _HID: Hardware ID
            Name (_UID, 0x15)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x23)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x80, 0x04,  // ........
                    /* 0008 */  0x00, 0x04, 0x00, 0x00, 0x86, 0x09, 0x00, 0x01,  // ........
                    /* 0010 */  0x00, 0x0C, 0x80, 0x04, 0x00, 0x04, 0x00, 0x00,  // ........
                    /* 0018 */  0x89, 0x06, 0x00, 0x03, 0x01, 0x73, 0x00, 0x00,  // .....s..
                    /* 0020 */  0x00, 0x79, 0x00                                 // .y.
                })
                Return (RBUF) /* \_SB_.CAMS._CRS.RBUF */
            }
        }

        Device (AVS0)
        {
            Name (_DEP, Package (0x03)  // _DEP: Dependencies
            {
                \_SB.SMMU, , 
                \_SB.VPE, , 
                \_SB.VFE0, 
            })
            Name (_HID, "QCOM0720")  // _HID: Hardware ID
            Name (_UID, 0x17)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x02)
                {
                     0x79, 0x00                                       // y.
                })
                Return (RBUF) /* \_SB_.AVS0._CRS.RBUF */
            }
        }

        Device (CAMG)
        {
            Name (_DEP, Package (0x02)  // _DEP: Dependencies
            {
                \_SB.SMMU, , 
                \_SB.PEP0, 
            })
            Name (_HID, "QCOM0730")  // _HID: Hardware ID
            Name (_UID, 0x18)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x17)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x60, 0x04,  // ......`.
                    /* 0008 */  0x00, 0x02, 0x00, 0x00, 0x89, 0x06, 0x00, 0x03,  // ........
                    /* 0010 */  0x01, 0x6D, 0x00, 0x00, 0x00, 0x79, 0x00         // .m...y.
                })
                Return (RBUF) /* \_SB_.CAMG._CRS.RBUF */
            }
        }

        Device (VFE0)
        {
            Name (_DEP, Package (0x02)  // _DEP: Dependencies
            {
                \_SB.SMMU, , 
                \_SB.PEP0, 
            })
            Name (_HID, "QCOM0700")  // _HID: Hardware ID
            Name (_UID, 0x16)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x2C)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x50, 0x04,  // ......P.
                    /* 0008 */  0x60, 0x07, 0x00, 0x00, 0x86, 0x09, 0x00, 0x01,  // `.......
                    /* 0010 */  0x00, 0x08, 0x80, 0x04, 0x00, 0x04, 0x00, 0x00,  // ........
                    /* 0018 */  0x89, 0x06, 0x00, 0x03, 0x01, 0x50, 0x00, 0x00,  // .....P..
                    /* 0020 */  0x00, 0x89, 0x06, 0x00, 0x03, 0x01, 0xC7, 0x00,  // ........
                    /* 0028 */  0x00, 0x00, 0x79, 0x00                           // ..y.
                })
                Return (RBUF) /* \_SB_.VFE0._CRS.RBUF */
            }
        }

        Device (VPE)
        {
            Name (_DEP, Package (0x02)  // _DEP: Dependencies
            {
                \_SB.SMMU, , 
                \_SB.PEP0, 
            })
            Name (_HID, "QCOM0770")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x17)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x30, 0x05,  // ......0.
                    /* 0008 */  0x00, 0x00, 0x10, 0x00, 0x89, 0x06, 0x00, 0x01,  // ........
                    /* 0010 */  0x01, 0x4F, 0x00, 0x00, 0x00, 0x79, 0x00         // .O...y.
                })
                Return (RBUF) /* \_SB_.VPE_._CRS.RBUF */
            }
        }

        Device (CESP)
        {
            Name (_HID, "CESP0001")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
        }

        Device (GIO0)
        {
            Name (_HID, "QCOM0500")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x29)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x80, 0x00,  // ........
                    /* 0008 */  0x00, 0x20, 0x00, 0x00, 0x89, 0x06, 0x00, 0x09,  // . ......
                    /* 0010 */  0x01, 0x30, 0x00, 0x00, 0x00, 0x89, 0x06, 0x00,  // .0......
                    /* 0018 */  0x09, 0x01, 0x30, 0x00, 0x00, 0x00, 0x89, 0x06,  // ..0.....
                    /* 0020 */  0x00, 0x09, 0x01, 0x30, 0x00, 0x00, 0x00, 0x79,  // ...0...y
                    /* 0028 */  0x00                                             // .
                })
                Return (RBUF) /* \_SB_.GIO0._CRS.RBUF */
            }

            Method (OFNI, 0, NotSerialized)
            {
                Name (RBUF, Buffer (0x02)
                {
                     0x98, 0x00                                       // ..
                })
                Return (RBUF) /* \_SB_.GIO0.OFNI.RBUF */
            }
        }

        Device (PWIO)
        {
            Name (_HID, "QCOM0D20")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x25)
                {
                    /* 0000 */  0x8C, 0x20, 0x00, 0x01, 0x00, 0x01, 0x00, 0x0D,  // . ......
                    /* 0008 */  0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00,  // ........
                    /* 0010 */  0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x33,  // ...#...3
                    /* 0018 */  0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x50, 0x4D,  // .\_SB.PM
                    /* 0020 */  0x30, 0x31, 0x00, 0x79, 0x00                     // 01.y.
                })
                Return (RBUF) /* \_SB_.PWIO._CRS.RBUF */
            }

            Method (PMIC, 0, NotSerialized)
            {
                Name (CFG0, Package (0x04)
                {
                    Zero, 
                    Zero, 
                    0x33, 
                    One
                })
                Return (CFG0) /* \_SB_.PWIO.PMIC.CFG0 */
            }

            Method (HRST, 0, NotSerialized)
            {
                Name (CFG0, Package (0x05)
                {
                    0x2810, 
                    0x64, 
                    One, 
                    One, 
                    One
                })
                Return (CFG0) /* \_SB_.PWIO.HRST.CFG0 */
            }

            Method (PKEY, 0, NotSerialized)
            {
                Name (CFG0, Package (0x02)
                {
                    One, 
                    One
                })
                Return (CFG0) /* \_SB_.PWIO.PKEY.CFG0 */
            }

            Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
            {
                While (One)
                {
                    Name (_T_0, Buffer (0x01)  // _T_x: Emitted by ASL Compiler, x=0-9, A-Z
                    {
                         0x00                                             // .
                    })
                    CopyObject (ToBuffer (Arg0), _T_0) /* \_SB_.PWIO._DSM._T_0 */
                    If ((_T_0 == ToUUID ("4f248f40-d5e2-499f-834c-27758ea1cd3f") /* GPIO Controller */))
                    {
                        While (One)
                        {
                            Name (_T_1, 0x00)  // _T_x: Emitted by ASL Compiler, x=0-9, A-Z
                            _T_1 = ToInteger (Arg2)
                            If ((_T_1 == Zero))
                            {
                                Return (Buffer (One)
                                {
                                     0x03                                             // .
                                })
                            }
                            ElseIf ((_T_1 == One))
                            {
                                Return (Package (0x01)
                                {
                                    0x10
                                })
                            }
                            Else
                            {
                            }

                            Break
                        }
                    }
                    Else
                    {
                        Return (Buffer (One)
                        {
                             0x00                                             // .
                        })
                    }

                    Break
                }
            }
        }

        Device (BTN0)
        {
            Name (_HID, "QCOM0D60")  // _HID: Hardware ID
            Name (_CID, "PNP0C40" /* Standard Button Controller */)  // _CID: Compatible ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x0160)
                {
                    /* 0000 */  0x8C, 0x20, 0x00, 0x01, 0x00, 0x01, 0x00, 0x0D,  // . ......
                    /* 0008 */  0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00,  // ........
                    /* 0010 */  0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x10,  // ...#....
                    /* 0018 */  0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x50, 0x57,  // .\_SB.PW
                    /* 0020 */  0x49, 0x4F, 0x00, 0x8C, 0x20, 0x00, 0x01, 0x01,  // IO.. ...
                    /* 0028 */  0x01, 0x00, 0x08, 0x00, 0x02, 0x00, 0x00, 0x00,  // ........
                    /* 0030 */  0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23, 0x00,  // ......#.
                    /* 0038 */  0x00, 0x00, 0x10, 0x00, 0x5C, 0x5F, 0x53, 0x42,  // ....\_SB
                    /* 0040 */  0x2E, 0x50, 0x57, 0x49, 0x4F, 0x00, 0x8C, 0x20,  // .PWIO.. 
                    /* 0048 */  0x00, 0x01, 0x00, 0x01, 0x00, 0x1D, 0x00, 0x01,  // ........
                    /* 0050 */  0x00, 0x00, 0x38, 0x18, 0x17, 0x00, 0x00, 0x19,  // ..8.....
                    /* 0058 */  0x00, 0x23, 0x00, 0x00, 0x00, 0xC2, 0x00, 0x5C,  // .#.....\
                    /* 0060 */  0x5F, 0x53, 0x42, 0x2E, 0x50, 0x4D, 0x30, 0x31,  // _SB.PM01
                    /* 0068 */  0x00, 0x8C, 0x20, 0x00, 0x01, 0x01, 0x01, 0x00,  // .. .....
                    /* 0070 */  0x08, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x17,  // ........
                    /* 0078 */  0x00, 0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00,  // ....#...
                    /* 0080 */  0xC2, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x50,  // ..\_SB.P
                    /* 0088 */  0x4D, 0x30, 0x31, 0x00, 0x8C, 0x20, 0x00, 0x01,  // M01.. ..
                    /* 0090 */  0x00, 0x01, 0x00, 0x1D, 0x00, 0x01, 0x00, 0x00,  // ........
                    /* 0098 */  0x38, 0x18, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // 8......#
                    /* 00A0 */  0x00, 0x00, 0x00, 0xC7, 0x00, 0x5C, 0x5F, 0x53,  // .....\_S
                    /* 00A8 */  0x42, 0x2E, 0x50, 0x4D, 0x30, 0x31, 0x00, 0x8C,  // B.PM01..
                    /* 00B0 */  0x20, 0x00, 0x01, 0x01, 0x01, 0x00, 0x08, 0x00,  //  .......
                    /* 00B8 */  0x01, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00, 0x00,  // ........
                    /* 00C0 */  0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0xC7, 0x00,  // ..#.....
                    /* 00C8 */  0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x50, 0x4D, 0x30,  // \_SB.PM0
                    /* 00D0 */  0x31, 0x00, 0x8C, 0x20, 0x00, 0x01, 0x00, 0x01,  // 1.. ....
                    /* 00D8 */  0x00, 0x0D, 0x00, 0x01, 0x00, 0x00, 0x38, 0x18,  // ......8.
                    /* 00E0 */  0x17, 0x00, 0x00, 0x19, 0x00, 0x23, 0x00, 0x00,  // .....#..
                    /* 00E8 */  0x00, 0xCA, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E,  // ...\_SB.
                    /* 00F0 */  0x50, 0x4D, 0x30, 0x31, 0x00, 0x8C, 0x20, 0x00,  // PM01.. .
                    /* 00F8 */  0x01, 0x01, 0x01, 0x00, 0x08, 0x00, 0x01, 0x00,  // ........
                    /* 0100 */  0x00, 0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00,  // ........
                    /* 0108 */  0x23, 0x00, 0x00, 0x00, 0xCA, 0x00, 0x5C, 0x5F,  // #.....\_
                    /* 0110 */  0x53, 0x42, 0x2E, 0x50, 0x4D, 0x30, 0x31, 0x00,  // SB.PM01.
                    /* 0118 */  0x8C, 0x20, 0x00, 0x01, 0x00, 0x01, 0x00, 0x1D,  // . ......
                    /* 0120 */  0x00, 0x01, 0x00, 0x00, 0x38, 0x18, 0x17, 0x00,  // ....8...
                    /* 0128 */  0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0xC9,  // ...#....
                    /* 0130 */  0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x50, 0x4D,  // .\_SB.PM
                    /* 0138 */  0x30, 0x31, 0x00, 0x8C, 0x20, 0x00, 0x01, 0x01,  // 01.. ...
                    /* 0140 */  0x01, 0x00, 0x08, 0x00, 0x01, 0x00, 0x00, 0x00,  // ........
                    /* 0148 */  0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23, 0x00,  // ......#.
                    /* 0150 */  0x00, 0x00, 0xC9, 0x00, 0x5C, 0x5F, 0x53, 0x42,  // ....\_SB
                    /* 0158 */  0x2E, 0x50, 0x4D, 0x30, 0x31, 0x00, 0x79, 0x00   // .PM01.y.
                })
                Return (RBUF) /* \_SB_.BTN0._CRS.RBUF */
            }

            Method (BNWP, 0, NotSerialized)
            {
                Name (RBUF, Buffer (0x05)
                {
                     0x00, 0x02, 0x03, 0x07, 0x08                     // .....
                })
                Return (RBUF) /* \_SB_.BTN0.BNWP.RBUF */
            }

            Method (BNAS, 0, NotSerialized)
            {
                Name (RBUF, Buffer (0x05)
                {
                     0x01, 0x00, 0x00, 0x00, 0x00                     // .....
                })
                Return (RBUF) /* \_SB_.BTN0.BNAS.RBUF */
            }
        }

        Device (GSBI)
        {
            Name (_HID, "QCOM0145")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Name (GCNF, Package (0x0C)
            {
                Package (0x04)
                {
                    One, 
                    0x16000000, 
                    0x20, 
                    Zero
                }, 

                Package (0x04)
                {
                    0x02, 
                    0x16100000, 
                    0x20, 
                    Zero
                }, 

                Package (0x04)
                {
                    0x03, 
                    0x16200000, 
                    0x20, 
                    0x02
                }, 

                Package (0x04)
                {
                    0x04, 
                    0x16300000, 
                    0x20, 
                    Zero
                }, 

                Package (0x04)
                {
                    0x05, 
                    0x16400000, 
                    0x20, 
                    Zero
                }, 

                Package (0x04)
                {
                    0x06, 
                    0x16500000, 
                    0x20, 
                    Zero
                }, 

                Package (0x04)
                {
                    0x07, 
                    0x16600000, 
                    0x20, 
                    Zero
                }, 

                Package (0x04)
                {
                    0x08, 
                    0x1A000000, 
                    0x20, 
                    Zero
                }, 

                Package (0x04)
                {
                    0x09, 
                    0x1A100000, 
                    0x20, 
                    0x02
                }, 

                Package (0x04)
                {
                    0x0A, 
                    0x1A200000, 
                    0x20, 
                    Zero
                }, 

                Package (0x04)
                {
                    0x0B, 
                    0x12440000, 
                    0x20, 
                    Zero
                }, 

                Package (0x04)
                {
                    0x0C, 
                    0x12480000, 
                    0x20, 
                    0x02
                }
            })
            Method (CONF, 0, NotSerialized)
            {
                Return (GCNF) /* \_SB_.GSBI.GCNF */
            }
        }

        Device (I2C9)
        {
            Name (_HID, "QCOM0180")  // _HID: Hardware ID
            Name (_UID, 0x09)  // _UID: Unique ID
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.GSBI, 
            })
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x17)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x18, 0x1A,  // ........
                    /* 0008 */  0x00, 0x08, 0x00, 0x00, 0x89, 0x06, 0x00, 0x01,  // ........
                    /* 0010 */  0x01, 0xDE, 0x00, 0x00, 0x00, 0x79, 0x00         // .....y.
                })
                Return (RBUF) /* \_SB_.I2C9._CRS.RBUF */
            }
        }

        Device (I2C3)
        {
            Name (_HID, "QCOM0180")  // _HID: Hardware ID
            Name (_UID, 0x03)  // _UID: Unique ID
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.GSBI, 
            })
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x17)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x28, 0x16,  // ......(.
                    /* 0008 */  0x00, 0x08, 0x00, 0x00, 0x89, 0x06, 0x00, 0x01,  // ........
                    /* 0010 */  0x01, 0xB7, 0x00, 0x00, 0x00, 0x79, 0x00         // .....y.
                })
                Return (RBUF) /* \_SB_.I2C3._CRS.RBUF */
            }
        }

        Device (IC12)
        {
            Name (_HID, "QCOM0180")  // _HID: Hardware ID
            Name (_UID, 0x0C)  // _UID: Unique ID
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.GSBI, 
            })
            Name (AVBL, Zero)
            Method (_REG, 2, NotSerialized)  // _REG: Region Availability
            {
                If ((Arg0 == 0x09))
                {
                    ^AVBL = Arg1
                }
            }

            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x17)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x4A, 0x12,  // ......J.
                    /* 0008 */  0x00, 0x08, 0x00, 0x00, 0x89, 0x06, 0x00, 0x01,  // ........
                    /* 0010 */  0x01, 0xE4, 0x00, 0x00, 0x00, 0x79, 0x00         // .....y.
                })
                Return (RBUF) /* \_SB_.IC12._CRS.RBUF */
            }
        }

        Device (SMEM)
        {
            Name (_HID, "QCOM0F00")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x3E)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x00, 0x80,  // ........
                    /* 0008 */  0x00, 0x00, 0x20, 0x00, 0x86, 0x09, 0x00, 0x01,  // .. .....
                    /* 0010 */  0x04, 0x06, 0x20, 0x01, 0x80, 0x00, 0x00, 0x00,  // .. .....
                    /* 0018 */  0x86, 0x09, 0x00, 0x01, 0x08, 0x10, 0x01, 0x02,  // ........
                    /* 0020 */  0x04, 0x00, 0x00, 0x00, 0x86, 0x09, 0x00, 0x01,  // ........
                    /* 0028 */  0x80, 0x40, 0x10, 0x12, 0x04, 0x00, 0x00, 0x00,  // .@......
                    /* 0030 */  0x86, 0x09, 0x00, 0x01, 0x94, 0x40, 0x10, 0x12,  // .....@..
                    /* 0038 */  0x04, 0x00, 0x00, 0x00, 0x79, 0x00               // ....y.
                })
                Return (RBUF) /* \_SB_.SMEM._CRS.RBUF */
            }
        }

        Device (SMD0)
        {
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.SMEM, 
            })
            Name (_HID, "QCOM0F10")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Device (GPS)
            {
                Name (_HID, "QCOM_GPS")  // _HID: Hardware ID
                Name (_CID, "ACPIQCOM_GPS")  // _CID: Compatible ID
                Name (_UID, Zero)  // _UID: Unique ID
            }

            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x26)
                {
                    /* 0000 */  0x89, 0x06, 0x00, 0x03, 0x01, 0x45, 0x00, 0x00,  // .....E..
                    /* 0008 */  0x00, 0x89, 0x06, 0x00, 0x03, 0x01, 0x7A, 0x00,  // ......z.
                    /* 0010 */  0x00, 0x00, 0x89, 0x06, 0x00, 0x03, 0x01, 0xAA,  // ........
                    /* 0018 */  0x00, 0x00, 0x00, 0x89, 0x06, 0x00, 0x03, 0x01,  // ........
                    /* 0020 */  0xE6, 0x00, 0x00, 0x00, 0x79, 0x00               // ....y.
                })
                Return (RBUF) /* \_SB_.SMD0._CRS.RBUF */
            }

            Method (INTR, 0, NotSerialized)
            {
                Name (RBUF, Package (0x14)
                {
                    One, 
                    0x04, 
                    Zero, 
                    Zero, 
                    One, 
                    0x02011008, 
                    0x08, 
                    Zero, 
                    0x02, 
                    0x02011008, 
                    0x8000, 
                    Zero, 
                    0x03, 
                    0x12104080, 
                    One, 
                    Zero, 
                    0x04, 
                    0x02011008, 
                    0x02000000, 
                    Zero
                })
                Return (RBUF) /* \_SB_.SMD0.INTR.RBUF */
            }
        }

        Device (SMSM)
        {
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.SMEM, 
            })
            Name (_HID, "QCOM0F30")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x26)
                {
                    /* 0000 */  0x89, 0x06, 0x00, 0x03, 0x01, 0x46, 0x00, 0x00,  // .....F..
                    /* 0008 */  0x00, 0x89, 0x06, 0x00, 0x03, 0x01, 0x79, 0x00,  // ......y.
                    /* 0010 */  0x00, 0x00, 0x89, 0x06, 0x00, 0x03, 0x01, 0xEC,  // ........
                    /* 0018 */  0x00, 0x00, 0x00, 0x89, 0x06, 0x00, 0x03, 0x01,  // ........
                    /* 0020 */  0xA9, 0x00, 0x00, 0x00, 0x79, 0x00               // ....y.
                })
                Return (RBUF) /* \_SB_.SMSM._CRS.RBUF */
            }

            Method (INTR, 0, NotSerialized)
            {
                Name (RBUF, Package (0x14)
                {
                    One, 
                    0x04, 
                    Zero, 
                    Zero, 
                    One, 
                    0x02011008, 
                    0x10, 
                    Zero, 
                    0x02, 
                    0x02011008, 
                    0x4000, 
                    Zero, 
                    0x03, 
                    0x02011008, 
                    0x00800000, 
                    Zero, 
                    0x04, 
                    0x12104094, 
                    One, 
                    Zero
                })
                Return (RBUF) /* \_SB_.SMSM.INTR.RBUF */
            }
        }

        Device (DMUX)
        {
            Name (_HID, "QCOM0F50")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
        }

        Device (RIVA)
        {
            Name (_DEP, Package (0x05)  // _DEP: Dependencies
            {
                \_SB.PEP0, , 
                \_SB.PMIC, , 
                \_SB.SMSM, , 
                \_SB.PILC, , 
                \_SB.SMD0, 
            })
            Name (_HID, "QCOM0E20")  // _HID: Hardware ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x0B)
                {
                    /* 0000 */  0x89, 0x06, 0x00, 0x03, 0x01, 0xE7, 0x00, 0x00,  // ........
                    /* 0008 */  0x00, 0x79, 0x00                                 // .y.
                })
                Return (RBUF) /* \_SB_.RIVA._CRS.RBUF */
            }

            Device (BTH0)
            {
                Name (_ADR, One)  // _ADR: Address
            }

            Device (QWLN)
            {
                Name (_ADR, 0x02)  // _ADR: Address
                Name (_PRW, Package (0x02)  // _PRW: Power Resources for Wake
                {
                    Zero, 
                    Zero
                })
                Name (_S0W, 0x02)  // _S0W: S0 Device Wake State
                Name (_S4W, 0x02)  // _S4W: S4 Device Wake State
                Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
                {
                    Name (RBUF, Buffer (0x20)
                    {
                        /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x00, 0x03,  // ........
                        /* 0008 */  0x00, 0x00, 0x00, 0x01, 0x89, 0x06, 0x00, 0x19,  // ........
                        /* 0010 */  0x01, 0xEA, 0x00, 0x00, 0x00, 0x89, 0x06, 0x00,  // ........
                        /* 0018 */  0x01, 0x01, 0xEB, 0x00, 0x00, 0x00, 0x79, 0x00   // ......y.
                    })
                    Return (RBUF) /* \_SB_.RIVA.QWLN._CRS.RBUF */
                }

                Method (_DIS, 0, NotSerialized)  // _DIS: Disable Device
                {
                }

                Method (_PS0, 0, NotSerialized)  // _PS0: Power State 0
                {
                }

                Method (_PS1, 0, NotSerialized)  // _PS1: Power State 1
                {
                }

                Method (_PS2, 0, NotSerialized)  // _PS2: Power State 2
                {
                }

                Method (_PS3, 0, NotSerialized)  // _PS3: Power State 3
                {
                }
            }

            Device (FMT0)
            {
                Name (_ADR, 0x03)  // _ADR: Address
            }

            Device (WPXY)
            {
                Name (_HID, "NOKIA_WLAN_PROXY")  // _HID: Hardware ID
            }

            Name (RMEM, Package (0x01)
            {
                Package (0x02)
                {
                    0x8F200000, 
                    0x0500
                }
            })
            Method (CONF, 0, NotSerialized)
            {
                Return (RMEM) /* \_SB_.RIVA.RMEM */
            }
        }

        Device (FTM0)
        {
            Name (_HID, "QCOM01E1")  // _HID: Hardware ID
        }

        Device (RFS0)
        {
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.IPC0, 
            })
            Name (_HID, "QCOM0F20")  // _HID: Hardware ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x0E)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0xB0, 0x8F,  // ........
                    /* 0008 */  0x00, 0x00, 0x30, 0x00, 0x79, 0x00               // ..0.y.
                })
                Return (RBUF) /* \_SB_.RFS0._CRS.RBUF */
            }
        }

        Device (IPC0)
        {
            Name (_HID, "QCOM0F40")  // _HID: Hardware ID
        }

        Device (SLM1)
        {
            Name (_HID, "QCOM0190")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x17)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x08, 0x28,  // .......(
                    /* 0008 */  0x00, 0x40, 0x00, 0x00, 0x89, 0x06, 0x00, 0x01,  // .@......
                    /* 0010 */  0x01, 0x41, 0x00, 0x00, 0x00, 0x79, 0x00         // .A...y.
                })
                Return (RBUF) /* \_SB_.SLM1._CRS.RBUF */
            }

            Method (FNOC, 0, NotSerialized)
            {
                Name (RBUF, Buffer (0x0F)
                {
                    /* 0000 */  0x00, 0x00, 0x40, 0x00, 0x17, 0x02, 0x01, 0x00,  // ..@.....
                    /* 0008 */  0x02, 0x03, 0x01, 0x01, 0xFE, 0xFE, 0xFE         // .......
                })
                Return (RBUF) /* \_SB_.SLM1.FNOC.RBUF */
            }

            Method (EKOP, 0, NotSerialized)
            {
                Name (RBUF, Buffer (0x08)
                {
                     0x7C, 0x20, 0x80, 0x00, 0x01, 0x00, 0x00, 0x00   // | ......
                })
                Return (RBUF) /* \_SB_.SLM1.EKOP.RBUF */
            }
        }

        Device (QQCE)
        {
            Name (_HID, "QCOM1100")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x0E)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x50, 0x18,  // ......P.
                    /* 0008 */  0x00, 0x00, 0x02, 0x00, 0x79, 0x00               // ....y.
                })
                Return (RBUF) /* \_SB_.QQCE._CRS.RBUF */
            }
        }

        Device (QCE2)
        {
            Name (_HID, "QCOM1190")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x0E)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x56, 0x12,  // ......V.
                    /* 0008 */  0x00, 0x00, 0x02, 0x00, 0x79, 0x00               // ....y.
                })
                Return (RBUF) /* \_SB_.QCE2._CRS.RBUF */
            }
        }

        Device (QRNG)
        {
            Name (_HID, "QCOM1110")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x0E)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x50, 0x1A,  // ......P.
                    /* 0008 */  0x00, 0x04, 0x00, 0x00, 0x79, 0x00               // ....y.
                })
                Return (RBUF) /* \_SB_.QRNG._CRS.RBUF */
            }
        }

        Device (QBCC)
        {
            Name (_DEP, Package (0x03)  // _DEP: Dependencies
            {
                \_SB.PEP0, , 
                \_SB.QQCE, , 
                \_SB.QCE2, 
            })
            Name (_HID, "QCOM1000")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
        }

        Device (TPM0)
        {
            Name (_HID, "MSFT0101" /* TPM 2.0 Security Device */)  // _HID: Hardware ID
            OperationRegion (TPMR, SystemMemory, 0x2A03FA94, 0x04)
            Field (TPMR, ByteAcc, NoLock, Preserve)
            {
                MORR,   8, 
                PCMD,   8, 
                CCMD,   8, 
                RCMD,   8
            }

            Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
            {
                If ((Arg0 == ToUUID ("3dddfaa6-361b-4eb4-a424-8d10089d1653") /* Physical Presence Interface */))
                {
                    If ((Arg2 == Zero))
                    {
                        Return (Buffer (0x02)
                        {
                             0xFF, 0x01                                       // ..
                        })
                    }

                    If ((Arg2 == One))
                    {
                        Return ("1.2")
                    }

                    If ((Arg2 == 0x02))
                    {
                        Return (0x02)
                    }

                    If ((Arg2 == 0x03))
                    {
                        Local0 = Package (0x02)
                            {
                                Zero, 
                                Zero
                            }
                        Local1 = RefOf (Local0 [One])
                        Local1 = \_SB.TPM0.PCMD
                        Return (Local0)
                    }

                    If ((Arg2 == 0x04))
                    {
                        Return (0x02)
                    }

                    If ((Arg2 == 0x05))
                    {
                        Local0 = Package (0x03)
                            {
                                Zero, 
                                Zero, 
                                Zero
                            }
                        Local1 = RefOf (Local0 [One])
                        Local2 = RefOf (Local0 [0x02])
                        Local1 = \_SB.TPM0.CCMD
                        Local2 = \_SB.TPM0.RCMD
                        Return (Local0)
                    }

                    If ((Arg2 == 0x06))
                    {
                        Return (0x03)
                    }

                    If ((Arg2 == 0x07))
                    {
                        PCMD = DerefOf (Arg3 [Zero])
                        Return (Zero)
                    }

                    If ((Arg2 == 0x08))
                    {
                        Return (0x04)
                    }

                    Return (Buffer (One)
                    {
                         0x00                                             // .
                    })
                }

                If ((Arg0 == ToUUID ("376054ed-cc13-4675-901c-4756d7f2d45d") /* TPM Memory Clear */))
                {
                    MORR = DerefOf (Arg3 [Zero])
                    Return (Zero)
                }

                Return (Buffer (One)
                {
                     0x00                                             // .
                })
            }
        }

        Device (SCM0)
        {
            Name (_HID, "QCOM0E90")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x26)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x94, 0xFA, 0x03, 0x2A,  // .......*
                    /* 0008 */  0x04, 0x00, 0x00, 0x00, 0x86, 0x09, 0x00, 0x01,  // ........
                    /* 0010 */  0x00, 0x00, 0x40, 0x81, 0x00, 0xD0, 0x03, 0x00,  // ..@.....
                    /* 0018 */  0x86, 0x09, 0x00, 0x01, 0x00, 0xD0, 0x43, 0x81,  // ......C.
                    /* 0020 */  0x00, 0x30, 0x00, 0x00, 0x79, 0x00               // .0..y.
                })
                Return (RBUF) /* \_SB_.SCM0._CRS.RBUF */
            }

            Method (GCFG, 0, NotSerialized)
            {
                Name (SCFG, Package (0x00){})
                Return (SCFG) /* \_SB_.SCM0.GCFG.SCFG */
            }
        }

        Device (SDC1)
        {
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.PEP0, 
            })
            Name (_HID, "QCOM7002")  // _HID: Hardware ID
            Name (_CID, "ACPIQCOM7002")  // _CID: Compatible ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x23)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x40, 0x12,  // ......@.
                    /* 0008 */  0x00, 0x08, 0x00, 0x00, 0x89, 0x06, 0x00, 0x01,  // ........
                    /* 0010 */  0x01, 0x88, 0x00, 0x00, 0x00, 0x55, 0x2E, 0x00,  // .....U..
                    /* 0018 */  0x00, 0x00, 0x02, 0x55, 0x2F, 0x00, 0x01, 0x00,  // ...U/...
                    /* 0020 */  0x02, 0x79, 0x00                                 // .y.
                })
                Return (RBUF) /* \_SB_.SDC1._CRS.RBUF */
            }

            Device (EMMC)
            {
                Method (_ADR, 0, NotSerialized)  // _ADR: Address
                {
                    Return (0x08)
                }

                Method (_RMV, 0, NotSerialized)  // _RMV: Removal Status
                {
                    Return (Zero)
                }
            }

            Method (_DIS, 0, NotSerialized)  // _DIS: Disable Device
            {
            }
        }

        Device (SDC3)
        {
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.PEP0, 
            })
            Name (_HID, "QCOM7002")  // _HID: Hardware ID
            Name (_CID, "ACPIQCOM7002")  // _CID: Compatible ID
            Name (_UID, 0x02)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x69)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x18, 0x12,  // ........
                    /* 0008 */  0x00, 0x08, 0x00, 0x00, 0x89, 0x06, 0x00, 0x01,  // ........
                    /* 0010 */  0x01, 0x86, 0x00, 0x00, 0x00, 0x55, 0x3A, 0x00,  // .....U:.
                    /* 0018 */  0x00, 0x00, 0x02, 0x55, 0x3B, 0x00, 0x01, 0x00,  // ...U;...
                    /* 0020 */  0x02, 0x8C, 0x20, 0x00, 0x01, 0x00, 0x01, 0x00,  // .. .....
                    /* 0028 */  0x1D, 0x00, 0x02, 0x00, 0x00, 0x30, 0x75, 0x17,  // .....0u.
                    /* 0030 */  0x00, 0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00,  // ....#...
                    /* 0038 */  0x5E, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x47,  // ^.\_SB.G
                    /* 0040 */  0x49, 0x4F, 0x30, 0x00, 0x8C, 0x20, 0x00, 0x01,  // IO0.. ..
                    /* 0048 */  0x01, 0x01, 0x00, 0x08, 0x00, 0x02, 0x00, 0x00,  // ........
                    /* 0050 */  0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // .......#
                    /* 0058 */  0x00, 0x00, 0x00, 0x5E, 0x00, 0x5C, 0x5F, 0x53,  // ...^.\_S
                    /* 0060 */  0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x79,  // B.GIO0.y
                    /* 0068 */  0x00                                             // .
                })
                Return (RBUF) /* \_SB_.SDC3._CRS.RBUF */
            }
        }

        Device (ACHW)
        {
            Name (_DEP, Package (0x06)  // _DEP: Dependencies
            {
                \_SB.PEP0, , 
                \_SB.PMIC, , 
                \_SB.Q6AD, , 
                \_SB.ACDB, , 
                \_SB.SLM1, , 
                \_SB.TICO, 
            })
            Name (_HID, "QCOM0741")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x25)
                {
                    /* 0000 */  0x8C, 0x20, 0x00, 0x01, 0x01, 0x01, 0x00, 0x00,  // . ......
                    /* 0008 */  0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00,  // ........
                    /* 0010 */  0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x2A,  // ...#...*
                    /* 0018 */  0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x47, 0x49,  // .\_SB.GI
                    /* 0020 */  0x4F, 0x30, 0x00, 0x79, 0x00                     // O0.y.
                })
                Return (RBUF) /* \_SB_.ACHW._CRS.RBUF */
            }

            Method (BFSZ, 0, NotSerialized)
            {
                Name (SIZE, Package (0x01)
                {
                    0x0800
                })
                Return (SIZE) /* \_SB_.ACHW.BFSZ.SIZE */
            }

            Method (GPNF, 0, NotSerialized)
            {
                Name (GPIO, Package (0x01)
                {
                    Package (0x03)
                    {
                        Zero, 
                        Zero, 
                        One
                    }
                })
                Return (GPIO) /* \_SB_.ACHW.GPNF.GPIO */
            }

            Method (PPNF, 0, NotSerialized)
            {
                Name (PP, Package (0x04)
                {
                    Package (0x02)
                    {
                        Zero, 
                        Package (0x03)
                        {
                            Zero, 
                            Zero, 
                            One
                        }
                    }, 

                    Package (0x03)
                    {
                        0x0E, 
                        Package (0x03)
                        {
                            Zero, 
                            Zero, 
                            One
                        }, 

                        Package (0x03)
                        {
                            0x03, 
                            Zero, 
                            0x02
                        }
                    }, 

                    Package (0x03)
                    {
                        0x44, 
                        Package (0x03)
                        {
                            Zero, 
                            Zero, 
                            One
                        }, 

                        Package (0x03)
                        {
                            0x03, 
                            Zero, 
                            0x02
                        }
                    }, 

                    Package (0x03)
                    {
                        0xC8, 
                        Package (0x03)
                        {
                            Zero, 
                            Zero, 
                            One
                        }, 

                        Package (0x03)
                        {
                            0x03, 
                            Zero, 
                            0x02
                        }
                    }
                })
                Return (PP) /* \_SB_.ACHW.PPNF.PP__ */
            }
        }

        Device (TICO)
        {
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.SLM1, 
            })
            Name (_HID, "QCOM0742")  // _HID: Hardware ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x25)
                {
                    /* 0000 */  0x8C, 0x20, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01,  // . ......
                    /* 0008 */  0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00,  // ........
                    /* 0010 */  0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x3E,  // ...#...>
                    /* 0018 */  0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x47, 0x49,  // .\_SB.GI
                    /* 0020 */  0x4F, 0x30, 0x00, 0x79, 0x00                     // O0.y.
                })
                Return (RBUF) /* \_SB_.TICO._CRS.RBUF */
            }
        }

        Device (MBHC)
        {
            Name (_DEP, Package (0x06)  // _DEP: Dependencies
            {
                \_SB.PEP0, , 
                \_SB.PMIC, , 
                \_SB.ACDB, , 
                \_SB.SLM1, , 
                \_SB.TICO, , 
                \_SB.ACHW, 
            })
            Name (_HID, "QCOM0746")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x6B)
                {
                    /* 0000 */  0x8C, 0x20, 0x00, 0x01, 0x01, 0x01, 0x00, 0x00,  // . ......
                    /* 0008 */  0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00,  // ........
                    /* 0010 */  0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x2B,  // ...#...+
                    /* 0018 */  0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x47, 0x49,  // .\_SB.GI
                    /* 0020 */  0x4F, 0x30, 0x00, 0x8C, 0x20, 0x00, 0x01, 0x01,  // O0.. ...
                    /* 0028 */  0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,  // ........
                    /* 0030 */  0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23, 0x00,  // ......#.
                    /* 0038 */  0x00, 0x00, 0x33, 0x00, 0x5C, 0x5F, 0x53, 0x42,  // ..3.\_SB
                    /* 0040 */  0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x8C, 0x20,  // .GIO0.. 
                    /* 0048 */  0x00, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x02,  // ........
                    /* 0050 */  0x00, 0x00, 0x00, 0x00, 0x17, 0x00, 0x00, 0x19,  // ........
                    /* 0058 */  0x00, 0x23, 0x00, 0x00, 0x00, 0x2B, 0x00, 0x5C,  // .#...+.\
                    /* 0060 */  0x5F, 0x53, 0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30,  // _SB.GIO0
                    /* 0068 */  0x00, 0x79, 0x00                                 // .y.
                })
                Return (RBUF) /* \_SB_.MBHC._CRS.RBUF */
            }
        }

        Device (MBGP)
        {
            Name (_DEP, Package (0x06)  // _DEP: Dependencies
            {
                \_SB.PEP0, , 
                \_SB.PMIC, , 
                \_SB.ACDB, , 
                \_SB.SLM1, , 
                \_SB.TICO, , 
                \_SB.ACHW, 
            })
            Name (_HID, "QCOM2149")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x8E)
                {
                    /* 0000 */  0x8C, 0x20, 0x00, 0x01, 0x01, 0x01, 0x00, 0x00,  // . ......
                    /* 0008 */  0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00,  // ........
                    /* 0010 */  0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x33,  // ...#...3
                    /* 0018 */  0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x47, 0x49,  // .\_SB.GI
                    /* 0020 */  0x4F, 0x30, 0x00, 0x8C, 0x20, 0x00, 0x01, 0x00,  // O0.. ...
                    /* 0028 */  0x01, 0x00, 0x1D, 0x00, 0x03, 0x00, 0x00, 0x50,  // .......P
                    /* 0030 */  0xC3, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23, 0x00,  // ......#.
                    /* 0038 */  0x00, 0x00, 0x2B, 0x00, 0x5C, 0x5F, 0x53, 0x42,  // ..+.\_SB
                    /* 0040 */  0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x8C, 0x20,  // .GIO0.. 
                    /* 0048 */  0x00, 0x01, 0x01, 0x01, 0x00, 0x08, 0x00, 0x03,  // ........
                    /* 0050 */  0x00, 0x00, 0x00, 0x00, 0x17, 0x00, 0x00, 0x19,  // ........
                    /* 0058 */  0x00, 0x23, 0x00, 0x00, 0x00, 0x2B, 0x00, 0x5C,  // .#...+.\
                    /* 0060 */  0x5F, 0x53, 0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30,  // _SB.GIO0
                    /* 0068 */  0x00, 0x8C, 0x20, 0x00, 0x01, 0x01, 0x01, 0x00,  // .. .....
                    /* 0070 */  0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x17,  // ........
                    /* 0078 */  0x00, 0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00,  // ....#...
                    /* 0080 */  0x2B, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x47,  // +.\_SB.G
                    /* 0088 */  0x49, 0x4F, 0x30, 0x00, 0x79, 0x00               // IO0.y.
                })
                Return (RBUF) /* \_SB_.MBGP._CRS.RBUF */
            }

            Method (BFSZ, 0, NotSerialized)
            {
                Name (SIZE, Package (0x01)
                {
                    0x0800
                })
                Return (SIZE) /* \_SB_.MBGP.BFSZ.SIZE */
            }

            Method (GPNF, 0, NotSerialized)
            {
                Name (GPIO, Package (0x03)
                {
                    Package (0x03)
                    {
                        One, 
                        0x02, 
                        One
                    }, 

                    Package (0x03)
                    {
                        0x02, 
                        0x03, 
                        One
                    }, 

                    Package (0x03)
                    {
                        0x03, 
                        0x04, 
                        Zero
                    }
                })
                Return (GPIO) /* \_SB_.MBGP.GPNF.GPIO */
            }
        }

        Device (UFN1)
        {
            Name (_HID, "QCOM01C0")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Name (REG, Zero)
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x17)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x00, 0x50, 0x12,  // ......P.
                    /* 0008 */  0x00, 0x02, 0x00, 0x00, 0x89, 0x06, 0x00, 0x09,  // ........
                    /* 0010 */  0x01, 0x84, 0x00, 0x00, 0x00, 0x79, 0x00         // .....y.
                })
                Local0 = RBUF /* \_SB_.UFN1._CRS.RBUF */
                ConcatenateResTemplate (Local0, Buffer (0x0B)
                    {
                        /* 0000 */  0x89, 0x06, 0x00, 0x19, 0x01, 0x84, 0x00, 0x00,  // ........
                        /* 0008 */  0x00, 0x79, 0x00                                 // .y.
                    }, Local1)
                Return (Local1)
            }

            OperationRegion (UCDR, SystemMemory, 0x12500000, 0x1000)
            Field (UCDR, WordAcc, NoLock, Preserve)
            {
                Offset (0x90), 
                AHBB,   32, 
                Offset (0x98), 
                AHBM,   32, 
                GENC,   32, 
                Offset (0x184), 
                PTSC,   32, 
                Offset (0x1A8), 
                MODE,   32
            }

            Method (_UBF, 0, NotSerialized)
            {
                MODE = 0x02
                REG = PTSC /* \_SB_.UFN1.PTSC */
                PTSC = (REG | 0x02)
                AHBM = 0x08
                AHBB = Zero
                GENC = 0x0CB0
            }

            Method (PHYC, 0, NotSerialized)
            {
                Name (CFG0, Package (0x02)
                {
                    Package (0x02)
                    {
                        0x81, 
                        0x38
                    }, 

                    Package (0x02)
                    {
                        0x82, 
                        0x14
                    }
                })
                Return (CFG0) /* \_SB_.UFN1.PHYC.CFG0 */
            }
        }

        Device (QDIG)
        {
            Name (_HID, "QCOM0F80")  // _HID: Hardware ID
        }

        Device (QDCI)
        {
            Name (_HID, "QCOM0F81")  // _HID: Hardware ID
        }

        Device (QCDB)
        {
            Name (_HID, "QCOM1204")  // _HID: Hardware ID
        }

        Device (ADC1)
        {
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.PMIC, 
            })
            Name (_HID, "QCOM0C00")  // _HID: Hardware ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x6B)
                {
                    /* 0000 */  0x8C, 0x20, 0x00, 0x01, 0x00, 0x01, 0x00, 0x11,  // . ......
                    /* 0008 */  0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00,  // ........
                    /* 0010 */  0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x4E,  // ...#...N
                    /* 0018 */  0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x50, 0x4D,  // .\_SB.PM
                    /* 0020 */  0x30, 0x31, 0x00, 0x8C, 0x20, 0x00, 0x01, 0x00,  // 01.. ...
                    /* 0028 */  0x01, 0x00, 0x11, 0x00, 0x02, 0x00, 0x00, 0x00,  // ........
                    /* 0030 */  0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23, 0x00,  // ......#.
                    /* 0038 */  0x00, 0x00, 0x48, 0x00, 0x5C, 0x5F, 0x53, 0x42,  // ..H.\_SB
                    /* 0040 */  0x2E, 0x50, 0x4D, 0x30, 0x31, 0x00, 0x8C, 0x20,  // .PM01.. 
                    /* 0048 */  0x00, 0x01, 0x00, 0x01, 0x00, 0x11, 0x00, 0x02,  // ........
                    /* 0050 */  0x00, 0x00, 0x00, 0x00, 0x17, 0x00, 0x00, 0x19,  // ........
                    /* 0058 */  0x00, 0x23, 0x00, 0x00, 0x00, 0x49, 0x00, 0x5C,  // .#...I.\
                    /* 0060 */  0x5F, 0x53, 0x42, 0x2E, 0x50, 0x4D, 0x30, 0x31,  // _SB.PM01
                    /* 0068 */  0x00, 0x79, 0x00                                 // .y.
                })
                Return (RBUF) /* \_SB_.ADC1._CRS.RBUF */
            }

            Method (CHAN, 0, NotSerialized)
            {
                Return (Package (0x17)
                {
                    Package (0x0D)
                    {
                        "VCOIN", 
                        Zero, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "VBATT", 
                        One, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "VCHG", 
                        0x02, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "ICHG", 
                        0x03, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "VPH_PWR", 
                        0x04, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "", 
                        0x05, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "BATT_THERM", 
                        0x08, 
                        0x02, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        BTTB, , 
                        Zero, 
                        Zero, 
                        Zero
                    }, 

                    Package (0x0D)
                    {
                        "BATT_THERM2", 
                        0x06, 
                        One, 
                        One, 
                        0x06, 
                        0x03, 
                        One, 
                        Zero, 
                        Zero, 
                        BTTB, , 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "BATT_ID", 
                        0x09, 
                        0x02, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero
                    }, 

                    Package (0x0D)
                    {
                        "BATT_RID", 
                        0x09, 
                        0x02, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        BRID, 0x02, 
                        Zero
                    }, 

                    Package (0x0D)
                    {
                        "USB_IN", 
                        0x0A, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "PMIC_THERM", 
                        0x0B, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        PTCF, 0x02, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "CHG_TEMP", 
                        0x0E, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        PTCF, 0x02, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "PA_THERM", 
                        0x06, 
                        One, 
                        One, 
                        0x03, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        PATB, , 
                        Zero, 
                        Zero, 
                        Zero
                    }, 

                    Package (0x0D)
                    {
                        "PA_THERM1", 
                        0x06, 
                        One, 
                        One, 
                        0x04, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        PATB, , 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "XO_THERM", 
                        0x0F, 
                        Zero, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        XTTB, , 
                        XOCF, One, 
                        Zero
                    }, 

                    Package (0x0D)
                    {
                        "XO_THERM_GPS", 
                        0x0F, 
                        Zero, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        One, 
                        XTTB, , 
                        XOCF, One, 
                        Zero
                    }, 

                    Package (0x0D)
                    {
                        "VBATT_GSM", 
                        One, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        0x02, 
                        Zero, 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "VREF", 
                        0x0F, 
                        0x04, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero
                    }, 

                    Package (0x0D)
                    {
                        "VGND", 
                        0x0F, 
                        0x03, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero
                    }, 

                    Package (0x0D)
                    {
                        "V0P625", 
                        0x0C, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "V1P25", 
                        0x0D, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "BOM_DET", 
                        0x06, 
                        One, 
                        One, 
                        0x06, 
                        0x02, 
                        One, 
                        Zero, 
                        Zero, 
                        Zero, 
                        BDCF, Zero, 
                        One
                    }
                })
            }

            Method (CBCH, 0, NotSerialized)
            {
                Return (Package (0x04)
                {
                    Package (0x0D)
                    {
                        "mvVdd", 
                        0x0F, 
                        0x04, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero
                    }, 

                    Package (0x0D)
                    {
                        "Ground", 
                        0x0F, 
                        0x03, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero
                    }, 

                    Package (0x0D)
                    {
                        "vRef1", 
                        0x0C, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        One
                    }, 

                    Package (0x0D)
                    {
                        "vRef2", 
                        0x0D, 
                        One, 
                        Zero, 
                        0xFFFF, 
                        0xFFFF, 
                        0xFFFF, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        Zero, 
                        One
                    }
                })
            }

            Method (CFGS, 0, NotSerialized)
            {
                Return (Package (0x03)
                {
                    Package (0x03)
                    {
                        One, 
                        Zero, 
                        0x03E8
                    }, 

                    Package (0x03)
                    {
                        0x03, 
                        Zero, 
                        0x0FA0
                    }, 

                    Package (0x03)
                    {
                        Zero, 
                        One, 
                        0x01F4
                    }
                })
            }

            Method (BTMP, 0, NotSerialized)
            {
                Return (Package (0x03)
                {
                    0x06, 
                    One, 
                    Package (0x0F)
                    {
                        0x000F4240, 
                        0x001E8480, 
                        0x002DC6C0, 
                        0x003D0900, 
                        0x004C4B40, 
                        0x005B8D80, 
                        0x006ACFC0, 
                        0x007A1200, 
                        0x00895440, 
                        0x00989680, 
                        0x00A7D8C0, 
                        0x00B71B00, 
                        0x00C65D40, 
                        0x00D59F80, 
                        0x00E4E1C0
                    }
                })
            }

            Method (GENP, 0, NotSerialized)
            {
                Return (Package (0x0B)
                {
                    One, 
                    Zero, 
                    Zero, 
                    One, 
                    0x0708, 
                    0x0271, 
                    0x04E2, 
                    One, 
                    Zero, 
                    Zero, 
                    Zero
                })
            }

            Method (BTTB, 0, NotSerialized)
            {
                Return (Package (0x0C)
                {
                    Package (0x02)
                    {
                        0x0690, 
                        0xFFFFFFE2
                    }, 

                    Package (0x02)
                    {
                        0x0639, 
                        0xFFFFFFEC
                    }, 

                    Package (0x02)
                    {
                        0x05BD, 
                        0xFFFFFFF6
                    }, 

                    Package (0x02)
                    {
                        0x051D, 
                        Zero
                    }, 

                    Package (0x02)
                    {
                        0x0465, 
                        0x0A
                    }, 

                    Package (0x02)
                    {
                        0x03AB, 
                        0x14
                    }, 

                    Package (0x02)
                    {
                        0x0300, 
                        0x1E
                    }, 

                    Package (0x02)
                    {
                        0x0273, 
                        0x28
                    }, 

                    Package (0x02)
                    {
                        0x0204, 
                        0x32
                    }, 

                    Package (0x02)
                    {
                        0x01B2, 
                        0x3C
                    }, 

                    Package (0x02)
                    {
                        0x0176, 
                        0x46
                    }, 

                    Package (0x02)
                    {
                        0x014B, 
                        0x50
                    }
                })
            }

            Method (PATB, 0, NotSerialized)
            {
                Return (Package (0x22)
                {
                    Package (0x02)
                    {
                        0x06E0, 
                        0xFFFFFFD8
                    }, 

                    Package (0x02)
                    {
                        0x06CF, 
                        0xFFFFFFDD
                    }, 

                    Package (0x02)
                    {
                        0x06BA, 
                        0xFFFFFFE2
                    }, 

                    Package (0x02)
                    {
                        0x069D, 
                        0xFFFFFFE7
                    }, 

                    Package (0x02)
                    {
                        0x0678, 
                        0xFFFFFFEC
                    }, 

                    Package (0x02)
                    {
                        0x064A, 
                        0xFFFFFFF1
                    }, 

                    Package (0x02)
                    {
                        0x0611, 
                        0xFFFFFFF6
                    }, 

                    Package (0x02)
                    {
                        0x05CD, 
                        0xFFFFFFFB
                    }, 

                    Package (0x02)
                    {
                        0x057E, 
                        Zero
                    }, 

                    Package (0x02)
                    {
                        0x0524, 
                        0x05
                    }, 

                    Package (0x02)
                    {
                        0x04C2, 
                        0x0A
                    }, 

                    Package (0x02)
                    {
                        0x045A, 
                        0x0F
                    }, 

                    Package (0x02)
                    {
                        0x03EF, 
                        0x14
                    }, 

                    Package (0x02)
                    {
                        0x0383, 
                        0x19
                    }, 

                    Package (0x02)
                    {
                        0x031B, 
                        0x1E
                    }, 

                    Package (0x02)
                    {
                        0x02B8, 
                        0x23
                    }, 

                    Package (0x02)
                    {
                        0x025D, 
                        0x28
                    }, 

                    Package (0x02)
                    {
                        0x020A, 
                        0x2D
                    }, 

                    Package (0x02)
                    {
                        0x01C0, 
                        0x32
                    }, 

                    Package (0x02)
                    {
                        0x017F, 
                        0x37
                    }, 

                    Package (0x02)
                    {
                        0x0147, 
                        0x3C
                    }, 

                    Package (0x02)
                    {
                        0x0116, 
                        0x41
                    }, 

                    Package (0x02)
                    {
                        0xED, 
                        0x46
                    }, 

                    Package (0x02)
                    {
                        0xCA, 
                        0x4B
                    }, 

                    Package (0x02)
                    {
                        0xAC, 
                        0x50
                    }, 

                    Package (0x02)
                    {
                        0x92, 
                        0x55
                    }, 

                    Package (0x02)
                    {
                        0x7D, 
                        0x5A
                    }, 

                    Package (0x02)
                    {
                        0x6B, 
                        0x5F
                    }, 

                    Package (0x02)
                    {
                        0x5C, 
                        0x64
                    }, 

                    Package (0x02)
                    {
                        0x4F, 
                        0x69
                    }, 

                    Package (0x02)
                    {
                        0x44, 
                        0x6E
                    }, 

                    Package (0x02)
                    {
                        0x3B, 
                        0x73
                    }, 

                    Package (0x02)
                    {
                        0x33, 
                        0x78
                    }, 

                    Package (0x02)
                    {
                        0x2C, 
                        0x7D
                    }
                })
            }

            Method (XTTB, 0, NotSerialized)
            {
                Return (Package (0xA6)
                {
                    Package (0x02)
                    {
                        0x000AFDFC, 
                        0xFFFF6000
                    }, 

                    Package (0x02)
                    {
                        0x000A3B47, 
                        0xFFFF6400
                    }, 

                    Package (0x02)
                    {
                        0x0009875A, 
                        0xFFFF6800
                    }, 

                    Package (0x02)
                    {
                        0x0008E0FB, 
                        0xFFFF6C00
                    }, 

                    Package (0x02)
                    {
                        0x00084710, 
                        0xFFFF7000
                    }, 

                    Package (0x02)
                    {
                        0x0007B895, 
                        0xFFFF7400
                    }, 

                    Package (0x02)
                    {
                        0x0007349F, 
                        0xFFFF7800
                    }, 

                    Package (0x02)
                    {
                        0x0006BA55, 
                        0xFFFF7C00
                    }, 

                    Package (0x02)
                    {
                        0x000648F3, 
                        0xFFFF8000
                    }, 

                    Package (0x02)
                    {
                        0x0005DFC4, 
                        0xFFFF8400
                    }, 

                    Package (0x02)
                    {
                        0x00057E23, 
                        0xFFFF8800
                    }, 

                    Package (0x02)
                    {
                        0x0005237A, 
                        0xFFFF8C00
                    }, 

                    Package (0x02)
                    {
                        0x0004CF3E, 
                        0xFFFF9000
                    }, 

                    Package (0x02)
                    {
                        0x000480F0, 
                        0xFFFF9400
                    }, 

                    Package (0x02)
                    {
                        0x0004381C, 
                        0xFFFF9800
                    }, 

                    Package (0x02)
                    {
                        0x0003F457, 
                        0xFFFF9C00
                    }, 

                    Package (0x02)
                    {
                        0x0003B520, 
                        0xFFFFA000
                    }, 

                    Package (0x02)
                    {
                        0x00037A42, 
                        0xFFFFA400
                    }, 

                    Package (0x02)
                    {
                        0x0003436A, 
                        0xFFFFA800
                    }, 

                    Package (0x02)
                    {
                        0x0003104B, 
                        0xFFFFAC00
                    }, 

                    Package (0x02)
                    {
                        0x0002E09E, 
                        0xFFFFB000
                    }, 

                    Package (0x02)
                    {
                        0x0002B424, 
                        0xFFFFB400
                    }, 

                    Package (0x02)
                    {
                        0x00028AA0, 
                        0xFFFFB800
                    }, 

                    Package (0x02)
                    {
                        0x000263DB, 
                        0xFFFFBC00
                    }, 

                    Package (0x02)
                    {
                        0x00023FA2, 
                        0xFFFFC000
                    }, 

                    Package (0x02)
                    {
                        0x00021DC7, 
                        0xFFFFC400
                    }, 

                    Package (0x02)
                    {
                        0x0001FE1F, 
                        0xFFFFC800
                    }, 

                    Package (0x02)
                    {
                        0x0001E081, 
                        0xFFFFCC00
                    }, 

                    Package (0x02)
                    {
                        0x0001C4CA, 
                        0xFFFFD000
                    }, 

                    Package (0x02)
                    {
                        0x0001AAD6, 
                        0xFFFFD400
                    }, 

                    Package (0x02)
                    {
                        0x00019287, 
                        0xFFFFD800
                    }, 

                    Package (0x02)
                    {
                        0x00017BB7, 
                        0xFFFFDC00
                    }, 

                    Package (0x02)
                    {
                        0x00016655, 
                        0xFFFFE000
                    }, 

                    Package (0x02)
                    {
                        0x00015249, 
                        0xFFFFE400
                    }, 

                    Package (0x02)
                    {
                        0x00013F7A, 
                        0xFFFFE800
                    }, 

                    Package (0x02)
                    {
                        0x00012DD3, 
                        0xFFFFEC00
                    }, 

                    Package (0x02)
                    {
                        0x00011D47, 
                        0xFFFFF000
                    }, 

                    Package (0x02)
                    {
                        0x00010DBB, 
                        0xFFFFF400
                    }, 

                    Package (0x02)
                    {
                        0xFF1F, 
                        0xFFFFF800
                    }, 

                    Package (0x02)
                    {
                        0xF163, 
                        0xFFFFFC00
                    }, 

                    Package (0x02)
                    {
                        0xE479, 
                        Zero
                    }, 

                    Package (0x02)
                    {
                        0xD84F, 
                        0x0400
                    }, 

                    Package (0x02)
                    {
                        0xCCDE, 
                        0x0800
                    }, 

                    Package (0x02)
                    {
                        0xC217, 
                        0x0C00
                    }, 

                    Package (0x02)
                    {
                        0xB7F2, 
                        0x1000
                    }, 

                    Package (0x02)
                    {
                        0xAE64, 
                        0x1400
                    }, 

                    Package (0x02)
                    {
                        0xA562, 
                        0x1800
                    }, 

                    Package (0x02)
                    {
                        0x9CE5, 
                        0x1C00
                    }, 

                    Package (0x02)
                    {
                        0x94E3, 
                        0x2000
                    }, 

                    Package (0x02)
                    {
                        0x8D55, 
                        0x2400
                    }, 

                    Package (0x02)
                    {
                        0x8635, 
                        0x2800
                    }, 

                    Package (0x02)
                    {
                        0x7F7A, 
                        0x2C00
                    }, 

                    Package (0x02)
                    {
                        0x7920, 
                        0x3000
                    }, 

                    Package (0x02)
                    {
                        0x731F, 
                        0x3400
                    }, 

                    Package (0x02)
                    {
                        0x6D73, 
                        0x3800
                    }, 

                    Package (0x02)
                    {
                        0x6817, 
                        0x3C00
                    }, 

                    Package (0x02)
                    {
                        0x6305, 
                        0x4000
                    }, 

                    Package (0x02)
                    {
                        0x5E39, 
                        0x4400
                    }, 

                    Package (0x02)
                    {
                        0x59AF, 
                        0x4800
                    }, 

                    Package (0x02)
                    {
                        0x5564, 
                        0x4C00
                    }, 

                    Package (0x02)
                    {
                        0x5154, 
                        0x5000
                    }, 

                    Package (0x02)
                    {
                        0x4D7A, 
                        0x5400
                    }, 

                    Package (0x02)
                    {
                        0x49D5, 
                        0x5800
                    }, 

                    Package (0x02)
                    {
                        0x4660, 
                        0x5C00
                    }, 

                    Package (0x02)
                    {
                        0x431A, 
                        0x6000
                    }, 

                    Package (0x02)
                    {
                        0x3FFF, 
                        0x6400
                    }, 

                    Package (0x02)
                    {
                        0x3D0D, 
                        0x6800
                    }, 

                    Package (0x02)
                    {
                        0x3A42, 
                        0x6C00
                    }, 

                    Package (0x02)
                    {
                        0x379B, 
                        0x7000
                    }, 

                    Package (0x02)
                    {
                        0x3517, 
                        0x7400
                    }, 

                    Package (0x02)
                    {
                        0x32B3, 
                        0x7800
                    }, 

                    Package (0x02)
                    {
                        0x306E, 
                        0x7C00
                    }, 

                    Package (0x02)
                    {
                        0x2E46, 
                        0x8000
                    }, 

                    Package (0x02)
                    {
                        0x2C39, 
                        0x8400
                    }, 

                    Package (0x02)
                    {
                        0x2A47, 
                        0x8800
                    }, 

                    Package (0x02)
                    {
                        0x286D, 
                        0x8C00
                    }, 

                    Package (0x02)
                    {
                        0x26AA, 
                        0x9000
                    }, 

                    Package (0x02)
                    {
                        0x24FD, 
                        0x9400
                    }, 

                    Package (0x02)
                    {
                        0x2365, 
                        0x9800
                    }, 

                    Package (0x02)
                    {
                        0x21E0, 
                        0x9C00
                    }, 

                    Package (0x02)
                    {
                        0x206E, 
                        0xA000
                    }, 

                    Package (0x02)
                    {
                        0x1F0E, 
                        0xA400
                    }, 

                    Package (0x02)
                    {
                        0x1DBF, 
                        0xA800
                    }, 

                    Package (0x02)
                    {
                        0x1C80, 
                        0xAC00
                    }, 

                    Package (0x02)
                    {
                        0x1B4F, 
                        0xB000
                    }, 

                    Package (0x02)
                    {
                        0x1A2D, 
                        0xB400
                    }, 

                    Package (0x02)
                    {
                        0x1918, 
                        0xB800
                    }, 

                    Package (0x02)
                    {
                        0x1810, 
                        0xBC00
                    }, 

                    Package (0x02)
                    {
                        0x1714, 
                        0xC000
                    }, 

                    Package (0x02)
                    {
                        0x1624, 
                        0xC400
                    }, 

                    Package (0x02)
                    {
                        0x153E, 
                        0xC800
                    }, 

                    Package (0x02)
                    {
                        0x1463, 
                        0xCC00
                    }, 

                    Package (0x02)
                    {
                        0x1393, 
                        0xD000
                    }, 

                    Package (0x02)
                    {
                        0x12CB, 
                        0xD400
                    }, 

                    Package (0x02)
                    {
                        0x120C, 
                        0xD800
                    }, 

                    Package (0x02)
                    {
                        0x1156, 
                        0xDC00
                    }, 

                    Package (0x02)
                    {
                        0x10A8, 
                        0xE000
                    }, 

                    Package (0x02)
                    {
                        0x1002, 
                        0xE400
                    }, 

                    Package (0x02)
                    {
                        0x0F63, 
                        0xE800
                    }, 

                    Package (0x02)
                    {
                        0x0ECB, 
                        0xEC00
                    }, 

                    Package (0x02)
                    {
                        0x0E39, 
                        0xF000
                    }, 

                    Package (0x02)
                    {
                        0x0DAE, 
                        0xF400
                    }, 

                    Package (0x02)
                    {
                        0x0D28, 
                        0xF800
                    }, 

                    Package (0x02)
                    {
                        0x0CA9, 
                        0xFC00
                    }, 

                    Package (0x02)
                    {
                        0x0C2F, 
                        0x00010000
                    }, 

                    Package (0x02)
                    {
                        0x0BBA, 
                        0x00010400
                    }, 

                    Package (0x02)
                    {
                        0x0B4A, 
                        0x00010800
                    }, 

                    Package (0x02)
                    {
                        0x0ADF, 
                        0x00010C00
                    }, 

                    Package (0x02)
                    {
                        0x0A78, 
                        0x00011000
                    }, 

                    Package (0x02)
                    {
                        0x0A16, 
                        0x00011400
                    }, 

                    Package (0x02)
                    {
                        0x09B8, 
                        0x00011800
                    }, 

                    Package (0x02)
                    {
                        0x095D, 
                        0x00011C00
                    }, 

                    Package (0x02)
                    {
                        0x0906, 
                        0x00012000
                    }, 

                    Package (0x02)
                    {
                        0x08B3, 
                        0x00012400
                    }, 

                    Package (0x02)
                    {
                        0x0863, 
                        0x00012800
                    }, 

                    Package (0x02)
                    {
                        0x0816, 
                        0x00012C00
                    }, 

                    Package (0x02)
                    {
                        0x07CD, 
                        0x00013000
                    }, 

                    Package (0x02)
                    {
                        0x0786, 
                        0x00013400
                    }, 

                    Package (0x02)
                    {
                        0x0742, 
                        0x00013800
                    }, 

                    Package (0x02)
                    {
                        0x0701, 
                        0x00013C00
                    }, 

                    Package (0x02)
                    {
                        0x06C3, 
                        0x00014000
                    }, 

                    Package (0x02)
                    {
                        0x0687, 
                        0x00014400
                    }, 

                    Package (0x02)
                    {
                        0x064D, 
                        0x00014800
                    }, 

                    Package (0x02)
                    {
                        0x0616, 
                        0x00014C00
                    }, 

                    Package (0x02)
                    {
                        0x05E1, 
                        0x00015000
                    }, 

                    Package (0x02)
                    {
                        0x05AE, 
                        0x00015400
                    }, 

                    Package (0x02)
                    {
                        0x057C, 
                        0x00015800
                    }, 

                    Package (0x02)
                    {
                        0x054D, 
                        0x00015C00
                    }, 

                    Package (0x02)
                    {
                        0x0520, 
                        0x00016000
                    }, 

                    Package (0x02)
                    {
                        0x04F4, 
                        0x00016400
                    }, 

                    Package (0x02)
                    {
                        0x04CA, 
                        0x00016800
                    }, 

                    Package (0x02)
                    {
                        0x04A1, 
                        0x00016C00
                    }, 

                    Package (0x02)
                    {
                        0x047A, 
                        0x00017000
                    }, 

                    Package (0x02)
                    {
                        0x0455, 
                        0x00017400
                    }, 

                    Package (0x02)
                    {
                        0x0431, 
                        0x00017800
                    }, 

                    Package (0x02)
                    {
                        0x040E, 
                        0x00017C00
                    }, 

                    Package (0x02)
                    {
                        0x03ED, 
                        0x00018000
                    }, 

                    Package (0x02)
                    {
                        0x03CC, 
                        0x00018400
                    }, 

                    Package (0x02)
                    {
                        0x03AD, 
                        0x00018800
                    }, 

                    Package (0x02)
                    {
                        0x038F, 
                        0x00018C00
                    }, 

                    Package (0x02)
                    {
                        0x0372, 
                        0x00019000
                    }, 

                    Package (0x02)
                    {
                        0x0356, 
                        0x00019400
                    }, 

                    Package (0x02)
                    {
                        0x033B, 
                        0x00019800
                    }, 

                    Package (0x02)
                    {
                        0x0322, 
                        0x00019C00
                    }, 

                    Package (0x02)
                    {
                        0x0309, 
                        0x0001A000
                    }, 

                    Package (0x02)
                    {
                        0x02F1, 
                        0x0001A400
                    }, 

                    Package (0x02)
                    {
                        0x02D9, 
                        0x0001A800
                    }, 

                    Package (0x02)
                    {
                        0x02C3, 
                        0x0001AC00
                    }, 

                    Package (0x02)
                    {
                        0x02AE, 
                        0x0001B000
                    }, 

                    Package (0x02)
                    {
                        0x0299, 
                        0x0001B400
                    }, 

                    Package (0x02)
                    {
                        0x0285, 
                        0x0001B800
                    }, 

                    Package (0x02)
                    {
                        0x0271, 
                        0x0001BC00
                    }, 

                    Package (0x02)
                    {
                        0x025E, 
                        0x0001C000
                    }, 

                    Package (0x02)
                    {
                        0x024C, 
                        0x0001C400
                    }, 

                    Package (0x02)
                    {
                        0x023B, 
                        0x0001C800
                    }, 

                    Package (0x02)
                    {
                        0x022A, 
                        0x0001CC00
                    }, 

                    Package (0x02)
                    {
                        0x021A, 
                        0x0001D000
                    }, 

                    Package (0x02)
                    {
                        0x020A, 
                        0x0001D400
                    }, 

                    Package (0x02)
                    {
                        0x01FB, 
                        0x0001D800
                    }, 

                    Package (0x02)
                    {
                        0x01EC, 
                        0x0001DC00
                    }, 

                    Package (0x02)
                    {
                        0x01DE, 
                        0x0001E000
                    }, 

                    Package (0x02)
                    {
                        0x01D0, 
                        0x0001E400
                    }, 

                    Package (0x02)
                    {
                        0x01C3, 
                        0x0001E800
                    }, 

                    Package (0x02)
                    {
                        0x01B6, 
                        0x0001EC00
                    }, 

                    Package (0x02)
                    {
                        0x01A9, 
                        0x0001F000
                    }, 

                    Package (0x02)
                    {
                        0x019D, 
                        0x0001F400
                    }
                })
            }

            Method (BRID, 1, NotSerialized)
            {
                Name (VREF, 0x0708)
                Name (RPUL, 0x64)
                Local1 = (VREF * 0x03E8)
                If ((Arg0 >= Local1))
                {
                    Return (0x7FFFFFFF)
                }

                Local0 = (0x64 * Arg0)
                Local1 -= Arg0
                Local1 += 0x01F4
                Local1 /= 0x03E8
                If ((Local1 == Zero))
                {
                    Return (0x7FFFFFFF)
                }

                Divide (Local0, Local1, Local2, Local3)
                Return (Local3)
            }

            Method (BDTB, 0, NotSerialized)
            {
                Return (Package (0x06)
                {
                    Package (0x02)
                    {
                        0x0384, 
                        One
                    }, 

                    Package (0x02)
                    {
                        0x02D9, 
                        0x02
                    }, 

                    Package (0x02)
                    {
                        0x021E, 
                        0x03
                    }, 

                    Package (0x02)
                    {
                        0x0145, 
                        0x04
                    }, 

                    Package (0x02)
                    {
                        0xA4, 
                        0x05
                    }, 

                    Package (0x02)
                    {
                        0x27, 
                        0x06
                    }
                })
            }

            Method (BDCF, 1, NotSerialized)
            {
                If (((Arg0 >= 0x0624) && (Arg0 <= 0x06A4)))
                {
                    Return (0x09)
                }

                If (((Arg0 >= 0x0586) && (Arg0 <= 0x0613)))
                {
                    Return (0x08)
                }

                If (((Arg0 >= 0x048A) && (Arg0 <= 0x0522)))
                {
                    Return (0x07)
                }

                If (((Arg0 >= 0x033D) && (Arg0 <= 0x03CD)))
                {
                    Return (One)
                }

                If (((Arg0 >= 0x0299) && (Arg0 <= 0x031C)))
                {
                    Return (0x02)
                }

                If (((Arg0 >= 0x0218) && (Arg0 <= 0x026A)))
                {
                    Return (0x03)
                }

                If (((Arg0 >= 0x0122) && (Arg0 <= 0x016B)))
                {
                    Return (0x04)
                }

                If (((Arg0 >= 0x91) && (Arg0 <= 0xB9)))
                {
                    Return (0x05)
                }

                If (((Arg0 >= 0x22) && (Arg0 <= 0x2C)))
                {
                    Return (0x06)
                }
                Else
                {
                    Return (Zero)
                }
            }

            Method (PTCF, 1, NotSerialized)
            {
                Local0 = (Arg0 >> One)
                Local0 -= 0x00042B08
                Return (Local0)
            }

            Method (XOCF, 1, NotSerialized)
            {
                Local1 = (Arg0 << 0x0E)
                Local0 = (0xFFFF - Arg0)
                Local2 = (Local0 >> One)
                If ((Local0 == Zero))
                {
                    Return (0x7FFFFFFF)
                }

                Local3 = (Local1 + Local2)
                Divide (Local3, Local0, Local4, Local3)
                If ((Local3 > 0x7FFFFFFF))
                {
                    Return (0x7FFFFFFF)
                }

                Return (Local3)
            }
        }

        Device (BAM0)
        {
            Name (_HID, "QCOM0910")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x17)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x40, 0x24, 0x12,  // .....@$.
                    /* 0008 */  0x00, 0x20, 0x00, 0x00, 0x89, 0x06, 0x00, 0x03,  // . ......
                    /* 0010 */  0x01, 0x89, 0x00, 0x00, 0x00, 0x79, 0x00         // .....y.
                })
                Return (RBUF) /* \_SB_.BAM0._CRS.RBUF */
            }

            Method (INFO, 0, NotSerialized)
            {
                Name (RBUF, Package (0x02)
                {
                    "BAMDMA", 
                    Zero
                })
                Return (RBUF) /* \_SB_.BAM0.INFO.RBUF */
            }

            Method (PIPE, 0, NotSerialized)
            {
                Return (Package (0x02)
                {
                    Package (0x07)
                    {
                        Zero, 
                        Zero, 
                        One, 
                        0x21, 
                        0x0100, 
                        Zero, 
                        Zero
                    }, 

                    Package (0x07)
                    {
                        One, 
                        One, 
                        One, 
                        0x21, 
                        0x0100, 
                        Zero, 
                        Zero
                    }
                })
            }
        }

        Device (BAM1)
        {
            Name (_HID, "QCOM0910")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x17)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x20, 0x4C, 0x12,  // ..... L.
                    /* 0008 */  0x00, 0x20, 0x00, 0x00, 0x89, 0x06, 0x00, 0x03,  // . ......
                    /* 0010 */  0x01, 0xF1, 0x00, 0x00, 0x00, 0x79, 0x00         // .....y.
                })
                Return (RBUF) /* \_SB_.BAM1._CRS.RBUF */
            }

            Method (INFO, 0, NotSerialized)
            {
                Name (RBUF, Package (0x02)
                {
                    "DataBAM", 
                    Zero
                })
                Return (RBUF) /* \_SB_.BAM1.INFO.RBUF */
            }
        }

        Device (BAM2)
        {
            Name (_HID, "QCOM0910")  // _HID: Hardware ID
            Name (_UID, 0x02)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x17)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x00, 0x40, 0x08, 0x28,  // .....@.(
                    /* 0008 */  0x00, 0x20, 0x00, 0x00, 0x89, 0x06, 0x00, 0x03,  // . ......
                    /* 0010 */  0x01, 0x42, 0x00, 0x00, 0x00, 0x79, 0x00         // .B...y.
                })
                Return (RBUF) /* \_SB_.BAM2._CRS.RBUF */
            }

            Method (INFO, 0, NotSerialized)
            {
                Name (RBUF, Package (0x02)
                {
                    "LPASS_BAM", 
                    One
                })
                Return (RBUF) /* \_SB_.BAM2.INFO.RBUF */
            }

            Method (SECC, 0, NotSerialized)
            {
                Return (Package (0x04)
                {
                    Package (0x02)
                    {
                        0x00FFFF98, 
                        Zero
                    }, 

                    Package (0x02)
                    {
                        0xFF000007, 
                        One
                    }, 

                    Package (0x02)
                    {
                        0x60, 
                        0x02
                    }, 

                    Package (0x02)
                    {
                        Zero, 
                        Zero
                    }
                })
            }

            Method (PIPE, 0, NotSerialized)
            {
                Return (Package (0x02)
                {
                    Package (0x07)
                    {
                        0x18, 
                        Zero, 
                        One, 
                        0x21, 
                        0x0100, 
                        Zero, 
                        Zero
                    }, 

                    Package (0x07)
                    {
                        0x19, 
                        One, 
                        One, 
                        0x21, 
                        0x0100, 
                        Zero, 
                        Zero
                    }
                })
            }
        }

        Device (HAL1)
        {
            Name (_HID, "QCOM1001")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
        }

        Device (HAL2)
        {
            Name (_HID, "QCOM1002")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
        }

        Device (HAL3)
        {
            Name (_HID, "QCOM1003")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
        }

        Device (HAL5)
        {
            Name (_HID, "QCOM1005")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
        }

        Device (QMUX)
        {
            Name (_HID, "QCOM0FA0")  // _HID: Hardware ID
        }

        Device (PILC)
        {
            Name (_DEP, Package (0x02)  // _DEP: Dependencies
            {
                \_SB.SCM0, , 
                \_SB.TPM0, 
            })
            Name (_HID, "QCOM0E00")  // _HID: Hardware ID
        }

        Device (CDI)
        {
            Name (_HID, "QCOM0E31")  // _HID: Hardware ID
        }

        Device (RPEN)
        {
            Name (_HID, "QCOM0E30")  // _HID: Hardware ID
        }

        Device (Q6AD)
        {
            Name (_DEP, Package (0x03)  // _DEP: Dependencies
            {
                \_SB.ACDB, , 
                \_SB.ADSP, , 
                \_SB.SMD0, 
            })
            Name (_HID, "QCOM0750")  // _HID: Hardware ID
            Method (INFO, 0, NotSerialized)
            {
                Name (RBUF, Package (0x03)
                {
                    0x29000000, 
                    0xD6FFFFFF, 
                    0x50
                })
                Return (RBUF) /* \_SB_.Q6AD.INFO.RBUF */
            }
        }

        Device (Q6VP)
        {
            Name (_HID, "QCOM0760")  // _HID: Hardware ID
        }

        Device (ACDB)
        {
            Name (_HID, "QCOM0790")  // _HID: Hardware ID
            Method (INFO, 0, NotSerialized)
            {
                Name (RBUF, Package (0x01)
                {
                    One
                })
                Return (RBUF) /* \_SB_.ACDB.INFO.RBUF */
            }
        }

        Device (AHWI)
        {
            Name (_DEP, Package (0x02)  // _DEP: Dependencies
            {
                \_SB.ACDB, , 
                \_SB.Q6AD, 
            })
            Name (_HID, "QCOM0743")  // _HID: Hardware ID
        }

        Device (QCRT)
        {
            Name (_DEP, Package (0x05)  // _DEP: Dependencies
            {
                \_SB.Q6AD, , 
                \_SB.AHWI, , 
                \_SB.MBGP, , 
                \_SB.TICO, , 
                \_SB.ACHW, 
            })
            Name (_HID, "QCOM0744")  // _HID: Hardware ID
            Method (_DEV, 0, NotSerialized)
            {
                Name (CFG0, Package (0x16)
                {
                    One, 
                    Package (0x06)
                    {
                        0x0E, 
                        0x0B, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x0A, 
                        0x08, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x07, 
                        0x04, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x44, 
                        Zero, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        Zero, 
                        Zero, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x0E, 
                        0x04, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x0E, 
                        0x04, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x0E, 
                        0x04, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        Zero, 
                        Zero, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x07, 
                        0x04, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x0E, 
                        0x27, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x0A, 
                        0x27, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x25, 
                        0x24, 
                        0x1F40, 
                        0x1F40, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x25, 
                        0x40, 
                        0x1F40, 
                        0x1F40, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x11, 
                        0x10, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        Zero, 
                        Zero, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        Zero, 
                        Zero, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x0E, 
                        0x04, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        0x0E, 
                        0x04, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    Package (0x06)
                    {
                        Zero, 
                        0x0B, 
                        0xBB80, 
                        0xBB80, 
                        0x10, 
                        0x10
                    }, 

                    0xFF
                })
                Return (CFG0) /* \_SB_.QCRT._DEV.CFG0 */
            }
        }

        Device (WDFH)
        {
            Name (_HID, "QCOM2146")  // _HID: Hardware ID
        }

        Device (AVSD)
        {
            Name (_HID, "QCOM0745")  // _HID: Hardware ID
        }

        Device (AVSE)
        {
            Name (_HID, "QCOM0747")  // _HID: Hardware ID
        }

        Device (CPU0)
        {
            Name (_HID, "ACPI0007" /* Processor Device */)  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
        }

        Device (CPU1)
        {
            Name (_HID, "ACPI0007" /* Processor Device */)  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
        }

        Device (CIN0)
        {
            Name (_HID, "QCOM1201")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x0E)
                {
                    /* 0000 */  0x86, 0x09, 0x00, 0x01, 0x54, 0x20, 0x80, 0x00,  // ....T ..
                    /* 0008 */  0x04, 0x00, 0x00, 0x00, 0x79, 0x00               // ....y.
                })
                Return (RBUF) /* \_SB_.CIN0._CRS.RBUF */
            }
        }

        Device (MBB0)
        {
            Name (_HID, "QCOM0EA0")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
        }

        Device (MBB1)
        {
            Name (_HID, "QCOM0EA0")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
        }

        Device (MBB2)
        {
            Name (_HID, "QCOM0EA0")  // _HID: Hardware ID
            Name (_UID, 0x02)  // _UID: Unique ID
        }

        Device (MBB3)
        {
            Name (_HID, "QCOM0EA0")  // _HID: Hardware ID
            Name (_UID, 0x03)  // _UID: Unique ID
        }

        Device (HWN0)
        {
            Name (_HID, "QCOM0D50")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (HWNL, 0, NotSerialized)
            {
                Name (CFG0, Package (0x0A)
                {
                    Zero, 
                    0x03, 
                    0x0F, 
                    0x14, 
                    Zero, 
                    0x03, 
                    One, 
                    0x04, 
                    0x02, 
                    0x05
                })
                Return (CFG0) /* \_SB_.HWN0.HWNL.CFG0 */
            }
        }

        Device (VIB1)
        {
            Name (_HID, "NOKIA_VIBRA_DIME")  // _HID: Hardware ID
            Name (_CID, "ACPINOKIA_VIBRA_DIME")  // _CID: Compatible ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x02)
                {
                     0x79, 0x00                                       // y.
                })
                Return (RBUF) /* \_SB_.VIB1._CRS.RBUF */
            }
        }

        Device (SSM)
        {
            Name (_HID, "QCOM2123")  // _HID: Hardware ID
        }

        Device (MBRG)
        {
            Name (_HID, "QCOM2145")  // _HID: Hardware ID
        }

        Device (TCH1)
        {
            Name (_HID, "NOKIA_TOUCH")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_DEP, Package (0x04)  // _DEP: Dependencies
            {
                \_SB.PEP0, , 
                \_SB.PRXY, , 
                \_SB.I2C3, , 
                \_SB.GIO0, 
            })
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x64)
                {
                    /* 0000 */  0x8E, 0x19, 0x00, 0x01, 0x00, 0x01, 0x02, 0x00,  // ........
                    /* 0008 */  0x00, 0x01, 0x06, 0x00, 0x80, 0x1A, 0x06, 0x00,  // ........
                    /* 0010 */  0x4B, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x49,  // K.\_SB.I
                    /* 0018 */  0x32, 0x43, 0x33, 0x00, 0x8C, 0x20, 0x00, 0x01,  // 2C3.. ..
                    /* 0020 */  0x00, 0x01, 0x00, 0x13, 0x00, 0x01, 0x00, 0x00,  // ........
                    /* 0028 */  0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // .......#
                    /* 0030 */  0x00, 0x00, 0x00, 0x0B, 0x00, 0x5C, 0x5F, 0x53,  // .....\_S
                    /* 0038 */  0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x8C,  // B.GIO0..
                    /* 0040 */  0x20, 0x00, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00,  //  .......
                    /* 0048 */  0x03, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00, 0x00,  // ........
                    /* 0050 */  0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x34, 0x00,  // ..#...4.
                    /* 0058 */  0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x47, 0x49, 0x4F,  // \_SB.GIO
                    /* 0060 */  0x30, 0x00, 0x79, 0x00                           // 0.y.
                })
                Return (RBUF) /* \_SB_.TCH1._CRS.RBUF */
            }

            Name (PGID, Buffer (0x0A)
            {
                "\\_SB.TCH1"
            })
            Name (DBUF, Buffer (0x0D){})
            CreateByteField (DBUF, Zero, STAT)
            CreateField (DBUF, 0x10, 0x50, DEID)
            CreateByteField (DBUF, 0x0C, DVAL)
            Method (_S1D, 0, NotSerialized)  // _S1D: S1 Device State
            {
                Return (0x03)
            }

            Method (_S2D, 0, NotSerialized)  // _S2D: S2 Device State
            {
                Return (0x03)
            }

            Method (_S3D, 0, NotSerialized)  // _S3D: S3 Device State
            {
                Return (0x03)
            }

            Method (_PS0, 0, NotSerialized)  // _PS0: Power State 0
            {
                DEID = PGID /* \_SB_.TCH1.PGID */
                DVAL = Zero
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.TCH1.DBUF */
                }
            }

            Method (_PS1, 0, NotSerialized)  // _PS1: Power State 1
            {
                DEID = PGID /* \_SB_.TCH1.PGID */
                DVAL = One
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.TCH1.DBUF */
                }
            }

            Method (_PS2, 0, NotSerialized)  // _PS2: Power State 2
            {
                DEID = PGID /* \_SB_.TCH1.PGID */
                DVAL = 0x02
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.TCH1.DBUF */
                }
            }

            Method (_PS3, 0, NotSerialized)  // _PS3: Power State 3
            {
                DEID = PGID /* \_SB_.TCH1.PGID */
                DVAL = 0x03
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.TCH1.DBUF */
                }
            }
        }

        Device (ATTS)
        {
            Name (_HID, "NOKIA_ATTS")  // _HID: Hardware ID
        }

        Device (RMNT)
        {
            Name (_HID, "QCOM2148")  // _HID: Hardware ID
        }

        Device (RMAT)
        {
            Name (_HID, "QCOM2155")  // _HID: Hardware ID
        }

        Device (EGP0)
        {
            Name (_HID, "ENOGPIO")  // _HID: Hardware ID
            Name (_CID, "ENOGPIO")  // _CID: Compatible ID
            Name (_UID, One)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x011A)
                {
                    /* 0000 */  0x8C, 0x20, 0x00, 0x01, 0x01, 0x01, 0x00, 0x08,  // . ......
                    /* 0008 */  0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00,  // ........
                    /* 0010 */  0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0xD9,  // ...#....
                    /* 0018 */  0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x50, 0x4D,  // .\_SB.PM
                    /* 0020 */  0x30, 0x31, 0x00, 0x8C, 0x20, 0x00, 0x01, 0x01,  // 01.. ...
                    /* 0028 */  0x01, 0x00, 0x08, 0x00, 0x01, 0x00, 0x00, 0x00,  // ........
                    /* 0030 */  0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23, 0x00,  // ......#.
                    /* 0038 */  0x00, 0x00, 0xC2, 0x00, 0x5C, 0x5F, 0x53, 0x42,  // ....\_SB
                    /* 0040 */  0x2E, 0x50, 0x4D, 0x30, 0x31, 0x00, 0x8C, 0x20,  // .PM01.. 
                    /* 0048 */  0x00, 0x01, 0x01, 0x01, 0x00, 0x08, 0x00, 0x01,  // ........
                    /* 0050 */  0x00, 0x00, 0x00, 0x00, 0x17, 0x00, 0x00, 0x19,  // ........
                    /* 0058 */  0x00, 0x23, 0x00, 0x00, 0x00, 0xC7, 0x00, 0x5C,  // .#.....\
                    /* 0060 */  0x5F, 0x53, 0x42, 0x2E, 0x50, 0x4D, 0x30, 0x31,  // _SB.PM01
                    /* 0068 */  0x00, 0x8C, 0x20, 0x00, 0x01, 0x01, 0x01, 0x00,  // .. .....
                    /* 0070 */  0x08, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x17,  // ........
                    /* 0078 */  0x00, 0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00,  // ....#...
                    /* 0080 */  0xCA, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x50,  // ..\_SB.P
                    /* 0088 */  0x4D, 0x30, 0x31, 0x00, 0x8C, 0x20, 0x00, 0x01,  // M01.. ..
                    /* 0090 */  0x01, 0x01, 0x00, 0x08, 0x00, 0x01, 0x00, 0x00,  // ........
                    /* 0098 */  0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // .......#
                    /* 00A0 */  0x00, 0x00, 0x00, 0xC9, 0x00, 0x5C, 0x5F, 0x53,  // .....\_S
                    /* 00A8 */  0x42, 0x2E, 0x50, 0x4D, 0x30, 0x31, 0x00, 0x8C,  // B.PM01..
                    /* 00B0 */  0x20, 0x00, 0x01, 0x01, 0x01, 0x00, 0x08, 0x00,  //  .......
                    /* 00B8 */  0x01, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00, 0x00,  // ........
                    /* 00C0 */  0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x10, 0x00,  // ..#.....
                    /* 00C8 */  0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x50, 0x57, 0x49,  // \_SB.PWI
                    /* 00D0 */  0x4F, 0x00, 0x8C, 0x20, 0x00, 0x01, 0x01, 0x01,  // O.. ....
                    /* 00D8 */  0x00, 0x08, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,  // ........
                    /* 00E0 */  0x17, 0x00, 0x00, 0x19, 0x00, 0x23, 0x00, 0x00,  // .....#..
                    /* 00E8 */  0x00, 0xC8, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E,  // ...\_SB.
                    /* 00F0 */  0x50, 0x4D, 0x30, 0x31, 0x00, 0x8C, 0x20, 0x00,  // PM01.. .
                    /* 00F8 */  0x01, 0x01, 0x01, 0x00, 0x08, 0x00, 0x01, 0x00,  // ........
                    /* 0100 */  0x00, 0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00,  // ........
                    /* 0108 */  0x23, 0x00, 0x00, 0x00, 0x62, 0x00, 0x5C, 0x5F,  // #...b.\_
                    /* 0110 */  0x53, 0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00,  // SB.GIO0.
                    /* 0118 */  0x79, 0x00                                       // y.
                })
                Return (RBUF) /* \_SB_.EGP0._CRS.RBUF */
            }
        }

        Device (DISP)
        {
            Name (_HID, "NOKIA_PANEL")  // _HID: Hardware ID
            Name (_CID, "ACPINOKIA_PANEL")  // _CID: Compatible ID
            Name (_UID, Zero)  // _UID: Unique ID
            Name (_DEP, Package (0x05)  // _DEP: Dependencies
            {
                \_SB.PEP0, , 
                \_SB.PRXY, , 
                \_SB.HWN0, , 
                \_SB.PMIC, , 
                \_SB.GPU0, 
            })
            Method (DPID, 0, NotSerialized)
            {
                Name (RBUF, Package (0x01)
                {
                    0x00E380C0
                })
                Return (RBUF) /* \_SB_.DISP.DPID.RBUF */
            }

            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x71)
                {
                    /* 0000 */  0x8C, 0x26, 0x00, 0x01, 0x01, 0x01, 0x00, 0x00,  // .&......
                    /* 0008 */  0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00,  // ........
                    /* 0010 */  0x00, 0x1F, 0x00, 0x29, 0x00, 0x00, 0x00, 0x00,  // ...)....
                    /* 0018 */  0x00, 0x64, 0x00, 0x65, 0x00, 0x66, 0x00, 0x5C,  // .d.e.f.\
                    /* 0020 */  0x5F, 0x53, 0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30,  // _SB.GIO0
                    /* 0028 */  0x00, 0x8C, 0x20, 0x00, 0x01, 0x01, 0x01, 0x00,  // .. .....
                    /* 0030 */  0x08, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x17,  // ........
                    /* 0038 */  0x00, 0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00,  // ....#...
                    /* 0040 */  0x3A, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x47,  // :.\_SB.G
                    /* 0048 */  0x49, 0x4F, 0x30, 0x00, 0x8C, 0x20, 0x00, 0x01,  // IO0.. ..
                    /* 0050 */  0x01, 0x01, 0x00, 0x08, 0x00, 0x02, 0x00, 0x00,  // ........
                    /* 0058 */  0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // .......#
                    /* 0060 */  0x00, 0x00, 0x00, 0x01, 0x00, 0x5C, 0x5F, 0x53,  // .....\_S
                    /* 0068 */  0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x79,  // B.GIO0.y
                    /* 0070 */  0x00                                             // .
                })
                Return (RBUF) /* \_SB_.DISP._CRS.RBUF */
            }
        }

        Device (NRSD)
        {
            Name (_HID, "NRSD0001")  // _HID: Hardware ID
            Name (_CID, "ACPINRSD0001")  // _CID: Compatible ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.PRXY, 
            })
            Name (PGID, Buffer (0x0A)
            {
                "\\_SB.NRSD"
            })
            Name (DBUF, Buffer (0x0D){})
            CreateByteField (DBUF, Zero, STAT)
            CreateField (DBUF, 0x10, 0x50, DEID)
            CreateByteField (DBUF, 0x0C, DVAL)
            Method (_S1D, 0, NotSerialized)  // _S1D: S1 Device State
            {
                Return (0x03)
            }

            Method (_S2D, 0, NotSerialized)  // _S2D: S2 Device State
            {
                Return (0x03)
            }

            Method (_S3D, 0, NotSerialized)  // _S3D: S3 Device State
            {
                Return (0x03)
            }

            Method (_PS0, 0, NotSerialized)  // _PS0: Power State 0
            {
                DEID = PGID /* \_SB_.NRSD.PGID */
                DVAL = Zero
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.NRSD.DBUF */
                }
            }

            Method (_PS1, 0, NotSerialized)  // _PS1: Power State 1
            {
                DEID = PGID /* \_SB_.NRSD.PGID */
                DVAL = One
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.NRSD.DBUF */
                }
            }

            Method (_PS2, 0, NotSerialized)  // _PS2: Power State 2
            {
                DEID = PGID /* \_SB_.NRSD.PGID */
                DVAL = 0x02
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.NRSD.DBUF */
                }
            }

            Method (_PS3, 0, NotSerialized)  // _PS3: Power State 3
            {
                DEID = PGID /* \_SB_.NRSD.PGID */
                DVAL = 0x03
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.NRSD.DBUF */
                }
            }
        }
    }
}

