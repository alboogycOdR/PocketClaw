/// Local tool definitions provided to the LLM for function calling
library;

final localToolDefinitions = <Map<String, dynamic>>[
  {
    'name': 'create_note',
    'description':
        'Save a note to local storage with a title and optional folder',
    'parameters': {
      'title': {'type': 'string', 'required': true},
      'content': {'type': 'string', 'required': true},
      'folder': {'type': 'string', 'required': false, 'default': 'general'},
    },
  },
  {
    'name': 'search_notes',
    'description': 'Search local notes by keyword or semantic query',
    'parameters': {
      'query': {'type': 'string', 'required': true},
      'limit': {'type': 'integer', 'required': false, 'default': 5},
    },
  },
  {
    'name': 'create_reminder',
    'description': 'Set a reminder notification at a specific time',
    'parameters': {
      'title': {'type': 'string', 'required': true},
      'datetime': {'type': 'string', 'format': 'iso8601', 'required': true},
    },
  },
  {
    'name': 'query_calendar',
    'description': 'Query device calendar for events in a date range',
    'parameters': {
      'start_date': {
        'type': 'string',
        'format': 'iso8601',
        'required': true,
      },
      'end_date': {'type': 'string', 'format': 'iso8601', 'required': true},
    },
  },
  {
    'name': 'calculate',
    'description': 'Perform a mathematical calculation',
    'parameters': {
      'expression': {'type': 'string', 'required': true},
    },
  },
  {
    'name': 'draft_message',
    'description':
        'Draft a message for the user to review and send via share sheet',
    'parameters': {
      'recipient': {'type': 'string', 'required': false},
      'subject': {'type': 'string', 'required': false},
      'body': {'type': 'string', 'required': true},
      'channel': {
        'type': 'string',
        'enum': ['email', 'whatsapp', 'sms', 'generic'],
      },
    },
  },
  {
    'name': 'read_file',
    'description': 'Read a file from local storage',
    'parameters': {
      'path': {'type': 'string', 'required': true},
    },
  },
  {
    'name': 'capture_photo',
    'description': 'Open camera to capture a photo for OCR or processing',
    'parameters': {
      'purpose': {
        'type': 'string',
        'enum': ['ocr', 'save', 'process'],
      },
    },
  },
  {
    'name': 'text_to_speech',
    'description': 'Read text aloud using device TTS',
    'parameters': {
      'text': {'type': 'string', 'required': true},
      'language': {'type': 'string', 'required': false, 'default': 'en'},
    },
  },
  {
    'name': 'ocr',
    'description':
        'Extract text from an image using on-device vision (OCR). '
        'Use after capturing a photo to read receipts, documents, whiteboards.',
    'parameters': {
      'image_path': {'type': 'string', 'required': true},
      'prompt': {
        'type': 'string',
        'required': false,
        'default': 'Extract all text from this image.',
      },
    },
  },
];
