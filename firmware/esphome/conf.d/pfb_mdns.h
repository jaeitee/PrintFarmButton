#pragma once
#include <cctype>
#include <cstring>
#include <string>

#include "esp_err.h"
#include "esp_log.h"
#include "mdns.h"
#include "esphome/components/network/util.h"

static std::string pfb_current_alias;

static inline std::string pfb_slug(const std::string &name) {
  std::string s;
  for (char c : name) {
    c = (char) tolower((unsigned char) c);
    if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
      s.push_back(c);
    } else if (!s.empty() && s.back() != '-') {
      s.push_back('-');
    }
  }
  while (!s.empty() && s.back() == '-')
    s.pop_back();
  if (s.size() > 24)
    s.resize(24);
  while (!s.empty() && s.back() == '-')
    s.pop_back();
  return s;
}

inline void pfb_update_alias(const std::string &printer_name) {
  std::string slug = pfb_slug(printer_name);
  std::string host = slug.empty() ? "" : slug + "-pfb";
  if (host == pfb_current_alias)
    return;

  if (!pfb_current_alias.empty()) {
    // Removing the delegated host also drops services registered for it.
    esp_err_t err = mdns_delegate_hostname_remove(pfb_current_alias.c_str());
    if (err != ESP_OK && err != ESP_ERR_NOT_FOUND) {
      ESP_LOGW("pfb_mdns", "Failed to remove alias %s: %s", pfb_current_alias.c_str(),
               esp_err_to_name(err));
    } else {
      ESP_LOGI("pfb_mdns", "Removed alias %s.local", pfb_current_alias.c_str());
    }
    pfb_current_alias.clear();
  }
  if (host.empty())
    return;

  auto ips = esphome::network::get_ip_addresses();
  mdns_ip_addr_t nodes[5];
  mdns_ip_addr_t *head = nullptr;
  mdns_ip_addr_t *prev = nullptr;
  size_t n = 0;
  for (auto &ip : ips) {
    if (!ip.is_set() || !ip.is_ip4())
      continue;
    // Do not use IPAddress::operator esp_ip_addr_t() — with IPv6 disabled it leaves
    // addr.type uninitialized, and mDNS skips A records unless type == V4.
    memset(&nodes[n], 0, sizeof(nodes[n]));
    nodes[n].addr.type = ESP_IPADDR_TYPE_V4;
    nodes[n].addr.u_addr.ip4 = (esp_ip4_addr_t) ip;
    nodes[n].next = nullptr;
    if (prev)
      prev->next = &nodes[n];
    else
      head = &nodes[n];
    prev = &nodes[n];
    n++;
    if (n >= 5)
      break;
  }
  if (head == nullptr) {
    ESP_LOGW("pfb_mdns", "No IPv4 yet; skip alias %s", host.c_str());
    return;
  }

  esp_err_t err = mdns_delegate_hostname_add(host.c_str(), head);
  if (err != ESP_OK) {
    ESP_LOGW("pfb_mdns", "delegate add failed for %s: %s", host.c_str(), esp_err_to_name(err));
    return;
  }
  err = mdns_service_add_for_host(nullptr, "_http", "_tcp", host.c_str(), 80, nullptr, 0);
  if (err != ESP_OK) {
    ESP_LOGW("pfb_mdns", "service add failed for %s: %s", host.c_str(), esp_err_to_name(err));
  }
  ESP_LOGI("pfb_mdns", "Alias registered: %s.local (%s)", host.c_str(), ips[0].str().c_str());
  pfb_current_alias = host;
}

inline void pfb_clear_alias() { pfb_update_alias(""); }
