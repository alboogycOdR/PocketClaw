/// Gateway URL + auth token input with test/persist and skip-for-offline.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart' as app_router;
import '../../app/theme.dart';
import '../../data/providers/core_providers.dart';

class GatewaySetup extends ConsumerStatefulWidget {
  const GatewaySetup({super.key});

  @override
  ConsumerState<GatewaySetup> createState() => _GatewaySetupState();
}

class _GatewaySetupState extends ConsumerState<GatewaySetup> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _testing = false;
  bool? _testSuccess;
  String? _testError;

  @override
  void initState() {
    super.initState();
    // DEBUG BUILD: hardcode URL + token via providers (ignore any stale prefs).
    _urlController.text = ref.read(gatewayUrlProvider);
    _tokenController.text = ref.read(gatewayTokenProvider);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) return;

    setState(() {
      _testing = true;
      _testSuccess = null;
      _testError = null;
    });

    final restUrl = rawUrl
        .replaceFirst('wss://', 'https://')
        .replaceFirst('ws://', 'http://');
    final token = _tokenController.text.trim();

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ));

    try {
      final response = await dio.get<Map<String, dynamic>>(
        '$restUrl/__openclaw__/api/health',
      );

      if (!mounted) return;
      setState(() {
        _testing = false;
        _testSuccess = response.statusCode == 200;
        if (!_testSuccess!) {
          _testError = 'Server returned status ${response.statusCode}';
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testSuccess = false;
        _testError = switch (e.type) {
          DioExceptionType.connectionTimeout => 'Connection timed out',
          DioExceptionType.connectionError => 'Could not reach server',
          DioExceptionType.badResponse =>
            'Server returned HTTP ${e.response?.statusCode}',
          _ => e.message ?? 'Connection failed',
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testSuccess = false;
        _testError = 'Connection failed: $e';
      });
    } finally {
      dio.close();
    }
  }

  Future<void> _saveAndProceed() async {
    final prefs = ref.read(sharedPrefsProvider);
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();

    if (url.isNotEmpty) {
      await prefs.setString('gateway_url', url);
      ref.read(gatewayUrlProvider.notifier).state = url;
    }
    if (token.isNotEmpty) {
      await prefs.setString('gateway_token', token);
      ref.read(gatewayTokenProvider.notifier).state = token;
    }

    await _markOnboarded(prefs);
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _skip() async {
    final prefs = ref.read(sharedPrefsProvider);
    await _markOnboarded(prefs);
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _markOnboarded(SharedPreferences prefs) async {
    await prefs.setBool('onboarded', true);
    app_router.hasOnboarded = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect Gateway')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect to your\nOpenClaw Gateway',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Optional — you can skip this and run fully offline with a '
                'local model, then set it up later in Settings.',
                style: TextStyle(color: Colors.white54, height: 1.5),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _urlController,
                style: GoogleFonts.jetBrainsMono(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Gateway URL',
                  hintText: 'ws://192.168.1.100:18789/__openclaw__/ws',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tokenController,
                obscureText: false,
                style: GoogleFonts.jetBrainsMono(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Auth token',
                  hintText: 'Bearer token from your OpenClaw dashboard',
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PocketClawTheme.lobsterRed,
                          ),
                        )
                      : const Icon(Icons.wifi_tethering, size: 18),
                  label: Text(_testing ? 'Testing...' : 'Test Connection'),
                ),
              ),

              if (_testSuccess != null) ...[
                const SizedBox(height: 12),
                _TestResultBanner(
                  success: _testSuccess!,
                  error: _testError,
                ),
              ],

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saveAndProceed,
                  child: const Text('Save & Continue'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _skip,
                  child: const Text(
                    'Skip — use offline only',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestResultBanner extends StatelessWidget {
  final bool success;
  final String? error;
  const _TestResultBanner({required this.success, this.error});

  @override
  Widget build(BuildContext context) {
    final color =
        success ? const Color(0xFF4CAF50) : PocketClawTheme.lobsterRed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.check_circle : Icons.error_outline,
              size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              success
                  ? 'Connected successfully!'
                  : error ?? 'Connection failed. Check the URL.',
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
