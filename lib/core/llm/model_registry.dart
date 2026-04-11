/// Full model registry — all supported local models
library;

import 'models/local_model_config.dart';
import 'models/model_format.dart';
import 'models/model_provider.dart';

const List<LocalModelConfig> kAvailableModels = [
  // -- GOOGLE (flutter_gemma / .task) -----------------------------------------

  LocalModelConfig(
    id: 'gemma-4-e2b',
    displayName: 'Gemma 4 E2B',
    description: 'Best quality \u2014 vision, audio, function calling',
    sizeGB: 1.5,
    ramMB: 6000,
    format: ModelFormat.task,
    provider: ModelProvider.google,
    hfRepo: 'google/gemma-4-e2b-it-litert-preview',
    downloadUrl:
        'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
    capabilities: ['vision', 'audio', 'function_calling'],
    requiresLicense: true,
    licenseUrl: 'https://huggingface.co/google/gemma-4-e2b-it-litert-preview',
    isBeta: true,
  ),

  LocalModelConfig(
    id: 'gemma-3-1b',
    displayName: 'Gemma 3 1B',
    description: 'Balanced speed and quality, Google',
    sizeGB: 0.6,
    ramMB: 4000,
    format: ModelFormat.task,
    provider: ModelProvider.google,
    hfRepo: 'google/gemma-3-1b-it-litert-preview',
    downloadUrl:
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
    requiresLicense: true,
    licenseUrl: 'https://huggingface.co/google/gemma-3-1b-it-litert-preview',
    capabilities: ['text'],
  ),

  LocalModelConfig(
    id: 'gemma-3-270m',
    displayName: 'Gemma 3 270M',
    description: 'Ultra-compact \u2014 fast and lightweight',
    sizeGB: 0.3,
    ramMB: 2000,
    format: ModelFormat.task,
    provider: ModelProvider.google,
    hfRepo: 'google/gemma-3-270m-it-litert-preview',
    downloadUrl:
        'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task',
    requiresLicense: true,
    licenseUrl: 'https://huggingface.co/google/gemma-3-270m-it-litert-preview',
    capabilities: ['text'],
  ),

  // -- META (fllama / .gguf) --------------------------------------------------

  LocalModelConfig(
    id: 'llama-3.2-3b',
    displayName: 'Llama 3.2 3B',
    description: 'Strong general tasks, Meta',
    sizeGB: 1.8,
    ramMB: 4000,
    format: ModelFormat.gguf,
    provider: ModelProvider.meta,
    hfRepo: 'bartowski/Llama-3.2-3B-Instruct-GGUF',
    hfFilename: 'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    capabilities: ['text', 'reasoning'],
    requiresLicense: true,
    licenseUrl: 'https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct',
  ),

  LocalModelConfig(
    id: 'llama-3.2-1b',
    displayName: 'Llama 3.2 1B',
    description: 'Fast and lightweight, Meta',
    sizeGB: 0.7,
    ramMB: 2000,
    format: ModelFormat.gguf,
    provider: ModelProvider.meta,
    hfRepo: 'bartowski/Llama-3.2-1B-Instruct-GGUF',
    hfFilename: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    capabilities: ['text'],
    requiresLicense: true,
    licenseUrl: 'https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct',
  ),

  // -- MICROSOFT (fllama / .gguf) ---------------------------------------------

  LocalModelConfig(
    id: 'phi-3.5-mini',
    displayName: 'Phi-3.5 Mini',
    description: 'Excellent reasoning and instruction following, Microsoft',
    sizeGB: 2.2,
    ramMB: 4000,
    format: ModelFormat.gguf,
    provider: ModelProvider.microsoft,
    hfRepo: 'microsoft/Phi-3.5-mini-instruct-gguf',
    hfFilename: 'Phi-3.5-mini-instruct-Q4_K_M.gguf',
    capabilities: ['text', 'reasoning', 'code'],
  ),

  LocalModelConfig(
    id: 'phi-3-mini',
    displayName: 'Phi-3 Mini 3.8B',
    description: 'Strong reasoning, compact size, Microsoft',
    sizeGB: 2.3,
    ramMB: 4000,
    format: ModelFormat.gguf,
    provider: ModelProvider.microsoft,
    hfRepo: 'microsoft/Phi-3-mini-4k-instruct-gguf',
    hfFilename: 'Phi-3-mini-4k-instruct-q4.gguf',
    capabilities: ['text', 'reasoning', 'code'],
  ),

  // -- ALIBABA (fllama / .gguf) -----------------------------------------------

  LocalModelConfig(
    id: 'qwen-2.5-1.5b',
    displayName: 'Qwen 2.5 1.5B',
    description: 'Multilingual, code-capable, Alibaba',
    sizeGB: 0.9,
    ramMB: 2000,
    format: ModelFormat.gguf,
    provider: ModelProvider.alibaba,
    hfRepo: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
    hfFilename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    capabilities: ['text', 'code', 'multilingual'],
  ),

  LocalModelConfig(
    id: 'qwen-2.5-0.5b',
    displayName: 'Qwen 2.5 0.5B',
    description: 'Smallest viable model \u2014 ultra-low RAM',
    sizeGB: 0.4,
    ramMB: 1000,
    format: ModelFormat.gguf,
    provider: ModelProvider.alibaba,
    hfRepo: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
    hfFilename: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    capabilities: ['text', 'multilingual'],
  ),

  // -- HUGGINGFACE (fllama / .gguf) -------------------------------------------

  LocalModelConfig(
    id: 'smollm2-1.7b',
    displayName: 'SmolLM2 1.7B',
    description: 'Surprisingly capable at its size, HuggingFace',
    sizeGB: 1.0,
    ramMB: 2000,
    format: ModelFormat.gguf,
    provider: ModelProvider.huggingFace,
    hfRepo: 'HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF',
    hfFilename: 'smollm2-1.7b-instruct-q4_k_m.gguf',
    capabilities: ['text', 'reasoning'],
  ),

  // -- CLOUD APIs (bring your own key) ----------------------------------------

  LocalModelConfig(
    id: 'claude-sonnet',
    displayName: 'Claude Sonnet 4',
    description: 'Anthropic\u2019s best balance of speed and intelligence',
    sizeGB: 0,
    ramMB: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.anthropic,
    cloudApiEndpoint: 'https://api.anthropic.com/v1/messages',
    cloudModelId: 'claude-sonnet-4-20250514',
    cloudApiKeyPrefix: 'sk-ant-',
    capabilities: ['text', 'reasoning', 'code', 'vision'],
  ),

  LocalModelConfig(
    id: 'claude-haiku',
    displayName: 'Claude Haiku 4.5',
    description: 'Anthropic\u2019s fastest model \u2014 great for quick tasks',
    sizeGB: 0,
    ramMB: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.anthropic,
    cloudApiEndpoint: 'https://api.anthropic.com/v1/messages',
    cloudModelId: 'claude-haiku-4-5-20251001',
    cloudApiKeyPrefix: 'sk-ant-',
    capabilities: ['text', 'reasoning', 'code'],
  ),

  LocalModelConfig(
    id: 'gpt-4o-mini',
    displayName: 'GPT-4o Mini',
    description: 'OpenAI\u2019s compact powerhouse \u2014 fast and affordable',
    sizeGB: 0,
    ramMB: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.openAI,
    cloudApiEndpoint: 'https://api.openai.com/v1/chat/completions',
    cloudModelId: 'gpt-4o-mini',
    cloudApiKeyPrefix: 'sk-',
    capabilities: ['text', 'reasoning', 'code', 'vision'],
  ),

  LocalModelConfig(
    id: 'gpt-4o',
    displayName: 'GPT-4o',
    description: 'OpenAI\u2019s flagship \u2014 maximum capability',
    sizeGB: 0,
    ramMB: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.openAI,
    cloudApiEndpoint: 'https://api.openai.com/v1/chat/completions',
    cloudModelId: 'gpt-4o',
    cloudApiKeyPrefix: 'sk-',
    capabilities: ['text', 'reasoning', 'code', 'vision'],
  ),

  LocalModelConfig(
    id: 'gemini-2-flash',
    displayName: 'Gemini 2.0 Flash',
    description: 'Google\u2019s fastest cloud model \u2014 free tier available',
    sizeGB: 0,
    ramMB: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.googleAI,
    cloudModelId: 'gemini-2.0-flash',
    capabilities: ['text', 'reasoning', 'code', 'vision'],
  ),

  LocalModelConfig(
    id: 'gemini-2.5-pro',
    displayName: 'Gemini 2.5 Pro',
    description: 'Google\u2019s most capable model \u2014 deep reasoning',
    sizeGB: 0,
    ramMB: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.googleAI,
    cloudModelId: 'gemini-2.5-pro-preview-06-05',
    capabilities: ['text', 'reasoning', 'code', 'vision'],
    isBeta: true,
  ),
];
