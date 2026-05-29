import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:kd_pannel/features/shared/widgets/morphing_save_button.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CreateCollectionPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final List<Map<String, dynamic>> allProducts;
  final ValueChanged<Map<String, dynamic>> onSave;

  const CreateCollectionPage({
    super.key,
    this.initialData,
    required this.allProducts,
    required this.onSave,
  });

  @override
  State<CreateCollectionPage> createState() => _CreateCollectionPageState();
}

class _CreateCollectionPageState extends State<CreateCollectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priorityController = TextEditingController(text: '0');

  Uint8List? _collectionImage;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  // Set of selected product IDs
  final Set<String> _selectedProductIds = {};
  String _productSearchQuery = '';
  bool _isActive = true;
  bool _isParentCollection = false;

  List<dynamic> _parentCollections = [];
  String? _selectedParentId;
  bool _isLoadingParents = false;

  Future<void> _loadParentCollections() async {
    setState(() => _isLoadingParents = true);
    try {
      final response = await ApiClient().get('/collections?all=true');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['collections'] is List) {
          setState(() {
            _parentCollections = data['collections'];
            if (widget.initialData != null) {
              _selectedParentId = widget.initialData!['parentId'];
            } else if (_parentCollections.isNotEmpty) {
              _selectedParentId = _parentCollections.first['_id'];
            }
          });
        }
      }
    } catch (e) {
      print('Error loading parent collections: $e');
    } finally {
      setState(() => _isLoadingParents = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadParentCollections();
    final data = widget.initialData;
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _descController.text = data['description'] ?? '';
      _isActive = data['isActive'] ?? true;
      _isParentCollection = data['parentId'] == null;
      if (_isParentCollection) {
        _priorityController.text = (data['priority'] ?? 0).toString();
      }
      print('=== DEBUG CreateCollectionPage.initState ===');
      print('initialData: ${widget.initialData}');
      print('image value: ${data['image']}');
      print('image type: ${data['image']?.runtimeType}');
      
      if (data['image'] != null) {
        if (data['image'] is String) {
          _existingImageUrl = data['image'];
          print('Assigned to _existingImageUrl: $_existingImageUrl');
        } else if (data['image'] is Uint8List) {
          _collectionImage = data['image'] as Uint8List;
          print('Assigned to _collectionImage');
        }
      }
      print('============================================');

      // Auto-populate selected products based on sub-collection name or ID
      final String colName = data['name'] ?? '';
      final String colId = (data['id'] ?? data['_id'] ?? '').toString();
      for (var prod in widget.allProducts) {
        final List assigned = prod['assignedCollections'] ?? [];
        if (assigned.contains(colName) ||
            (colId.isNotEmpty && assigned.contains(colId))) {
          final String prodId = (prod['id'] ?? prod['_id'] ?? '').toString();
          if (prodId.isNotEmpty) {
            _selectedProductIds.add(prodId);
          }
        }
      }
    } else {
      // Listen to name changes to auto-populate existing products for new collections
      _nameController.addListener(_onNameChanged);
    }
  }

  void _onNameChanged() {
    if (widget.initialData != null) return; // Only apply for new creations
    if (_isParentCollection) return; // Only for sub-collections

    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    bool changed = false;
    for (var prod in widget.allProducts) {
      final List assigned = prod['assignedCollections'] ?? [];
      // If the product already has this exact string tag, auto-check it
      if (assigned.contains(newName)) {
        final String prodId = (prod['id'] ?? prod['_id'] ?? '').toString();
        if (prodId.isNotEmpty && !_selectedProductIds.contains(prodId)) {
          _selectedProductIds.add(prodId);
          changed = true;
        }
      }
    }

    if (changed) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (widget.initialData == null) {
      _nameController.removeListener(_onNameChanged);
    }
    _nameController.dispose();
    _descController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;

        final Uint8List? editedImage = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ImageEditor(image: bytes)),
        );

        if (editedImage != null) {
          setState(() {
            _collectionImage = editedImage;
            _existingImageUrl = null;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  bool _isSaving = false;

  Future<void> _saveCollection() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isParentCollection && _selectedParentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a collection first'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final String name = _nameController.text.trim();
      final bool isActive = _isActive;
      final bool isEdit = widget.initialData != null;

      http.Response response;

      if (!_isParentCollection && _collectionImage != null) {
        final endpoint = isEdit
            ? '/collections/${widget.initialData!['parentId']}/sub/${widget.initialData!['id'] ?? widget.initialData!['_id']}'
            : '/collections/$_selectedParentId/sub';

        final method = isEdit ? 'PUT' : 'POST';
        
        final fields = {
          'name': name,
          'isActive': isActive.toString(),
        };

        final capturedCollectionImage = _collectionImage!;
        response = await ApiClient().multipartRequest(
          method: method,
          endpoint: endpoint,
          fields: fields,
          filesBuilder: () => [
            http.MultipartFile.fromBytes(
              'image',
              capturedCollectionImage,
              filename: 'collection_image.jpg',
              contentType: MediaType('image', 'jpeg'),
            )
          ],
        );
      } else {
        final responseBody = _isParentCollection
            ? {
                'name': name,
                'description': _descController.text.trim(),
                'isActive': isActive,
                'priority': int.tryParse(_priorityController.text) ?? 0,
              }
            : {'name': name, 'isActive': isActive};

        response = _isParentCollection
            ? (isEdit
                  ? await ApiClient().put(
                      '/collections/${widget.initialData!['id'] ?? widget.initialData!['_id']}',
                      responseBody,
                    )
                  : await ApiClient().post('/collections', responseBody))
            : (isEdit
                  ? await ApiClient().put(
                      '/collections/${widget.initialData!['parentId']}/sub/${widget.initialData!['id'] ?? widget.initialData!['_id']}',
                      responseBody,
                    )
                  : await ApiClient().post(
                      '/collections/$_selectedParentId/sub',
                      responseBody,
                    ));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body);

        Map<String, dynamic> savedCol = {};
        if (_isParentCollection) {
          savedCol = resData['collection'] ?? {};
        } else {
          // Try multiple common response formats for sub-collection creation
          savedCol = resData['subCollection'] ?? resData['data'] ?? {};

          // If the backend returned the updated parent collection instead, find our sub-collection in it
          if (savedCol.isEmpty && resData['collection'] != null) {
            final List subs = resData['collection']['subCollections'] ?? [];
            for (var sub in subs) {
              if (sub['name'] == name) {
                savedCol = sub;
                break;
              }
            }
          }
        }

        // Sync products with this collection only if it's a sub-collection
        if (!_isParentCollection) {
          final String colId = (savedCol['_id'] ?? savedCol['id'] ?? '')
              .toString();

          if (colId.isEmpty) {
            // Fallback: If we STILL can't find the ID, we might have a data structure issue.
            // We should print/log this, but for now we fallback to the name so it doesn't break entirely.
            print(
              'WARNING: Could not extract sub-collection ID from response: $resData',
            );
          }
          final String colName = name;
          final String oldName = widget.initialData?['name'] ?? '';

          for (var prod in widget.allProducts) {
            final String prodId = (prod['id'] ?? prod['_id'] ?? '').toString();
            final bool isSelected = _selectedProductIds.contains(prodId);

            final List<String> currentAssigned = List<String>.from(
              prod['assignedCollections'] ?? [],
            );

            bool needsUpdate = false;

            if (isSelected) {
              if (colName.isNotEmpty && !currentAssigned.contains(colName)) {
                currentAssigned.add(colName);
                needsUpdate = true;
              }
              if (colId.isNotEmpty && !currentAssigned.contains(colId)) {
                currentAssigned.add(colId);
                needsUpdate = true;
              }
              if (oldName.isNotEmpty && oldName != colName && currentAssigned.contains(oldName)) {
                currentAssigned.remove(oldName);
                needsUpdate = true;
              }
            } else {
              // Not selected, remove name, ID and oldName
              if (colName.isNotEmpty && currentAssigned.contains(colName)) {
                currentAssigned.remove(colName);
                needsUpdate = true;
              }
              if (colId.isNotEmpty && currentAssigned.contains(colId)) {
                currentAssigned.remove(colId);
                needsUpdate = true;
              }
              if (oldName.isNotEmpty && currentAssigned.contains(oldName)) {
                currentAssigned.remove(oldName);
                needsUpdate = true;
              }
            }

            if (needsUpdate && prodId.isNotEmpty) {
              await ApiClient().put('/products/$prodId', {
                'assignedCollections': currentAssigned,
              });
              prod['assignedCollections'] = currentAssigned;
            }
          }
        }

        widget.onSave(savedCol);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        throw Exception(
          'Server returned status code ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save collection: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.initialData != null 
              ? 'Edit ${_isParentCollection ? 'Collection' : 'Sub-collection'}'
              : 'Create ${_isParentCollection ? 'Collection' : 'Sub-collection'}',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildLeftForm()),
                            if (!_isParentCollection) ...[
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: _buildRightProductsSelector(),
                              ),
                            ],
                          ],
                        )
                      : Column(
                          children: [
                            _buildLeftForm(),
                            if (!_isParentCollection) ...[
                              const SizedBox(height: 24),
                              _buildRightProductsSelector(),
                            ],
                          ],
                        ),
                ),
              ),

              // Bottom Bar Actions
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    MorphingSaveButton(
                      isLoading: _isSaving,
                      onTap: _saveCollection,
                      text: widget.initialData != null
                          ? 'Save Changes'
                          : 'Create Collection',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. General Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Collection details',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Toggle for Parent vs Sub-collection (only on Create)
              if (widget.initialData == null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create as Collection',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Creates a top-level collection folder',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isParentCollection,
                      onChanged: (val) {
                        setState(() {
                          _isParentCollection = val;
                          if (val) {
                            _selectedParentId = null;
                          } else if (_parentCollections.isNotEmpty) {
                            _selectedParentId =
                                _parentCollections.first['_id'] ??
                                _parentCollections.first['id'];
                          }
                        });
                      },
                      activeThumbColor: AppTheme.primaryColor,
                      activeTrackColor: AppTheme.primaryColor.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Parent Collection Dropdown (only if sub-collection)
              if (!_isParentCollection) ...[
                Text(
                  'Collection',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                _isLoadingParents
                    ? const SizedBox(
                        height: 48,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedParentId,
                            isExpanded: true,
                            hint: Text(
                              'Select Collection',
                              style: GoogleFonts.outfit(
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 14,
                              ),
                            ),
                            items: _parentCollections.map((col) {
                              return DropdownMenuItem<String>(
                                value: col['_id'] ?? col['id'],
                                child: Text(
                                  col['name'] ?? '',
                                  style: GoogleFonts.outfit(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: widget.initialData != null
                                ? null // Disable changing parent during edit
                                : (val) {
                                    setState(() {
                                      _selectedParentId = val;
                                    });
                                  },
                          ),
                        ),
                      ),
                const SizedBox(height: 16),
              ],

              // Name Input
              Text(
                'Collection Name',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Paddy, Wheat, Aphids',
                  hintStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (val) {
                  if ((val == null || val.trim().isEmpty) && _collectionImage == null) {
                    return 'Please enter a name or upload an image';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Image Picker (Only for sub-collections)
              if (!_isParentCollection) ...[
                Text(
                  'Sub-collection Image',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: (_collectionImage != null || _existingImageUrl != null)
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _collectionImage != null 
                                  ? Image.memory(_collectionImage!, fit: BoxFit.cover)
                                  : Image.network(
                                      _existingImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(Icons.broken_image, color: Colors.grey),
                                        );
                                      },
                                    ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _collectionImage = null;
                                    _existingImageUrl = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_upload_outlined, color: AppTheme.textSecondary, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                'Click to upload image',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],


              // Description (only if parent collection)
              if (_isParentCollection) ...[
                Text(
                  'Description',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Describe this collection...',
                    hintStyle: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Display Priority
                Text(
                  'Display Priority',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _priorityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Higher priority displays first, e.g. 10',
                    hintStyle: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Colors.redAccent,
                        width: 1.0,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Colors.redAccent,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a display priority (0 to 9999)';
                    }
                    final num = int.tryParse(val.trim());
                    if (num == null) return 'Must be a whole number';
                    if (num < 0 || num > 9999) {
                      return 'Priority must be between 0 and 9999';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Status Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Active collections are visible to dealers',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (val) => setState(() => _isActive = val),
                    activeThumbColor: AppTheme.primaryColor,
                    activeTrackColor: AppTheme.primaryColor.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightProductsSelector() {
    // Filtered products list based on search query
    final filtered = widget.allProducts.where((p) {
      final name = p['name'].toString().toLowerCase();
      final sku = (p['sku'] ?? '').toString().toLowerCase();
      final query = _productSearchQuery.toLowerCase();
      return name.contains(query) || sku.contains(query);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Products',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedProductIds.length} Selected',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search input
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _productSearchQuery = val),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search product name or SKU...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Products list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'No products found.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      final prodId = (product['id'] ?? product['_id'] ?? '').toString();
                      final isSelected = _selectedProductIds.contains(prodId);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedProductIds.add(prodId);
                            } else {
                              _selectedProductIds.remove(prodId);
                            }
                          });
                        },
                        title: Text(
                          product['name'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          (product['brandName'] ?? 'No Brand').toString(),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        activeColor: AppTheme.primaryColor,
                        checkboxShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.borderColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );
    final path = Path()..addRRect(rrect);

    for (final ui.PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = dashWidth;
        final nextDistance = distance + length;
        final subPath = metric.extractPath(
          distance,
          nextDistance > metric.length ? metric.length : nextDistance,
        );
        canvas.drawPath(subPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
