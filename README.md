# Whisperbar

A polished native macOS menu bar dictation app with blind A/B testing across three transcription backends.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon Mac (M-series)
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build Instructions

```bash
# Clone / navigate to the project
cd ~/Developer/Whisperbar

# Generate Xcode project and build
make build

# Or step by step:
xcodegen generate
xcodebuild -project Whisperbar.xcodeproj -scheme Whisperbar build

# Run the app
make run
```

## First Launch

On first launch, an onboarding wizard guides you through:

1. **Microphone** permission (required for recording)
2. **Accessibility** permission (required for text injection)
3. **Speech Recognition** permission (required for Apple backend)
4. **Whisper model download** (~140 MB, stored in `~/Library/Application Support/Whisperbar/Models/`)
5. **Mode selection**: Blind A/B test or single backend

## Permissions Setup

| Permission | Why |
|-----------|-----|
| Microphone | Record audio |
| Accessibility | Inject transcribed text into any app |
| Speech Recognition | Apple on-device speech engine |

If a permission is revoked, a warning badge appears on the menu bar icon. Click it to re-grant.

## Usage

- **Default hotkey:** `⌥Space` (configurable in Settings → Hotkey)
- **Hold mode:** Hold `⌥Space` to record, release to transcribe
- **Toggle mode:** Press once to start, again to stop
- Transcribed text is injected at the cursor position in any app

## How A/B Mode Works

When **Blind A/B test mode** is enabled (Settings → General):

1. Each recording randomly picks **Apple**, **Whisper**, or **Hybrid** — no indication of which
2. After transcription, a rating toast appears: 👍 Good / 👌 OK / 👎 Bad
3. Ratings are logged to `~/Library/Application Support/Whisperbar/sessions.db`
4. After 20 rated sessions, Settings → Stats shows a "Reveal Winner" button
5. Backend identities remain hidden until you click Reveal

## Backends

| Backend | Speed | Accuracy | Notes |
|---------|-------|----------|-------|
| Apple | ⚡ < 200ms | Good | On-device Neural Engine, no download |
| Whisper | 🚀 < 800ms | Excellent | ggml-base.en + Metal acceleration |
| Hybrid | ⚡+🚀 | Excellent | Apple for live feedback, Whisper final |

## Export Session Data

```bash
# Export to CSV via Makefile
make export-sessions > sessions.csv

# Or via the Stats tab in Settings — click "Export to CSV…"
```

CSV format: `id, timestamp, backend, duration_ms, latency_ms, word_count, transcript, rating`

## Core ML Note

The whisper.cpp Core ML encoder integration requires downloading `ggml-base.en-encoder.mlmodelc.zip` and compiling with `WHISPER_COREML=1`. The current build uses Metal-only acceleration via `GGML_USE_METAL=1`, which achieves excellent performance on M-series chips. To enable Core ML:

1. Download the encoder: `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-encoder.mlmodelc.zip`
2. Unzip to `~/Library/Application Support/Whisperbar/Models/`
3. Edit `Packages/WhisperKit/Package.swift` and add `.define("WHISPER_COREML", to: "1")` to cSettings
4. Rebuild

## Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Cold start | < 400ms | Model loaded lazily |
| Idle RAM | < 80MB | Whisper unloaded |
| RAM with model | < 400MB | base.en ~140MB |
| Apple transcription | < 200ms | 10s clip |
| Whisper transcription | < 800ms | 10s clip, Metal |
| Hybrid (Apple result) | < 200ms | |
| Hybrid (Whisper final) | < 1000ms | |

## Data Privacy

All processing is on-device. No audio or transcripts are sent to any server. The session database is local at `~/Library/Application Support/Whisperbar/sessions.db`.
