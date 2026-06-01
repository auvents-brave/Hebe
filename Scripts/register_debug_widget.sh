#!/bin/sh

set -eu

app_path="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
widget_path="${app_path}/Contents/PlugIns/HebeWidgets.appex"
installed_widget="/Applications/Hebe.app/Contents/PlugIns/HebeWidgets.appex"

if [ ! -d "$widget_path" ]; then
  echo "warning: missing widget at ${widget_path}" >&2
  exit 0
fi

if [ -d "$installed_widget" ] && [ "$installed_widget" != "$widget_path" ]; then
  pluginkit -r "$installed_widget" >/dev/null 2>&1 || true
fi

pluginkit -a "$widget_path" >/dev/null 2>&1 || true
killall chronod >/dev/null 2>&1 || true
