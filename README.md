# MidiClaw
## Autonomous MIDI Agent with On-Device Intelligence
### Product Specification & Engineering PRD
### v0.1.0 — March 2026
#### Author: Johnny Clemmer | Status: DRAFT

1. Executive Summary
MidiClaw is a native macOS application that acts as an autonomous MIDI agent. It sits between any MIDI source and destination, observing, reasoning about, and generating MIDI data in real time using on-device large language models. The core innovation is a lightweight transformer adapter layer that bidirectionally maps between MIDI protocol data and the embedding space of a host LLM, enabling the model to “understand” musical and control data without requiring a music-specific foundation model.
The agent operates in three modes: Monitor (observe and annotate), Copilot (suggest and transform with user approval), and Autonomous (closed-loop generation and response). The target user is a technical musician, sound designer, or creative coder who wants AI-augmented MIDI workflows without cloud latency or data egress.
SCOPE: This PRD covers the macOS vertical slice. iOS and cross-platform targets are explicitly deferred to post-v1.0.

2. Problem Statement
Current AI music tools fall into two camps: cloud-based generation services (high latency, no real-time interaction, privacy concerns) and rule-based MIDI utilities (deterministic, no semantic understanding). Neither enables a tight, real-time feedback loop where an AI agent can observe a performer’s MIDI stream, reason about musical intent, and respond with contextually appropriate MIDI output — all on-device, all at instrument-grade latency.
MidiClaw bridges this gap by treating MIDI as a first-class token type that an LLM can natively reason over, using a custom adapter rather than brute-force text serialization of MIDI bytes.

3. Core Architecture
3.1 System Overview
MidiClaw is structured as four composable layers, each of which is independently testable and replaceable:



|Layer        |Responsibility                                       |Implementation                                                                                           |
|-------------|-----------------------------------------------------|---------------------------------------------------------------------------------------------------------|
|**MIDI I/O** |Send/receive MIDI from any virtual or hardware port  |CoreMIDI via Swift, virtual port creation, MIDI 2.0 aware                                                |
|**Tokenizer**|Convert raw MIDI bytes ↔ structured tokens           |Custom MidiToken vocabulary: note events, CC, timing deltas, sysex. ~512 base tokens + learned extensions|
|**Adapter**  |Project MIDI tokens into LLM embedding space and back|Lightweight transformer encoder/decoder (~2–5M params). Trained offline, runs via CoreML or MLX          |
|**Agent**    |Observe → Reason → Act loop with mode selection      |Swift agent runtime, tool-use pattern, configurable system prompt per mode                               |

3.2 The Adapter: MIDI ↔ Embedding Bridge
This is the novel technical contribution. Rather than serializing MIDI as text (“Note On channel 1 note 60 velocity 100”) and burning context window on syntax, the adapter is a small, purpose-built transformer that:
	∙	Encodes a window of MidiTokens into a fixed-size embedding matrix compatible with the host LLM’s hidden dimension.
	∙	Decodes LLM output embeddings back into a sequence of MidiTokens for MIDI output.
	∙	Preserves timing by encoding inter-onset intervals as explicit delta tokens, not relying on text-level sequencing.
The adapter is frozen at inference time. It is trained offline against a paired dataset of (MIDI sequences, text descriptions) using a contrastive objective that aligns MIDI token embeddings with the host LLM’s text embeddings for semantically equivalent content. Think of it as a MIDI-native CLIP adapter.
KEY: The adapter is NOT a music generation model. It is a projection layer that lets a general-purpose LLM reason about MIDI the same way it reasons about text.
3.3 MidiToken Vocabulary
The tokenizer defines a fixed vocabulary designed for dense, unambiguous representation of MIDI protocol data:



|Token Class          |Range  |Notes                                                                  |
|---------------------|-------|-----------------------------------------------------------------------|
|**NOTE_ON_[0-127]**  |0–127  |One token per MIDI note. Velocity encoded as a separate modifier token.|
|**NOTE_OFF_[0-127]** |128–255|Explicit note-off avoids ambiguity with running status.                |
|**VEL_[bucket]**     |256–287|32 velocity buckets (4-unit resolution). Follows a NOTE_ON.            |
|**DELTA_[bucket]**   |288–351|64 time-delta buckets, log-scaled from 1ms to 4s.                      |
|**CC_[num]_[bucket]**|352–479|Control change. Covers CC 0–31 with 4 value buckets each.              |
|**SPECIAL**          |480–511|PAD, BOS, EOS, BAR, PHRASE, CHANNEL_[0-15].                            |

