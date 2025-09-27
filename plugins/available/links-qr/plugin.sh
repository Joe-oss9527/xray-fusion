#!/usr/bin/env bash
XRF_PLUGIN_ID="links-qr"
XRF_PLUGIN_VERSION="1.0.0"
XRF_PLUGIN_DESC="Render QR codes for client links (if qrencode present)"
XRF_PLUGIN_HOOKS=("links_render")
links_qr::links_render() {
  command -v qrencode > /dev/null 2>&1 || {
    echo "[links-qr] qrencode not found"
    return 0
  }
  echo "[links-qr] Tip: pipe link to qrencode to show QR"
}
