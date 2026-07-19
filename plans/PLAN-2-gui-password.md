# Plan 2: Password-protect the Web GUI

## Goal
Require a username/password to access the button's web UI. Ship with a known
initial password, and let the user change it from the UI afterwards. Do NOT lock
the user out and keep OTA + REST usable.

## Key facts (already in repo)
- Web UI is configured in `firmware/esphome/conf.d/web_server.yaml`
  (`web_server: port: 80, version: 3, ...`), included from `common.yaml`
  (`web_server: !include conf.d/web_server.yaml`). It has NO auth today.
- `common.yaml` also enables web OTA (`ota: - platform: web_server`) and
  `http_request` — so the web port can currently upload firmware with no auth.
- ESPHome supports `web_server: auth:` with `username` / `password` and
  `type: basic|digest` (digest recommended; default `basic` until 2027.1.0).
  Runtime setters exist: `set_auth_username()` / `set_auth_password()`.
- Existing secret pattern: Printago config uses `text` components with
  `mode: password`, `restore_value: true` (e.g. `api_key_text`,
  `firmware/esphome/conf.d/cloud_printago.yaml` line 711-716). Same pattern works
  for a stored web password.
- REST usage documented in `.github/instructions/Resources.instructions.md`
  (curl to `/text/username`, `/binary_sensor/...`) will need credentials once
  auth is on.

## Decision: initial password source
The user asked about pulling a "Printago access code" as the initial password.
This firmware only holds **API key + Store ID** (`api_key_text`, `storeid_text`),
there is no separate low-privilege access code. Recommendation:
- Use a **device-derived default** initial password (e.g. `pfb-<mac_suffix>`,
  printable on the label) OR a fixed default like `printfarm`.
- Do NOT reuse the Printago API key as the web password (chicken-and-egg before
  Printago is set up, and it mixes a high-privilege cloud secret into local UI
  login).
- Then allow the user to change it in the UI (persisted to NVS).

> Confirm with user: default = `pfb-<mac_suffix>` (recommended) vs a static
> `printfarm` vs a build-time secret.

## Approach

### Phase A - Static auth (fast, low risk)
1. In `firmware/esphome/conf.d/web_server.yaml` add:
```yaml
web_server:
  port: 80
  version: 3
  auth:
    username: admin
    password: !secret web_ui_password   # or a substitution/default
    type: basic   # digest is stronger but breaks plain curl; see risks
  # ...existing sorting_groups...
```
2. Add `web_ui_password` to `firmware/esphome/secrets.yaml` (gitignored; a
   `.gitignore` already exists under `firmware/esphome/`).
3. Note in README that web OTA + REST now require these credentials.

This alone satisfies "put a password on the GUI".

### Phase B - User-changeable password (moderate)
Make the password editable from the UI and persisted across reboots.
1. Give the web server an id so it can be reconfigured at runtime:
```yaml
web_server:
  id: pfb_web
  auth:
    username: admin
    password: "PLACEHOLDER"   # overwritten at boot from stored value
```
2. Add a stored password `text` input (reuse the `api_key_text` pattern) in a
   config file included by `common.yaml` (e.g. new `conf.d/web_auth.yaml` or add
   to `web_server.yaml`'s package):
```yaml
text:
- platform: template
  name: "Web UI Password"
  id: web_ui_password_text
  mode: password
  restore_value: true
  optimistic: true
  web_server:
    sorting_group_id: cloud   # or a new "Security" sorting group
  on_value:
    then:
    - lambda: |-
        std::string p = x.empty() ? std::string("DEFAULT_HERE") : x;
        id(pfb_web).set_auth_password(p.c_str());
```
3. Seed the default at boot in `common.yaml` `on_boot`:
```yaml
- lambda: |-
    std::string p = id(web_ui_password_text).state;
    if (p.empty()) p = "pfb-" + <mac_suffix>;   // device-derived default
    id(pfb_web).set_auth_password(p.c_str());
    id(pfb_web).set_auth_username("admin");
```
4. (Optional) Add a "Security" `sorting_groups` entry in `web_server.yaml` so the
   password field groups nicely in the UI.

### Files to change
- `firmware/esphome/conf.d/web_server.yaml` - add `id:` + `auth:` (+ optional
  Security sorting group).
- `firmware/esphome/secrets.yaml` - add `web_ui_password` (Phase A only).
- `firmware/esphome/common.yaml` - seed default password/username in `on_boot`.
- New (Phase B): `firmware/esphome/conf.d/web_auth.yaml` (the `text` input),
  included from `common.yaml` `packages:`.
- `README.md` / `DEV.md` / `.github/instructions/Resources.instructions.md` -
  document that REST + web OTA now need credentials (e.g.
  `curl -u admin:<pw> ...`, and `--digest` if digest is chosen).

## Risks / caveats (call out to user)
- **Lockout**: if the stored value is empty/garbage and no default is seeded,
  the user is locked out (recovery = serial reflash). The boot seed + non-empty
  fallback above prevents this. Consider keeping a hard-coded recovery default.
- **basic vs digest**: `basic` sends the password base64 (cleartext on LAN) but
  works with plain `curl`. `digest` keeps it off the wire but requires
  `curl --digest` and every REST client to support it. Pick per user preference;
  min_version is `2025.7.0` so digest `type:` should be available, but confirm
  at build.
- **REST + web OTA impact**: enabling auth changes the documented curl commands
  and web-UI OTA uploads (they need `-u`/`--digest`). Native ESPHome OTA
  (`platform: esphome`) is unaffected.
- **Not a Printago access code**: initial password is device-derived/static, not
  from Printago (no such code exists in this firmware). If Printago later exposes
  a real pairing code via the API, it could seed the default instead.
- Changing the password field over an UNauthed session (first setup) is fine;
  after that, the UI already required the old password to reach the field.

## Test plan
1. Build + flash. Browser opens `http://<device>.local` → prompts for login.
2. Wrong password rejected; correct default (`pfb-<mac>`) accepted.
3. Phase B: change password in UI → reboot → new password required, old rejected.
4. REST: `curl -u admin:<pw> http://<device>.local/binary_sensor/printer_is_online`
   works; without `-u` returns 401.
5. Confirm native ESPHome OTA still flashes without web creds.

## Out of scope
- Friendly `<printer>-pfb.local` URL (that is Plan 1).
- Multi-user accounts / roles (single shared admin login only).
