import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:quoteflow/services/zimra/buyer_contract.dart';
import 'billing/ledger.dart';
import 'billing/paynow.dart';
import 'billing/routes.dart';
import 'billing/service.dart';

const _allowedBaseUrls = {
  'https://fdmsapitest.zimra.co.zw',
  'https://fdmsapi.zimra.co.zw',
};

const _contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
};

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final webRoot = Directory(
    Platform.environment['WEB_ROOT'] ?? 'build/web',
  ).absolute;
  if (!await webRoot.exists()) {
    stderr.writeln(
      'Web build not found at ${webRoot.path}. Run flutter build web first.',
    );
    exitCode = 66;
    return;
  }

  final billing = await loadBilling();
  final server = await HttpServer.bind(
    Platform.environment['BIND_ADDRESS'] ?? InternetAddress.anyIPv4,
    port,
  );
  stdout.writeln('QuoteFlow web server listening on port $port');
  await for (final request in server) {
    unawaited(_handleRequest(request, webRoot, billing));
  }
}

Future<void> _handleRequest(
  HttpRequest request,
  Directory webRoot,
  BillingService? billing,
) async {
  try {
    if (request.uri.path.startsWith('/api/billing/') ||
        request.uri.path == '/api/paynow/result' ||
        request.uri.path == '/api/paynow/results') {
      await handleBilling(request, billing);
    } else if (request.uri.path == '/api/zimra') {
      await _handleZimraProxy(request, billing);
    } else {
      await _serveWebFile(request, webRoot);
    }
  } on BillingError catch (error) {
    await billingJson(request.response, error.status, {'error': error.message});
  } on FormatException {
    await billingJson(request.response, 400, {'error': 'Invalid request.'});
  } on TypeError {
    await billingJson(request.response, 400, {
      'error': 'Invalid request fields.',
    });
  } catch (_) {
    stderr.writeln(
      'Request failed. Credentials and payment payloads are not logged.',
    );
    if (!request.response.headers.chunkedTransferEncoding &&
        request.response.contentLength == -1) {
      await _jsonResponse(request.response, HttpStatus.internalServerError, {
        'error': 'Internal server error',
      });
    }
  }
}

Future<void> _handleZimraProxy(
  HttpRequest request,
  BillingService? billing,
) async {
  _setCorsHeaders(request);
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }
  if (request.method != 'POST') {
    await _jsonResponse(request.response, HttpStatus.methodNotAllowed, {
      'error': 'POST required',
    });
    return;
  }
  if (request.contentLength > 2 * 1024 * 1024) {
    await _jsonResponse(request.response, HttpStatus.requestEntityTooLarge, {
      'error': 'Request is too large',
    });
    return;
  }

  final payload =
      jsonDecode(await readLimited(request)) as Map<String, dynamic>;
  final baseUrl = payload['baseUrl'] as String? ?? '';
  final method = (payload['method'] as String? ?? '').toUpperCase();
  final path = payload['path'] as String? ?? '';
  if (!_allowedBaseUrls.contains(baseUrl) ||
      !const {'GET', 'POST'}.contains(method) ||
      !_validZimraPath(path)) {
    await _jsonResponse(request.response, HttpStatus.badRequest, {
      'error': 'Unsupported ZIMRA request',
    });
    return;
  }

  final certificatePem = payload['certificatePem'] as String?;
  final privateKeyPem = payload['privateKeyPem'] as String?;
  final authenticated = path.startsWith('/Device/');
  if (authenticated && (certificatePem == null || privateKeyPem == null)) {
    await _jsonResponse(request.response, HttpStatus.badRequest, {
      'error': 'Device credentials are required',
    });
    return;
  }

  if (path.endsWith('/SubmitReceipt')) {
    try {
      validateReceiptBuyer((payload['body'] as Map)['receipt'] as Map);
    } catch (error) {
      await _jsonResponse(request.response, HttpStatus.badRequest, {
        'error': error is FiscalBuyerException
            ? error.toString()
            : 'Invalid receipt',
      });
      return;
    }
  }

  VerifiedBusiness? business;
  int? deviceId;
  final production = baseUrl == 'https://fdmsapi.zimra.co.zw';
  if (production && authenticated) {
    if (billing == null) {
      throw const BillingError(
        503,
        'Production credit billing is not configured.',
      );
    }
    final origin = request.headers.value('origin');
    if (origin != null && origin != billing.publicBaseUrl.origin) {
      throw const BillingError(403, 'Origin is not allowed.');
    }
    business = billing.authenticate(
      payload['businessTin'] as String? ?? '',
      request.headers.value('authorization'),
    );
    deviceId = int.parse(path.split('/')[3]);
    if (!business.deviceIds.contains(deviceId)) {
      throw const BillingError(
        403,
        'Fiscal device does not belong to this business.',
      );
    }
    if (path.endsWith('/SubmitFile')) {
      throw const BillingError(
        400,
        'Production file uploads are not supported. Use the signed receipt queue.',
      );
    }
  }
  Future<FiscalReply> forward() => _forwardZimra(
    payload,
    certificatePem,
    privateKeyPem,
    authenticated,
  ).timeout(const Duration(seconds: 40));
  final reply = production && path.endsWith('/SubmitReceipt')
      ? await billing!.fiscalise(
          business!,
          deviceId!,
          Map<String, dynamic>.from(payload['body'] as Map),
          forward,
        )
      : await forward();
  await _jsonResponse(request.response, HttpStatus.ok, reply.toJson());
}

