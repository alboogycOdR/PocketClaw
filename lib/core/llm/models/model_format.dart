/// Supported local model file formats
library;

enum ModelFormat {
  task,  // Google MediaPipe .task -- used by flutter_gemma
  gguf,  // llama.cpp GGUF -- used by fllama
  cloud, // Cloud API -- Anthropic, OpenAI, Google AI, etc.
}
