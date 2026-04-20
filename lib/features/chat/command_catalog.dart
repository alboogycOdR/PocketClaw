/// Authoritative OpenClaw slash-command catalog for PocketClaw.
///
/// Generated from `commands.list --json` on the live gateway (OpenClaw
/// v2026.4.15, 48/99 plugins). Rerun that RPC to refresh — the set is
/// plugin-dependent (anything with `source: 'skill' | 'plugin'` may come
/// and go with installs).
///
/// Scope inference: OpenClaw's per-command authorization uses per-channel
/// access-group authorizers, not operator.* scopes. The scope values here
/// are inferred from intent so the client can hide/gate commands the
/// phone's token clearly can't use. Treat them as best-effort.
library;

enum CommandCategory { session, agent, tools, model, memory, system, plugin, dev }

enum CommandSource { native, skill, plugin }

class CommandSpec {
  final String name;
  final String description;
  final bool takesArgs;
  final String? argsHint;
  final bool destructive;
  final String scope;
  final CommandCategory category;
  final bool channelGated;
  final CommandSource source;
  final String? plugin;
  final List<String> aliases;

  const CommandSpec({
    required this.name,
    required this.description,
    required this.takesArgs,
    this.argsHint,
    this.destructive = false,
    required this.scope,
    required this.category,
    this.channelGated = false,
    required this.source,
    this.plugin,
    this.aliases = const [],
  });

  /// Does `typed` prefix-match this command (or any alias)?
  bool matches(String typed) {
    if (typed.isEmpty) return false;
    final q = typed.toLowerCase();
    if (name.toLowerCase().startsWith(q)) return true;
    for (final a in aliases) {
      if (a.toLowerCase().startsWith(q)) return true;
    }
    return false;
  }
}

