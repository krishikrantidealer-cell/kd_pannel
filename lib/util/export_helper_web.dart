// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// export_helper_web.dart
// Web implementation of CSV file saving using dart:html.

import 'dart:convert';
import 'dart:html' as html;

void saveCsvFile(String csvContent, String fileName) {
  // Convert CSV content to UTF-8 bytes
  final bytes = utf8.encode(csvContent);
  
  // Create a Blob from the bytes
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  
  // Create an Object URL for the blob
  final url = html.Url.createObjectUrlFromBlob(blob);
  
  // Create a temporary AnchorElement to trigger the download
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  
  // Append to the DOM, click, and clean up
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  
  // Revoke the Object URL to release memory
  html.Url.revokeObjectUrl(url);
}
