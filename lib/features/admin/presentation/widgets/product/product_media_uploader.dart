import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class ProductMediaUploader extends StatelessWidget {
  final List<String> existingImageUrls;
  final List<Uint8List> productImages;
  final VoidCallback onPickImages;
  final Function(int index) onRemoveExistingImage;
  final Function(int index) onRemoveNewImage;
  final Function(int index, Uint8List newBytes) onEditNewImage;

  const ProductMediaUploader({
    super.key,
    required this.existingImageUrls,
    required this.productImages,
    required this.onPickImages,
    required this.onRemoveExistingImage,
    required this.onRemoveNewImage,
    required this.onEditNewImage,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasAnyImages =
        existingImageUrls.isNotEmpty || productImages.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (existingImageUrls.isNotEmpty) ...[
          Text(
            'Current Images',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: existingImageUrls.length,
              itemBuilder: (context, index) {
                final url = existingImageUrls[index];
                return Stack(
                  children: [
                    Container(
                      width: 90,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: index == 0
                              ? AppTheme.primaryColor
                              : AppTheme.borderColor,
                          width: index == 0 ? 2 : 1,
                        ),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Main',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 14,
                      child: InkWell(
                        onTap: () => onRemoveExistingImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 11,
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
          const SizedBox(height: 12),
        ],
        if (productImages.isNotEmpty) ...[
          Text(
            'New Images (will be uploaded)',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: productImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final Uint8List? editedImage = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProImageEditor.memory(
                              productImages[index],
                              callbacks: ProImageEditorCallbacks(
                                onImageEditingComplete: (Uint8List editedBytes) async {
                                  Navigator.pop(context, editedBytes);
                                },
                              ),
                            ),
                          ),
                        );
                        if (editedImage != null) {
                          onEditNewImage(index, editedImage);
                        }
                      },
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFF59E0B),
                            width: 2,
                          ),
                          image: DecorationImage(
                            image: MemoryImage(productImages[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'New',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 14,
                      child: InkWell(
                        onTap: () => onRemoveNewImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 11,
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
          const SizedBox(height: 12),
        ],

        InkWell(
          onTap: onPickImages,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: hasAnyImages ? 16 : 32),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(hasAnyImages ? 8 : 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppTheme.primaryColor,
                    size: hasAnyImages ? 20 : 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasAnyImages ? 'Add more images' : 'Click to upload images',
                  style: GoogleFonts.outfit(
                    fontSize: hasAnyImages ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                if (!hasAnyImages) ...[
                  const SizedBox(height: 4),
                  Text(
                    'PNG, JPG or GIF (max. 5MB each)',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
