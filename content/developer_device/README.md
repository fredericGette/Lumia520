# Configuration of a Lumia 520 for development

> [!NOTE]
> Nothing indicated here is mandatory. This is just an example of configuration.  

## Unlock and root the phone

Use [wpi](https://github.com/fredericGette/wpi) to unlock and root the phone.  

```
wpi --ffu=C:\Users\frede\Lumia520\Denim_RM914_059S341_3058.51000.1523.1010\RM914_3058.51000.1523.1010_RETAIL_apac_australia_new_zealand_295_10_482764_prd_signed.ffu --hex=C:\Users\frede\Lumia520\Emergency\FAST8930_FAME_ROW.hex --sbl3Bin=C:\Users\frede\Lumia520\Engineering-SBL3s\Engineering-SBL3-Lumia-520.bin --donorFfu=C:\Users\frede\supported-ffu\RM1085_1078.0053.10586.13169.13829.034EA6_retail_prod_signed.ffu --uefiBsNvBin=E:\wpi\UEFI_BS_NV.bin
```

> [!WARNING]
> The first boot after the unlock and root procedure can be pretty long.  


## First configuration

During the *Out Of the Box Experience* (OOBE), configure the phone as below:  
- Language = English (United-States)
- Accept the *Terms of Use*.
- Connect to Wi-Fi.
- Accept *Wi-Fi Sense* default configuration.
- Choose *recommended* phone settings.
- Accept *Time and region* default configuration.
- Select *Sign in later* in the *Keep your life in sync* page.
- Deselect *Join the Nokia Improvement Program* in the *Thank you for choosing Nokia* page.


## Install apps

- [WPTweaker](https://github.com/sensboston/WPTweaker)
- [CMD.Injector_WP8](https://github.com/fadilfadz01/CMD.Injector_WP8)

## Second configuration

In CMD.Injector_WP8:  
- Reboot the phone as asked to intialize the app.
- Select *Home* then *Inject*, then reboot.
- Select *BootConfig* and switch on *TestSigning* and *NonIntegrityChecks* in *Boot Loader*, then reboot.

In WPTweaker:  
- In *System*, activate *'Never' screen timeout option*.
- In *System*, select *Never* value for *Screen timeout (on battery)*.
- In *System*, select *Never* value for *Screen timeout (when charging)*.
- Quit the app and reboot the phone.

