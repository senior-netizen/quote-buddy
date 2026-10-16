import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'encoded path separators cannot read files outside the web root',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'quoteflow-web-boundary',
      );
      final web = await Directory('${directory.path}/web').create();
      await File(
        '${web.path}/index.html',
      ).writeAsString('QuoteFlow local test page');
      await File(
        '${directory.path}/private-canary.txt',
      ).writeAsString('AUDIT_CANARY_OUTSIDE_WEB_ROOT');
      final reservation = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close(force: true);
      final environment = Map<String, String>.from(Platform.environment)
        ..removeWhere(
          (key, _) => key.startsWith('PAYNOW_') || key.startsWith('BILLING_'),
        )
        ..addAll({
          'WEB_ROOT': web.path,
          'BIND_ADDRESS': '127.0.0.1',
          'PORT': '$port',
        });
      final cache = File(
        Platform.resolvedExecutable,
      ).parent.parent.parent.parent;
      final dart =
          '${cache.path}/dart-sdk/bin/${Platform.isWindows ? 'dart.exe' : 'dart'}';
      final process = await Process.start(
        dart,
        [
          '--packages=.dart_tool/package_config.json',
          'server/quote_flow_server.dart',
        ],
        environment: environment,
        includeParentEnvironment: false,
        runInShell: false,
      );
      final ready = Completer<void>();
      final out = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.contains('listening on port') && !ready.isCompleted)
              ready.complete();
          });
      final errors = process.stderr.drain<void>();
      final client = HttpClient();
      try {
        await ready.future.timeout(const Duration(seconds: 30));
        for (final route in ['', 'documents/quotation']) {
          final request = await client.getUrl(
            Uri.parse('http://127.0.0.1:$port/$route'),
          );
          final response = await request.close();
          expect(response.statusCode, 200);
          expect(
            await response.transform(utf8.decoder).join(),
            'QuoteFlow local test page',
          );
        }
        for (final path in [
          '..%2Fprivate-canary.txt',
          '..%5Cprivate-canary.txt',
        ]) {
          final request = await client.getUrl(
            Uri.parse('http://127.0.0.1:$port/$path'),
          );
          final response = await request.close();
          final body = await response.transform(utf8.decoder).join();
          expect(
            body,
            isNot(contains('AUDIT_CANARY_OUTSIDE_WEB_ROOT')),
            reason: path,
          );
          expect(response.statusCode, 400, reason: path);
        }
      } finally {
        client.close(force: true);
        process.kill();
        await process.exitCode.timeout(const Duration(seconds: 5));
        await out.cancel();
        await errors.timeout(const Duration(seconds: 5));
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
