/// Riverpod providers for the shared SSH transport (Sprint 3 / §5.2).
///
/// Sensitive material (password, future key files) lives in
/// flutter_secure_storage. SharedPreferences holds host, port, username,
/// and the auth-method selector only.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/ssh/hermes_ssh_client.dart';
import 'core_providers.dart';

const _kSshPasswordKey = 'ssh_password';

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

// ── Settings (sync, prefs-backed) ────────────────────────────────────────

final sshHostProvider = StateProvider<String>((ref) =>
    ref.watch(sharedPrefsProvider).getString('ssh_host') ?? '');

final sshPortProvider = StateProvider<int>((ref) =>
    ref.watch(sharedPrefsProvider).getInt('ssh_port') ?? 22);

final sshUsernameProvider = StateProvider<String>((ref) =>
    ref.watch(sharedPrefsProvider).getString('ssh_username') ?? '');

/// 'password' | 'key'. Only password is wired today; key is a Sprint 3+
/// follow-up.
final sshAuthMethodProvider = StateProvider<String>((ref) =>
    ref.watch(sharedPrefsProvider).getString('ssh_auth_method') ?? 'password');

/// Bumped by the settings screen after Save so dependent providers
/// rebuild and pick up the new password from secure storage.
final sshSettingsRevProvider = StateProvider<int>((_) => 0);

// ── Password (async, secure-storage-backed) ──────────────────────────────

Future<String?> readSshPassword() => _secureStorage.read(key: _kSshPasswordKey);

Future<void> writeSshPassword(String password) =>
    _secureStorage.write(key: _kSshPasswordKey, value: password);

Future<void> clearSshPassword() => _secureStorage.delete(key: _kSshPasswordKey);

// ── Client (async — needs to await secure-storage password) ──────────────

/// The live SSH client. Returns null when host/username are unset, or
/// when password auth is selected and no password is stored.
final sshClientProvider =
    FutureProvider<HermesSshClient?>((ref) async {
  ref.watch(sshSettingsRevProvider); // rebuild on settings save
  final host = ref.watch(sshHostProvider);
  final port = ref.watch(sshPortProvider);
  final user = ref.watch(sshUsernameProvider);
  final method = ref.watch(sshAuthMethodProvider);

  if (host.isEmpty || user.isEmpty) return null;

  late final SshAuth auth;
  if (method == 'password') {
    final pw = await readSshPassword();
    if (pw == null || pw.isEmpty) return null;
    auth = SshPasswordAuth(pw);
  } else {
    // Key-based auth not yet wired — surface as not-configured.
    return null;
  }

  final client = HermesSshClient(
    host: host,
    port: port,
    username: user,
    auth: auth,
  );
  ref.onDispose(client.disconnect);
  return client;
});

/// True when the SSH client is configured AND can authenticate. Cheap
/// connection probe; the connection is held open across calls.
final sshReachableProvider = FutureProvider<bool>((ref) async {
  final client = await ref.watch(sshClientProvider.future);
  if (client == null) return false;
  return client.isReachable();
});
