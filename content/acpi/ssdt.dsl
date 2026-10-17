/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20260408 (32-bit version)
 * Copyright (c) 2000 - 2026 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of C:/Users/frede/Projects/Lumia520/ssdt.aml
 *
 * Original Table Header:
 *     Signature        "SSDT"
 *     Length           0x00000D24 (3364)
 *     Revision         0x01
 *     Checksum         0x23
 *     OEM ID           "NOKIA "
 *     OEM Table ID     "MSM8930 "
 *     OEM Revision     0x00000004 (4)
 *     Compiler ID      "MSFT"
 *     Compiler Version 0x04000000 (67108864)
 */
DefinitionBlock ("", "SSDT", 1, "NOKIA ", "MSM8930 ", 0x00000004)
{
    External (_SB_.ABD_.AVBL, IntObj)
    External (_SB_.IC12, DeviceObj)
    External (_SB_.IC12.AVBL, UnknownObj)
    External (_SB_.PEP0, UnknownObj)
    External (_SB_.PRXY, UnknownObj)
    External (_SB_.PRXY.FLD0, UnknownObj)

    Scope (\_SB)
    {
        Device (ACC1)
        {
            Name (_HID, "KXTNK")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_DEP, Package (One)  // _DEP: Dependencies
            {
                \_SB.PRXY, 
            })
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x64)
                {
                    /* 0000 */  0x8E, 0x19, 0x00, 0x01, 0x00, 0x01, 0x02, 0x00,  // ........
                    /* 0008 */  0x00, 0x01, 0x06, 0x00, 0x80, 0x1A, 0x06, 0x00,  // ........
                    /* 0010 */  0x1E, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x49,  // ..\_SB.I
                    /* 0018 */  0x43, 0x31, 0x32, 0x00, 0x8C, 0x20, 0x00, 0x01,  // C12.. ..
                    /* 0020 */  0x00, 0x01, 0x00, 0x03, 0x00, 0x02, 0x00, 0x00,  // ........
                    /* 0028 */  0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // .......#
                    /* 0030 */  0x00, 0x00, 0x00, 0x2E, 0x00, 0x5C, 0x5F, 0x53,  // .....\_S
                    /* 0038 */  0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x8C,  // B.GIO0..
                    /* 0040 */  0x20, 0x00, 0x01, 0x00, 0x01, 0x00, 0x03, 0x00,  //  .......
                    /* 0048 */  0x02, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00, 0x00,  // ........
                    /* 0050 */  0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x43, 0x00,  // ..#...C.
                    /* 0058 */  0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x47, 0x49, 0x4F,  // \_SB.GIO
                    /* 0060 */  0x30, 0x00, 0x79, 0x00                           // 0.y.
                })
                Return (RBUF) /* \_SB_.ACC1._CRS.RBUF */
            }

            Name (_PLD, Package (One)  // _PLD: Physical Location of Device
            {
                Buffer (0x14)
                {
                    /* 0000 */  0x82, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // ........
                    /* 0008 */  0x28, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x00,  // (.....0.
                    /* 0010 */  0xFF, 0xFF, 0xFF, 0xFF                           // ....
                }
            })
            Method (ROTM, 0, NotSerialized)
            {
                Name (RBUF, Package (0x03)
                {
                    "1 0 0", 
                    "0 1 0", 
                    "0 0 -1"
                })
                Return (RBUF) /* \_SB_.ACC1.ROTM.RBUF */
            }

            Name (PGID, Buffer (0x0A)
            {
                "\\_SB.ACC1"
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
                DEID = PGID /* \_SB_.ACC1.PGID */
                DVAL = Zero
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.ACC1.DBUF */
                }
            }

            Method (_PS1, 0, NotSerialized)  // _PS1: Power State 1
            {
                DEID = PGID /* \_SB_.ACC1.PGID */
                DVAL = One
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.ACC1.DBUF */
                }
            }

            Method (_PS2, 0, NotSerialized)  // _PS2: Power State 2
            {
                DEID = PGID /* \_SB_.ACC1.PGID */
                DVAL = 0x02
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.ACC1.DBUF */
                }
            }

            Method (_PS3, 0, NotSerialized)  // _PS3: Power State 3
            {
                DEID = PGID /* \_SB_.ACC1.PGID */
                DVAL = 0x03
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.ACC1.DBUF */
                }
            }
        }

        Device (ALS1)
        {
            Name (_HID, "QPDS_T900_ALS")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_DEP, Package (0x03)  // _DEP: Dependencies
            {
                \_SB.IC12, , 
                \_SB.PRXY, , 
                \_SB.PEP0, 
            })
            Scope (\_SB.IC12)
            {
                OperationRegion (ALS1, GenericSerialBus, Zero, 0x0100)
            }

            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                Field (\_SB.IC12.ALS1, BufferAcc, NoLock, Preserve)
                {
                    Connection (
                        I2cSerialBusV2 (0x0039, ControllerInitiated, 0x00061A80,
                            AddressingMode7Bit, "\\_SB.IC12",
                            0x00, ResourceConsumer, , Exclusive,
                            )
                    ), 
                    AccessAs (BufferAcc, AttribByte), 
                    Offset (0x92), 
                    FLD0,   8
                }

                If ((\_SB.IC12.AVBL != One))
                {
                    Return (Zero)
                }

                \_SB.ALS1._PS0 ()
                Name (BUFF, Buffer (0x03){})
                CreateByteField (BUFF, Zero, STAT)
                CreateByteField (BUFF, 0x02, DATA)
                BUFF = FLD0 /* \_SB_.ALS1._STA.FLD0 */
                \_SB.ALS1._PS3 ()
                If ((STAT != Zero))
                {
                    Return (Zero)
                }
                ElseIf ((DATA == 0x29))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }

            Name (PGID, Buffer (0x0A)
            {
                "\\_SB.ALS1"
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
                DEID = PGID /* \_SB_.ALS1.PGID */
                DVAL = Zero
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.ALS1.DBUF */
                }
            }

            Method (_PS3, 0, NotSerialized)  // _PS3: Power State 3
            {
                DEID = PGID /* \_SB_.ALS1.PGID */
                DVAL = 0x03
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.ALS1.DBUF */
                }
            }

            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x41)
                {
                    /* 0000 */  0x8E, 0x19, 0x00, 0x01, 0x00, 0x01, 0x02, 0x00,  // ........
                    /* 0008 */  0x00, 0x01, 0x06, 0x00, 0x80, 0x1A, 0x06, 0x00,  // ........
                    /* 0010 */  0x39, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x49,  // 9.\_SB.I
                    /* 0018 */  0x43, 0x31, 0x32, 0x00, 0x8C, 0x20, 0x00, 0x01,  // C12.. ..
                    /* 0020 */  0x00, 0x01, 0x00, 0x0B, 0x00, 0x01, 0x00, 0x00,  // ........
                    /* 0028 */  0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // .......#
                    /* 0030 */  0x00, 0x00, 0x00, 0x31, 0x00, 0x5C, 0x5F, 0x53,  // ...1.\_S
                    /* 0038 */  0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x79,  // B.GIO0.y
                    /* 0040 */  0x00                                             // .
                })
                Return (RBUF) /* \_SB_.ALS1._CRS.RBUF */
            }

            Method (MODE, 0, NotSerialized)
            {
                Name (RBUF, Buffer (One)
                {
                     0x01                                             // .
                })
                Return (RBUF) /* \_SB_.ALS1.MODE.RBUF */
            }

            Method (PASS, 0, NotSerialized)
            {
                Name (RBUF, Buffer (One)
                {
                     0x42                                             // B
                })
                Return (RBUF) /* \_SB_.ALS1.PASS.RBUF */
            }
        }

        Device (ALS2)
        {
            Name (_HID, "LTR_554ALS_02_ALS")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_DEP, Package (0x03)  // _DEP: Dependencies
            {
                \_SB.IC12, , 
                \_SB.PRXY, , 
                \_SB.PEP0, 
            })
            Name (PGID, Buffer (0x0A)
            {
                "\\_SB.ALS2"
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
                DEID = PGID /* \_SB_.ALS2.PGID */
                DVAL = Zero
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.ALS2.DBUF */
                }
            }

            Method (_PS3, 0, NotSerialized)  // _PS3: Power State 3
            {
                DEID = PGID /* \_SB_.ALS2.PGID */
                DVAL = 0x03
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.ALS2.DBUF */
                }
            }

            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x41)
                {
                    /* 0000 */  0x8E, 0x19, 0x00, 0x01, 0x00, 0x01, 0x02, 0x00,  // ........
                    /* 0008 */  0x00, 0x01, 0x06, 0x00, 0x80, 0x1A, 0x06, 0x00,  // ........
                    /* 0010 */  0x23, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x49,  // #.\_SB.I
                    /* 0018 */  0x43, 0x31, 0x32, 0x00, 0x8C, 0x20, 0x00, 0x01,  // C12.. ..
                    /* 0020 */  0x00, 0x01, 0x00, 0x0B, 0x00, 0x01, 0x00, 0x00,  // ........
                    /* 0028 */  0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // .......#
                    /* 0030 */  0x00, 0x00, 0x00, 0x31, 0x00, 0x5C, 0x5F, 0x53,  // ...1.\_S
                    /* 0038 */  0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x79,  // B.GIO0.y
                    /* 0040 */  0x00                                             // .
                })
                Return (RBUF) /* \_SB_.ALS2._CRS.RBUF */
            }

            Method (MODE, 0, NotSerialized)
            {
                Name (RBUF, Buffer (One)
                {
                     0x01                                             // .
                })
                Return (RBUF) /* \_SB_.ALS2.MODE.RBUF */
            }
        }

        Device (PRX1)
        {
            Name (_HID, "QPDS_T900_PRX")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_DEP, Package (0x03)  // _DEP: Dependencies
            {
                \_SB.IC12, , 
                \_SB.PRXY, , 
                \_SB.PEP0, 
            })
            Scope (\_SB.IC12)
            {
                OperationRegion (PRX1, GenericSerialBus, Zero, 0x0100)
            }

            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                Field (\_SB.IC12.PRX1, BufferAcc, NoLock, Preserve)
                {
                    Connection (
                        I2cSerialBusV2 (0x0039, ControllerInitiated, 0x00061A80,
                            AddressingMode7Bit, "\\_SB.IC12",
                            0x00, ResourceConsumer, , Exclusive,
                            )
                    ), 
                    AccessAs (BufferAcc, AttribByte), 
                    Offset (0x92), 
                    FLD0,   8
                }

                If ((\_SB.IC12.AVBL != One))
                {
                    Return (Zero)
                }

                \_SB.PRX1._PS0 ()
                Name (BUFF, Buffer (0x03){})
                CreateByteField (BUFF, Zero, STAT)
                CreateByteField (BUFF, 0x02, DATA)
                BUFF = FLD0 /* \_SB_.PRX1._STA.FLD0 */
                \_SB.PRX1._PS3 ()
                If ((STAT != Zero))
                {
                    Return (Zero)
                }
                ElseIf ((DATA == 0x29))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }

            Name (PGID, Buffer (0x0A)
            {
                "\\_SB.PRX1"
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
                DEID = PGID /* \_SB_.PRX1.PGID */
                DVAL = Zero
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.PRX1.DBUF */
                }
            }

            Method (_PS3, 0, NotSerialized)  // _PS3: Power State 3
            {
                DEID = PGID /* \_SB_.PRX1.PGID */
                DVAL = 0x03
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.PRX1.DBUF */
                }
            }

            Method (VRSN, 0, NotSerialized)
            {
                Return (Package (0x03)
                {
                    One, 
                    Zero, 
                    Zero
                })
            }

            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x41)
                {
                    /* 0000 */  0x8E, 0x19, 0x00, 0x01, 0x00, 0x01, 0x02, 0x00,  // ........
                    /* 0008 */  0x00, 0x01, 0x06, 0x00, 0x80, 0x1A, 0x06, 0x00,  // ........
                    /* 0010 */  0x39, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x49,  // 9.\_SB.I
                    /* 0018 */  0x43, 0x31, 0x32, 0x00, 0x8C, 0x20, 0x00, 0x01,  // C12.. ..
                    /* 0020 */  0x00, 0x01, 0x00, 0x0B, 0x00, 0x01, 0x00, 0x00,  // ........
                    /* 0028 */  0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // .......#
                    /* 0030 */  0x00, 0x00, 0x00, 0x31, 0x00, 0x5C, 0x5F, 0x53,  // ...1.\_S
                    /* 0038 */  0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x79,  // B.GIO0.y
                    /* 0040 */  0x00                                             // .
                })
                Return (RBUF) /* \_SB_.PRX1._CRS.RBUF */
            }

            Method (MODE, 0, NotSerialized)
            {
                Name (RBUF, Buffer (One)
                {
                     0x02                                             // .
                })
                Return (RBUF) /* \_SB_.PRX1.MODE.RBUF */
            }
        }

        Device (PRX2)
        {
            Name (_HID, "LTR_554ALS_02_PRX")  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_DEP, Package (0x03)  // _DEP: Dependencies
            {
                \_SB.IC12, , 
                \_SB.PRXY, , 
                \_SB.PEP0, 
            })
            Name (PGID, Buffer (0x0A)
            {
                "\\_SB.PRX2"
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
                DEID = PGID /* \_SB_.PRX2.PGID */
                DVAL = Zero
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.PRX2.DBUF */
                }
            }

            Method (_PS3, 0, NotSerialized)  // _PS3: Power State 3
            {
                DEID = PGID /* \_SB_.PRX2.PGID */
                DVAL = 0x03
                If (\_SB.ABD.AVBL)
                {
                    \_SB.PRXY.FLD0 = DBUF /* \_SB_.PRX2.DBUF */
                }
            }

            Method (VRSN, 0, NotSerialized)
            {
                Return (Package (0x03)
                {
                    One, 
                    Zero, 
                    Zero
                })
            }

            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x41)
                {
                    /* 0000 */  0x8E, 0x19, 0x00, 0x01, 0x00, 0x01, 0x02, 0x00,  // ........
                    /* 0008 */  0x00, 0x01, 0x06, 0x00, 0x80, 0x1A, 0x06, 0x00,  // ........
                    /* 0010 */  0x23, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x49,  // #.\_SB.I
                    /* 0018 */  0x43, 0x31, 0x32, 0x00, 0x8C, 0x20, 0x00, 0x01,  // C12.. ..
                    /* 0020 */  0x00, 0x01, 0x00, 0x0B, 0x00, 0x01, 0x00, 0x00,  // ........
                    /* 0028 */  0x00, 0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  // .......#
                    /* 0030 */  0x00, 0x00, 0x00, 0x31, 0x00, 0x5C, 0x5F, 0x53,  // ...1.\_S
                    /* 0038 */  0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x79,  // B.GIO0.y
                    /* 0040 */  0x00                                             // .
                })
                Return (RBUF) /* \_SB_.PRX2._CRS.RBUF */
            }

            Method (MODE, 0, NotSerialized)
            {
                Name (RBUF, Buffer (One)
                {
                     0x02                                             // .
                })
                Return (RBUF) /* \_SB_.PRX2.MODE.RBUF */
            }
        }

        Device (NDLD)
        {
            Name (_HID, "DATA_LOGGER")  // _HID: Hardware ID
        }

        Device (NREG)
        {
            Name (_HID, "ODDT_REG")  // _HID: Hardware ID
        }

        Device (VIB2)
        {
            Name (_HID, "ODDT_VIB")  // _HID: Hardware ID
            Name (_CID, "ACPIODDT_VIB")  // _CID: Compatible ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0x02)
                {
                     0x79, 0x00                                       // y.
                })
                Return (RBUF) /* \_SB_.VIB2._CRS.RBUF */
            }
        }

        Device (NCPU)
        {
            Name (_HID, "ODDT_CPU")  // _HID: Hardware ID
        }

        Device (NEDD)
        {
            Name (_HID, "NOKI0B00")  // _HID: Hardware ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (RBUF, Buffer (0xD4)
                {
                    /* 0000 */  0x8C, 0x20, 0x00, 0x01, 0x00, 0x01, 0x00, 0x1D,  // . ......
                    /* 0008 */  0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00,  // ........
                    /* 0010 */  0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0x0F,  // ...#....
                    /* 0018 */  0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x50, 0x4D,  // .\_SB.PM
                    /* 0020 */  0x30, 0x31, 0x00, 0x8C, 0x20, 0x00, 0x01, 0x00,  // 01.. ...
                    /* 0028 */  0x01, 0x00, 0x1D, 0x00, 0x01, 0x00, 0x00, 0x00,  // ........
                    /* 0030 */  0x00, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23, 0x00,  // ......#.
                    /* 0038 */  0x00, 0x00, 0x2A, 0x00, 0x5C, 0x5F, 0x53, 0x42,  // ..*.\_SB
                    /* 0040 */  0x2E, 0x50, 0x4D, 0x30, 0x31, 0x00, 0x8C, 0x20,  // .PM01.. 
                    /* 0048 */  0x00, 0x01, 0x00, 0x01, 0x00, 0x1B, 0x00, 0x01,  // ........
                    /* 0050 */  0x00, 0x00, 0xC8, 0x00, 0x17, 0x00, 0x00, 0x19,  // ........
                    /* 0058 */  0x00, 0x23, 0x00, 0x00, 0x00, 0x0D, 0x00, 0x5C,  // .#.....\
                    /* 0060 */  0x5F, 0x53, 0x42, 0x2E, 0x50, 0x4D, 0x30, 0x31,  // _SB.PM01
                    /* 0068 */  0x00, 0x8C, 0x20, 0x00, 0x01, 0x00, 0x01, 0x00,  // .. .....
                    /* 0070 */  0x19, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x17,  // ........
                    /* 0078 */  0x00, 0x00, 0x19, 0x00, 0x23, 0x00, 0x00, 0x00,  // ....#...
                    /* 0080 */  0x2E, 0x00, 0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x50,  // ..\_SB.P
                    /* 0088 */  0x4D, 0x30, 0x31, 0x00, 0x8C, 0x20, 0x00, 0x01,  // M01.. ..
                    /* 0090 */  0x00, 0x01, 0x00, 0x19, 0x00, 0x03, 0x00, 0x00,  // ........
                    /* 0098 */  0x20, 0x4E, 0x17, 0x00, 0x00, 0x19, 0x00, 0x23,  //  N.....#
                    /* 00A0 */  0x00, 0x00, 0x00, 0x5B, 0x00, 0x5C, 0x5F, 0x53,  // ...[.\_S
                    /* 00A8 */  0x42, 0x2E, 0x47, 0x49, 0x4F, 0x30, 0x00, 0x8C,  // B.GIO0..
                    /* 00B0 */  0x20, 0x00, 0x01, 0x00, 0x01, 0x00, 0x1D, 0x00,  //  .......
                    /* 00B8 */  0x01, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00, 0x00,  // ........
                    /* 00C0 */  0x19, 0x00, 0x23, 0x00, 0x00, 0x00, 0xC0, 0x00,  // ..#.....
                    /* 00C8 */  0x5C, 0x5F, 0x53, 0x42, 0x2E, 0x50, 0x4D, 0x30,  // \_SB.PM0
                    /* 00D0 */  0x31, 0x00, 0x79, 0x00                           // 1.y.
                })
                Return (RBUF) /* \_SB_.NEDD._CRS.RBUF */
            }

            Method (CHGR, 0, NotSerialized)
            {
                Return (Package (0x03)
                {
                    0x5A, 
                    Package (0x06)
                    {
                        Package (0x06)
                        {
                            0x010E, 
                            0x0110, 
                            0x0F3C, 
                            0x0145, 
                            Zero, 
                            Zero
                        }, 

                        Package (0x06)
                        {
                            0x0118, 
                            0x011A, 
                            0x1004, 
                            0x036B, 
                            0x0FD2, 
                            0x0FA0
                        }, 

                        Package (0x06)
                        {
                            0x0122, 
                            0x0124, 
                            0x1068, 
                            0x036B, 
                            0x1036, 
                            0x1004
                        }, 

                        Package (0x06)
                        {
                            0x012E, 
                            0x0130, 
                            0x1068, 
                            0x036B, 
                            0x1036, 
                            0x1004
                        }, 

                        Package (0x06)
                        {
                            0x013A, 
                            0x013C, 
                            0x1004, 
                            0x036B, 
                            0x0FD2, 
                            0x0FA0
                        }, 

                        Package (0x06)
                        {
                            0x014D, 
                            0x014F, 
                            Zero, 
                            Zero, 
                            Zero, 
                            Zero
                        }
                    }, 

                    Package (0x06)
                    {
                        Package (0x06)
                        {
                            0x010E, 
                            0x0110, 
                            0x0F3C, 
                            0x0145, 
                            Zero, 
                            Zero
                        }, 

                        Package (0x06)
                        {
                            0x0118, 
                            0x011A, 
                            0x1004, 
                            0x036B, 
                            0x0FD2, 
                            0x0FA0
                        }, 

                        Package (0x06)
                        {
                            0x0122, 
                            0x0124, 
                            0x1068, 
                            0x036B, 
                            0x1036, 
                            0x1004
                        }, 

                        Package (0x06)
                        {
                            0x012E, 
                            0x0130, 
                            0x1068, 
                            0x036B, 
                            0x1036, 
                            0x1004
                        }, 

                        Package (0x06)
                        {
                            0x013A, 
                            0x013C, 
                            0x1004, 
                            0x036B, 
                            0x0FD2, 
                            0x0FA0
                        }, 

                        Package (0x06)
                        {
                            0x0149, 
                            0x014B, 
                            Zero, 
                            Zero, 
                            Zero, 
                            Zero
                        }
                    }
                })
            }

            Method (CUTF, 0, NotSerialized)
            {
                Return (Package (0x03)
                {
                    Zero, 
                    0x0CE4, 
                    0x0D48
                })
            }

            Method (CONF, 0, NotSerialized)
            {
                Return (Package (0x06)
                {
                    0x64, 
                    Zero, 
                    0x02, 
                    0x08, 
                    0x0546, 
                    0x0596
                })
            }
        }
    }
}

