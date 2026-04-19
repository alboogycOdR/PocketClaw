/// Main chat screen with message list, text input, voice & photo buttons
library;

import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme.dart';

import '../../core/local_agent/llm_engine.dart';
import '../../data/models/chat_message.dart';
import '../../data/providers/chat_providers.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/extensions.dart';
import '../../shared/widgets/connection_indicator.dart';
import 'chat_bubble.dart';
import 'chat_mode_selector.dart';
import 'draft_confirm_card.dart';
import 'function_call_indicator.dart';
import 'photo_preview.dart';
import 'privacy_warning_banner.dart';
import 'voice_input_widget.dart';

const _uuid = Uuid();

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  String? _pendingImageUrl;
  bool _isVoiceRecording = false;
  String _draftText = '';

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onDraftChanged);
  }

  void _onDraftChanged() {
    final next = _textController.text;
    if (next != _draftText) {
      setState(() => _draftText = next);
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onDraftChanged);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty && _pendingImageUrl == null) return;

    ref.read(sendMessageProvider)(
      text.isNotEmpty ? text : 'Analyse this image',
      imageUrl: _pendingImageUrl,
    );
    _textController.clear();
    setState(() => _pendingImageUrl = null);

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo != null && mounted) {
        setState(() => _pendingImageUrl = photo.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _onVoiceStart() {
    setState(() => _isVoiceRecording = true);
    _focusNode.requestFocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Listening... Type your message or tap the mic again to send.',
          ),
          backgroundColor: PocketClawTheme.lobsterRed.withAlpha(200),
          duration: const Duration(seconds: 30),
          action: SnackBarAction(
            label: 'Cancel',
            textColor: Colors.white,
            onPressed: () {
              setState(() => _isVoiceRecording = false);
            },
          ),
        ),
      );
  }

  void _onVoiceStop() {
    setState(() => _isVoiceRecording = false);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      // User typed text while "recording" — send it as a message.
      _sendMessage();
      return;
    }

    // No text was entered. Check whether the active model supports audio.
    final engine = ref.read(llmEngineProvider);
    final config = engine.config;
    final hasAudioCap =
        config != null && config.capabilities.contains(ModelCap.audio);

    if (!engine.isLoaded) {
      _showVoiceSnackBar(
        'No model loaded. Download a model in Settings to enable voice input.',
      );
    } else if (!hasAudioCap) {
      _showVoiceSnackBar(
        'Voice input requires the Gemma 4 E2B model. '
        'Your current model (${config?.displayName ?? "unknown"}) '
        'does not support audio.',
      );
    } else {
      // Model supports audio but we lack a native audio capture package.
      _showVoiceSnackBar(
        'Audio capture is not yet available. '
        'Type your message while the mic is active, then tap the mic to send.',
      );
    }
  }

  void _showVoiceSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ── Draft action callbacks ──

  void _handleDraftConfirm(ChatMessage msg) {
    final draft = msg.draftAction!;
    final messages = ref.read(messagesProvider.notifier);

    switch (draft.type) {
      case ActionType.email:
      case ActionType.message:
      case ActionType.generic:
        final shareService = ref.read(shareServiceProvider);
        final channel = switch (draft.type) {
          ActionType.email => 'email',
          ActionType.message => 'sms',
          _ => 'generic',
        };
        shareService.draft(
          body: draft.body,
          recipient: draft.recipient,
          subject: draft.title,
          channel: channel,
        );
      case ActionType.calendar:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calendar event noted: ${draft.title}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case ActionType.reminder:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder set: ${draft.title}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    // Mark the draft as confirmed
    messages.updateById(
      msg.id,
      (m) => m.copyWith(
        draftAction: DraftAction(
          type: draft.type,
          title: draft.title,
          body: draft.body,
          recipient: draft.recipient,
          isConfirmed: true,
        ),
      ),
    );
  }

  void _handleDraftEdit(ChatMessage msg) {
    final draft = msg.draftAction!;
    final editController = TextEditingController(text: draft.body);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PocketClawTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Edit draft',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editController,
              maxLines: 8,
              minLines: 3,
              autofocus: true,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: PocketClawTheme.surfaceContainerLow,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final newBody = editController.text.trim();
                    if (newBody.isNotEmpty) {
                      ref.read(messagesProvider.notifier).updateById(
                        msg.id,
                        (m) => m.copyWith(
                          draftAction: DraftAction(
                            type: draft.type,
                            title: draft.title,
                            body: newBody,
                            recipient: draft.recipient,
                            isConfirmed: draft.isConfirmed,
                          ),
                        ),
                      );
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    ).then((_) => editController.dispose());
  }

  void _handleDraftCancel(ChatMessage msg) {
    final messages = ref.read(messagesProvider.notifier);
    messages.removeById(msg.id);
    messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.system,
      content: 'Action cancelled.',
      source: MessageSource.device,
      timestamp: DateTime.now(),
    ));
  }

  void _openSessionDrawer() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PocketClawTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SessionDrawer(
        onSessionSelected: (key) async {
          Navigator.pop(ctx);
          final session = ref.read(sessionManagerProvider);
          await session.loadSession(key);
          final history = await session.recentHistory(100);
          ref.read(messagesProvider.notifier).clear();
          for (final msg in history) {
            ref.read(messagesProvider.notifier).add(msg);
          }
          ref.read(currentSessionKeyProvider.notifier).state = key;
        },
        onNewSession: () async {
          Navigator.pop(ctx);
          final session = ref.read(sessionManagerProvider);
          await session.startNewSession();
          ref.read(messagesProvider.notifier).clear();
          ref.read(currentSessionKeyProvider.notifier).state =
              session.currentSessionKey;
          ref.invalidate(sessionListAutoProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gatewayState = ref.watch(connectionStateProvider);
    final messages = ref.watch(messagesProvider);
    final isProcessing = ref.watch(isProcessingProvider);

    // 3A: Model indicator
    final engine = ref.watch(llmEngineProvider);
    final modelConfig = engine.config;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pocket Claw',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  modelConfig != null
                      ? modelConfig.displayName
                      : 'No model',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: modelConfig != null
                        ? Colors.white38
                        : Colors.white24,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            ConnectionIndicator(state: gatewayState),
          ],
        ),
        actions: [
          // Session management button
          IconButton(
            icon: const Icon(Icons.forum_outlined, size: 20),
            tooltip: 'Sessions',
            onPressed: _openSessionDrawer,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            tooltip: 'New chat',
            onPressed: () {
              ref.read(resetChatProvider)();
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat mode selector (Local / Cloud / OpenClaw)
          const ChatModeSelector(),

          // Message list
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🦀',
                          style: const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length + (isProcessing ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Processing indicator as last item
                      if (index == messages.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: PocketClawTheme.lobsterRed,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Thinking...',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final msg = messages[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Function call indicator
                          if (msg.functionCall != null)
                            FunctionCallIndicator(
                                functionCall: msg.functionCall!),

                          // Draft action card
                          if (msg.draftAction != null)
                            DraftConfirmCard(
                              draft: msg.draftAction!,
                              onConfirm: () => _handleDraftConfirm(msg),
                              onEdit: () => _handleDraftEdit(msg),
                              onCancel: () => _handleDraftCancel(msg),
                            ),

                          // Photo preview
                          if (msg.imageUrl != null)
                            PhotoPreview(imageUrl: msg.imageUrl!),

                          // Message bubble
                          ChatBubble(message: msg),
                        ],
                      );
                    },
                  ),
          ),

          // Pending image preview
          if (_pendingImageUrl != null)
            _buildPendingImage(),

          // Privacy warning (shown when sensitive keywords typed in
          // Cloud or OpenClaw mode)
          PrivacyWarningBanner(draftText: _draftText),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildPendingImage() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              io.File(_pendingImageUrl!),
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Image attached',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: Colors.white38,
            onPressed: () => setState(() => _pendingImageUrl = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final isProcessing = ref.watch(isProcessingProvider);
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: PocketClawTheme.surfaceDim,
        border: Border(
          top: BorderSide(
            color: const Color(0xFF3A3A50).withAlpha(80),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Photo button
          IconButton(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.photo_camera_outlined, size: 22),
            color: Colors.white54,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),

          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _isVoiceRecording
                      ? 'Speak or type, then tap mic to send...'
                      : 'Ask anything...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: PocketClawTheme.lobsterRed.withAlpha(120),
                    ),
                  ),
                  filled: true,
                  fillColor: PocketClawTheme.surfaceContainer,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Voice button
          VoiceInputWidget(
            onStart: _onVoiceStart,
            onStop: _onVoiceStop,
          ),

          // Send / Stop button — swaps to Stop while a server reply is
          // streaming, so the user can cancel long tool runs.
          if (isProcessing)
            IconButton(
              onPressed: () => ref.read(abortChatProvider)(),
              icon: const Icon(Icons.stop_circle_outlined, size: 22),
              color: PocketClawTheme.lobsterRed,
              tooltip: 'Stop',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            )
          else
            IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded, size: 22),
              color: PocketClawTheme.lobsterRed,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
        ],
      ),
    );
  }
}

