#!/bin/sh
# User-level installation only. Never overwrites an unrelated component.
set -eu
cd "$(dirname "$0")"
component="dist/VoicePrep.component"
[ -d "$component" ] || { printf 'Run ./build.sh first.\n'; exit 1; }
plugin_dir="$HOME/Library/Audio/Plug-Ins/Components"
mkdir -p "$plugin_dir"
if [ -e "$plugin_dir/VoicePrep.component" ]; then
  identifier=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$plugin_dir/VoicePrep.component/Contents/Info.plist")
  [ "$identifier" = dev.aaltahms.voiceprep.au ] || { printf 'A different VoicePrep.component already exists. Installation stopped.\n'; exit 1; }
  backup_dir="$HOME/Library/Audio/Plug-Ins/VoicePrep-Backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup_dir"
  mv "$plugin_dir/VoicePrep.component" "$backup_dir/VoicePrep.component"
fi
ditto "$component" "$plugin_dir/VoicePrep.component"
printf 'Installed the VoicePrep Audio Unit for this user. Restart your audio host to rescan.\n'
