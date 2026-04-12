/// Serves the latest release APK over the local network so a phone on the
/// same Wi-Fi (or Tailscale) can download it directly.
///
/// Zero external dependencies — uses only dart:io.
///
/// Usage: `dart scripts/serve_apk.dart`
library;

import 'dart:io';

const _apkPath = 'build/app/outputs/flutter-apk/app-release.apk';
const _port = 8080;

Future<void> main(List<String> args) async {
  final apk = File(_apkPath);
  if (!apk.existsSync()) {
    stderr.writeln('APK not found at $_apkPath');
    stderr.writeln('Run: flutter build apk --release --target-platform android-arm64');
    exit(1);
  }

  final sizeMb = (apk.lengthSync() / 1024 / 1024).toStringAsFixed(1);
  final lanIp = await _detectLanIp() ?? 'localhost';
  final url = 'http://$lanIp:$_port/pocket-claw.apk';
  final qrUrl =
      'https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=${Uri.encodeComponent(url)}';

  HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
  } catch (e) {
    stderr.writeln('Failed to bind port $_port: $e');
    stderr.writeln('Another process may be using it. Try closing other servers.');
    exit(1);
  }

  stdout.writeln('');
  stdout.writeln('============================================================');
  stdout.writeln('  Pocket Claw APK ready for your phone');
  stdout.writeln('============================================================');
  stdout.writeln('');
  stdout.writeln('  Size:     $sizeMb MB');
  stdout.writeln('  Built:    ${apk.lastModifiedSync()}');
  stdout.writeln('');
  stdout.writeln('  On your phone, open any browser and go to:');
  stdout.writeln('');
  stdout.writeln('      $url');
  stdout.writeln('');
  stdout.writeln('  Or scan the QR code at this URL (open in your PC browser):');
  stdout.writeln('');
  stdout.writeln('      $qrUrl');
  stdout.writeln('');
  stdout.writeln('  Phone must be on the same Wi-Fi as this PC,');
  stdout.writeln('  or on the same Tailscale network.');
  stdout.writeln('');
  stdout.writeln('  First time on Windows? If the phone cannot reach this URL,');
  stdout.writeln('  allow Dart through Windows Firewall when prompted.');
  stdout.writeln('');
  stdout.writeln('  Press Ctrl+C to stop the server.');
  stdout.writeln('');
  stdout.writeln('============================================================');
  stdout.writeln('');

  server.listen((request) async {
    final path = request.uri.path;
    stdout.writeln('[${DateTime.now().toIso8601String()}] '
        '${request.method} $path (from ${request.connectionInfo?.remoteAddress.address})');

    if (path == '/pocket-claw.apk' || path == '/app-release.apk') {
      request.response.headers.contentType =
          ContentType('application', 'vnd.android.package-archive');
      request.response.headers.contentLength = apk.lengthSync();
      request.response.headers.add(
        'Content-Disposition',
        'attachment; filename="pocket-claw.apk"',
      );
      try {
        await apk.openRead().pipe(request.response);
      } catch (e) {
        stderr.writeln('Stream error: $e');
      }
    } else if (path == '/' || path == '/index.html') {
      request.response.headers.contentType =
          ContentType('text', 'html', charset: 'utf-8');
      request.response.write(
        '<!DOCTYPE html><html><head><title>Pocket Claw APK</title>'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<style>body{font-family:-apple-system,sans-serif;background:#1A1A2E;'
        'color:white;padding:40px;text-align:center}'
        'a{background:#E53935;color:white;padding:20px 40px;border-radius:12px;'
        'text-decoration:none;display:inline-block;margin-top:20px;'
        'font-size:18px;font-weight:bold}h1{color:#00E5CC}</style></head>'
        '<body><h1>\u{1F980} Pocket Claw</h1>'
        '<p>Tap the button below to download the APK.</p>'
        '<p>Size: $sizeMb MB</p>'
        '<a href="/pocket-claw.apk" download>Download APK</a>'
        '</body></html>',
      );
      await request.response.close();
    } else {
      request.response.statusCode = 404;
      request.response.write('Not found. Try /pocket-claw.apk');
      await request.response.close();
    }
  });
}

Future<String?> _detectLanIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );

    // Filter out virtual adapters (Docker, WSL, VMware, vEthernet).
    final realInterfaces = interfaces.where((iface) {
      final name = iface.name.toLowerCase();
      return !name.contains('docker') &&
          !name.contains('wsl') &&
          !name.contains('vmware') &&
          !name.contains('vethernet') &&
          !name.contains('virtual') &&
          !name.contains('hyper-v');
    }).toList();

    // Priority order: 192.168.* > 100.* (Tailscale) > 10.* > 172.*
    final prefixPriority = ['192.168.', '100.', '10.', '172.'];

    for (final prefix in prefixPriority) {
      for (final iface in realInterfaces) {
        for (final addr in iface.addresses) {
          if (addr.address.startsWith(prefix)) {
            return addr.address;
          }
        }
      }
    }

    // Fall back to first non-virtual IPv4 anywhere
    for (final iface in realInterfaces) {
      for (final addr in iface.addresses) {
        return addr.address;
      }
    }

    // Last resort: any IP
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        return addr.address;
      }
    }
  } catch (_) {
    // Will fall back to 'localhost'
  }
  return null;
}
