/// Factory for creating the correct LLM engine based on model format
library;

import '../models/local_model_config.dart';
import '../models/model_format.dart';
import 'abstract_llm_engine.dart';
import 'cloud_llm_engine.dart';
import 'gemma_engine.dart';
import 'llama_cpp_engine.dart';

class LLMEngineFactory {
  LLMEngineFactory._();

  static AbstractLLMEngine forModel(LocalModelConfig model) {
    return switch (model.format) {
      ModelFormat.task  => GemmaEngine(config: model),
      ModelFormat.gguf  => LlamaCppEngine(config: model),
      ModelFormat.cloud => CloudLLMEngine(config: model),
    };
  }
}
