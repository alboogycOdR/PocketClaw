/// Cloud LLM registry. Local GGUF models are loaded from
/// `assets/model_allowlist.json` via `ModelAllowlistService` so that adding
/// a new local model doesn't require an app store release. Cloud models stay
/// in code because their endpoints and IDs are stable and the UI flow for
/// them (BYO API key, custom-id override) is fundamentally different.
library;

import 'models/local_model_config.dart';
import 'models/model_format.dart';
import 'models/model_provider.dart';

const List<LocalModelConfig> kCloudModels = [
  // -- Anthropic --------------------------------------------------------------

  LocalModelConfig(
    id: 'claude-sonnet',
    displayName: 'Claude Sonnet 4',
    description: 'Anthropic’s best balance of speed and intelligence',
    sizeBytes: 0,
    minRamBytes: 0,
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
    description: 'Anthropic’s fastest model — great for quick tasks',
    sizeBytes: 0,
    minRamBytes: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.anthropic,
    cloudApiEndpoint: 'https://api.anthropic.com/v1/messages',
    cloudModelId: 'claude-haiku-4-5-20251001',
    cloudApiKeyPrefix: 'sk-ant-',
    capabilities: ['text', 'reasoning', 'code'],
  ),

  // -- OpenAI -----------------------------------------------------------------

  LocalModelConfig(
    id: 'gpt-4o-mini',
    displayName: 'GPT-4o Mini',
    description: 'OpenAI’s compact powerhouse — fast and affordable',
    sizeBytes: 0,
    minRamBytes: 0,
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
    description: 'OpenAI’s flagship — maximum capability',
    sizeBytes: 0,
    minRamBytes: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.openAI,
    cloudApiEndpoint: 'https://api.openai.com/v1/chat/completions',
    cloudModelId: 'gpt-4o',
    cloudApiKeyPrefix: 'sk-',
    capabilities: ['text', 'reasoning', 'code', 'vision'],
  ),

  // -- Google AI (Gemini) -----------------------------------------------------

  LocalModelConfig(
    id: 'gemini-2-flash',
    displayName: 'Gemini 2.0 Flash',
    description: 'Google’s fastest cloud model — free tier available',
    sizeBytes: 0,
    minRamBytes: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.googleAI,
    cloudModelId: 'gemini-2.0-flash',
    capabilities: ['text', 'reasoning', 'code', 'vision'],
  ),

  LocalModelConfig(
    id: 'gemini-2.5-flash',
    displayName: 'Gemini 2.5 Flash',
    description: 'Google’s mid-tier — faster, cheaper than Pro',
    sizeBytes: 0,
    minRamBytes: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.googleAI,
    cloudModelId: 'gemini-2.5-flash',
    capabilities: ['text', 'reasoning', 'code', 'vision'],
  ),

  LocalModelConfig(
    id: 'gemini-2.5-pro',
    displayName: 'Gemini 2.5 Pro',
    description: 'Google’s most capable model — deep reasoning',
    sizeBytes: 0,
    minRamBytes: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.googleAI,
    cloudModelId: 'gemini-2.5-pro',
    capabilities: ['text', 'reasoning', 'code', 'vision'],
  ),

  // -- xAI (Grok) -------------------------------------------------------------

  LocalModelConfig(
    id: 'grok-4',
    displayName: 'Grok 4',
    description: 'xAI’s flagship — strong reasoning, real-time access',
    sizeBytes: 0,
    minRamBytes: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.xai,
    cloudApiEndpoint: 'https://api.x.ai/v1/chat/completions',
    cloudModelId: 'grok-4-latest',
    cloudApiKeyPrefix: 'xai-',
    capabilities: ['text', 'reasoning', 'code'],
  ),

  // -- Moonshot (Kimi) --------------------------------------------------------

  LocalModelConfig(
    id: 'kimi-k2',
    displayName: 'Kimi K2',
    description: 'Moonshot’s long-context flagship — strong on code and tools',
    sizeBytes: 0,
    minRamBytes: 0,
    format: ModelFormat.cloud,
    provider: ModelProvider.moonshot,
    cloudApiEndpoint: 'https://api.moonshot.ai/v1/chat/completions',
    cloudModelId: 'kimi-k2-turbo-preview',
    cloudApiKeyPrefix: 'sk-',
    capabilities: ['text', 'reasoning', 'code'],
  ),
];