This gives a base vocabulary of ~512 tokens. The tokenizer is deterministic and stateless: any raw MIDI byte stream can be round-tripped through encode/decode with zero loss. The vocabulary is intentionally small to keep the adapter lightweight.

4. Agent Modes
MidiClaw operates in one of three runtime modes, selectable at launch or switchable at runtime via system tray / menu bar:



|Mode          |Behavior                                                                               |Use Case                                                                               |
|--------------|---------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
|**Monitor**   |Passthrough. Agent observes MIDI, builds internal representation, annotates. No output.|Practice analysis, session logging, MIDI stream debugging.                             |
|**Copilot**   |Agent proposes MIDI transformations or responses. User approves/rejects before output. |Arrangement assistance, harmonization suggestions, CC automation.                      |
|**Autonomous**|Closed-loop. Agent reads input, reasons, writes MIDI output with no gate.              |Live performance accompaniment, generative installations, MIDI-responsive environments.|

5. Technical Constraints & Decisions
5.1 On-Device LLM Strategy
MidiClaw targets on-device inference exclusively. No cloud fallback. This is a product value, not just a technical constraint — musicians will not tolerate round-trip latency to a server during performance, and MIDI data from a creative session is intimate intellectual property.
Supported inference backends, in priority order:
	∙	MLX (Apple Silicon): Primary target. MLX provides the best throughput/watt on Apple Silicon and supports custom model architectures natively. The adapter layer can be loaded as a separate MLX module.
	∙	CoreML: Fallback for pre-converted models. Useful if distributing via App Store where MLX is less straightforward.
	∙	llama.cpp (via Swift bindings): Hedge for running quantized open-weight models (Llama 3, Mistral, Phi) if MLX model availability is limited.
The host LLM should be in the 1B–7B parameter range. Anything larger will not sustain real-time inference on current Apple Silicon. The adapter itself targets <5M parameters.
5.2 Latency Budget
For Autonomous mode to be musically useful, the total pipeline latency from MIDI input to MIDI output must stay under 50ms for simple responses (e.g., harmonize a note) and under 200ms for complex responses (e.g., generate a 4-bar phrase). This drives the decision to keep the adapter small and use speculative decoding where possible.
5.3 Platform Scope
macOS only for v1. The entire stack (CoreMIDI, MLX, menu bar app pattern) is macOS-native. iOS is architecturally feasible (CoreMIDI exists on iOS, CoreML works, MLX is Apple Silicon) but the UX paradigm is different enough to warrant a separate product pass. Do not design for iOS portability in v1 — design for macOS excellence.

6. Engineering Epics
The following epics are ordered by dependency. Each epic is shippable independently and produces a testable artifact. Phase boundaries represent natural demo/review checkpoints.
NOTE: Story-level breakdown is deferred to sprint planning. Epics define scope boundaries and acceptance criteria only.

PHASE 1: FOUNDATION
Goal: A working macOS app that can see, tokenize, and replay MIDI. No AI yet — just the I/O and data layer done right.

EPIC 1 — MIDI I/O Engine



|                |                                                                                                                                                                                                                                                                                                              |
|----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Objective**   |Establish reliable, low-latency CoreMIDI communication with virtual and hardware ports.                                                                                                                                                                                                                       |
|**Key Stories** |Virtual MIDI port creation (source + destination) • Hardware device enumeration and hot-plug handling • Raw MIDI byte stream capture with nanosecond timestamps • MIDI output with configurable channel routing • MIDI 2.0 UMP awareness (parse, don’t crash; full support deferred) • Loopback self-test mode|
|**Tech Notes**  |Swift + CoreMIDI. No third-party MIDI libraries. Build the abstraction layer you’ll own forever. Use MIDIPacketList for MIDI 1.0 and MIDIEventList for 2.0. Timestamp everything with mach_absolute_time for sub-ms accuracy.                                                                                 |
|**Dependencies**|None (greenfield).                                                                                                                                                                                                                                                                                            |
|**Effort**      |2–3 weeks. Low uncertainty — CoreMIDI is well-documented and you’ve shipped CoreMIDI code before.                                                                                                                                                                                                             |

EPIC 2 — MidiToken Vocabulary & Tokenizer



