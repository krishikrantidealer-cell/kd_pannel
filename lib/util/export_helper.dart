// export_helper.dart
// Unified export helper using conditional imports to support both Web and VM compilation.

import 'export_helper_stub.dart'
    if (dart.library.html) 'export_helper_web.dart' as helper;

/// Downloads the given CSV content as a file with the specified filename.
/// On Web, this triggers a browser download dialog to save to the local downloads folder.
void downloadCsv(String csvContent, String fileName) {
  helper.saveCsvFile(csvContent, fileName);
}