Future<FiscalReply> _forwardZimra(
  Map<String, dynamic> payload,
  String? certificatePem,
  String? privateKeyPem,
  bool authenticated,
) async {
  SecurityContext? securityContext;
  if (authenticated) {
    securityContext = SecurityContext(withTrustedRoots: true)
      ..useCertificateChainBytes(utf8.encode(certificatePem!))
      ..usePrivateKeyBytes(utf8.encode(privateKeyPem!));
  }
  final client = HttpClient(context: securityContext)
    ..connectionTimeout = const Duration(seconds: 30);
  try {
    return await (() async {
      final upstreamUri = Uri.parse('${payload['baseUrl']}${payload['path']}');
      final upstream = payload['method'].toString().toUpperCase() == 'GET'
          ? await client.getUrl(upstreamUri)
          : await client.postUrl(upstreamUri);
      upstream.followRedirects = false;
      upstream.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final suppliedHeaders = Map<String, dynamic>.from(
        payload['headers'] as Map? ?? const {},
      );
      for (final name in const ['DeviceModelName', 'DeviceModelVersion']) {
        final value = suppliedHeaders[name];
        if (value is String && value.isNotEmpty) {
          upstream.headers.set(name, value);
        }
      }
      final body = payload['body'];
      if (body != null) {
        upstream.headers.contentType = ContentType.json;
        upstream.write(jsonEncode(body));
      }
      final response = await upstream.close();
      final rawBody = await response.transform(utf8.decoder).join();
      return FiscalReply(response.statusCode, rawBody);
    })().timeout(const Duration(seconds: 40));
  } finally {
    client.close(force: true);
  }
}

bool _validZimraPath(String path) {
  return RegExp(
    r'^/(Public/v1/(?:\d+/(?:RegisterDevice|VerifyTaxpayerInformation)|GetServerCertificate)|Device/v1/\d+/(?:CloseDay|GetConfig|GetStatus|IssueCertificate|OpenDay|Ping|SubmitFile|SubmitReceipt|SubmittedFileList))$',
  ).hasMatch(path);
}

Future<void> _serveWebFile(HttpRequest request, Directory webRoot) async {
  if (request.method != 'GET' && request.method != 'HEAD') {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    await request.response.close();
    return;
  }
  final segments = request.uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.any(
    (segment) =>
        segment == '..' ||
        segment.contains('/') ||
        segment.contains('\\') ||
        segment.contains(':') ||
        segment.contains('\x00'),
  )) {
    request.response.statusCode = HttpStatus.badRequest;
    await request.response.close();
    return;
  }

  var file = File(
    '${webRoot.path}${Platform.pathSeparator}${segments.join(Platform.pathSeparator)}',
  );
  if (segments.isEmpty || !await file.exists()) {
    file = File('${webRoot.path}${Platform.pathSeparator}index.html');
  }
  // Resolve filesystem links as well as encoded URL components. A symlink or
  // junction inside the public directory must not expose a private file.
  final rootPath = await webRoot.resolveSymbolicLinks();
  final filePath = await file.resolveSymbolicLinks();
  final rootBoundary = rootPath.endsWith(Platform.pathSeparator)
      ? rootPath
      : '$rootPath${Platform.pathSeparator}';
  final withinRoot = Platform.isWindows
      ? filePath.toLowerCase().startsWith(rootBoundary.toLowerCase())
      : filePath.startsWith(rootBoundary);
  if (!withinRoot) {
    request.response.statusCode = HttpStatus.badRequest;
    await request.response.close();
    return;
  }
  final extension = file.path.contains('.')
      ? file.path.substring(file.path.lastIndexOf('.')).toLowerCase()
      : '';
  request.response.headers.set(
    HttpHeaders.contentTypeHeader,
    _contentTypes[extension] ?? 'application/octet-stream',
  );
  request.response.headers.set(
    HttpHeaders.cacheControlHeader,
    extension == '.html' ? 'no-cache' : 'public, max-age=86400',
  );
  if (request.method == 'GET') {
    await request.response.addStream(file.openRead());
  }
  await request.response.close();
}

void _setCorsHeaders(HttpRequest request) {
  final allowedOrigin = Platform.environment['WEB_ALLOWED_ORIGIN'];
  final origin = request.headers.value('origin');
  if (allowedOrigin != null && origin == allowedOrigin) {
    request.response.headers
      ..set(HttpHeaders.accessControlAllowOriginHeader, allowedOrigin)
      ..set(HttpHeaders.accessControlAllowMethodsHeader, 'POST, OPTIONS')
      ..set(
        HttpHeaders.accessControlAllowHeadersHeader,
        'Content-Type, Authorization',
      );
  }
}

Future<void> _jsonResponse(
  HttpResponse response,
  int statusCode,
  Map<String, dynamic> body,
) async {
  response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await response.close();
}
