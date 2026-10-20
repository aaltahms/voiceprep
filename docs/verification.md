# VoicePrep v0.1.0 verification — October 20, 2026

Local environment: Apple Silicon macOS, Apple clang 17, installed native AppKit/AVFoundation SDK, Python 3.9.6. Version 0.1.0 includes offline file preparation, live microphone processing and an AUv2 effect.

## DSP and file behavior

- 13 C++ checks pass. A 100 Hz Butterworth cutoff matches -3.01 dB; a 20 Hz tone is attenuated by more than 27 dB; a 1 kHz tone remains within .05 dB of its original level.
- Downward compression reduces a 20 dB test-tone input-level difference to less than 13 dB. Linked stereo gain preserves a 2:1 channel amplitude relationship.
- Global peak protection holds sample peaks at or below -1 dBFS. Silence stays silent, and off/zero controls preserve below-ceiling input samples exactly.
- Processing the same data as one block or irregular 137-frame blocks produces identical output. Supported sample-rate extremes remain finite. Invalid values/settings are rejected.
- The 13 checks also pass with undefined-behavior sanitizer enabled. An additional address-sanitizer run did not complete in the execution environment and was interrupted; no ASan pass is claimed.
- Four Python integration tests pass using the actual native file reader/writer and CLI: mono/stereo dimensions, 24-bit PCM output, preserved 44.1 kHz sample rate and frame count, deterministic output, unchanged originals, rejection of an existing CLI output, malformed audio, nonfinite controls and trailing garbage. AIFF and AAC/M4A imports preserve the decoded frame count, sample rate and channel count. The AAC fixture test runs outside the execution sandbox because the sandbox prevents the system encoder from loading.
- Five native export-safety scenarios pass: refusing original paths, symlink aliases and hard-link aliases; refusing occupied destinations by default; explicitly replacing a separate file while retaining the original.

## Live engine and Audio Unit

- 15 real-time checks pass, including 8–192 kHz transient/sustained peak protection, linked stereo, an exact 5 ms delay, irregular block boundaries, rapid parameter automation, nonfinite input sanitization and smoothed gain changes. The same suite passes UBSan.
- The live processor uses fixed storage, no locks, and no file operations. An allocation-trapping local benchmark ran 20,000 stereo blocks of 64 frames at 192 kHz with no C++ heap allocations during processing. Mean processing time was 1.85 µs and the worst observed block was 9.58 µs against a 333.33 µs buffer budget. These are local measurements, not a real-time scheduling guarantee.
- Apple `auval -v aufx Vprp Aalt` passed. It tested mono/stereo, multiple sample rates and frame sizes, parameter setting/scheduling, initialization/reset, properties and connection semantics. The final build publishes parameter names as CFStrings, and validation completed without warnings.
- A real AVAudioEngine host loaded and registered the component, rendered 51,200 frames each in mono and stereo, verified a −1 dBFS sample-peak ceiling and linked stereo, saved/restored state, and read the reported 5 ms latency. No microphone was used by this harness.
- The native live panel started the actual microphone after the owner granted permission, showed callbacks receiving and processing microphone buffers and stopped cleanly. Monitoring remained muted during this check. Actual acoustic quality and headphone-monitoring latency are not established by that observation.

## Recorded speech and measurements

Human speech: Open Speech Repository, `OSR_us_000_0010_8k.wav`, with attribution and modification recipe in examples/. The 18-second example deliberately introduces a 35 Hz component and varying voice gain. At 80 Hz rumble cutoff, 50% leveling and +3 dB output, the measured 35 Hz component falls by approximately 12.0 dB. This verifies behavior on a repeatable constructed impairment, not perceived quality on an uncontrolled room recording. The 8 kHz source cannot establish full-band audio quality.

A five-run local benchmark rendered a 30-second, 48 kHz stereo synthetic tone in a median of approximately 0.023 seconds (slowest approximately 0.024 seconds). This measures the offline C++ render path on this machine. It is not callback latency, a scheduling deadline guarantee, sustained device performance, or a comparison against commercial products. Reproduce with `tests/benchmark.cpp` and the same optimization settings.

## Native app observations

- The compiled application opens its initial state with playback and export disabled until a file is prepared.
- The bundled human speech example loads and correctly identifies its source and introduced faults.
- Playback advances the actual recording time. Switching Original/Prepared retains the advancing timeline. Both players use one scheduled device start and a 12 ms audition crossfade. Average-volume matching is an optional attenuation-only comparison aid.
- The rumble slider was changed from 80 to 100 Hz; the recording was prepared again while retaining the paused position.
- The native Save panel wrote `native-export-check.wav`. Independent file inspection confirmed mono, 8 kHz, 144,000 frames and 24-bit PCM. Every byte matched a separate CLI invocation at the same settings.
- A malformed `.wav` was rejected; the previous recording and controls remained available. The system's cryptic decoder message was replaced with an actionable recovery message in the final build.
- Standard native controls and keyboard shortcuts provide access to playback, seeking, settings, open and export. Visual inspection confirmed the complete desktop layout. This is not an accessibility certification.

## Boundaries and next product validation

No VST, LUFS implementation, true-peak limiter, denoising model, clipped-audio restoration or user preference study is claimed. AUv2 validation does not establish compatibility with every third-party DAW. The native application is locally ad-hoc signed; it is not notarized. The GitHub Actions configuration is prepared, but no hosted run is claimed before publication.

The next product milestone is a listening trial on the owner's actual presentation/interview recordings, with comparisons at similar volume. The live path uses a lookahead limiter; offline export uses one whole-file trim, so their dynamics can differ when peak protection engages.