const List<CommandSpec> kCommandCatalog = [
  CommandSpec(
    name: '/help',
    description: 'Show available commands.',
    takesArgs: false,
    scope: 'operator.read',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/commands',
    description: 'List all slash commands.',
    takesArgs: false,
    scope: 'operator.read',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/tools',
    description: 'List available runtime tools.',
    takesArgs: true,
    argsHint: '[compact|verbose]',
    scope: 'operator.read',
    category: CommandCategory.tools,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/skill',
    description: 'Run a skill by name.',
    takesArgs: true,
    argsHint: '<name> [input]',
    scope: 'operator.write',
    category: CommandCategory.tools,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/status',
    description: 'Show current status.',
    takesArgs: false,
    scope: 'operator.read',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/tasks',
    description: 'List background tasks for this session.',
    takesArgs: false,
    scope: 'operator.read',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/allowlist',
    description: 'List/add/remove allowlist entries.',
    takesArgs: true,
    argsHint: '[list|add|remove] [entry]',
    scope: 'operator.admin',
    category: CommandCategory.system,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/approve',
    description: 'Approve or deny exec requests.',
    takesArgs: true,
    argsHint: '<id> [allow|deny]',
    scope: 'operator.admin',
    category: CommandCategory.tools,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/context',
    description: 'Explain how context is built and used.',
    takesArgs: true,
    scope: 'operator.read',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/btw',
    description: 'Ask a side question without changing future session context.',
    takesArgs: true,
    argsHint: '<question>',
    scope: 'operator.write',
    category: CommandCategory.agent,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/export-session',
    description: 'Export current session to HTML file with full system prompt.',
    takesArgs: true,
    argsHint: '[path]',
    scope: 'operator.read',
    category: CommandCategory.session,
    source: CommandSource.native,
    aliases: ['/export'],
  ),
  CommandSpec(
    name: '/tts',
    description: 'Control text-to-speech (TTS).',
    takesArgs: true,
    argsHint: '<on|off|status|provider|limit|summary|audio|help> [value]',
    scope: 'operator.write',
    category: CommandCategory.system,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/whoami',
    description: 'Show your sender id.',
    takesArgs: false,
    scope: 'operator.read',
    category: CommandCategory.session,
    source: CommandSource.native,
    aliases: ['/id'],
  ),
  CommandSpec(
    name: '/session',
    description: 'Manage session-level settings (for example /session idle).',
    takesArgs: true,
    argsHint: '<idle|max-age> <duration|off>',
    scope: 'operator.write',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/subagents',
    description: 'List, kill, log, spawn, or steer subagent runs for this session.',
    takesArgs: true,
    argsHint: '<list|kill|log|info|send|steer|spawn> [target] [value]',
    scope: 'operator.write',
    category: CommandCategory.agent,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/acp',
    description: 'Manage ACP sessions and runtime options.',
    takesArgs: true,
    argsHint:
        '<spawn|cancel|steer|close|sessions|status|set-mode|set|cwd|permissions|timeout|model|reset-options|doctor|install|help> [value]',
    scope: 'operator.write',
    category: CommandCategory.agent,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/focus',
    description: 'Bind this thread (Discord) or topic/conversation (Telegram) to a session target.',
    takesArgs: true,
    argsHint: '<target>',
    scope: 'operator.write',
    category: CommandCategory.session,
    channelGated: true,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/unfocus',
    description: 'Remove the current thread (Discord) or topic/conversation (Telegram) binding.',
    takesArgs: false,
    scope: 'operator.write',
    category: CommandCategory.session,
    channelGated: true,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/agents',
    description: 'List thread-bound agents for this session.',
    takesArgs: false,
    scope: 'operator.read',
    category: CommandCategory.agent,
    channelGated: true,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/kill',
    description: 'Kill a running subagent (or all).',
    takesArgs: true,
    argsHint: '<label|run-id|index|all>',
    destructive: true,
    scope: 'operator.admin',
    category: CommandCategory.agent,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/steer',
    description: 'Send guidance to a running subagent.',
    takesArgs: true,
    argsHint: '<target> <message>',
    scope: 'operator.write',
    category: CommandCategory.agent,
    source: CommandSource.native,
    aliases: ['/tell'],
  ),
  CommandSpec(
    name: '/usage',
    description: 'Usage footer or cost summary.',
    takesArgs: true,
    argsHint: '[off|tokens|full|cost]',
    scope: 'operator.read',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/stop',
    description: 'Stop the current run.',
    takesArgs: false,
    destructive: true,
    scope: 'operator.write',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/restart',
    description: 'Restart OpenClaw.',
    takesArgs: false,
    destructive: true,
    scope: 'operator.admin',
    category: CommandCategory.system,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/activation',
    description: 'Set group activation mode.',
    takesArgs: true,
    argsHint: '<mention|always>',
    scope: 'operator.write',
    category: CommandCategory.session,
    channelGated: true,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/send',
    description: 'Set send policy.',
    takesArgs: true,
    argsHint: '<on|off|inherit>',
    scope: 'operator.write',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/reset',
    description: 'Reset the current session.',
    takesArgs: true,
    destructive: true,
    scope: 'operator.write',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/new',
    description: 'Start a new session.',
    takesArgs: true,
    destructive: true,
    scope: 'operator.write',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/compact',
    description: 'Compact the session context.',
    takesArgs: true,
    argsHint: '[instructions]',
    destructive: true,
    scope: 'operator.write',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/think',
    description: 'Set thinking level.',
    takesArgs: true,
    argsHint: '<off|minimal|low|medium|high|xhigh>',
    scope: 'operator.write',
    category: CommandCategory.model,
    source: CommandSource.native,
    aliases: ['/thinking', '/t'],
  ),
  CommandSpec(
    name: '/verbose',
    description: 'Toggle verbose mode.',
    takesArgs: true,
    argsHint: '<on|off>',
    scope: 'operator.write',
    category: CommandCategory.session,
    source: CommandSource.native,
    aliases: ['/v'],
  ),
  CommandSpec(
    name: '/trace',
    description: 'Toggle plugin trace lines.',
    takesArgs: true,
    argsHint: '<on|off|raw>',
    scope: 'operator.write',
    category: CommandCategory.dev,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/fast',
    description: 'Toggle fast mode.',
    takesArgs: true,
    argsHint: '<status|on|off>',
    scope: 'operator.write',
    category: CommandCategory.model,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/reasoning',
    description: 'Toggle reasoning visibility.',
    takesArgs: true,
    argsHint: '<on|off|stream>',
    scope: 'operator.write',
    category: CommandCategory.model,
    source: CommandSource.native,
    aliases: ['/reason'],
  ),
  CommandSpec(
    name: '/elevated',
    description: 'Toggle elevated mode.',
    takesArgs: true,
    argsHint: '<on|off|ask|full>',
    destructive: true,
    scope: 'operator.admin',
    category: CommandCategory.system,
    source: CommandSource.native,
    aliases: ['/elev'],
  ),
  CommandSpec(
    name: '/exec',
    description: 'Set exec defaults for this session.',
    takesArgs: true,
    argsHint:
        '[host=<sandbox|gateway|node>] [security=<deny|allowlist|full>] [ask=<off|on-miss|always>] [node=<id>]',
    scope: 'operator.admin',
    category: CommandCategory.system,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/model',
    description: 'Show or set the model.',
    takesArgs: true,
    argsHint: '<provider/model|id>',
    scope: 'operator.write',
    category: CommandCategory.model,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/models',
    description: 'List model providers or provider models.',
    takesArgs: true,
    argsHint: '[provider]',
    scope: 'operator.read',
    category: CommandCategory.model,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/queue',
    description: 'Adjust queue settings.',
    takesArgs: true,
    argsHint: '[mode] [debounce:<dur>] [cap:<n>] [drop:<old|new|summarize>]',
    scope: 'operator.write',
    category: CommandCategory.session,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/bash',
    description: 'Run host shell commands (host-only).',
    takesArgs: true,
    argsHint: '<command>',
    destructive: true,
    scope: 'operator.admin',
    category: CommandCategory.system,
    source: CommandSource.native,
  ),
  CommandSpec(
    name: '/dock-telegram',
    description: 'Switch to telegram for replies.',
    takesArgs: false,
    scope: 'operator.write',
    category: CommandCategory.plugin,
    channelGated: true,
    source: CommandSource.plugin,
    plugin: 'telegram',
    aliases: ['/dock_telegram'],
  ),
  CommandSpec(
    name: '/coding_agent',
    description: 'Delegate coding tasks to Codex, Claude Code, or Pi agents via background process.',
    takesArgs: true,
    scope: 'operator.write',
    category: CommandCategory.agent,
    source: CommandSource.skill,
    plugin: 'coding_agent',
  ),
  CommandSpec(
    name: '/healthcheck',
    description: 'Host security hardening and risk-tolerance configuration for OpenClaw deployments.',
    takesArgs: true,
    scope: 'operator.admin',
    category: CommandCategory.system,
    source: CommandSource.skill,
    plugin: 'healthcheck',
  ),
  CommandSpec(
    name: '/node_connect',
    description: 'Diagnose OpenClaw node connection and pairing failures for Android, iOS, and macOS companion apps.',
    takesArgs: true,
    scope: 'operator.admin',
    category: CommandCategory.system,
    source: CommandSource.skill,
    plugin: 'node_connect',
  ),
  CommandSpec(
    name: '/skill_creator',
    description: 'Create, edit, improve, or audit AgentSkills.',
    takesArgs: true,
    scope: 'operator.write',
    category: CommandCategory.dev,
    source: CommandSource.skill,
    plugin: 'skill_creator',
  ),
  CommandSpec(
    name: '/taskflow',
    description: 'Span work across one or more detached tasks while behaving like one job with a single owner.',
    takesArgs: true,
    scope: 'operator.write',
    category: CommandCategory.agent,
    source: CommandSource.skill,
    plugin: 'taskflow',
  ),
  CommandSpec(
    name: '/taskflow_inbox_triage',
    description: 'Example TaskFlow authoring pattern for inbox triage.',
    takesArgs: true,
    scope: 'operator.write',
    category: CommandCategory.agent,
    source: CommandSource.skill,
    plugin: 'taskflow_inbox_triage',
  ),
  CommandSpec(
    name: '/tmux',
    description: 'Remote-control tmux sessions for interactive CLIs by sending keystrokes and scraping pane output.',
    takesArgs: true,
    scope: 'operator.write',
    category: CommandCategory.tools,
    source: CommandSource.skill,
    plugin: 'tmux',
  ),
  CommandSpec(
    name: '/weather',
    description: 'Get current weather and forecasts via wttr.in or Open-Meteo.',
    takesArgs: true,
    argsHint: '[location]',
    scope: 'operator.read',
    category: CommandCategory.tools,
    source: CommandSource.skill,
    plugin: 'weather',
  ),
  CommandSpec(
    name: '/dreaming',
    description: 'Enable or disable memory dreaming.',
    takesArgs: true,
    argsHint: '<on|off>',
    scope: 'operator.write',
    category: CommandCategory.memory,
    source: CommandSource.plugin,
    plugin: 'dreaming',
  ),
];

/// Commands visible in PocketClaw — filters out group-chat-only commands
/// that don't apply to a 1:1 mobile client.
List<CommandSpec> commandsForMobile() =>
    kCommandCatalog.where((c) => !c.channelGated).toList();

/// Autocomplete filter: returns mobile-appropriate commands whose name or
/// alias starts with the typed fragment (including the leading slash).
List<CommandSpec> autocompleteCommands(String typed) {
  if (!typed.startsWith('/')) return const [];
  return commandsForMobile().where((c) => c.matches(typed)).toList();
}

/// Category display order + labels for the command palette.
const Map<CommandCategory, String> kCategoryLabels = {
  CommandCategory.session: 'Session',
  CommandCategory.agent: 'Agents & subagents',
  CommandCategory.model: 'Model & reasoning',
  CommandCategory.tools: 'Tools & skills',
  CommandCategory.memory: 'Memory',
  CommandCategory.plugin: 'Plugin',
  CommandCategory.system: 'System (admin)',
  CommandCategory.dev: 'Developer',
};
