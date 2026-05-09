/// Supported local model file formats. Cloud was dropped 2026-05-09 —
/// PocketClaw is local + agentic only.
library;

enum ModelFormat {
  task, // Google MediaPipe .task — used by flutter_gemma
  gguf, // llama.cpp GGUF — used by fllama
}
