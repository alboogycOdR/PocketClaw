/// Manages the active conversation session — context window and message flow.
/// Each session is scoped to a chat mode (local / cloud / openclaw) and its
/// history never crosses into other modes.
library;

import 'package:uuid/uuid.dart';

import '../../data/database/daos/message_dao.dart';
import '../../data/models/chat_message.dart';
import 'session_history.dart';

class SessionManager {
  final MessageDao _messageDao;
  final SessionHistory _history;
  final _uuid = const Uuid();

  String _currentSessionKey;
  String _currentMode;
  final List<ChatMessage> _buffer = [];

  /// Maximum messages to keep in the in-memory buffer before flushing.
  static const int _bufferFlushThreshold = 100;

  SessionManager({
    MessageDao? messageDao,
    SessionHistory? history,
    String? sessionKey,
    String mode = 'openclaw',
  })  : _messageDao = messageDao ?? MessageDao(),
        _history = history ?? SessionHistory(),
        _currentSessionKey =
            sessionKey ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
        _currentMode = mode;

  /// The key that identifies the active session.
  String get currentSessionKey => _currentSessionKey;

  /// The mode this session belongs to.
  String get currentMode => _currentMode;

  /// Set the active mode. Should be called when the user switches chat mode.
  void setMode(String mode) {
    _currentMode = mode;
  }

  /// Start a fresh session for the given mode (or current mode if null).
  Future<void> startNewSession({String? mode}) async {
    // Persist current buffer before switching
    if (_buffer.isNotEmpty) {
      await _history.saveSession(_currentSessionKey, _buffer,
          mode: _currentMode);
    }

    if (mode != null) _currentMode = mode;
    _currentSessionKey =
        'session_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
    _buffer.clear();
  }

  /// Append a message to the current session.
  Future<void> addMessage(ChatMessage message) async {
    _buffer.add(message);

    // Persist to database immediately so nothing is lost
    await _messageDao.insert({
      'id': message.id,
      'session_key': _currentSessionKey,
      'role': message.role.name,
      'content': message.content,
      'source': message.source?.name,
      'timestamp': message.timestamp.toIso8601String(),
      'image_url': message.imageUrl,
      'mode': _currentMode,
    });

    // Trim the in-memory buffer if it gets too large
    if (_buffer.length > _bufferFlushThreshold) {
      _buffer.removeRange(0, _buffer.length - _bufferFlushThreshold);
    }
  }

  /// Return the most recent [limit] messages for prompt context.
  Future<List<ChatMessage>> recentHistory([int limit = 20]) async {
    // If the buffer has enough, use it directly
    if (_buffer.length >= limit) {
      return _buffer.sublist(_buffer.length - limit);
    }

    // Otherwise read from the database
    final rows = await _messageDao.getRecent(_currentSessionKey, limit: limit);
    return rows.map(_rowToMessage).toList();
  }

  /// Clear all messages in the current session from both buffer and storage.
  Future<void> clearSession() async {
    _buffer.clear();
    await _messageDao.deleteBySessionKey(_currentSessionKey);
  }

  /// Restore a previous session by key.
  Future<void> loadSession(String key) async {
    // Persist current before switching
    if (_buffer.isNotEmpty) {
      await _history.saveSession(_currentSessionKey, _buffer,
          mode: _currentMode);
    }

    _currentSessionKey = key;
    final messages = await _history.loadSession(key);
    _buffer
      ..clear()
      ..addAll(messages);
  }

  /// List saved sessions. If [mode] is provided, only that mode's sessions
  /// are returned — critical for privacy isolation.
  Future<List<SessionInfo>> listSessions({String? mode}) =>
      _history.listSessions(mode: mode);

  ChatMessage _rowToMessage(Map<String, dynamic> row) => ChatMessage(
        id: row['id'] as String,
        role: MessageRole.values.firstWhere(
          (r) => r.name == row['role'],
          orElse: () => MessageRole.user,
        ),
        content: row['content'] as String,
        source: row['source'] != null
            ? MessageSource.values.firstWhere(
                (s) => s.name == row['source'],
                orElse: () => MessageSource.local,
              )
            : null,
        timestamp: DateTime.parse(row['timestamp'] as String),
        imageUrl: row['image_url'] as String?,
      );
}
