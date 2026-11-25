# Camera stack (rear camera)

### Components

Built from the [drivers](../drivers/README.md) and [libraries](../libraries/README.md) pages. Solid arrows: calls / IOCTLs / data. Dotted arrows: creation (PDO, COM object, DLL loading) or links that aren't confirmed (`?`). The Microsoft components (`Windows.Media.dll`, the MF device source, `ks.sys`, `dxgkrnl.sys`, PoFx) are not documented here.

The Lumia 520 has no front camera and no flash: [qccamfrontsensor8930.sys](../drivers/qccamfrontsensor8930.md) and [qccamflash8930.sys](../drivers/qccamflash8930.md) are loaded (shared Nokia code base) but their hardware detection fails, so they aren't in the chart.

```mermaid
flowchart TB
    subgraph UM["User mode"]
        direction TB
        MOBILEUI["MobileUI.exe<br/>camera button → InvokeCamera"]
        PHOTOS["Photos / Camera app<br/>PhotosApp.Models.dll<br/>(Camera WPMC, WMCCamera WMC)"]
        OTHERAPP["Other apps / lenses<br/>(Windows.Media.Capture,<br/>Windows.Phone.Media.Capture)"]
        WINMEDIA["Windows.Media.dll<br/>MediaCaptureServer<br/>(Microsoft)"]
        PAL["MFPalWP.dll<br/>camera resource reservation"]
        ENGINE["MFCaptureEngine.dll<br/>IMFCaptureEngine<br/>preview / record / photo sinks"]
        DEVSRC["MF device source / KS proxy<br/>(Microsoft)"]
        MFTPREV["nokia_mft_preview.dll<br/>face tracking, motion (AMBR)"]
        MFTSTILL["nokia_mft_still.dll<br/>red-eye, denoise, vibrance"]
        JPEGMFT["QCJpegEncoderMFT.dll<br/>JPEG + EXIF"]
        VIDENC["qcvidencmfth2648930.dll<br/>qcvidencmftmpeg48930.dll<br/>qcvidencmfth2638930.dll"]
        VIDUM["qcvidum8930.dll<br/>D3D11 video UMD"]
        VSINKRT["VideoSink_RT.dll<br/>WP8 preview sink (ALPC)"]
    end

    subgraph KM["Kernel mode"]
        direction TB
        KS["ks.sys<br/>AVStream (Microsoft)"]
        AVS["qccamavs8930.sys<br/>AVStream minidriver, filter Back Sensor<br/>ISP service, 3A (ELFS), chromatix, Nokia plug-ins"]
        DXG["dxgkrnl.sys<br/>(Microsoft)"]
        DXKM["qcdxkm8930.sys<br/>display / GPU / video codec"]
        SENSOR["qccamsensor8930.sys<br/>#92;_SB.CAMS, SMIA++ driver, CSI 0"]
        VFE["qccamvfe8930.sys<br/>#92;_SB.VFE0, VFE + ISPIF"]
        VPE["qcvpe8930.sys<br/>#92;_SB.VPE, scale / crop / rotate"]
        ESP["nokia_cam_esp.sys<br/>#92;_SB.CESP, orientation, thermal limit"]
        PLATFORM["qccamplatform8930.sys<br/>#92;_SB.CAMP, I2C (GSBI4), GPIO, power"]
        GEMINI["qccamgemini8930.sys<br/>#92;??#92;QcCamGeminiDriver"]
        VCM["qcvcm8930.sys<br/>VCM export driver"]
        SMMU["qcsmmu8930.sys"]
        PEP["qcpep8930.sys<br/>PEP (via PoFx)"]
        ACPIEX["acpiex.sys<br/>Resource Hub → GPIO"]
    end

    subgraph HW["Hardware"]
        direction TB
        CAM["Rear camera module<br/>(5 MP sensor)"]
        CSI["CSID + CSIPHY<br/>(MIPI CSI receiver)"]
        VFEHW["VFE (ISP)"]
        VPEHW["VPE"]
        JPEGHW["Gemini JPEG encoder"]
        VIDC["VIDC video core"]
        IOMMU["SMMU / IOMMUs"]
    end

    %% user mode
    MOBILEUI -.->|"launches"| PHOTOS
    PHOTOS -->|"WMC model"| WINMEDIA
    PHOTOS -.->|"WPMC model ?"| VSINKRT
    OTHERAPP --> WINMEDIA
    WINMEDIA -->|"MFMCPal* (RmAcquireResources)"| PAL
    WINMEDIA -.->|"CoCreateInstance"| ENGINE
    ENGINE -->|"source reader"| DEVSRC
    ENGINE -.->|"photo sink ?"| MFTSTILL
    ENGINE -->|"photo sink (NV12 → JPEG)"| JPEGMFT
    ENGINE -.->|"record sink ?"| VIDENC
    DEVSRC -.->|"preview MFT ?"| MFTPREV
    VIDENC -->|"DecoderExtension"| VIDUM

    %% user mode -> kernel mode
    DEVSRC -->|"KS properties, streams<br/>(PROPSETID_VIDCAP_CAMERACONTROL 1000-1031,<br/>ExtendedCameraControl)"| KS
    WINMEDIA -->|"KS properties"| KS
    PHOTOS -->|"OEM custom KS properties"| KS
    MFTPREV -->|"faces, motion<br/>(camera control interface)"| KS
    JPEGMFT -->|"CreateFile, DeviceIoControl"| GEMINI
    VIDUM -->|"via qcdx9um8930.dll and the D3D runtime<br/>command buffers, escapes"| DXG

    %% kernel mode
    KS --> AVS
    DXG --> DXKM
    DXKM -.->|"creates PDO VEN_QCOM&DEV__AVSTREAM<br/>#92;_SB.GPU0.AVS0"| AVS
    AVS -->|"query interface<br/>DirectX allocations"| DXKM
    AVS -->|"internal IOCTLs<br/>sensor control"| SENSOR
    AVS -->|"internal IOCTLs<br/>VFE commands"| VFE
    AVS -->|"IOCTLs 0x900 / 0x950 / 0x9A0"| VPE
    AVS -->|"IOCTLs 0x222410 / 0x222414 / 0x222424"| ESP
    AVS -->|"Vcm*"| VCM
    VPE -->|"Vcm*"| VCM
    GEMINI -->|"Vcm*"| VCM
    DXKM -->|"Vcm*"| VCM
    VCM -->|"IOCTL 0xC3502004<br/>function table"| SMMU
    SENSOR -->|"internal IOCTLs<br/>power, I2C, clock"| PLATFORM
    SENSOR -->|"PoFx component 0"| PEP
    PLATFORM -->|"PoFx component 0"| PEP
    VFE -->|"P-state"| PEP
    VPE -->|"P-state"| PEP
    PLATFORM -->|"IOCTL_GPIO_WRITE_PINS"| ACPIEX

    %% kernel mode -> hardware
    PLATFORM -->|"I2C (QUP GSBI4)"| CAM
    ACPIEX -->|"GPIO"| CAM
    SENSOR -->|"registers"| CSI
    VFE -->|"registers"| VFEHW
    VPE -->|"registers"| VPEHW
    GEMINI -->|"registers, interrupt"| JPEGHW
    DXKM -->|"registers"| VIDC
    SMMU -->|"page tables"| IOMMU

    %% hardware data path
    CAM -->|"MIPI CSI-2 frames"| CSI
    CSI -->|"ISPIF"| VFEHW
    VFEHW -->|"frames in memory"| VPEHW
```

