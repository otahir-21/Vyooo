#!/bin/bash
# After Flutter regenerates GeneratedPluginRegistrant.m, remove Agora + Iris
# registration so Iris does not start at app launch (avoids DartWorker crash on device).
# They are registered later from Dart via MethodChannel — see AgoraDeferredRegistration.m
set -euo pipefail
REG="${SRCROOT}/Runner/GeneratedPluginRegistrant.m"
if [[ ! -f "$REG" ]]; then
  echo "warning: strip_agora_at_launch: missing $REG"
  exit 0
fi
perl -i -ne 'print unless /\[AgoraRtcNgPlugin registerWithRegistrar/;' "$REG"
perl -i -ne 'print unless /\[IrisMethodChannelPlugin registerWithRegistrar/;' "$REG"
if grep -q '\[AgoraRtcNgPlugin registerWithRegistrar' "$REG" \
  || grep -q '\[IrisMethodChannelPlugin registerWithRegistrar' "$REG"; then
  echo "error: strip_agora_at_launch: Agora/Iris registration lines still present in $REG"
  exit 1
fi
