/// Tool definitions the local model can call. Wire format is
/// OpenAI-compatible JSON-Schema so any GGUF tool-calling model can
/// understand them with the same prompt scaffolding.
library;

class ToolParam {
  final String type;
  final String description;
  final bool required;
  final List<String>? enumValues;
  const ToolParam({
    required this.type,
    required this.description,
    this.required = false,
    this.enumValues,
  });

  Map<String, dynamic> toSchema() => {
    'type': type,
    'description': description,
    if (enumValues != null) 'enum': enumValues,
  };
}

class ToolDefinition {
  final String id;
  final String name;
  final String displayName;
  final String description;
  final bool requiresNetwork;
  final Map<String, ToolParam> parameters;

  const ToolDefinition({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    this.requiresNetwork = false,
    required this.parameters,
  });

  Map<String, dynamic> toOpenAiSchema() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': {
          for (final e in parameters.entries) e.key: e.value.toSchema(),
        },
        'required': parameters.entries
            .where((e) => e.value.required)
            .map((e) => e.key)
            .toList(),
      },
    },
  };
}

const kAvailableTools = <ToolDefinition>[
  ToolDefinition(
    id: 'web_search',
    name: 'web_search',
    displayName: 'Web Search',
    description: 'Search the web for current information.',
    requiresNetwork: true,
    parameters: {
      'query': ToolParam(
        type: 'string',
        description: 'Search query.',
        required: true,
      ),
    },
  ),
  ToolDefinition(
    id: 'calculator',
    name: 'calculator',
    displayName: 'Calculator',
    description: 'Evaluate a mathematical expression.',
    parameters: {
      'expression': ToolParam(
        type: 'string',
        description: 'Math expression to evaluate, e.g. "(2 + 3) * 4".',
        required: true,
      ),
    },
  ),
  ToolDefinition(
    id: 'get_current_datetime',
    name: 'get_current_datetime',
    displayName: 'Date & Time',
    description: 'Get the current date and time.',
    parameters: {
      'timezone': ToolParam(
        type: 'string',
        description:
            'Optional IANA timezone (e.g. Africa/Johannesburg). Defaults to device local.',
      ),
    },
  ),
  ToolDefinition(
    id: 'get_device_info',
    name: 'get_device_info',
    displayName: 'Device Info',
    description: 'Get device hardware information.',
    parameters: {
      'info_type': ToolParam(
        type: 'string',
        description: 'Type of info: battery, storage, memory, all.',
        enumValues: ['battery', 'storage', 'memory', 'all'],
      ),
    },
  ),
  ToolDefinition(
    id: 'dns_lookup',
    name: 'dns_lookup',
    displayName: 'DNS Lookup',
    description:
        'Resolve DNS records for a domain: A, AAAA, MX, NS, TXT, and CNAME.',
    requiresNetwork: true,
    parameters: {
      'domain': ToolParam(
        type: 'string',
        description: 'Domain to resolve, e.g. example.com.',
        required: true,
      ),
    },
  ),
  ToolDefinition(
    id: 'whois_lookup',
    name: 'whois_lookup',
    displayName: 'WHOIS Lookup',
    description:
        'Get registration metadata for a domain or IP address, including registrar and expiry.',
    requiresNetwork: true,
    parameters: {
      'target': ToolParam(
        type: 'string',
        description: 'Domain or IP address to inspect.',
        required: true,
      ),
    },
  ),
  ToolDefinition(
    id: 'ip_intelligence',
    name: 'ip_intelligence',
    displayName: 'IP Intelligence',
    description:
        'Get geolocation, ASN, ISP, and threat information for an IP address.',
    requiresNetwork: true,
    parameters: {
      'ip': ToolParam(
        type: 'string',
        description: 'IP address to investigate.',
        required: true,
      ),
    },
  ),
  ToolDefinition(
    id: 'ssl_inspect',
    name: 'ssl_inspect',
    displayName: 'SSL Inspector',
    description:
        'Inspect a domain SSL/TLS certificate chain, issuer, expiry, and grade.',
    requiresNetwork: true,
    parameters: {
      'domain': ToolParam(
        type: 'string',
        description: 'Domain to inspect.',
        required: true,
      ),
    },
  ),
  ToolDefinition(
    id: 'cve_lookup',
    name: 'cve_lookup',
    displayName: 'CVE Lookup',
    description:
        'Search vulnerability records by CVE ID, software name, or keyword.',
    requiresNetwork: true,
    parameters: {
      'query': ToolParam(
        type: 'string',
        description: 'CVE ID or software keyword.',
        required: true,
      ),
    },
  ),
  ToolDefinition(
    id: 'get_earthquakes',
    name: 'get_earthquakes',
    displayName: 'Earthquake Monitor',
    description: 'Get recent significant earthquake activity.',
    requiresNetwork: true,
    parameters: {},
  ),
  ToolDefinition(
    id: 'get_active_fires',
    name: 'get_active_fires',
    displayName: 'Active Fire Monitor',
    description: 'Get live wildfire and hotspot activity.',
    requiresNetwork: true,
    parameters: {
      'region': ToolParam(
        type: 'string',
        description: 'Optional region filter, e.g. South Africa or California.',
      ),
    },
  ),
  ToolDefinition(
    id: 'intelligence_briefing',
    name: 'intelligence_briefing',
    displayName: 'Intelligence Briefing',
    description:
        'Get a combined situational briefing across earthquakes, conflict zones, fires, and news.',
    requiresNetwork: true,
    parameters: {
      'focus': ToolParam(
        type: 'string',
        description: 'Optional focus: seismic, conflict, fire, or all.',
      ),
    },
  ),
];
