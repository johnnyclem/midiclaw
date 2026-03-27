<p align="center">
  <h1 align="center">🎹 MidiClaw</h1>
  <p align="center">
    <strong>Autonomous MIDI Agent with On-Device Intelligence</strong>
  </p>
  <p align="center">
    An AI-powered MIDI companion that listens, reasons, and plays — entirely on your Mac.
  </p>
  <p align="center">
    <a href="#features">Features</a> •
    <a href="#how-it-works">How It Works</a> •
    <a href="#getting-started">Getting Started</a> •
    <a href="#architecture">Architecture</a> •
    <a href="#usage">Usage</a> •
    <a href="#building-plugins">Plugins</a> •
    <a href="#contributing">Contributing</a>
  </p>
  <p align="center">
    <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square">
    <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square">
    <img alt="License" src="https://img.shields.io/badge/license-MIT-green?style=flat-square">
    <img alt="Status" src="https://img.shields.io/badge/status-v0.1.0%20alpha-yellow?style=flat-square">
  </p>
</p>

---

## What is MidiClaw?

MidiClaw is a native macOS app that sits between any MIDI source and destination — your keyboard, DAW, synths, drum machines — and uses **on-device AI** to observe, understand, and generate MIDI in real time.

No cloud. No latency. No data leaves your machine.

The core innovation is a **lightweight transformer adapter** that maps MIDI protocol data directly into an LLM's embedding space. Instead of awkwardly serializing MIDI as text, MidiClaw lets the AI *natively* understand musical data — notes, velocities, timing, control changes — as first-class tokens.

### Why MidiClaw?

| Problem | MidiClaw's Answer |
|---|---|
| Cloud AI music tools have too much latency for live performance | 100% on-device inference via MLX on Apple Silicon |
| Rule-based MIDI tools are deterministic and lack musical understanding | LLM-powered reasoning about harmony, rhythm, and intent |
| AI tools treat MIDI as text, wasting context on syntax | Custom 512-token vocabulary with direct embedding projection |
| Creative MIDI data is sensitive IP | Nothing ever leaves your Mac |

---

## Features

### Three Operating Modes

- **Monitor** — Passive observation. MidiClaw watches your MIDI stream, identifies chords, keys, and phrases, and annotates everything in real time. Great for practice analysis and session logging.

- **Copilot** — The AI suggests transformations — harmonizations, arpeggios, CC automation — and waits for your approval before sending any MIDI output.

- **Autonomous** — Full closed-loop generation. Play piano, and MidiClaw generates drum accompaniment. Lay down a beat, and it responds with chords. Zero-latency creative partner for live performance and generative installations.

### Meet Mindi, Your AI Accompanist

Mindi is MidiClaw's built-in AI accompanist. Toggle it from the menu bar and start playing:

- **Play piano** → Mindi generates complementary drum patterns
- **Play drums** → Mindi responds with piano chords and melodies
- **Chat with Mindi** → Ask for specific patterns, styles, or changes in natural language

### Instruments & Interfaces

- **Piano Roll** — Interactive keyboard UI with configurable range (C3–C6 default), click or use your MIDI controller
- **Step Sequencer** — 16-step drum pattern editor with a visual grid for kick, snare, hi-hat, and more
- **Token Stream View** — Debug display showing the raw MidiToken stream in real time
- **Session Browser** — Record, replay, search, import, and export MIDI sessions

### Session Recording

Every MIDI session is tokenized and stored with **nanosecond-precision timestamps** in a local SQLite database. Sessions can be:

- Browsed and searched
- Replayed with exact timing fidelity
- Exported as Standard MIDI Files (`.mid`)
- Imported from existing `.mid` files
- Used as training data for adapter fine-tuning

### Plugin Formats

MidiClaw ships as both a standalone app and audio plugins:

- **AUv3 Audio Unit** — MIDI effect plugin for Logic Pro, GarageBand, and any AU-compatible host
- **VST3** — MIDI effect plugin for Ableton Live, Cubase, Reaper, and other VST3 hosts

---

## How It Works

### The MidiToken Vocabulary

MidiClaw defines a compact, **512-token vocabulary** purpose-built for MIDI:

