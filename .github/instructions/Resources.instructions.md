---
applyTo: '**'
---
Coding standards, domain knowledge, and preferences that AI should follow.

https://context7.com/esphome/esphome-docs/llms.txt

how to get from the rest api

Web UI + REST use HTTP Basic auth. Default: `admin` / `pfb-<last6hex>` (MAC suffix matching hostname). Web-UI OTA needs these credentials; native ESPHome OTA does not.

```
curl -u admin:pfb-xxxxxx "http://printfarmbutton-xxxx.local/binary_sensor/printer_is_online"
{"id":"binary_sensor-printer_is_online","value":false,"state":"OFF"}%
```


Get username
```
curl -u admin:pfb-xxxxxx -v "http://printfarmbutton-xxxxxx.local/text/username"
{"id":"text-username","min_length":0,"max_length":255,"pattern":"","state":"foobar","value":"foobar"}
```

Set username
```
curl -u admin:pfb-xxxxxx -X POST  "http://printfarmbutton-xxxxxx.local/text/username/set?value=foo"
```