|                |                                                                                                                                                                                                                                                                                                                                                                                             |
|----------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Objective**   |Implement the bidirectional MidiToken codec: raw MIDI bytes ↔ MidiToken sequences.                                                                                                                                                                                                                                                                                                           |
|**Key Stories** |Define MidiToken enum with all token classes from Section 3.3 • Encoder: MIDI byte stream → [MidiToken] with timing preservation • Decoder: [MidiToken] → MIDI byte stream with timing reconstruction • Round-trip fidelity tests (encode → decode = identity) • Vocabulary serialization format (for adapter training pipeline) • Token stream visualization (debug UI: scrolling token log)|
|**Tech Notes**  |Pure Swift, zero dependencies. This is a data structure and codec — keep it blazing fast and 100% deterministic. The vocabulary is fixed at compile time for v1 (no dynamic extension). Write exhaustive property-based tests: any valid MIDI input must round-trip cleanly.                                                                                                                 |
|**Dependencies**|Epic 1 (needs MIDI byte streams to encode).                                                                                                                                                                                                                                                                                                                                                  |
|**Effort**      |2 weeks. The vocabulary design is already specified; this is implementation and testing.                                                                                                                                                                                                                                                                                                     |

EPIC 3 — Session Recorder & Replay



|                |                                                                                                                                                                                                                                                                                                                                                                   |
|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Objective**   |Record tokenized MIDI sessions to disk and replay them with timing fidelity.                                                                                                                                                                                                                                                                                       |
|**Key Stories** |Session recording (token stream + timestamps to SQLite or flat file) • Session replay with original timing • Session browse/search UI (list, filter by date, preview) • Export to Standard MIDI File (.mid) • Import from .mid to token stream                                                                                                                     |
|**Tech Notes**  |Sessions are the training data pipeline for the adapter. Design the storage format now with that in mind — each session should be a self-contained, labeled training example. SQLite with a simple schema (session_id, timestamp, token_id, raw_bytes) is fine. .mid import/export uses a lightweight Swift MIDI file parser — don’t pull in AudioToolbox for this.|
|**Dependencies**|Epics 1 and 2.                                                                                                                                                                                                                                                                                                                                                     |
|**Effort**      |1–2 weeks. Straightforward persistence layer.                                                                                                                                                                                                                                                                                                                      |

PHASE 2: INTELLIGENCE
Goal: Train the adapter, integrate an on-device LLM, and ship Monitor mode.

EPIC 4 — Adapter Training Pipeline (Offline)



|                |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
|----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Objective**   |Build the toolchain to train the MIDI ↔ embedding adapter outside the app.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|**Key Stories** |Training data preparation: pair (MIDI token sequences, text descriptions) from public datasets (Lakh MIDI, MusicNet, GiantMIDI-Piano) • Adapter architecture implementation in PyTorch: small transformer encoder + projection head, small transformer decoder + token head • Contrastive training loop (CLIP-style): align MIDI embeddings with host LLM text embeddings • Evaluation metrics: embedding cosine similarity, downstream classification accuracy, round-trip reconstruction loss • Export to MLX / CoreML format                                                                      |
|**Tech Notes**  |This is the R&D epic. The adapter architecture is: (a) a 4-layer transformer encoder that takes MidiToken IDs → embeddings matching the host LLM’s hidden_dim, and (b) a 4-layer transformer decoder that takes LLM output embeddings → MidiToken logits. Train in PyTorch on GPU, export to MLX via mlx-lm toolchain. Start with a frozen Phi-3-mini (3.8B) as the host LLM for embedding alignment. The paired dataset is the hardest part — start with GiantMIDI-Piano (metadata has piece descriptions) and augment with GPT-generated captions for Lakh MIDI subsets. Budget for iteration here.|
|**Dependencies**|Epic 2 (tokenizer must be frozen before training).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|**Effort**      |4–6 weeks. High uncertainty. This is research. Plan for 2–3 architecture iterations.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |

EPIC 5 — On-Device LLM Runtime



|                |                                                                                                                                                                                                                                                                                                                                                                                                 |
|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Objective**   |Integrate an on-device LLM with the trained adapter for inference.                                                                                                                                                                                                                                                                                                                               |
|**Key Stories** |MLX model loading and inference pipeline • Adapter module loading (separate from host LLM weights) • Inference API: (input: [MidiToken]) → (output: LLM response, optionally including MidiToken sequences) • Latency benchmarking harness (measure per-token and end-to-end) • Memory profiling (must fit in 8GB unified memory with headroom) • Fallback to llama.cpp if MLX target unavailable|
|**Tech Notes**  |Use mlx-swift for MLX integration. The inference pipeline is: tokenize MIDI → adapter.encode() → interleave with text prompt tokens → LLM forward pass → extract MIDI-tagged output tokens → adapter.decode() → MidiTokens. Start with Phi-3-mini quantized to 4-bit. Profile on M1 (8GB) as the floor target.                                                                                   |
|**Dependencies**|Epic 4 (trained adapter weights).                                                                                                                                                                                                                                                                                                                                                                |
|**Effort**      |3–4 weeks. Medium uncertainty — MLX Swift bindings are maturing but may have gaps.                                                                                                                                                                                                                                                                                                               |

