import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/services/telephony_audio_service.dart';

/// Modal dialog for uploading and sending WhatsApp images and document attachments
class WhatsAppMediaPickerDialog extends StatefulWidget {
  final String conversationId;
  final String mediaType; // 'Image' or 'Document'
  final PlatformFile? initialFile;
  final VoidCallback? onMediaSent;

  const WhatsAppMediaPickerDialog({
    super.key,
    required this.conversationId,
    required this.mediaType,
    this.initialFile,
    this.onMediaSent,
  });

  static void show(
    BuildContext context, {
    required String conversationId,
    required String mediaType,
    PlatformFile? initialFile,
    VoidCallback? onMediaSent,
  }) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppMediaPickerDialog(
        conversationId: conversationId,
        mediaType: mediaType,
        initialFile: initialFile,
        onMediaSent: onMediaSent,
      ),
    );
  }

  @override
  State<WhatsAppMediaPickerDialog> createState() => _WhatsAppMediaPickerDialogState();
}

class _WhatsAppMediaPickerDialogState extends State<WhatsAppMediaPickerDialog> {
  int _selectedTab = 0; // 0: device file, 1: direct URL
  PlatformFile? _selectedFile;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _selectedFile = widget.initialFile;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isImage = widget.mediaType == 'Image';
    final Color accentColor = isImage ? const Color(0xFF008069) : const Color(0xFF2563EB);
    final Color accentBg = isImage ? const Color(0xFF008069).withValues(alpha: 0.1) : const Color(0xFF2563EB).withValues(alpha: 0.1);

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: accentBg, shape: BoxShape.circle),
                      child: Icon(
                        isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isImage ? 'Send Photo / Image' : 'Send Document / File',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color(0xFF111B21),
                          ),
                        ),
                        Text(
                          isImage ? 'Upload PNG, JPG, WebP from device or URL' : 'Upload PDF, DOCX, XLSX catalogs from device or URL',
                          style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: _isUploading ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mode Switcher
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _isUploading ? null : () => setState(() => _selectedTab = 0),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: _selectedTab == 0
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file_rounded, size: 16, color: _selectedTab == 0 ? accentColor : const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              'Browse Device File',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                                color: _selectedTab == 0 ? accentColor : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _isUploading ? null : () => setState(() => _selectedTab = 1),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: _selectedTab == 1
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.link_rounded, size: 16, color: _selectedTab == 1 ? accentColor : const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              'Paste Direct URL',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                                color: _selectedTab == 1 ? accentColor : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedTab == 0) ...[
              // File Picker Box
              InkWell(
                onTap: _isUploading
                    ? null
                    : () async {
                        final allowedExts = isImage
                            ? ['jpg', 'jpeg', 'png', 'webp']
                            : ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'png', 'jpg', 'jpeg'];
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: allowedExts,
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          setState(() {
                            _selectedFile = result.files.first;
                          });
                        }
                      },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _selectedFile == null ? const Color(0xFFF8FAFC) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedFile != null ? accentColor : const Color(0xFFCBD5E1),
                      width: _selectedFile != null ? 1.5 : 1.0,
                    ),
                  ),
                  child: _selectedFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isImage ? Icons.add_photo_alternate_outlined : Icons.note_add_outlined,
                              size: 36,
                              color: accentColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isImage ? 'Click to select an image' : 'Click to select a document / catalog',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isImage ? 'PNG, JPG, WebP up to 16MB' : 'PDF, DOCX, XLSX, CSV up to 32MB',
                              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            if (isImage && _selectedFile!.bytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _selectedFile!.bytes!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: accentBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
                                  color: accentColor,
                                  size: 28,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFile!.name,
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                                          style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Ready to dispatch',
                                        style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.change_circle_outlined, color: accentColor, size: 24),
                              tooltip: 'Change File',
                              onPressed: _isUploading
                                  ? null
                                  : () async {
                                      final allowedExts = isImage
                                          ? ['jpg', 'jpeg', 'png', 'webp']
                                          : ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'png', 'jpg', 'jpeg'];
                                      final result = await FilePicker.pickFiles(
                                        type: FileType.custom,
                                        allowedExtensions: allowedExts,
                                        withData: true,
                                      );
                                      if (result != null && result.files.isNotEmpty) {
                                        setState(() {
                                          _selectedFile = result.files.first;
                                        });
                                      }
                                    },
                            ),
                          ],
                        ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _urlController,
                enabled: !_isUploading,
                decoration: InputDecoration(
                  labelText: isImage ? 'Image Direct URL' : 'Document Direct URL',
                  hintText: isImage ? 'https://storage.googleapis.com/.../photo.jpg' : 'https://example.com/catalog.pdf',
                  labelStyle: GoogleFonts.outfit(color: accentColor, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accentColor, width: 1.5)),
                  isDense: true,
                ),
                style: GoogleFonts.outfit(fontSize: 13.5),
              ),
            ],

            const SizedBox(height: 14),
            TextField(
              controller: _captionController,
              enabled: !_isUploading,
              decoration: InputDecoration(
                labelText: 'Caption (Optional)',
                hintText: isImage ? 'e.g. Here is the requested product photo' : 'e.g. Please review our latest product catalog',
                labelStyle: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              style: GoogleFonts.outfit(fontSize: 13.5),
            ),

            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: _isUploading ? null : () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                  onPressed: (_isUploading || (_selectedTab == 0 && _selectedFile == null) || (_selectedTab == 1 && _urlController.text.trim().isEmpty))
                      ? null
                      : () async {
                          final conversationId = widget.conversationId;
                          final caption = _captionController.text.trim();

                          setState(() => _isUploading = true);

                          try {
                            String finalMediaUrl = '';

                            if (_selectedTab == 0 && _selectedFile != null) {
                              final bytes = _selectedFile!.bytes;
                              if (bytes == null) throw Exception('Unable to read file bytes');

                              // Determine MIME type
                              final nameLower = _selectedFile!.name.toLowerCase();
                              String mimeType = 'application/octet-stream';
                              if (nameLower.endsWith('.jpg') || nameLower.endsWith('.jpeg')) {
                                mimeType = 'image/jpeg';
                              } else if (nameLower.endsWith('.png')) {
                                mimeType = 'image/png';
                              } else if (nameLower.endsWith('.webp')) {
                                mimeType = 'image/webp';
                              } else if (nameLower.endsWith('.pdf')) {
                                mimeType = 'application/pdf';
                              } else if (nameLower.endsWith('.csv')) {
                                mimeType = 'text/csv';
                              } else if (nameLower.endsWith('.xlsx')) {
                                mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
                              } else if (nameLower.endsWith('.xls')) {
                                mimeType = 'application/vnd.ms-excel';
                              } else if (nameLower.endsWith('.docx')) {
                                mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
                              } else if (nameLower.endsWith('.doc')) {
                                mimeType = 'application/msword';
                              } else if (nameLower.endsWith('.txt')) {
                                mimeType = 'text/plain';
                              } else if (nameLower.endsWith('.zip') || nameLower.endsWith('.rar') || nameLower.endsWith('.7z')) {
                                mimeType = 'application/zip';
                              } else if (nameLower.endsWith('.mp3')) {
                                mimeType = 'audio/mpeg';
                              } else if (nameLower.endsWith('.ogg')) {
                                mimeType = 'audio/ogg';
                              } else if (nameLower.endsWith('.mp4')) {
                                mimeType = 'video/mp4';
                              }

                              // Step 1: Direct authenticated upload to MyOperator WhatsApp Free Media Vault (Zero GCS Storage Cost)
                              bool uploadSuccess = false;
                              try {
                                final res = await ApiClient().multipartRequest(
                                  method: 'POST',
                                  endpoint: '/conversations/media/upload',
                                  fields: {},
                                  filesBuilder: () => [
                                    http.MultipartFile.fromBytes(
                                      'file',
                                      bytes,
                                      filename: _selectedFile!.name,
                                      contentType: MediaType.parse(mimeType),
                                    ),
                                  ],
                                );

                                if (res.statusCode == 200) {
                                  final decoded = jsonDecode(res.body);
                                  if (decoded['success'] == true) {
                                    finalMediaUrl = decoded['data']?['mediaUrl'] ?? decoded['mediaUrl'] ?? '';
                                    if (finalMediaUrl.isNotEmpty) {
                                      uploadSuccess = true;
                                    }
                                  }
                                }
                              } catch (uploadErr) {
                                debugPrint('[WhatsApp CRM] Direct MyOperator media upload fallback: $uploadErr');
                              }

                              // Step 2: Fallback to GCS Presigned URL if MyOperator direct upload had an issue
                              if (!uploadSuccess) {
                                try {
                                  final urlRes = await ApiClient().post('/conversations/media/upload-url', {
                                    'fileName': _selectedFile!.name,
                                    'mimeType': mimeType,
                                  });
                                  if (urlRes.statusCode == 200) {
                                    final urlData = jsonDecode(urlRes.body);
                                    if (urlData['success'] == true && urlData['data']?['uploadUrl'] != null) {
                                      final uploadUrl = urlData['data']['uploadUrl'].toString();
                                      final publicUrl = urlData['data']['mediaUrl'].toString();

                                      final gcsRes = await http.put(
                                        Uri.parse(uploadUrl),
                                        headers: {'Content-Type': mimeType},
                                        body: bytes,
                                      );
                                      if (gcsRes.statusCode == 200) {
                                        finalMediaUrl = publicUrl;
                                        uploadSuccess = true;
                                      }
                                    }
                                  }
                                } catch (gcsErr) {
                                  debugPrint('[WhatsApp CRM] GCS upload fallback: $gcsErr');
                                }
                              }
                            } else {
                              finalMediaUrl = _urlController.text.trim();
                            }

                            if (finalMediaUrl.isEmpty) throw Exception('Media URL could not be generated');

                            // Send WhatsApp message
                            final sendRes = await ApiClient().post('/messages/send', {
                              'conversationId': conversationId,
                              'type': widget.mediaType,
                              'content': caption,
                              'mediaUrl': finalMediaUrl,
                            });

                            if (sendRes.statusCode == 200 || sendRes.statusCode == 201) {
                              TelephonyAudioService().playOutgoingMessageSentTone();
                              if (context.mounted) {
                                Navigator.pop(context);
                                widget.onMediaSent?.call();
                              }
                            } else {
                              final decoded = jsonDecode(sendRes.body);
                              throw Exception(decoded['message'] ?? 'Failed to send message');
                            }
                          } catch (e) {
                            debugPrint('[WhatsApp CRM] Error uploading media: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isUploading = false);
                          }
                        },
                  child: _isUploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Send ${isImage ? "Photo" : "Document"}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
