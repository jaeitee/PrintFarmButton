# Plan 1: Friendly `<printer>-pfb.local` URL

## Goal
Give the button a second, human-memorable mDNS address derived from the selected
Printago printer name, e.g. `x1c-carbon-pfb.local`, while keeping the existing
`printfarmbutton-<mac>.local` hostname intact for OTA / Improv / dashboard.

## Key facts (already in repo)
- Firmware is ESPHome, framework `esp-idf` for all boards
  (`firmware/esphome/esp32c3-supermini.yaml` line 10-11; same for the other
  `esp32*/atom-matrix` board files). All boards `!include common.yaml`.
- Base name is set in `firmware/esphome/common.yaml`:
  `name: printfarmbutton` + `name_add_mac_suffix: true` → runtime hostname
  `printfarmbutton-<mac>`.
- The selected printer name is already fetched and stored in a template
  text_sensor `id(printer_name)` (`firmware/esphome/conf.d/cloud_printago.yaml`
  line 625-629). It is published in two spots:
  - REST status parse: `id(printer_name).publish_state(name);` (~line 142)
  - MQTT stats callback: `id(printer_name).publish_state(name);` (~line 836)
- mDNS is implicit (no `mdns:` component file exists). ESP-IDF ships an mDNS
  responder that ESPHome configures.

## Approach (recommended: ESP-IDF delegated hostname)
Do NOT change the base `name`. Instead register an ADDITIONAL mDNS hostname that
points at the same IP, using the ESP-IDF mDNS "delegated host" API. This adds an
A record for `<slug>-pfb.local` alongside the existing hostname.

Core steps:
1. Add a small C++ helper (lambda or a tiny custom `esphome:` `includes:` header)
   that:
   - Builds a DNS-safe slug from `id(printer_name)`:
     - lowercase, replace any non `[a-z0-9-]` with `-`, collapse repeats, trim
       leading/trailing `-`, cap length (~24 chars) to stay within mDNS limits.
     - Append `-pfb` → final label `<slug>-pfb`.
     - If the slug is empty (no printer selected), skip / remove the alias.
   - Removes the previously registered alias if the name changed
     (`mdns_delegate_hostname_remove(prev)`), then adds the new one:
     - Get current IP via `esphome::network::get_ip_addresses()`.
     - `mdns_delegate_hostname_add(new_host, &addr_list);`
     - Advertise HTTP on it so browsers resolve + connect:
       `mdns_service_add_for_host(NULL, "_http", "_tcp", new_host, 80, NULL, 0);`
   - Store the current alias in a `globals:` string so we can remove/replace it.
2. Trigger the helper whenever the name becomes known / changes:
   - In `common.yaml` `on_boot` (after wifi up) — or better, in
     `conf.d/wifi.yaml` `on_connect` since the delegated host needs a valid IP.
   - On every `id(printer_name)` update. Easiest: add an `on_value:` to the
     `printer_name` text_sensor (line 625) that calls the helper. That single
     hook covers both the REST and MQTT publish paths.
3. Re-register on reconnect: also call the helper in `wifi.yaml` `on_connect`
   (the delegated host / IP must be re-added after a network drop).

### Files to change
- `firmware/esphome/conf.d/cloud_printago.yaml`
  - Add `on_value:` to the `printer_name` text_sensor → run alias-update lambda.
- `firmware/esphome/conf.d/wifi.yaml`
  - In `on_connect`, call the alias-update lambda (needs IP present).
  - In `on_disconnect`, optionally clear the alias.
- `firmware/esphome/common.yaml`
  - Add `globals:` for `current_pfb_alias` (std::string, restore_value: no).
  - If using a shared C++ header, add `esphome: includes: [conf.d/pfb_mdns.h]`.
- (Optional new) `firmware/esphome/conf.d/pfb_mdns.h`
  - Slug + register/unregister helpers, so the lambdas stay small.

### Code sketch (verify exact ESP-IDF mDNS symbols at build time)
```cpp
// pfb_mdns.h
#include "mdns.h"
#include "esphome/components/network/util.h"

static std::string pfb_slug(const std::string &name) {
  std::string s;
  for (char c : name) {
    c = (char)tolower((unsigned char)c);
    if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) s.push_back(c);
    else if (!s.empty() && s.back() != '-') s.push_back('-');
  }
  while (!s.empty() && s.back() == '-') s.pop_back();
  if (s.size() > 24) s.resize(24);
  return s;
}

static std::string g_pfb_alias;  // or use an ESPHome global

inline void pfb_update_alias(const std::string &printer_name) {
  std::string slug = pfb_slug(printer_name);
  std::string host = slug.empty() ? "" : slug + "-pfb";
  if (host == g_pfb_alias) return;

  if (!g_pfb_alias.empty()) {
    mdns_service_remove_for_host("_http", "_tcp", g_pfb_alias.c_str());
    mdns_delegate_hostname_remove(g_pfb_alias.c_str());
    g_pfb_alias.clear();
  }
  if (host.empty()) return;

  auto ips = esphome::network::get_ip_addresses();
  // Build mdns_ip_addr_t list from ips (IPv4 at minimum).
  // mdns_delegate_hostname_add(host.c_str(), &addr_list);
  // mdns_service_add_for_host(NULL, "_http", "_tcp", host.c_str(), 80, NULL, 0);
  g_pfb_alias = host;
}
```

## Risks / caveats (call out to user)
- ESP-IDF mDNS delegated-host API details (`mdns_delegate_hostname_add`, address
  list struct) must be confirmed against the pinned ESP-IDF version during build;
  symbol names / signatures can vary. If delegated hosts are unavailable, the
  fallback is to expose a user-set custom hostname via `wifi: use_address`
  (changes the single hostname; loses the fixed MAC name) — less desirable.
- Printer names with spaces/emoji/duplicates → slug collisions or empty slugs;
  the slug rules above must handle these. Two buttons pointing at printers with
  the same name would advertise the same alias (last one wins on the network).
- mDNS caching: a rename can leave clients briefly resolving the old alias until
  TTL expires. Always keep the IP + `printfarmbutton-<mac>.local` as fallbacks.
- Only affects mDNS/`.local`; no effect on WAN. Some corporate/guest networks
  block mDNS entirely.

## Test plan
1. Build + flash one board (e.g. esp32c3-supermini).
2. Select a printer named "X1C Carbon"; confirm log shows alias `x1c-carbon-pfb`.
3. From a Mac on the same LAN: `ping x1c-carbon-pfb.local` and open
   `http://x1c-carbon-pfb.local` → button web UI loads.
4. Confirm `printfarmbutton-<mac>.local` STILL works (OTA/dashboard unaffected).
5. Change the selected printer → old alias stops resolving, new one resolves.
6. Reboot + Wi-Fi drop/reconnect → alias re-registers automatically.

## Out of scope
- GUI password / auth (that is Plan 2).
- Renaming the primary hostname or Home Assistant entity ids.
