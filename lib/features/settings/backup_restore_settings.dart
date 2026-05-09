/// Backup & Restore — export the current settings to a JSON file or
/// import a previously exported file. Credentials (auth tokens, API
/// keys, SSH password, HuggingFace token) are opt-in via a checkbox.
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../core/device/settings_backup_service.dart';
import '../../shared/constants.dart';

class BackupRestoreSettings extends ConsumerStatefulWidget {
  const BackupRestoreSettings({super.key});

  @override
  ConsumerState<BackupRestoreSettings> createState() =>
      _BackupRestoreSettingsState();
}

class _BackupRestoreSettingsState
    extends ConsumerState<BackupRestoreSettings> {
  bool _includeCredentials = false;
  bool _busy = false;
  String? _lastMessage;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _lastMessage = null;
    });
    try {
      final svc = SettingsBackupService();
      final json = await svc.exportSettings(
        includeCredentials: _includeCredentials,
        appVersion: AppConstants.appVersion,
      );

      // Write to a tmp file with a meaningful name and hand off to the
      // OS share sheet. The user picks Drive / Files / email-to-self.
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pocketclaw-settings-$stamp.json');
      await file.writeAsString(json, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'PocketClaw settings backup',
        text: _includeCredentials
            ? 'PocketClaw settings — INCLUDES CREDENTIALS. Treat this '
                'file like a password manager export.'
            : 'PocketClaw settings (no credentials).',
      );

      if (mounted) {
        setState(() => _lastMessage =
            'Exported. Save the file somewhere you can find it later.');
      }
    } catch (e) {
      if (mounted) setState(() => _lastMessage = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _lastMessage = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() {
          _busy = false;
          _lastMessage = null;
        });
        return;
      }
      final file = result.files.first;
      final raw = file.bytes != null
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();

      final svc = SettingsBackupService();
      final parsed = await svc.parse(raw);

      if (!parsed.ok) {
        if (mounted) setState(() => _lastMessage = parsed.errorMessage);
        return;
      }

      if (!mounted) return;
      final confirmed = await _showConfirmDialog(parsed);
      if (confirmed != true) {
        setState(() => _lastMessage = 'Import cancelled.');
        return;
      }

      await svc.apply(parsed);
      if (mounted) {
        setState(() => _lastMessage =
            'Imported ${parsed.totalKeyCount} setting${parsed.totalKeyCount == 1 ? "" : "s"}. '
            'Force-stop and reopen PocketClaw to apply everywhere.');
      }
    } catch (e) {
      if (mounted) setState(() => _lastMessage = 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showConfirmDialog(BackupParseResult parsed) {
    final keys = [
      ...parsed.prefs.keys,
      ...parsed.secureKeys.keys.map((k) => '$k (secure)'),
    ]..sort();
    return showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Apply backup?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400, maxWidth: 360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (parsed.exportedAt != null)
                Text(
                  'Exported ${parsed.exportedAt!.toLocal().toString().split('.').first}',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              if (parsed.includedCredentials)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '⚠ Includes credentials',
                    style: TextStyle(
                      fontSize: 11,
                      color: PocketClawTheme.warning,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'The following ${keys.length} value${keys.length == 1 ? "" : "s"} will be overwritten:',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final k in keys)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            '· $k',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: PocketClawTheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What gets backed up',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PocketClawTheme.electricTeal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Always: gateway / Hermes / Paperclip URLs, SSH host '
                    'and username, selected local model, chat-mode + '
                    'session keys, Academy & Life Architect state, '
                    'Smart Router preferences.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Opt-in only: gateway auth token, Hermes API key, '
                    'Paperclip API key, SSH password, HuggingFace token. '
                    'These live in secure storage on this device.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Never: device identity (Ed25519 keypair), '
                    'in-flight onboarding state.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                CheckboxListTile(
                  title: const Text('Include credentials in export'),
                  subtitle: const Text(
                    'Auth tokens + API keys + SSH password + HF token. '
                    'Treat the resulting file like a password export.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _includeCredentials,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                            _includeCredentials = v ?? false;
                          }),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: PocketClawTheme.lobsterRed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Export'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Import'),
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          if (_lastMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _lastMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