Notes:
- [qccamavs8930.sys](../drivers/qccamavs8930.md) contains most of the camera stack (ISP service, 3A algorithms, tuning, multipass snapshot). The other kernel drivers are thin hardware drivers reached through device interfaces; only [qccamgemini8930.sys](../drivers/qccamgemini8930.md) has a symbolic link and is opened from user mode.
- The camera driver is a child of the display adapter ([qcdxkm8930.sys](../drivers/qcdxkm8930.md#child-devices)), so the display and the camera share the same buffers through the [allocation sharing interface](../drivers/qcdxkm8930.md#allocation-sharing-interface).
- The process that loads [nokia_mft_preview.dll](../libraries/nokia_mft_preview.md), [nokia_mft_still.dll](../libraries/nokia_mft_still.md), [QCJpegEncoderMFT.dll](../libraries/qcjpegencodermft.md) and the video encoder MFTs isn't known: the links to the capture engine are guesses (`?`). [MFCaptureEngine.dll](../libraries/mfcaptureengine.md#photo-encoder) does use the Qualcomm phone JPEG encoder for NV12 photos.
- The client of the `0x222400`…`0x22241C` IOCTLs of [nokia_cam_esp.sys](../drivers/nokia_cam_esp.md#clients) (named event on camera state, device orientation) isn't known.
- The Windows Phone 8 camera API (`Windows.Phone.Media.Capture`) isn't analysed; [VideoSink_RT.dll](../libraries/videosink_rt.md) is its preview sink according to its class name.
- The rear sensor runs its own 8051 firmware (mask ROM + a RAM patch uploaded from the `.dcc` file at each power on): see [Rear camera sensor firmware](../sensor_firmware/README.md).
- The camera button is handled by [msgpiowinphone.sys](../drivers/msgpiowinphone.md) → [kbdclasswp.sys](../drivers/kbdclasswp.md) → [MobileUI.exe](../applications/mobileui.md) / [ShellChrome.dll](../libraries/shellchrome.md) (`InvokeCamera`).
