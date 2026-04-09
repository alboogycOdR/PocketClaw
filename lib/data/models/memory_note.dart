/// Memory note model
library;

class MemoryNote {
  final String id;
  final String title;
  final String content;
  final String folder;
  final List<String> tags;
  final DateTime created;
  final DateTime modified;
  final bool syncEnabled;
  final String source; // local, server

  const MemoryNote({
    required this.id,
    required this.title,
    required this.content,
    this.folder = 'general',
    this.tags = const [],
    required this.created,
    required this.modified,
    this.syncEnabled = true,
    this.source = 'local',
  });

  factory MemoryNote.fromJson(Map<String, dynamic> json) => MemoryNote(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        folder: json['folder'] as String? ?? 'general',
        tags: (json['tags'] as List?)?.cast<String>() ?? [],
        created: DateTime.parse(json['created'] as String),
        modified: DateTime.parse(json['modified'] as String),
        syncEnabled: json['syncEnabled'] as bool? ?? true,
        source: json['source'] as String? ?? 'local',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'folder': folder,
        'tags': tags,
        'created': created.toIso8601String(),
        'modified': modified.toIso8601String(),
        'syncEnabled': syncEnabled,
        'source': source,
      };

  MemoryNote copyWith({
    String? title,
    String? content,
    String? folder,
    List<String>? tags,
    DateTime? modified,
    bool? syncEnabled,
  }) =>
      MemoryNote(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        folder: folder ?? this.folder,
        tags: tags ?? this.tags,
        created: created,
        modified: modified ?? DateTime.now(),
        syncEnabled: syncEnabled ?? this.syncEnabled,
        source: source,
      );

  String toMarkdown() => '''---
id: "$id"
title: "$title"
folder: "$folder"
tags: [${tags.map((t) => '"$t"').join(', ')}]
created: "${created.toIso8601String()}"
modified: "${modified.toIso8601String()}"
sync: $syncEnabled
source: "$source"
---

$content
''';
}

class MemoryFile {
  final String name;
  final String path;
  final bool isDirectory;
  final DateTime? modified;

  const MemoryFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.modified,
  });

  factory MemoryFile.fromJson(Map<String, dynamic> json) => MemoryFile(
        name: json['name'] as String,
        path: json['path'] as String,
        isDirectory: json['isDirectory'] as bool? ?? false,
        modified: json['modified'] != null
            ? DateTime.parse(json['modified'] as String)
            : null,
      );
}