EPIC 6 — Monitor Mode



|                |                                                                                                                                                                                                                                                                                                                                                                   |
|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Objective**   |Ship the first AI-powered mode: passive observation and annotation of live MIDI.                                                                                                                                                                                                                                                                                   |
|**Key Stories** |Real-time MIDI stream → tokenize → adapter.encode() → LLM analysis • Annotations: key detection, chord labeling, phrase boundary detection, tempo estimation • Annotation overlay UI (floating panel or sidebar alongside token stream) • Session annotations persisted with recordings (Epic 3 storage) • Configurable analysis depth (fast/shallow vs. slow/deep)|
|**Tech Notes**  |Monitor mode is inference-only, no MIDI output. This makes it safe to ship early — it can’t break anyone’s signal chain. Use a sliding window of the last N tokens (start with N=256) as context for the LLM. Annotations are generated asynchronously — they lag behind real-time and that’s fine for v1.                                                         |
|**Dependencies**|Epics 3, 5.                                                                                                                                                                                                                                                                                                                                                        |
|**Effort**      |2–3 weeks. Low uncertainty once the runtime is stable.                                                                                                                                                                                                                                                                                                             |

PHASE 3: AGENCY
Goal: Close the loop. The agent writes MIDI.

EPIC 7 — Copilot Mode



|                |                                                                                                                                                                                                                                                                                                                                                                                                        |
|----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Objective**   |Enable the agent to propose MIDI transformations that the user approves before output.                                                                                                                                                                                                                                                                                                                  |
|**Key Stories** |Proposal generation: agent observes input, generates candidate MIDI output as token sequence • Proposal preview UI: show proposed notes on a piano roll or staff, audition via built-in synth • Accept/reject/edit flow • Transformation presets: harmonize, arpeggiate, transpose, rhythmic variation, CC automation • User feedback loop: accepted/rejected proposals logged for potential fine-tuning|
|**Tech Notes**  |The approval gate is the entire UX. Design it to be fast — a performer can’t wait for a modal dialog. Think: inline preview with a single keypress to accept. The built-in synth for audition can be a simple FluidSynth or AVAudioEngine sampler — just enough to hear the proposal without needing external gear.                                                                                     |
|**Dependencies**|Epic 6 (Monitor mode validates the inference pipeline).                                                                                                                                                                                                                                                                                                                                                 |
|**Effort**      |3–4 weeks. Medium uncertainty — mostly UX design risk, not technical.                                                                                                                                                                                                                                                                                                                                   |

EPIC 8 — Autonomous Mode



|                |                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Objective**   |Full closed-loop: agent reads MIDI input, reasons, writes MIDI output with no human gate.                                                                                                                                                                                                                                                                                                                                                              |
|**Key Stories** |Autonomous agent loop: observe → reason → generate → output, continuous • Safety rails: output velocity ceiling, note rate limiter, panic button (all-notes-off) • Context management: sliding window with summarization for long sessions • Latency optimization: speculative decoding, KV cache management, batch inference for multi-voice output • Mode-specific system prompts: accompanist, echo/delay, generative ambient, MIDI effect processor|
|**Tech Notes**  |This is where latency matters most. The 50ms budget for simple responses means the adapter + LLM forward pass must be heavily optimized. Start with the simplest case (single-note harmonization) and expand. The panic button is non-negotiable — bind it to a MIDI CC (suggest CC 120 / All Sound Off) and a keyboard shortcut.                                                                                                                      |
|**Dependencies**|Epic 7 (Copilot validates generation quality before removing the gate).                                                                                                                                                                                                                                                                                                                                                                                |
|**Effort**      |4–6 weeks. High uncertainty. Real-time generation at musical tempo is the hardest problem in this entire project.                                                                                                                                                                                                                                                                                                                                      |

PHASE 4: ECOSYSTEM
Goal: Make MidiClaw extensible and shareable.

EPIC 9 — Plugin & Preset System



|                |                                                                                                                                                                                                                                                                                                                             |
|----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Objective**   |Allow users to create, share, and load agent behaviors as portable presets.                                                                                                                                                                                                                                                  |
|**Key Stories** |Preset format: system prompt + adapter fine-tune weights (optional) + parameter overrides, packaged as a .midiclaw bundle • Preset browser UI • Community sharing (local export/import for v1; cloud marketplace deferred) • Preset creation wizard: record a session, describe desired behavior, auto-generate system prompt|
|**Tech Notes**  |The .midiclaw bundle is a ZIP containing a manifest.json, a system_prompt.txt, and optionally a LoRA delta for the adapter. Keep the format simple and documented — this is the extension point for the community.                                                                                                           |
|**Dependencies**|Epic 8.                                                                                                                                                                                                                                                                                                                      |
|**Effort**      |2–3 weeks.                                                                                                                                                                                                                                                                                                                   |

