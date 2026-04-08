#!/bin/bash
# Two-part defence against DartWorker EXC_BAD_ACCESS (code=50 / KERN_NOT_IN_MAP)
# caused by Agora Iris SDK C++ static initializers conflicting with Flutter JIT
# on physical iPhone in Debug mode.
#
# Part 1 (this script, build-time):
#   a) Strip Agora + Iris plugin registration from GeneratedPluginRegistrant.m so
#      Flutter never registers the plugin in any build configuration.
#   b) In Debug builds, clear the CocoaPods xcfilelist for the "Embed Pods
#      Frameworks" phase so Xcode does not warn about Agora framework outputs
#      that were intentionally not embedded (see Part 2 below).
#
# Part 2 (Podfile post_install, pod-install-time):
#   The Debug block in Pods-Runner-frameworks.sh (which copies Agora dynamic
#   frameworks into the .app bundle) is removed by the Podfile post_install hook.
#   Without those .dylib files in Frameworks/, dyld never loads Agora/Iris, so
#   the C++ static initializers never run and the crash cannot occur.
#   Profile and Release builds are unaffected — Agora is fully embedded there.
set -euo pipefail

# Fail-fast guard: Debug + physical iPhone + Agora is unsupported (JIT/Iris).
# Stop the build with a clear action instead of dyld / EXC_BAD_ACCESS crashes.
# We intentionally detect iphoneos using multiple env vars because Xcode/flutter
# does not always populate EFFECTIVE_PLATFORM_NAME consistently across phases.
IS_DEVICE_BUILD=0
if [[ "${EFFECTIVE_PLATFORM_NAME:-}" == "-iphoneos" ]] \
  || [[ "${PLATFORM_NAME:-}" == "iphoneos" ]] \
  || [[ "${SDK_NAME:-}" == iphoneos* ]] \
  || [[ "${SDKROOT:-}" == *iphoneos* ]]; then
  IS_DEVICE_BUILD=1
fi

if [[ "${CONFIGURATION:-}" == "Debug" && "${IS_DEVICE_BUILD}" == "1" ]]; then
  echo "error: Vyooo does not support Debug mode on physical iPhone when Agora is linked."
  echo "error: Use one of these instead:"
  echo "error:   flutter run --profile"
  echo "error:   flutter run --release"
  echo "error:   Xcode scheme Runner-Device-Profile"
  exit 1
fi

# ── Part 1a: strip plugin registration ───────────────────────────────────────
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

# ── Part 1b: clear Debug xcfilelists so Xcode does not warn about missing ────
#            Agora framework outputs (they are intentionally not embedded).
#            This runs before [CP] Embed Pods Frameworks.
if [[ "${CONFIGURATION}" == "Debug" ]]; then
  SUPPORT="${PODS_ROOT}/Target Support Files/Pods-Runner"
  for DIRECTION in input output; do
    XCFILELIST="${SUPPORT}/Pods-Runner-frameworks-Debug-${DIRECTION}-files.xcfilelist"
    if [[ -f "${XCFILELIST}" ]]; then
      # Keep only non-Agora lines (input list retains the .sh script reference).
      grep -vE 'AgoraIrisRTC|AgoraVideo_Special|/Agora|/aosl\.framework|/video_dec\.framework|/video_enc\.framework' \
        "${XCFILELIST}" > "${XCFILELIST}.tmp" || true
      mv "${XCFILELIST}.tmp" "${XCFILELIST}"
    fi
  done
fi