```
Token Class           Range      Description
─────────────────────────────────────────────────────────────
NOTE_ON_[0–127]       0–127      One token per MIDI note
NOTE_OFF_[0–127]      128–255    Explicit note-off events
VEL_[bucket]          256–287    32 velocity buckets (4-unit resolution)
DELTA_[bucket]        288–351    64 time-delta buckets (log-scaled, 1ms–4s)
CC_[num]_[bucket]     352–479    Control Change 0–31, 4 value buckets each
SPECIAL               480–511    PAD, BOS, EOS, BAR, PHRASE, CHANNEL_0–15
```

The tokenizer is **deterministic and lossless** — any MIDI byte stream round-trips through encode → decode with zero information loss.

### The Adapter Layer

Rather than burning context window on text like `"Note On channel 1 note 60 velocity 100"`, MidiClaw uses a small transformer (~2–5M parameters) that:

1. **Encodes** a window of MidiTokens into embedding matrices compatible with the host LLM
2. **Decodes** LLM output embeddings back into MidiToken sequences
3. **Preserves timing** via explicit delta tokens instead of relying on text sequencing

Think of it as a **MIDI-native CLIP adapter** — trained offline with contrastive learning to align MIDI embeddings with the LLM's text embeddings for semantically equivalent content.

### Latency Targets

| Response Type | Target Latency | Example |
|---|---|---|
| Simple | < 50ms | Harmonize a single note |
| Complex | < 200ms | Generate a 4-bar phrase |

Benchmarked on M1 Pro with 8GB unified memory.

---

## Getting Started

### Prerequisites

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** (M1/M2/M3+) recommended for MLX inference
- **Xcode 15+** (for building from source)

### Build & Run

```bash
# Clone the repository
git clone https://github.com/johnnyclem/midiclaw.git
cd midiclaw

# Build with Swift Package Manager
swift build

# Run the app
swift run MidiClaw

# Run tests
swift test
```

### For Production Builds

```bash
swift build -c release
```

### AI Inference Dependencies (Optional)

For full AI accompaniment features, install the MLX inference stack:

```bash
# Install Python 3.8+ if needed
brew install python3

# Install MLX and the LM serving layer
pip install mlx mlx-lm

# MidiClaw will auto-detect and use a default model (Llama-3.2-1B-Instruct-4bit)
```

MidiClaw works without these — Mindi falls back to heuristic-based pattern generation — but the LLM integration unlocks the full reasoning capabilities.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        MidiClaw App                             │
│  ┌───────────┐  ┌───────────┐  ┌────────────┐  ┌────────────┐  │
│  │  SwiftUI  │  │   Mindi   │  │   LLM      │  │  Session   │  │
│  │   Views   │  │Accompanist│  │  Manager   │  │  Store     │  │
│  └─────┬─────┘  └─────┬─────┘  └──────┬─────┘  └──────┬─────┘  │
│        │              │               │               │         │
│  ┌─────┴──────────────┴───────────────┴───────────────┴─────┐  │
│  │                     MidiClawCore                          │  │
│  │  ┌──────────┐  ┌──────────────┐  ┌────────────────────┐  │  │
│  │  │  MIDI    │  │  Tokenizer   │  │     Session        │  │  │
│  │  │  I/O     │  │  (encode/    │  │  (record/replay/   │  │  │
│  │  │  Layer   │  │   decode)    │  │   import/export)   │  │  │
│  │  └────┬─────┘  └──────────────┘  └────────────────────┘  │  │
│  └───────┼───────────────────────────────────────────────────┘  │
│          │                                                      │
└──────────┼──────────────────────────────────────────────────────┘
           │
     ┌─────┴─────┐
     │  CoreMIDI  │ ←→ Hardware controllers, DAWs, virtual ports
     └───────────┘
```

### Project Structure

```
Sources/
├── MidiClawCore/              # Core library (MIDI I/O, tokenizer, sessions)
│   ├── MIDI/                  # CoreMIDI client, ports, parsing, hardware scanning
│   ├── Tokenizer/             # MidiToken vocabulary, encoder, decoder
│   ├── Session/               # Recording, playback, MIDI file import/export
│   └── Util/                  # Logger, mach-time utilities
│
├── MidiClaw/                  # macOS host application
│   ├── Models/                # LLMManager, Mindi accompanist, instruments
│   └── Views/                 # SwiftUI views (piano roll, sequencer, chat, etc.)
│
└── MidiClawAU/                # AUv3 Audio Unit MIDI effect plugin