EPIC 10 — MCP Server Integration



|                |                                                                                                                                                                                                                                                      |
|----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Objective**   |Expose MidiClaw’s capabilities as an MCP server so external AI agents can send/receive/query MIDI through MidiClaw.                                                                                                                                   |
|**Key Stories** |MCP tool definitions: send_midi, receive_midi, get_session, analyze_stream, set_mode • MCP resource definitions: active ports, current session, agent state • Stdio and SSE transport support • Integration tests with Claude Desktop and Claude Code |
|**Tech Notes**  |This is right in your wheelhouse given Polytician and JCAppleScript. MidiClaw as an MCP server means any LLM client can become MIDI-aware by connecting to it. Use the MCP Swift SDK if it exists by then, otherwise a thin JSON-RPC layer over stdio.|
|**Dependencies**|Epics 1–8 (full agent must be functional).                                                                                                                                                                                                            |
|**Effort**      |2 weeks. Low uncertainty for you specifically.                                                                                                                                                                                                        |

7. Timeline Summary



|Phase    |Epics                                               |Calendar Estimate            |
|---------|----------------------------------------------------|-----------------------------|
|Phase 1  |1 (MIDI I/O) + 2 (Tokenizer) + 3 (Sessions)         |5–7 weeks                    |
|Phase 2  |4 (Adapter Training) + 5 (LLM Runtime) + 6 (Monitor)|9–13 weeks                   |
|Phase 3  |7 (Copilot) + 8 (Autonomous)                        |7–10 weeks                   |
|Phase 4  |9 (Presets) + 10 (MCP)                              |4–5 weeks                    |
|**TOTAL**|                                                    |**25–35 weeks (~6–8 months)**|

These estimates assume part-time effort alongside other commitments. The adapter training pipeline (Epic 4) is the critical path and the highest-variance item. Everything else is engineering execution with known patterns.

8. Key Risks



|Risk                                             |Mitigation                                                                                                                                                                                                |Impact if Hit                                           |
|-------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------|
|**Adapter doesn’t converge to useful embeddings**|Start with smallest viable adapter (2 layers). Use GiantMIDI-Piano (clean labels) before noisy datasets. Have a fallback: text-serialize MIDI tokens and skip the adapter entirely (worse but functional).|HIGH. Degrades to brute-force text tokenization of MIDI.|
|**Latency exceeds musical usefulness**           |Profile early (Epic 5). Use smallest viable LLM. Implement speculative decoding. Degrade gracefully: Copilot mode is tolerant of higher latency than Autonomous.                                          |MEDIUM. Autonomous mode may be limited to slow tempos.  |
|**MLX Swift ecosystem gaps**                     |Maintain llama.cpp fallback. Contribute upstream fixes. Worst case: run MLX inference in a Python subprocess and bridge via IPC.                                                                          |LOW. Multiple fallback paths exist.                     |
|**Scope creep into music generation**            |MidiClaw is a MIDI agent, not a music generator. It reasons about MIDI and produces MIDI responses. It does not generate songs, arrangements, or compositions from scratch. Hold this line.               |HIGH. Kills focus and ships nothing.                    |

9. Explicit Non-Goals (v1)
	∙	Audio processing of any kind. MidiClaw is MIDI-only.
	∙	Cloud inference or hybrid cloud/local routing.
	∙	iOS, Windows, or Linux targets.
	∙	Training the adapter inside the app (training is offline-only).
	∙	Music generation from text prompts (“write me a jazz ballad”).
	∙	DAW plugin format (AU/VST). MidiClaw is a standalone MIDI router, not a plugin.
	∙	Real-time audio synthesis. Output is MIDI data only; the user routes it to their own synths.

10. Success Criteria
MidiClaw v1.0 is successful if:
	∙	A musician can plug in a MIDI controller, launch MidiClaw, and see intelligent real-time annotations of their playing within 30 seconds of launch.
	∙	Copilot mode can harmonize a monophonic melody with contextually appropriate chords at least 70% of the time (subjective evaluation by 3+ musicians).
	∙	Autonomous mode can maintain a musically coherent call-and-response interaction for at least 60 seconds at 120 BPM without degeneration.
	∙	All inference runs on-device with zero network calls.
	∙	End-to-end latency in Autonomous mode is under 100ms on M1 Pro for single-note responses.
