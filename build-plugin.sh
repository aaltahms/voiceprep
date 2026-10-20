#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build dist/VoicePrep.component/Contents/MacOS
clang++ -std=c++23 -O3 -DNDEBUG -DAUSDK_HAVE_UI=0 -Ivendor/AudioUnitSDK/include -mmacosx-version-min=13.0 -bundle src/Plugin.cpp vendor/AudioUnitSDK/src/AudioUnitSDK/*.cpp -framework AudioUnit -framework AudioToolbox -framework CoreAudio -framework CoreFoundation -framework CoreMIDI -o dist/VoicePrep.component/Contents/MacOS/VoicePrepAU
cp Plugin-Info.plist dist/VoicePrep.component/Contents/Info.plist
codesign --force --sign - dist/VoicePrep.component
