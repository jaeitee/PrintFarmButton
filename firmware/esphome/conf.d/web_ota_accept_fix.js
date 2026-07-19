// ESPHome web UI v3 puts the OTA <input type=file> inside shadow DOM with
// accept="application/octet-stream". On macOS .bin is UTI "MacBinary", so
// those files are greyed out. Walk open shadow roots and loosen accept.
(() => {
  const ACCEPT = ".bin,application/octet-stream,*/*";

  const visit = (root, fn) => {
    fn(root);
    root.querySelectorAll("*").forEach((el) => {
      if (el.shadowRoot) visit(el.shadowRoot, fn);
    });
  };

  const fix = () => {
    visit(document, (root) => {
      root.querySelectorAll('input[type="file"][name="update"]').forEach((el) => {
        if (el.getAttribute("accept") !== ACCEPT) {
          el.setAttribute("accept", ACCEPT);
        }
      });
    });
  };

  fix();
  new MutationObserver(fix).observe(document.documentElement, {
    childList: true,
    subtree: true,
  });
  // Lit / esp-app mounts async; retry a few times after load.
  [100, 500, 1000, 2000, 5000].forEach((ms) => setTimeout(fix, ms));
})();