VST/                           # VST3 MIDI effect plugin (C++)

Tests/
├── MidiClawCoreTests/         # 40+ tests: parser, tokenizer round-trips, sessions
└── MidiClawAUTests/           # Plugin parameter & processor tests
```

### Key Design Decisions

| Decision | Rationale |
|---|---|
| **On-device only** | Musicians won't tolerate cloud latency during performance; MIDI data is sensitive creative IP |
| **Custom token vocabulary** | 512 tokens vs. thousands of text tokens for the same MIDI data — 10x more efficient context usage |
| **Adapter, not fine-tuning** | A frozen ~2–5M param projection layer lets you swap the host LLM without retraining |
| **Deterministic tokenizer** | Lossless MIDI round-tripping is non-negotiable for a professional audio tool |
| **macOS-first** | CoreMIDI + MLX + SwiftUI = best-in-class experience on Apple Silicon; iOS deferred intentionally |

---

## Usage

### First Launch

1. MidiClaw detects your connected MIDI hardware automatically
2. The onboarding flow guides you through port selection
3. Choose your instrument (piano or drums)
4. Toggle Mindi in the menu bar to start jamming

### MIDI Routing

MidiClaw creates **virtual MIDI ports** that appear in any DAW or MIDI app:

- **MidiClaw Input** — Send MIDI into MidiClaw from any source
- **MidiClaw Output** — Receive MidiClaw's AI-generated MIDI

Connect your controller → MidiClaw → your DAW/synth for an AI-in-the-loop signal chain.

### Recording Sessions

Sessions auto-record when MIDI is flowing. Use the Session Browser to:

- Name and organize recordings
- Replay with original timing
- Export to `.mid` for use in any DAW
- Import existing `.mid` files for analysis

---

## Building Plugins

### AUv3 Audio Unit

```bash
xcodebuild -scheme MidiClawAU -configuration Release
# Installs to ~/Library/Audio/Plug-Ins/Components/
```

Load "MidiClaw" as a MIDI effect in Logic Pro, GarageBand, or any AU host.

### VST3

```bash
cd VST
cmake -B build -DVST3_SDK_ROOT=/path/to/vst3sdk
cmake --build build
cmake --install build
# Installs to ~/Library/Audio/Plug-Ins/VST3/
```

> **Note:** The VST3 build requires the [Steinberg VST3 SDK](https://github.com/steinbergmedia/vst3sdk) downloaded separately.

---

## Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| [GRDB.swift](https://github.com/groue/GRDB.swift) | 6.24.0+ | SQLite persistence for session recording |
| CoreMIDI | System | MIDI I/O (macOS native) |
| AVFoundation | System | Audio infrastructure |
| AudioToolbox | System | Audio/MIDI infrastructure |
| CoreAudioKit | System | AudioUnit UI |
| MLX / mlx-lm | Latest | On-device LLM inference (optional) |

---

## Roadmap

- [x] **Phase 1: Foundation** — MIDI I/O engine, tokenizer, session recorder
- [x] **Phase 2: Plugins** — AUv3 Audio Unit + VST3 MIDI effects
- [x] **Phase 3: Host App** — macOS app with Mindi accompanist, piano roll, step sequencer
- [ ] **Phase 4: Intelligence** — Adapter training pipeline, MLX runtime integration
- [ ] **Phase 5: Copilot & Autonomous modes** — Full AI-in-the-loop workflows
- [ ] **Phase 6: Polish** — Plugin presets, MCP server integration, onboarding refinements

See [`PRD.md`](PRD.md) for the complete product specification and engineering epics.

---

## Contributing

Contributions are welcome! This project is in early alpha, so there's plenty of room to shape its direction.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing-thing`)
3. Commit your changes
4. Push to the branch (`git push origin feature/amazing-thing`)
5. Open a Pull Request

### Running Tests

```bash
swift test
```

The test suite includes 47 tests covering MIDI parsing, tokenizer round-trips, session persistence, MIDI file I/O, and AudioUnit parameter handling.

---

## License

[MIT](LICENSE) — Copyright (c) 2026 John Clem

---

<p align="center">
  <sub>Built for musicians who want AI that plays <em>with</em> them, not <em>for</em> them.</sub>
</p>
