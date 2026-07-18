# PrintFarmButton
NOTE: This is a fork of Spencer's original PrintFarmButton project.
If you are looking to deloy to your farm visit his project directly: https://github.com/spuder/PrintFarmButton 

This fork of the proejct exists only for me to test features within my own farm, which may or may not work.  

### Printago States:  
🟦 - Idle  
🟨 - Downloading / Starting   
🟧 - Warming / heat soak (tap to skip)  
🟪 - Finished / Waiting for bed clear  
🟩 - Printing  
🟥 - Error

### PETG heat soak (machine start G-code)

Add this to your **printer machine start G-code** (Bambu Studio / Orca → Printer settings → Machine start G-code), after the bed reaches temperature.

Use `M400 U1` (wait for Resume), **not** `M400 S900` (timed dwell). Only a Resume pause can be skipped from the farm button.

There is **no timed wait in G-code** — the printer pauses until Resume. The button enforces ~15 minutes (tap to skip early). Printago may show `0300-8013` (“paused by the user”); that is expected, not a fault.

```gcode
M190 S[bed_temperature_initial_layer_single] ; wait for bed temp

;===== PETG bed heat soak (start of print only) =====
; M400 U1 = wait for Resume (button tap, Printago, or printer UI).
; PrintFarmButton shows orange, auto-resumes after 15 min, or skip early with a tap.
{if filament_type[initial_extruder]=="PETG"}
M140 S[bed_temperature_initial_layer_single] ; hold bed at initial-layer temp
M400 U1 ; heat soak — resume to continue
{endif}
;===== PETG heat soak end =====
```

**How it works with the button**

1. PETG job starts → bed heats → printer pauses on `M400 U1`
2. Button shows 🟧 orange (warming)
3. **Tap** the button to skip the soak and continue the print, **or** wait ~15 minutes and the button auto-sends Resume
4. Print continues → button shows 🟩 green

Flash firmware that includes the warming / resume feature for skip + auto-resume to work.

**Notes**

- Button tap (resume / mark ready) needs HTTPS to `api.printago.io`. MQTT alone can update the LED but cannot send commands.
- Printago **virtual printers** do not reliably simulate `M400 U1` pauses — test heat soak on a real Bambu.
