#!/bin/bash
# Defer Agora + Iris registration until Dart calls registerAgora (live flows),
# so cold start avoids loading those native plugins too early.
#
# Note: Physical iPhone + Debug (JIT) + Agora can still hit DartWorker crashes
# during live calls — use `flutter run --profile` or scheme Runner-Device-Profile
# when testing camera/live. Debug must embed Agora frameworks or dyld fails with
# "Library not loaded: AgoraRtcWrapper".
set -euo pipefail

# ── Strip plugin registration from GeneratedPluginRegistrant.m ───────────────
REG="${SRCROOT}/Runner/GeneratedPluginRegistrant.m"
if [[ ! -f "$REG" ]]; then
  echo "warning: strip_agora_at_launch: missing $REG"
  exit 0
fi
perl -i -ne 'print unless /\[AgoraRtcNgPlugin registerWithRegistrar/;' "$REG"
perl -i -ne 'print unless /\[IrisMethodChannelPlugin registerWithRegistrar/;' "$REG"
# Drop header/import blocks so this translation unit does not pull modules at compile time.
perl -0777 -i -pe 's/#if __has_include\(<agora_rtc_engine\/AgoraRtcNgPlugin.h>\).*?#endif\n//sg' "$REG"
perl -0777 -i -pe 's/#if __has_include\(<iris_method_channel\/IrisMethodChannelPlugin.h>\).*?#endif\n//sg' "$REG"
if grep -q '\[AgoraRtcNgPlugin registerWithRegistrar' "$REG" \
  || grep -q '\[IrisMethodChannelPlugin registerWithRegistrar' "$REG"; then
  echo "error: strip_agora_at_launch: Agora/Iris registration lines still present in $REG"
  exit 1
fi
if grep -qE 'AgoraRtcNgPlugin|IrisMethodChannelPlugin' "$REG"; then
  echo "error: strip_agora_at_launch: stray Agora/Iris references in $REG"
  exit 1
fi
