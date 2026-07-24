# States

```
# Blue (Ready)
isOnline: true
confirmedReady: true
isAvailable: true

# Purple (Set Ready)
isOnline: true
confirmedReady: false
isAvailable: true

# Downloading / Starting (blue breathing to white — DownloadPulse effect)
state: PREPARE

# Orange (Warming / heat soak)
isAvailable: false
early print (layer 0) + paused (M400 U1) or soak-related stage
Tap button → Printago resume (skips soak) via HTTPS API
Auto-resume: ESP32 stores soak start millis; after Heat soak (minutes) (web UI, default 15) calls Printago resume.
WiFi drops do not reset the countdown (start time kept in RAM until soak ends).
Bambu HMS 0300-8013 / 0300-8001 (“paused by the user”) is expected — not treated as hard red error.

# Green (busy)
isOnline: true
isAvailable: false
confirmedReady: false

# Purple/white pulse (Cool-down)
Local-only state after a heat-soaked job finishes; delays the purple "waiting for bed clear" LED.
Trigger: finish edge (isAvailable false -> true) + confirmedReady false + job_had_heat_soak.
job_had_heat_soak is set when is_warming was observed this job; cleared on new job (PREPARE),
cool-down end, bed clear (confirm-ready), or clear_printago_status.
LED: CoolDownPulse effect (alternates purple/white at the Pulse cadence). No API call involved.
Ends when EITHER cool_down_start_ms elapsed >= Cool-down (minutes) (web UI, default 60)
OR the selected temp gate is satisfied (see Cool-down temps). WiFi drops do not reset the countdown.

# Red (error)
health.errors present (excluding user-pause HMS codes above) / health.warnings present
```

# Cool-down temps

Bed/chamber temps come from MQTT `printer-stats` `data.temps.bedTemp` / `data.temps.chamberTemp`
(cached to last_bed_temp / last_chamber_temp; -1000 = unknown). No extra HTTP polling.
chamber_temp_known is true only when the latest message included a chamber temp.

Temp gate (threshold = `Cool-down temp (°C)`, web UI default 45):
- Wait for bed only        → bed <= threshold
- Wait for chamber only     → chamber <= threshold (ignored if chamber not reported → time-only)
- Wait for bed + chamber    → both <= threshold (chamber ignored if not reported → bed only)
- Neither                   → time-only
Unknown bed temp while bed wait is required is NOT satisfied (time still caps cool-down).
Cool-down end is local (no API), so it is not gated on MQTT connectivity; the max-time cap fires even offline.
evaluate_cool_down runs on the 5s interval and on every stats message (so fresh temps end it promptly).

# Heat soak (machine start G-code)

Use a resumable pause (`M400 U1`), not a timed dwell (`M400 S900`).
Timed dwells cannot be skipped by Resume / the farm button.
No seconds in G-code — wait is on the button (`Heat soak (minutes)` web UI, default 15) after pause is detected.
PLA and TPU skip the pause; all other filaments heat-soak.

Virtual printers do not reliably pause on `M400 U1`; validate on a real Bambu.

```gcode
M190 S[bed_temperature_initial_layer_single] ; wait for bed temp

;===== Jaeitee PrintFarmButton Bed Heat Soak =====
; M400 U1 = wait for Resume (button tap, Printago, or printer UI).
; PrintFarmButton shows orange, auto-resumes after Heat soak (minutes), or skip early with a tap.
{if filament_type[initial_extruder]!="PLA" && filament_type[initial_extruder]!="TPU"}
M140 S[bed_temperature_initial_layer_single] ; hold bed at initial-layer temp
M400 U1 ; heat soak — resume to continue
{endif}
;===== Jaeitee PrintFarmButton Bed Heat Soak =====
```

Button actions (resume, confirm-ready) require HTTPS to `api.printago.io`. MQTT updates LEDs only.

# API

Get info about printers
```
curl -X GET "https://api.printago.io/v1/printers/$PRINTERID" \
  -H "authorization: ApiKey $YOUR_API_KEY" \
  -H "x-printago-storeid: $USERNAME" | jq
  ```

Skip heat soak / resume paused print
```
curl -X POST "https://api.printago.io/v1/printer-commands/send" \
  -H "authorization: ApiKey $YOUR_API_KEY" \
  -H "x-printago-storeid: $USERNAME" \
  -H "content-type: application/json" \
  -d "{\"ids\":[\"$PRINTERID\"],\"command\":{\"command\":\"resume\"}}"
```

Get MQTT messages

Updates for printers, e.g. when transitioning from idle to ready
`stores/$USERNAME/entities/printers/$PRINTER`

`stores/$USERNAME$/entities/printers/#`


Gets basic information about printer
`stores/$USERNAME/printer-stats/$PRINTER`


The Rest api provides all 3 entities

Whereas the MQTT `printer-stats/` provides `isOnline` and `isAvailable`, but only `entities/printers` provides `confirmedReady`. 
Furthermore `entities/printers` does not have retain enabled on the messages, so unless you are activly watching, you won't be able to get that state. 
