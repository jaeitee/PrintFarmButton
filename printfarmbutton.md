# PrintFarmButton

Local working copy of [jaeitee/PrintFarmButton](https://github.com/jaeitee/PrintFarmButton), a fork of [spuder/PrintFarmButton](https://github.com/spuder/PrintFarmButton).

This fork is for testing features on a personal print farm. For a production farm deploy, prefer the upstream project.

## What it is

A physical button + RGB LED status light for a 3D print farm, driven by ESPHome on ESP32 boards. It talks to [Printago](https://printago.io) over MQTT/API and shows printer state by LED color. A short press on the button marks the bed clear / ready.

## Printago LED states

| Color | Meaning |
|-------|---------|
| Blue | Idle / ready |
| Yellow | Downloading / starting |
| Orange | Warming / heat soak (tap to skip; auto-resume after Heat soak minutes) |
| Purple | Finished / waiting for bed clear |
| Green | Printing |
| Red | Error |

### State flags (from `DEV.md`)

| Visual | `isOnline` | `confirmedReady` | `isAvailable` |
|--------|------------|------------------|---------------|
| Blue (ready) | true | true | true |
| Purple (set ready) | true | false | true |
| Green (busy) | true | false | false |

## Repo layout

```
firmware/esphome/   ESPHome YAML (boards + shared packages in conf.d/)
firmware/output/    Prebuilt factory/OTA binaries + flash manifests
hardware/           3D-printable STLs + Fritzing schematic
images/             Docs / product images
index.html          Project landing / setup page
flash.html          Browser-based firmware flasher
DEV.md              Printago state + API/MQTT notes
TODO                Feature backlog
```

## Supported boards

- ESP32-S3 Zero / SuperMini
- ESP32-C3 Zero / SuperMini
- M5Stack Atom Matrix

Firmware packages live under `firmware/esphome/` (`esp32s3-zero.yaml`, `esp32c3-supermini.yaml`, `atom-matrix.yaml`, etc.). Shared behavior is in `common.yaml` and `conf.d/` (LED, MQTT, Printago cloud, WiFi, OTA, web server).

## Integrations

- **Printago REST API** — printer info (`/v1/printers/$PRINTERID`)
- **Printago MQTT** — live updates on `stores/$USERNAME/entities/printers/...` and `printer-stats/`
  - `printer-stats` has `isOnline` / `isAvailable`
  - `entities/printers` has `confirmedReady` (not retained — must be subscribed live)
- **Device web UI** — ESPHome web server + Improv serial for provisioning
- **OTA** — ESPHome / HTTP / web_server update platforms

## Build firmware

From `firmware/esphome/`:

```bash
podman run -it -v $PWD:/data -v $PWD/.esphome/platformio:/cache \
  esphome/esphome:2025.7.0b1 compile /data/esp32s3-supermini.yaml
```

CI builds on tags via `.github/workflows/esphome-build.yml`. Prebuilt images are in `firmware/output/`.

## Local device API examples

```bash
# Online status
curl "http://printfarmbutton-xxxx.local/binary_sensor/printer_is_online"

# Get / set Printago username
curl "http://printfarmbutton-xxxxxx.local/text/username"
curl -X POST "http://printfarmbutton-xxxxxx.local/text/username/set?value=foo"
```

## Upstream vs this fork

| | Upstream | This fork |
|--|----------|-----------|
| Repo | [spuder/PrintFarmButton](https://github.com/spuder/PrintFarmButton) | [jaeitee/PrintFarmButton](https://github.com/jaeitee/PrintFarmButton) |
| Purpose | Shared / deployable farm button | Personal feature testing |

## Open items (from `TODO`)

- Throb green when paused; support yellow / white-grey more fully
- Lower power (~300–500 mA target)
- Improv serial; show version in web UI; check for updates on boot
- Press-and-hold to mark print failed
- Auto-fetch printer list on boot; fix offline→green bug; persist store id; fetch status on boot
