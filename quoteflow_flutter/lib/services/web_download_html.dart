// ignore_for_file: deprecated_member_use

import 'dart:html' as html;

void downloadTextFile(String contents, String filename) {
  final blob = html.Blob([contents], 'application/json;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
