#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build dist/VoicePrep.app/Contents/MacOS dist/VoicePrep.app/Contents/Resources
clang++ -std=c++17 -O3 -Wall -Wextra -pedantic tests/dsp_tests.cpp -o build/dsp-tests
./build/dsp-tests
clang++ -std=c++17 -O3 -Wall -Wextra -pedantic tests/realtime_tests.cpp -o build/realtime-tests
./build/realtime-tests
clang++ -std=c++17 -O3 -fobjc-arc -Wall -Wextra -mmacosx-version-min=13.0 -framework Foundation -framework AVFoundation src/cli.mm -o build/voiceprep-cli
clang++ -std=c++17 -O2 -fobjc-arc -Wall -Wextra -mmacosx-version-min=13.0 -framework Foundation -framework AVFoundation tests/io_safety.mm -o build/io-safety-tests
./build/io-safety-tests
if [ "${1:-}" = "--engine-only" ]; then exit 0; fi
sh ./build-plugin.sh
clang++ -std=c++17 -O2 -fobjc-arc -framework Foundation -framework AVFoundation -framework AudioToolbox tests/plugin_host.mm -o build/plugin-host
clang++ -std=c++17 -O3 -fobjc-arc -Wall -Wextra -mmacosx-version-min=13.0 -framework Cocoa -framework AudioToolbox -framework AVFoundation -framework UniformTypeIdentifiers src/App.mm -o dist/VoicePrep.app/Contents/MacOS/VoicePrep
cp Info.plist dist/VoicePrep.app/Contents/Info.plist
if [ -f examples/spoken-original.wav ]; then cp examples/spoken-original.wav dist/VoicePrep.app/Contents/Resources/; fi
mkdir -p dist/VoicePrep.app/Contents/PlugIns
ditto dist/VoicePrep.component dist/VoicePrep.app/Contents/PlugIns/VoicePrep.component
codesign --force --sign - dist/VoicePrep.app
printf '\nBuilt dist/VoicePrep.app\n'
