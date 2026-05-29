import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:url_launcher/url_launcher.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/features/shared/widgets/stat_card_widget.dart';

class CategoriesTabView extends StatefulWidget {
  final List<dynamic> categories;
  final List<Map<String, dynamic>> products;
  final VoidCallback onRefresh;

  const CategoriesTabView({
    super.key,
    required this.categories,
    required this.products,
    required this.onRefresh,
  });

  @override
  State<CategoriesTabView> createState() => _CategoriesTabViewState();
}

class _CategoriesTabViewState extends State<CategoriesTabView> {
  String _categorySearchQuery = '';
  Map<String, int> _categoryProductCounts = {};
  Map<String, int> _subCategoryProductCounts =
      {}; // Key: "categoryName_subCategoryName"
  String? _selectedCategoryId;

  // Filter cache
  List<dynamic> _cachedFilteredCategories = [];
  String _lastSearchQuery = '';
  List<dynamic>? _lastCategories;

  @override
  void initState() {
    super.initState();
    _calculateProductCounts();
  }

  @override
  void didUpdateWidget(covariant CategoriesTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products) {
      _calculateProductCounts();
    }
  }

  void _calculateProductCounts() {
    final catCounts = <String, int>{};
    final subCatCounts = <String, int>{};

    for (final p in widget.products) {
      final cat = p['category']?.toString() ?? '';
      final sub = p['subCategory']?.toString() ?? '';

      catCounts[cat] = (catCounts[cat] ?? 0) + 1;
      final subKey = '${cat}_$sub';
      subCatCounts[subKey] = (subCatCounts[subKey] ?? 0) + 1;
    }

    _categoryProductCounts = catCounts;
    _subCategoryProductCounts = subCatCounts;
  }

  List<dynamic> get _filteredCategories {
    if (_lastCategories == widget.categories &&
        _lastSearchQuery == _categorySearchQuery) {
      return _cachedFilteredCategories;
    }
    _lastCategories = widget.categories;
    _lastSearchQuery = _categorySearchQuery;

    _cachedFilteredCategories = widget.categories.where((cat) {
      final name = cat['name']?.toString().toLowerCase() ?? '';
      return name.contains(_categorySearchQuery.toLowerCase());
    }).toList();

    return _cachedFilteredCategories;
  }

  int _getProductCountForCategory(String categoryName) {
    return _categoryProductCounts[categoryName] ?? 0;
  }

  int _getProductCountForSubCategory(
    String categoryName,
    String subCategoryName,
  ) {
    return _subCategoryProductCounts['${categoryName}_$subCategoryName'] ?? 0;
  }

  Future<void> _createCategory() async {
    final TextEditingController controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        Uint8List? categoryImage;
        fp.PlatformFile? cataloguePdfFile;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Create Category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Category Name',
                          hintText: 'e.g. Fertilizers',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter category name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Category Banner Image',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          try {
                            final XFile? image = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 800,
                              maxHeight: 600,
                              imageQuality: 85,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              final Uint8List? editedImage =
                                  await Navigator.push(
                                    ctx,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ImageEditor(image: bytes),
                                    ),
                                  );
                              if (editedImage != null) {
                                setState(() {
                                  categoryImage = editedImage;
                                });
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Failed to pick image: $e'),
                              ),
                            );
                          }
                        },
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: categoryImage != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        categoryImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            categoryImage = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.cloud_upload_outlined,
                                      color: AppTheme.textSecondary,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Click to upload banner image',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Category Catalogue PDF',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          try {
                            fp.FilePickerResult? result =
                                await fp.FilePicker.pickFiles(
                                  type: fp.FileType.custom,
                                  allowedExtensions: ['pdf'],
                                  withData: true,
                                );
                            if (result != null && result.files.isNotEmpty) {
                              setState(() {
                                cataloguePdfFile = result.files.first;
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Failed to pick PDF: $e')),
                            );
                          }
                        },
                        child: Container(
                          height: 72,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: cataloguePdfFile != null
                              ? Row(
                                  children: [
                                    const SizedBox(width: 16),
                                    const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: Colors.redAccent,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cataloguePdfFile!.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${(cataloguePdfFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: AppTheme.textSecondary,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          cataloguePdfFile = null;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.document_scanner_outlined,
                                      color: AppTheme.textSecondary,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Click to upload catalogue PDF',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            http.Response response;
                            final List<http.MultipartFile> multipartFiles = [];
                            if (categoryImage != null) {
                              multipartFiles.add(
                                http.MultipartFile.fromBytes(
                                  'image',
                                  categoryImage!,
                                  filename: 'category_banner.jpg',
                                  contentType: MediaType('image', 'jpeg'),
                                ),
                              );
                            }
                            if (cataloguePdfFile != null &&
                                cataloguePdfFile!.bytes != null) {
                              multipartFiles.add(
                                http.MultipartFile.fromBytes(
                                  'cataloguePdf',
                                  cataloguePdfFile!.bytes!,
                                  filename: cataloguePdfFile!.name,
                                  contentType: MediaType('application', 'pdf'),
                                ),
                              );
                            }

                            if (multipartFiles.isNotEmpty) {
                              response = await ApiClient().multipartRequest(
                                method: 'POST',
                                endpoint: '/products/categories',
                                fields: {'name': controller.text.trim()},
                                files: multipartFiles,
                              );
                            } else {
                              response = await ApiClient().post(
                                '/products/categories',
                                {'name': controller.text.trim()},
                              );
                            }
                            if (response.statusCode == 201) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Category created successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              final err = jsonDecode(response.body);
                              throw Exception(
                                err['message'] ?? 'Failed to create category',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Create',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editCategory(dynamic cat) async {
    final TextEditingController controller = TextEditingController(
      text: cat['name'],
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        Uint8List? categoryImage;
        String? existingImageUrl = cat['bannerImage'];
        fp.PlatformFile? cataloguePdfFile;
        String? existingPdfUrl = cat['cataloguePdf'];
        bool deletedExistingPdf = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Edit Category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Category Name',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter category name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Category Banner Image',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          try {
                            final XFile? image = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 800,
                              maxHeight: 600,
                              imageQuality: 85,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              final Uint8List? editedImage =
                                  await Navigator.push(
                                    ctx,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ImageEditor(image: bytes),
                                    ),
                                  );
                              if (editedImage != null) {
                                setState(() {
                                  categoryImage = editedImage;
                                  existingImageUrl = null;
                                });
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Failed to pick image: $e'),
                              ),
                            );
                          }
                        },
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child:
                              (categoryImage != null ||
                                  existingImageUrl != null)
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: categoryImage != null
                                          ? Image.memory(
                                              categoryImage!,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.network(
                                              existingImageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => const Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                            ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            categoryImage = null;
                                            existingImageUrl = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.cloud_upload_outlined,
                                      color: AppTheme.textSecondary,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Click to upload banner image',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Category Catalogue PDF',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          try {
                            fp.FilePickerResult? result =
                                await fp.FilePicker.pickFiles(
                                  type: fp.FileType.custom,
                                  allowedExtensions: ['pdf'],
                                  withData: true,
                                );
                            if (result != null && result.files.isNotEmpty) {
                              setState(() {
                                cataloguePdfFile = result.files.first;
                                existingPdfUrl = null;
                                deletedExistingPdf = false;
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Failed to pick PDF: $e')),
                            );
                          }
                        },
                        child: Container(
                          height: 72,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child:
                              (cataloguePdfFile != null ||
                                  (existingPdfUrl != null &&
                                      existingPdfUrl!.isNotEmpty))
                              ? Row(
                                  children: [
                                    const SizedBox(width: 16),
                                    const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: Colors.redAccent,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cataloguePdfFile != null
                                                ? cataloguePdfFile!.name
                                                : 'catalogue_document.pdf',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (cataloguePdfFile != null)
                                            Text(
                                              '${(cataloguePdfFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary,
                                              ),
                                            )
                                          else
                                            GestureDetector(
                                              onTap: () async {
                                                if (existingPdfUrl != null) {
                                                  final uri = Uri.parse(
                                                    existingPdfUrl!,
                                                  );
                                                  if (await canLaunchUrl(uri)) {
                                                    await launchUrl(uri);
                                                  }
                                                }
                                              },
                                              child: Text(
                                                'Click to view uploaded PDF',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  color: AppTheme.primaryColor,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: AppTheme.textSecondary,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          cataloguePdfFile = null;
                                          existingPdfUrl = null;
                                          deletedExistingPdf = true;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.document_scanner_outlined,
                                      color: AppTheme.textSecondary,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Click to upload catalogue PDF',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            http.Response response;
                            final List<http.MultipartFile> multipartFiles = [];
                            final Map<String, String> fields = {
                              'name': controller.text.trim(),
                            };

                            if (categoryImage != null) {
                              multipartFiles.add(
                                http.MultipartFile.fromBytes(
                                  'image',
                                  categoryImage!,
                                  filename: 'category_banner.jpg',
                                  contentType: MediaType('image', 'jpeg'),
                                ),
                              );
                            } else if (existingImageUrl == null) {
                              fields['bannerImage'] = '';
                            }

                            if (cataloguePdfFile != null &&
                                cataloguePdfFile!.bytes != null) {
                              multipartFiles.add(
                                http.MultipartFile.fromBytes(
                                  'cataloguePdf',
                                  cataloguePdfFile!.bytes!,
                                  filename: cataloguePdfFile!.name,
                                  contentType: MediaType('application', 'pdf'),
                                ),
                              );
                            } else if (deletedExistingPdf) {
                              fields['cataloguePdf'] = '';
                            }

                            if (multipartFiles.isNotEmpty) {
                              response = await ApiClient().multipartRequest(
                                method: 'PUT',
                                endpoint: '/products/categories/${cat['_id']}',
                                fields: fields,
                                files: multipartFiles,
                              );
                            } else {
                              final Map<String, dynamic> body = Map.from(
                                fields,
                              );
                              response = await ApiClient().put(
                                '/products/categories/${cat['_id']}',
                                body,
                              );
                            }
                            if (response.statusCode == 200) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Category updated successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              throw Exception('Failed to update category');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCategory(dynamic cat) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Delete Category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Are you sure you want to delete category "${cat['name']}"? All associated products will have their category removed. This action cannot be undone.',
                style: GoogleFonts.outfit(fontSize: 13.5, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            final response = await ApiClient().delete(
                              '/products/categories/${cat['_id']}',
                            );
                            if (response.statusCode == 200) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Category deleted successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              throw Exception('Failed to delete category');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Delete',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addSubCategory(dynamic cat) async {
    final TextEditingController controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Add Sub-category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Sub-category Name',
                    hintText: 'e.g. Organic, Chemical',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter sub-category name';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            final response = await ApiClient().post(
                              '/products/categories/${cat['_id']}/subcategories',
                              {'name': controller.text.trim()},
                            );
                            if (response.statusCode == 201) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sub-category added successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              throw Exception('Failed to add sub-category');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Add',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editSubCategory(dynamic cat, dynamic sub) async {
    final TextEditingController controller = TextEditingController(
      text: sub['name'],
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Rename Sub-category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Sub-category Name',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter sub-category name';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            final response = await ApiClient().put(
                              '/products/categories/${cat['_id']}/subcategories/${sub['_id']}',
                              {'name': controller.text.trim()},
                            );
                            if (response.statusCode == 200) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sub-category renamed successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              throw Exception('Failed to rename sub-category');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSubCategory(dynamic cat, dynamic sub) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Delete Sub-category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Are you sure you want to delete sub-category "${sub['name']}"? Associated products will have their sub-category reference cleared.',
                style: GoogleFonts.outfit(fontSize: 13.5, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            final response = await ApiClient().delete(
                              '/products/categories/${cat['_id']}/subcategories/${sub['_id']}',
                            );
                            if (response.statusCode == 200) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sub-category deleted successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              throw Exception('Failed to delete sub-category');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Delete',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickStats() {
    final totalCategories = widget.categories.length;

    int totalSubCategories = 0;
    for (final cat in widget.categories) {
      final List subs = cat['subCategories'] as List? ?? [];
      totalSubCategories += subs.length;
    }

    int categorizedProducts = 0;
    final Map<String, int> catCounts = {};
    for (final p in widget.products) {
      final cat = p['category']?.toString() ?? '';
      if (cat.isNotEmpty && cat != 'N/A') {
        categorizedProducts++;
        catCounts[cat] = (catCounts[cat] ?? 0) + 1;
      }
    }

    String topCategory = 'None';
    int maxCount = 0;
    catCounts.forEach((catName, count) {
      if (count > maxCount) {
        maxCount = count;
        topCategory = catName;
      }
    });

    final stats = [
      {
        'title': 'Total Categories',
        'value': '$totalCategories',
        'icon': Icons.category_rounded,
        'color': AppTheme.primaryColor,
      },
      {
        'title': 'Total Sub-categories',
        'value': '$totalSubCategories',
        'icon': Icons.schema_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Categorized Products',
        'value': '$categorizedProducts',
        'icon': Icons.inventory_2_rounded,
        'color': AppTheme.success,
      },
      {
        'title': 'Top Category',
        'value': topCategory,
        'icon': Icons.emoji_events_rounded,
        'color': const Color(0xFFF59E0B),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 16.0;
        final int columns = constraints.maxWidth >= 600 ? 4 : 2;
        final double cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats.map((stat) {
            return StatCardWidget(
              width: cardWidth,
              isCompact: true,
              title: stat['title'] as String,
              value: stat['value'] as String,
              icon: stat['icon'] as IconData,
              color: stat['color'] as Color,
            );
          }).toList(),
        );
      },
    );
  }

  dynamic get _selectedCategory {
    if (_selectedCategoryId == null) return null;
    try {
      return widget.categories.firstWhere(
        (cat) => cat['_id'] == _selectedCategoryId,
        orElse: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  void _showMobileCategoryDetails(dynamic cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                controller: controller,
                child: _CategoryDetailsPanel(
                  category: cat,
                  productCount: _getProductCountForCategory(cat['name'] ?? ''),
                  onEditCategory: _editCategory,
                  onDeleteCategory: (c) async {
                    Navigator.pop(ctx);
                    await _deleteCategory(c);
                  },
                  onAddSubCategory: _addSubCategory,
                  onEditSubCategory: _editSubCategory,
                  onDeleteSubCategory: _deleteSubCategory,
                  getSubProductCount: _getProductCountForSubCategory,
                  onRefresh: widget.onRefresh,
                  isMobileSheet: true,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: const Center(
        child: Text(
          'No categories found',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    final bool isSmallMobile = MediaQuery.of(context).size.width < 400;
    final filtered = _filteredCategories;
    final selectedCat = _selectedCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuickStats(),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: TextField(
                  onChanged: (val) =>
                      setState(() => _categorySearchQuery = val),
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search category name...',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            isSmallMobile
                ? IconButton(
                    onPressed: _createCategory,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(10),
                    ),
                    tooltip: 'Add Category',
                  )
                : ElevatedButton.icon(
                    onPressed: _createCategory,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(isMobile ? 'Add' : 'Add Category'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Compact grid of category cards
            Expanded(
              flex: (selectedCat != null && !isMobile) ? 3 : 1,
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isMobile
                            ? MediaQuery.of(context).size.width
                            : (selectedCat != null ? 300 : 400),
                        mainAxisExtent: isMobile ? 96 : 110,
                        crossAxisSpacing: isMobile ? 10 : 16,
                        mainAxisSpacing: isMobile ? 10 : 16,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final cat = filtered[index];
                        final catName = cat['name'] ?? '';
                        final productCount = _getProductCountForCategory(
                          catName,
                        );
                        final subs = cat['subCategories'] as List? ?? [];
                        final isSelected = _selectedCategoryId == cat['_id'];

                        return _AnimatedListItem(
                          index: index,
                          child: CategoryCompactCardWidget(
                            category: cat,
                            productCount: productCount,
                            subCategoriesCount: subs.length,
                            isSelected: isSelected && !isMobile,
                            onTap: () {
                              if (isMobile) {
                                _showMobileCategoryDetails(cat);
                              } else {
                                setState(() {
                                  if (isSelected) {
                                    _selectedCategoryId = null;
                                  } else {
                                    _selectedCategoryId = cat['_id'];
                                  }
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
            // Right Column: Split details panel on desktop
            if (selectedCat != null && !isMobile) ...[
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 500,
                  child: _CategoryDetailsPanel(
                    category: selectedCat,
                    productCount: _getProductCountForCategory(
                      selectedCat['name'] ?? '',
                    ),
                    onEditCategory: _editCategory,
                    onDeleteCategory: (c) async {
                      setState(() {
                        _selectedCategoryId = null;
                      });
                      await _deleteCategory(c);
                    },
                    onAddSubCategory: _addSubCategory,
                    onEditSubCategory: _editSubCategory,
                    onDeleteSubCategory: _deleteSubCategory,
                    getSubProductCount: _getProductCountForSubCategory,
                    onRefresh: widget.onRefresh,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class CategoryCompactCardWidget extends StatefulWidget {
  final dynamic category;
  final int productCount;
  final int subCategoriesCount;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryCompactCardWidget({
    super.key,
    required this.category,
    required this.productCount,
    required this.subCategoriesCount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<CategoryCompactCardWidget> createState() =>
      _CategoryCompactCardWidgetState();
}

class _CategoryCompactCardWidgetState extends State<CategoryCompactCardWidget> {
  bool _isHovered = false;

  Widget _buildBannerPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.12),
            AppTheme.primaryColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.grid_view_rounded,
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catName = widget.category['name'] ?? '';
    final hasBanner =
        widget.category['bannerImage'] != null &&
        widget.category['bannerImage'].toString().isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.primaryColor
                  : (_isHovered
                        ? AppTheme.primaryColor.withValues(alpha: 0.4)
                        : AppTheme.borderColor),
              width: (widget.isSelected || _isHovered) ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.04)
                    : (_isHovered
                          ? AppTheme.primaryColor.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.015)),
                blurRadius: _isHovered ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail Banner Left
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFF3F4F6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: hasBanner
                        ? Image.network(
                            widget.category['bannerImage'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildBannerPlaceholder(),
                          )
                        : _buildBannerPlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                // Metadata Right
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        catName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            size: 13,
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.productCount} Product${widget.productCount != 1 ? 's' : ''}',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schema_rounded,
                            size: 13,
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.subCategoriesCount} Sub-categor${widget.subCategoriesCount != 1 ? 'ies' : 'y'}',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: widget.isSelected
                      ? AppTheme.primaryColor
                      : Colors.grey.shade300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryDetailsPanel extends StatefulWidget {
  final dynamic category;
  final int productCount;
  final Function(dynamic) onEditCategory;
  final Function(dynamic) onDeleteCategory;
  final Function(dynamic) onAddSubCategory;
  final Function(dynamic, dynamic) onEditSubCategory;
  final Function(dynamic, dynamic) onDeleteSubCategory;
  final int Function(String, String) getSubProductCount;
  final VoidCallback onRefresh;
  final bool isMobileSheet;

  const _CategoryDetailsPanel({
    required this.category,
    required this.productCount,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onAddSubCategory,
    required this.onEditSubCategory,
    required this.onDeleteSubCategory,
    required this.getSubProductCount,
    required this.onRefresh,
    this.isMobileSheet = false,
  });

  @override
  State<_CategoryDetailsPanel> createState() => _CategoryDetailsPanelState();
}

class _CategoryDetailsPanelState extends State<_CategoryDetailsPanel> {
  final TextEditingController _newSubNameController = TextEditingController();
  bool _isAddingSub = false;

  @override
  void dispose() {
    _newSubNameController.dispose();
    super.dispose();
  }

  Future<void> _submitNewSub() async {
    final name = _newSubNameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isAddingSub = true;
    });

    try {
      final response = await ApiClient().post(
        '/products/categories/${widget.category['_id']}/subcategories',
        {'name': name},
      );
      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sub-category added successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
        _newSubNameController.clear();
        widget.onRefresh();
      } else {
        throw Exception('Failed to add sub-category');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingSub = false;
        });
      }
    }
  }

  Future<void> _showEditSubCategoryDialog(dynamic sub) async {
    final TextEditingController controller = TextEditingController(
      text: sub['name'],
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        Uint8List? subImage;
        String? existingImageUrl = sub['bannerImage'];

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Edit Sub-category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Sub-category Name',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter sub-category name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Sub-category Banner Image',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          try {
                            final XFile? image = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 800,
                              maxHeight: 600,
                              imageQuality: 85,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              final Uint8List? editedImage =
                                  await Navigator.push(
                                    ctx,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ImageEditor(image: bytes),
                                    ),
                                  );
                              if (editedImage != null) {
                                setState(() {
                                  subImage = editedImage;
                                  existingImageUrl = null;
                                });
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Failed to pick image: $e'),
                              ),
                            );
                          }
                        },
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: (subImage != null || existingImageUrl != null)
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: subImage != null
                                          ? Image.memory(
                                              subImage!,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.network(
                                              existingImageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => const Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                            ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            subImage = null;
                                            existingImageUrl = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.cloud_upload_outlined,
                                      color: AppTheme.textSecondary,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Click to upload sub-banner image',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            http.Response response;
                            if (subImage != null) {
                              response = await ApiClient().multipartRequest(
                                method: 'PUT',
                                endpoint:
                                    '/products/categories/${widget.category['_id']}/subcategories/${sub['_id']}',
                                fields: {'name': controller.text.trim()},
                                files: [
                                  http.MultipartFile.fromBytes(
                                    'image',
                                    subImage!,
                                    filename: 'subcategory_banner.jpg',
                                    contentType: MediaType('image', 'jpeg'),
                                  ),
                                ],
                              );
                            } else {
                              final Map<String, dynamic> body = {
                                'name': controller.text.trim(),
                              };
                              if (existingImageUrl == null) {
                                body['bannerImage'] = '';
                              }
                              response = await ApiClient().put(
                                '/products/categories/${widget.category['_id']}/subcategories/${sub['_id']}',
                                body,
                              );
                            }
                            if (response.statusCode == 200) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sub-category updated successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              throw Exception('Failed to update sub-category');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSub(dynamic sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Sub-category',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete sub-category "${sub['name']}"? Associated products will lose their sub-category reference.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiClient().delete(
        '/products/categories/${widget.category['_id']}/subcategories/${sub['_id']}',
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sub-category deleted successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
        widget.onRefresh();
      } else {
        throw Exception('Failed to delete sub-category');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catName = widget.category['name'] ?? '';
    final hasBanner =
        widget.category['bannerImage'] != null &&
        widget.category['bannerImage'].toString().isNotEmpty;
    final List subs = widget.category['subCategories'] as List? ?? [];
    final totalProds = widget.productCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: widget.isMobileSheet
            ? null
            : Border.all(color: AppTheme.borderColor),
        boxShadow: widget.isMobileSheet
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cover Banner Image
          Stack(
            children: [
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(15),
                    bottom: widget.isMobileSheet
                        ? const Radius.circular(15)
                        : Radius.zero,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.9),
                      AppTheme.primaryColor.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(15),
                    bottom: widget.isMobileSheet
                        ? const Radius.circular(15)
                        : Radius.zero,
                  ),
                  child: hasBanner
                      ? Image.network(
                          widget.category['bannerImage'],
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withValues(alpha: 0.2),
                                AppTheme.primaryColor.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.grid_view_rounded,
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.3,
                              ),
                              size: 48,
                            ),
                          ),
                        ),
                ),
              ),
              // Dark gradient overlay
              Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(15),
                    bottom: widget.isMobileSheet
                        ? const Radius.circular(15)
                        : Radius.zero,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              // Text Metadata overlay
              Positioned(
                bottom: 16,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalProds Total Product${totalProds != 1 ? 's' : ''}',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Edit/Delete controls top right
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black38,
                        hoverColor: Colors.black54,
                      ),
                      tooltip: 'Edit Category',
                      onPressed: () => widget.onEditCategory(widget.category),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black38,
                        hoverColor: Colors.black54,
                      ),
                      tooltip: 'Delete Category',
                      onPressed: () => widget.onDeleteCategory(widget.category),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Catalogue PDF Preview
          if (widget.category['cataloguePdf'] != null &&
              widget.category['cataloguePdf'].toString().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CATALOGUE PDF',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.redAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Catalogue Document',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(
                              widget.category['cataloguePdf'],
                            );
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: Text(
                            'View PDF',
                            style: GoogleFonts.outfit(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. Sub-categories Section Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SUB-CATEGORIES',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),

                // Inline insertion textbox
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 12),
                      Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _newSubNameController,
                          style: GoogleFonts.outfit(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Add new sub-category...',
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                          ),
                          onSubmitted: (_) => _submitNewSub(),
                        ),
                      ),
                      _isAddingSub
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : TextButton(
                              onPressed: _submitNewSub,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Add',
                                style: GoogleFonts.outfit(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Subcategories list
          if (!widget.isMobileSheet)
            Expanded(
              child: subs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 20,
                      ),
                      child: Center(
                        child: Text(
                          'No sub-categories created yet.\nType name above and click "Add" to create one.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        bottom: 20,
                      ),
                      itemCount: subs.length,
                      itemBuilder: (context, index) {
                        final sub = subs[index];
                        final subName = sub['name'] ?? '';
                        final subCount = widget.getSubProductCount(
                          catName,
                          subName,
                        );
                        final share = totalProds > 0
                            ? (subCount / totalProds)
                            : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SubCategoryTileWidget(
                            sub: sub,
                            count: subCount,
                            share: share,
                            onEdit: () => _showEditSubCategoryDialog(sub),
                            onDelete: () => _deleteSub(sub),
                            isMobile: false,
                          ),
                        );
                      },
                    ),
            )
          else ...[
            if (subs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                child: Center(
                  child: Text(
                    'No sub-categories created yet.\nType name above and click "Add" to create one.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subs.length,
                itemBuilder: (context, index) {
                  final sub = subs[index];
                  final subName = sub['name'] ?? '';
                  final subCount = widget.getSubProductCount(catName, subName);
                  final share = totalProds > 0 ? (subCount / totalProds) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SubCategoryTileWidget(
                      sub: sub,
                      count: subCount,
                      share: share,
                      onEdit: () => _showEditSubCategoryDialog(sub),
                      onDelete: () => _deleteSub(sub),
                      isMobile: true,
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _SubCategoryTileWidget extends StatefulWidget {
  final dynamic sub;
  final int count;
  final double share;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isMobile;

  const _SubCategoryTileWidget({
    required this.sub,
    required this.count,
    required this.share,
    required this.onEdit,
    required this.onDelete,
    this.isMobile = false,
  });

  @override
  State<_SubCategoryTileWidget> createState() => _SubCategoryTileWidgetState();
}

class _SubCategoryTileWidgetState extends State<_SubCategoryTileWidget> {
  bool _isHovered = false;

  Widget _buildSubBannerPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.primaryColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.subdirectory_arrow_right_rounded,
          color: AppTheme.primaryColor.withValues(alpha: 0.35),
          size: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String subName = widget.sub['name'] ?? '';
    final percentageDisplay = (widget.share * 100).toStringAsFixed(0);
    final hasBanner =
        widget.sub['bannerImage'] != null &&
        widget.sub['bannerImage'].toString().isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Sub-category Thumbnail
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFFF3F4F6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: hasBanner
                        ? Image.network(
                            widget.sub['bannerImage'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildSubBannerPlaceholder(),
                          )
                        : _buildSubBannerPlaceholder(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subName,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                // Badge Count
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.count} Product${widget.count != 1 ? 's' : ''}',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Actions: always visible on touch devices, subtle on desktop hover
                Builder(
                  builder: (context) {
                    final isTouchDevice =
                        MediaQuery.of(context).size.width < 768;
                    if (isTouchDevice) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: widget.onEdit,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: widget.onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 15,
                                color: AppTheme.error,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: AppTheme.textSecondary,
                            onPressed: widget.onEdit,
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 14,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: AppTheme.error,
                            onPressed: widget.onDelete,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: widget.share,
                      backgroundColor: const Color(0xFFF3F4F6),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor.withValues(alpha: 0.6),
                      ),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$percentageDisplay%',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedListItem({required this.index, required this.child});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final delayIndex = widget.index.clamp(0, 8);
    Future.delayed(Duration(milliseconds: delayIndex * 40), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
