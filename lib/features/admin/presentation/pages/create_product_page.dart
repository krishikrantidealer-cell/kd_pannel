import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_picker/image_picker.dart';

class CreateProductPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onSave;

  const CreateProductPage({super.key, this.initialData, required this.onSave});

  @override
  State<CreateProductPage> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends State<CreateProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _vendorController = TextEditingController();
  final _tagController = TextEditingController();
  final HtmlEditorController _descriptionController = HtmlEditorController();
  List<String> _tags = [];
  List<Map<String, dynamic>> _formVariants = [];
  List<Uint8List> _productImages = [];
  final ImagePicker _picker = ImagePicker();

  String _formCategory = 'Irrigation';
  String _formSubCategory = 'Drip';
  bool _formInStock = true;

  final List<String> _categories = [
    'Irrigation',
    'Seeds',
    'Machinery',
    'Fertilizers',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _vendorController.text = data['vendor'] ?? '';
      _formCategory = data['category'] ?? 'Irrigation';
      _formSubCategory = data['subCategory'] ?? 'Drip';
      _formInStock = data['inStock'] ?? true;
      _tags = List<String>.from(data['tags'] ?? []);

      if (data['variants'] != null) {
        for (var v in data['variants']) {
          _formVariants.add({
            'price': TextEditingController(text: v['price']),
            'compareAtPrice': TextEditingController(text: v['compareAtPrice']),
            'packSize': TextEditingController(text: v['packSize']),
            'baseQuantity': TextEditingController(text: v['baseQuantity']),
            'image': v['image'],
          });
        }
      }
      if (_formVariants.isEmpty) {
        _addVariant();
      }

      Future.delayed(const Duration(milliseconds: 100), () {
        _descriptionController.setText(data['description'] ?? '');
      });
    } else {
      _addVariant();
      Future.delayed(const Duration(milliseconds: 100), () {
        _descriptionController.clear();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vendorController.dispose();
    _tagController.dispose();
    for (var variant in _formVariants) {
      variant['price']?.dispose();
      variant['compareAtPrice']?.dispose();
      variant['packSize']?.dispose();
      variant['baseQuantity']?.dispose();
    }
    // Note: HtmlEditorController does not have a dispose() method in html_editor_enhanced.
    // Its lifecycle and webview resources are managed internally by the package.
    super.dispose();
  }

  void _addVariant() {
    setState(() {
      _formVariants.add({
        'price': TextEditingController(),
        'compareAtPrice': TextEditingController(),
        'packSize': TextEditingController(),
        'baseQuantity': TextEditingController(),
        'image': null,
      });
    });
  }

  void _removeVariant(int index) {
    final variant = _formVariants[index];
    variant['price']?.dispose();
    variant['compareAtPrice']?.dispose();
    variant['packSize']?.dispose();
    variant['baseQuantity']?.dispose();
    setState(() {
      _formVariants.removeAt(index);
    });
  }

  List<String> getFormSubCategories(String cat) {
    switch (cat) {
      case 'Irrigation':
        return ['Drip', 'Sprinkler'];
      case 'Seeds':
        return ['Vegetable', 'Grain'];
      case 'Machinery':
        return ['Pumps', 'Tillers'];
      case 'Fertilizers':
        return ['Organic', 'NPK'];
      default:
        return ['Other'];
    }
  }

  Future<void> _pickAndEditImage({
    required Function(Uint8List) onImageEdited,
  }) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final Uint8List imageBytes = await image.readAsBytes();
      if (!mounted) return;

      final Uint8List? editedImage = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ImageEditor(image: imageBytes)),
      );

      if (editedImage != null) {
        onImageEdited(editedImage);
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the validation errors in the form.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    String description = '';
    try {
      description = await _descriptionController.getText();
    } catch (_) {}

    List<Map<String, dynamic>> variantsData = [];
    for (var v in _formVariants) {
      variantsData.add({
        'price': v['price'].text,
        'compareAtPrice': v['compareAtPrice'].text,
        'packSize': v['packSize'].text,
        'baseQuantity': v['baseQuantity'].text,
        'image': v['image'],
      });
    }

    String displayPrice = '₹0';
    if (variantsData.isNotEmpty && variantsData.first['price'].isNotEmpty) {
      displayPrice = variantsData.first['price'].startsWith('₹')
          ? variantsData.first['price']
          : '₹${variantsData.first['price']}';
    }

    final data = {
      'sku':
          widget.initialData?['sku'] ??
          'PROD-NEW-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'name': _nameController.text.trim(),
      'category': _formCategory,
      'subCategory': _formSubCategory,
      'vendor': _vendorController.text.trim(),
      'price': displayPrice,
      'inStock': _formInStock,
      'description': description,
      'variants': variantsData,
      'images': _productImages,
      'tags': _tags,
    };

    widget.onSave(data);
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _addTag() {
    final text = _tagController.text.trim();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text);
        _tagController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.initialData != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
          tooltip: 'Cancel',
        ),
        title: Text(
          isEdit ? 'Edit Product' : 'Create New Product',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      side: const BorderSide(color: AppTheme.borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      foregroundColor: AppTheme.textPrimary,
                    ),
                    child: Text(
                      'Discard',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _handleSave,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(isEdit ? 'Save Changes' : 'Publish Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 800;

              final leftColumn = Column(
                children: [
                  _buildSectionCard(
                    title: 'Basic Details',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormTextField(
                          label: 'Product Title',
                          hint: 'e.g. Premium Drip Irrigation Kit',
                          controller: _nameController,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Product Title is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Description',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.borderColor),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: HtmlEditor(
                              controller: _descriptionController,
                              htmlEditorOptions: const HtmlEditorOptions(
                                hint:
                                    'Provide a detailed product description...',
                                shouldEnsureVisible: true,
                              ),
                              htmlToolbarOptions: const HtmlToolbarOptions(
                                toolbarPosition: ToolbarPosition.aboveEditor,
                                toolbarType: ToolbarType.nativeScrollable,
                              ),
                              otherOptions: const OtherOptions(height: 300),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    title: 'Product Variants',
                    icon: Icons.style_outlined,
                    action: TextButton.icon(
                      onPressed: _addVariant,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        'Add Variant',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                    child: Column(
                      children: _formVariants.asMap().entries.map((entry) {
                        return _buildVariantCard(entry.key, entry.value);
                      }).toList(),
                    ),
                  ),
                ],
              );

              final rightColumn = Column(
                children: [
                  _buildSectionCard(
                    title: 'Publishing Status',
                    icon: Icons.visibility_outlined,
                    child: _buildAvailabilitySelector(),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    title: 'Organization',
                    icon: Icons.category_outlined,
                    child: Column(
                      children: [
                        _buildCategoryDropdowns(),
                        const SizedBox(height: 20),
                        _buildFormTextField(
                          label: 'Vendor',
                          hint: 'e.g. Jain Irrigation, Mahyco',
                          controller: _vendorController,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vendor is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildTagsSection(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    title: 'Product Media',
                    icon: Icons.image_outlined,
                    child: _buildMediaUploader(),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: leftColumn),
                    const SizedBox(width: 24),
                    Expanded(flex: 1, child: rightColumn),
                  ],
                );
              } else {
                return Column(
                  children: [
                    leftColumn,
                    const SizedBox(height: 24),
                    rightColumn,
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildFormTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    Widget? prefixIcon,
    bool isCompact = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: isCompact ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          style: GoogleFonts.outfit(
            fontSize: isCompact ? 13 : 14,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: isCompact ? 13 : 14,
            ),
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isCompact ? 10 : 16,
            ),
            isDense: isCompact,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
              borderSide: const BorderSide(color: AppTheme.error, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
              borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaUploader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            _pickAndEditImage(
              onImageEdited: (editedImage) {
                setState(() {
                  _productImages.add(editedImage);
                });
              },
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Click to upload images',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SVG, PNG, JPG or GIF (max. 5MB)',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_productImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _productImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                        image: DecorationImage(
                          image: MemoryImage(_productImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 16,
                      child: InkWell(
                        onTap: () =>
                            setState(() => _productImages.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryDropdowns() {
    final subCats = getFormSubCategories(_formCategory);
    if (!subCats.contains(_formSubCategory)) _formSubCategory = subCats.first;

    return Column(
      children: [
        _buildFormDropdown(
          label: 'Primary Category',
          value: _formCategory,
          options: _categories,
          onChanged: (val) {
            setState(() {
              _formCategory = val!;
              _formSubCategory = getFormSubCategories(_formCategory).first;
            });
          },
        ),
        const SizedBox(height: 20),
        _buildFormDropdown(
          label: 'Sub-category',
          value: _formSubCategory,
          options: subCats,
          onChanged: (val) => setState(() => _formSubCategory = val!),
        ),
      ],
    );
  }

  Widget _buildFormDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              onChanged: onChanged,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(
                Icons.unfold_more_rounded,
                size: 20,
                color: AppTheme.textSecondary,
              ),
              items: options
                  .map(
                    (val) => DropdownMenuItem(
                      value: val,
                      child: Text(
                        val,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilitySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _formInStock
            ? AppTheme.success.withValues(alpha: 0.05)
            : AppTheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _formInStock
              ? AppTheme.success.withValues(alpha: 0.2)
              : AppTheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _formInStock
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : AppTheme.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _formInStock
                  ? Icons.check_circle_outline_rounded
                  : Icons.remove_circle_outline_rounded,
              color: _formInStock ? AppTheme.success : AppTheme.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formInStock ? 'Active Product' : 'Draft / Out of Stock',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _formInStock ? AppTheme.success : AppTheme.error,
                  ),
                ),
                Text(
                  _formInStock
                      ? 'This product will be visible to buyers.'
                      : 'This product is currently hidden.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _formInStock,
            activeColor: Colors.white,
            activeTrackColor: AppTheme.success,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppTheme.error.withValues(alpha: 0.5),
            onChanged: (val) => setState(() => _formInStock = val),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Tags',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Press enter to add tags...',
                    hintStyle: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              IconButton(
                onPressed: _addTag,
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                splashRadius: 20,
              ),
            ],
          ),
        ),
        if (_tags.isNotEmpty) const SizedBox(height: 12),
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => setState(() => _tags.remove(tag)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 10,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildVariantCard(int index, Map<String, dynamic> variant) {
    // Discount badge calculation
    final priceText = variant['price'].text;
    final compareText = variant['compareAtPrice'].text;
    double? price = double.tryParse(priceText);
    double? compare = double.tryParse(compareText);
    Widget? discountBadge;
    if (price != null && compare != null && compare > price) {
      final discountPercent = ((compare - price) / compare * 100).round();
      final savings = compare - price;
      discountBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_offer_outlined,
              size: 12,
              color: AppTheme.success,
            ),
            const SizedBox(width: 4),
            Text(
              '$discountPercent% OFF (Save ₹${savings.toStringAsFixed(0)})',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.success,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppTheme.primaryColor, width: 3),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Variant Option ${index + 1}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (discountBadge != null) ...[
                        const SizedBox(width: 12),
                        discountBadge,
                      ],
                    ],
                  ),
                  if (_formVariants.length > 1)
                    IconButton(
                      onPressed: () => _removeVariant(index),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppTheme.error,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Remove Variant',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Image',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          _pickAndEditImage(
                            onImageEdited: (editedImage) {
                              setState(() => variant['image'] = editedImage);
                            },
                          );
                        },
                        child: Container(
                          height: 70,
                          width: 70,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                            image:
                                variant['image'] != null &&
                                    variant['image'] is Uint8List
                                ? DecorationImage(
                                    image: MemoryImage(
                                      variant['image'] as Uint8List,
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child:
                              variant['image'] == null ||
                                  variant['image'] is! Uint8List
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: AppTheme.textSecondary,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormTextField(
                                label: 'Selling Price',
                                hint: '0.00',
                                controller: variant['price'],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'),
                                  ),
                                ],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final numPrice = double.tryParse(val);
                                  if (numPrice == null || numPrice <= 0) {
                                    return 'Invalid price';
                                  }
                                  return null;
                                },
                                onChanged: (val) => setState(() {}),
                                prefixIcon: const Icon(
                                  Icons.currency_rupee_rounded,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                isCompact: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormTextField(
                                label: 'Compare at Price',
                                hint: '0.00',
                                controller: variant['compareAtPrice'],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'),
                                  ),
                                ],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return null; // optional
                                  }
                                  final comp = double.tryParse(val);
                                  if (comp == null || comp <= 0) {
                                    return 'Invalid price';
                                  }
                                  final pVal = variant['price'].text;
                                  final p = double.tryParse(pVal);
                                  if (p != null && comp < p) {
                                    return 'Must be >= Selling Price';
                                  }
                                  return null;
                                },
                                onChanged: (val) => setState(() {}),
                                prefixIcon: const Icon(
                                  Icons.currency_rupee_rounded,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                isCompact: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormTextField(
                                label: 'Pack Size',
                                hint: 'e.g. 500g',
                                controller: variant['packSize'],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                                prefixIcon: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                isCompact: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormTextField(
                                label: 'Inventory Qty',
                                hint: '0',
                                controller: variant['baseQuantity'],
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final qty = int.tryParse(val);
                                  if (qty == null || qty < 0) {
                                    return 'Invalid Qty';
                                  }
                                  return null;
                                },
                                prefixIcon: const Icon(
                                  Icons.layers_outlined,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                isCompact: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
