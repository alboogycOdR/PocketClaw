/// Device info — RAM, storage, model details, GPU/NPU availability.
library;

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/providers/core_providers.dart';
import '../../shared/utils/storage_formatter.dart';

class DeviceFacts {
  final String deviceName;
  final String osName;
  final int totalRamBytes;
  final int? availableRamBytes;
  final int? totalStorageBytes;
  final int? freeStorageBytes;
  final int cpuCores;
  final bool isQualcomm;

  const DeviceFacts({
    required this.deviceName,
    required this.osName,
    required this.totalRamBytes,
    required this.cpuCores,
    required this.isQualcomm,
    this.availableRamBytes,
    this.totalStorageBytes,
    this.freeStorageBytes,
  });
}

final deviceFactsProvider = FutureProvider<DeviceFacts>((ref) async {
  var deviceName = 'Unknown device';
  var osName = Platform.operatingSystem;
  var totalRam = 0;
  var cpuCores = Platform.numberOfProcessors;
  var isQualcomm = false;

  try {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      deviceName = '${info.manufacturer} ${info.model}';
      osName = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
      isQualcomm =
          info.hardware.toLowerCase().contains('qcom') ||
          (info.systemFeatures.any((f) => f.toLowerCase().contains('qti')));
    } else if (Platform.isIOS) {
      final info = await DeviceInfoPlugin().iosInfo;
      deviceName = '${info.name} ${info.model}';
      osName = 'iOS ${info.systemVersion}';
    }
  } catch (_) {}

  try {
    const channel = MethodChannel('com.nuburo.hermescommander/device');
    final ram = await channel.invokeMethod<int>('getTotalRam');
    if (ram != null) totalRam = ram;
  } catch (_) {}

  // Free storage on Android — best-effort via getApplicationDocumentsDirectory.
  int? totalStorage;
  int? freeStorage;
  try {
    final dir = await getApplicationDocumentsDirectory();
    final stat = await Process.run('df', ['-k', dir.path]);
    if (stat.exitCode == 0) {
      // df output: Filesystem 1K-blocks Used Available Use% Mounted
      final lines = (stat.stdout as String).split('\n');
      if (lines.length > 1) {
        final parts = lines[1].split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          totalStorage = int.tryParse(parts[1]).let((v) => v * 1024);
          freeStorage = int.tryParse(parts[3]).let((v) => v * 1024);
        }
      }
    }
  } catch (_) {}

  return DeviceFacts(
    deviceName: deviceName,
    osName: osName,
    totalRamBytes: totalRam,
    cpuCores: cpuCores,
    isQualcomm: isQualcomm,
    totalStorageBytes: totalStorage,
    freeStorageBytes: freeStorage,
  );
});

extension _IntOpt on int? {
  int? let(int Function(int) f) => this == null ? null : f(this!);
}

class DeviceInfoScreen extends ConsumerWidget {
  const DeviceInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factsAsync = ref.watch(deviceFactsProvider);
    final model = ref.watch(selectedModelConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Device Info')),
      body: factsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('Failed: $e')),
        ),
        data: (facts) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section('Hardware', [
              _Row(label: 'Device', value: facts.deviceName),
              _Row(label: 'OS', value: facts.osName),
              _Row(
                label: 'RAM',
                value: facts.totalRamBytes == 0
                    ? 'Unknown'
                    : formatBytes(facts.totalRamBytes),
              ),
              _Row(label: 'CPU cores', value: '${facts.cpuCores}'),
              if (facts.freeStorageBytes != null)
                _Row(
                  label: 'Storage free',
                  value: formatBytes(facts.freeStorageBytes!),
                ),
              if (facts.totalStorageBytes != null)
                _Row(
                  label: 'Storage total',
                  value: formatBytes(facts.totalStorageBytes!),
                ),
            ]),
            if (model != null) ...[
              const SizedBox(height: 18),
              _Section('Active model', [
                _Row(label: 'Name', value: model.displayName),
                _Row(label: 'Size', value: formatBytes(model.sizeBytes)),
                _Row(label: 'Min RAM', value: formatBytes(model.minRamBytes)),
                _Row(label: 'Template', value: model.chatTemplate.name),
              ]),
            ],
            const SizedBox(height: 18),
            _Section('Acceleration', [
              _Row(label: 'GPU (OpenCL)', value: 'Not detected'),
              _Row(
                label: 'NPU (QNN)',
                value: facts.isQualcomm ? 'Available (Snapdragon)' : 'N/A',
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 0.14,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
          ),
        ),
        const SizedBox(height: 6),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