// ── Session Drawer (3C) ──

class _SessionDrawer extends ConsumerWidget {
  final void Function(String key) onSessionSelected;
  final VoidCallback onNewSession;

  const _SessionDrawer({
    required this.onSessionSelected,
    required this.onNewSession,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionListAutoProvider);
    final currentKey = ref.watch(currentSessionKeyProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Sessions',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onNewSession,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Session list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: sessionsAsync.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No saved sessions yet.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                    final isCurrent = s.key == currentKey;
                    return ListTile(
                      dense: true,
                      selected: isCurrent,
                      selectedTileColor:
                          PocketClawTheme.lobsterRed.withAlpha(20),
                      leading: Icon(
                        isCurrent
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                        size: 18,
                        color: isCurrent
                            ? PocketClawTheme.lobsterRed
                            : Colors.white38,
                      ),
                      title: Text(
                        s.startedAt.shortDate,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight:
                              isCurrent ? FontWeight.w600 : FontWeight.w400,
                          color: isCurrent ? Colors.white : Colors.white70,
                        ),
                      ),
                      subtitle: Text(
                        '${s.messageCount} messages  ·  ${s.startedAt.timeAgo}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                      onTap: isCurrent ? null : () => onSessionSelected(s.key),
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Failed to load sessions: $e',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
