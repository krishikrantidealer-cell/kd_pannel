import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/core/utils/local_cache_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isPersistentSession = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Warm up the server in the background (proactively trigger cold start if any)
    _warmUpServer();
  }

  void _warmUpServer() {
    ApiClient().get('/products/categories').catchError((_) {
      return http.Response('', 500);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache core assets to ensure they load instantly on transition
    precacheImage(const AssetImage('assets/images/logo_copy.png'), context);
    precacheImage(const AssetImage('assets/images/logo.png'), context);
    precacheImage(const AssetImage('assets/images/admin.png'), context);
  }

  void _precacheProductData() {
    final client = ApiClient();
    Future.wait([
          client.get('/products?limit=1000'),
          client.get('/collections?all=true'),
          client.get('/products/categories'),
        ])
        .then((results) {
          final productsRes = results[0];
          final collectionsRes = results[1];
          final categoriesRes = results[2];

          // Parse products
          if (productsRes.statusCode == 200) {
            final data = jsonDecode(productsRes.body);
            if (data['success'] == true && data['products'] is List) {
              final List rawProducts = data['products'];
              final List<Map<String, dynamic>> preparedProducts = [];
              for (var p in rawProducts) {
                final String minPriceStr = p['minPrice'] != null
                    ? '₹${p['minPrice']}'
                    : '₹0';
                final String maxPriceStr = p['maxPrice'] != null
                    ? '₹${p['maxPrice']}'
                    : '₹0';
                final String priceRange = p['minPrice'] == p['maxPrice']
                    ? minPriceStr
                    : '$minPriceStr - $maxPriceStr';
                final bool inStock = p['availabilityStatus'] != 'Out of Stock';

                String categoryName = 'N/A';
                if (p['categoryId'] != null && p['categoryId'] is Map) {
                  categoryName = p['categoryId']['name'] ?? 'N/A';
                }

                String subCategoryName = 'N/A';
                if (p['subCategoryId'] != null &&
                    p['categoryId'] != null &&
                    p['categoryId'] is Map &&
                    p['categoryId']['subCategories'] is List) {
                  final List subs = p['categoryId']['subCategories'];
                  final matchingSub = subs.firstWhere(
                    (s) => s['_id'] == p['subCategoryId'],
                    orElse: () => null,
                  );
                  if (matchingSub != null) {
                    subCategoryName = matchingSub['name'] ?? 'N/A';
                  }
                }

                preparedProducts.add({
                  'id': p['_id'],
                  'sku': p['_id']
                      .toString()
                      .substring(
                        p['_id'].toString().length >= 6
                            ? p['_id'].toString().length - 6
                            : 0,
                      )
                      .toUpperCase(),
                  'name': p['title'] ?? '',
                  'category': categoryName,
                  'subCategory': subCategoryName,
                  'vendor': p['brandName'] ?? p['vendor'] ?? 'N/A',
                  'price': priceRange,
                  'inStock': inStock,
                  'availabilityStatus':
                      p['availabilityStatus'] ??
                      (inStock ? 'In Stock' : 'Out of Stock'),
                  'variants': p['variants'] ?? [],
                  'images': p['images'] ?? [],
                  'thumbnail': p['thumbnail'],
                  'thumbnailBytes': null,
                  'assignedCollections': p['assignedCollections'] ?? [],
                  'description': p['description'] ?? '',
                  'specifications': p['specifications'] ?? {},
                  'tags': p['tags'] ?? [],
                  'mediumImages': p['mediumImages'] ?? [],
                  'originalImages': p['originalImages'] ?? [],
                  'isFeatured': p['isFeatured'] ?? false,
                });
              }
              client.cachedProducts = preparedProducts;
              LocalCacheHelper.saveCachedProducts(preparedProducts);
            }
          }

          // Parse collections
          if (collectionsRes.statusCode == 200) {
            final data = jsonDecode(collectionsRes.body);
            if (data['success'] == true && data['collections'] is List) {
              final List rawCollections = data['collections'];
              final List<Map<String, dynamic>> preparedCollections = [];
              for (var c in rawCollections) {
                final String parentId = c['_id'] ?? c['id'] ?? '';
                final List subList = c['subCollections'] as List? ?? [];
                preparedCollections.add({
                  'id': parentId,
                  'name': c['name'] ?? '',
                  'slug': c['slug'] ?? '',
                  'isActive': c['isActive'] ?? true,
                  'subCollections': subList
                      .map(
                        (sub) => {
                          'id': sub['_id'] ?? sub['id'] ?? '',
                          'parentId': parentId,
                          'name': sub['name'] ?? '',
                          'slug': sub['slug'] ?? '',
                          'isActive': sub['isActive'] ?? true,
                        },
                      )
                      .toList(),
                });
              }
              client.cachedCollections = preparedCollections;
              LocalCacheHelper.saveCachedCollections(preparedCollections);
            }
          }

          // Parse categories
          if (categoriesRes.statusCode == 200) {
            final data = jsonDecode(categoriesRes.body);
            if (data['success'] == true && data['categories'] is List) {
              final loaded = data['categories'] as List<dynamic>;
              client.cachedCategories = loaded;
              LocalCacheHelper.saveCachedCategories(loaded);
            }
          }
        })
        .catchError((e) {
          print('Background precache failed: $e');
        });
  }

  void _handleLogin(UserRole role) async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
    });

    final success = await AuthService().login(
      email: email,
      password: password,
      role: role,
      rememberMe: _isPersistentSession,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        if (role == UserRole.admin) {
          _precacheProductData();
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/leads');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AuthService().lastError ??
                  'Authorization failed. Please verify your credentials.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  UserRole _selectedRole = UserRole.admin;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return SelectionArea(
      child: Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // LAYER 1: Background Gradient + Animated Neural Mesh (Full screen on mobile/tablet, 65% on desktop)
          if (isDesktop)
            ClipPath(
              clipper: OrganicClipper(),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.65,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1B5E20),
                      AppTheme.primaryColor,
                      const Color(0xFF2D6A4F),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    const Positioned.fill(child: AnimatedNeuralMesh()),

                    // Core Brand Presentation
                    Padding(
                      padding: const EdgeInsets.fromLTRB(110, 80, 110, 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Prismatic Logo Core
                          Container(
                            height: 85,
                            width: 85,
                            padding: const EdgeInsets.all(17),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logo_copy.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const Spacer(),
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white.withOpacity(0.7),
                              ],
                            ).createShader(bounds),
                            child: Text(
                              'KrishiDealer',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 94,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -3.5,
                                height: 0.9,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'INTELLECTUAL ORCHESTRATION',
                            style: GoogleFonts.outfit(
                              color: AppTheme.accentColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 10,
                            ),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            'The high-performance engine for global agricultural excellence.',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                              height: 1.4,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Mobile/Tablet background: deep luxurious forest green gradient + floating neural mesh!
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D2C15), // Ultra deep forest green
                    Color(0xFF1B5E20), // Primary green
                    Color(0xFF144D20), // Medium-dark green
                  ],
                ),
              ),
            ),
            const Positioned.fill(child: AnimatedNeuralMesh()),
          ],

          // LAYER 2: Floating Zen Portal (No Card on Desktop, Frosted Glassmorphism on Mobile/Tablet)
          Align(
            alignment: isDesktop ? const Alignment(0.92, 0) : Alignment.center,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              margin: EdgeInsets.symmetric(
                horizontal: isDesktop
                    ? 60
                    : (Responsive.isMobile(context) ? 20 : 40),
                vertical: isDesktop ? 32 : 12, // Responsive vertical margin
              ),
              decoration: !isDesktop
                  ? BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    )
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: !isDesktop ? 15.0 : 0.0,
                    sigmaY: !isDesktop ? 15.0 : 0.0,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop
                          ? 40
                          : (Responsive.isMobile(context) ? 24 : 36),
                      vertical: isDesktop
                          ? 36
                          : 24, // Responsive vertical inner padding
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Brand Header for Mobile/Tablet (Non-Desktop)
                        if (!isDesktop) ...[
                          Row(
                            children: [
                              Container(
                                height: 36,
                                width: 36,
                                padding: const EdgeInsets.all(7),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  'assets/images/logo_copy.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'KrishiDealer',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Text(
                                      'INTELLECTUAL ORCHESTRATION',
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.accentColor,
                                        fontSize: 6,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.15),
                                  ),
                                ),
                                child: Text(
                                  'SYSTEM ACCESS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white.withOpacity(0.9),
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        // High-Tech Header - Only show on Desktop
                        if (isDesktop) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'SYSTEM ACCESS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryColor,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.shield_moon_rounded,
                                color: AppTheme.primaryColor.withOpacity(0.4),
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        TypewriterText(
                          text: 'Authorized Portal',
                          style: GoogleFonts.outfit(
                            fontSize: isDesktop
                                ? 30
                                : 22, // Beautiful scaling title font
                            fontWeight: FontWeight.w900,
                            color: isDesktop
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            letterSpacing: -0.8,
                          ),
                          cursorColor: isDesktop
                              ? AppTheme.primaryColor
                              : Colors.white,
                        ),
                        if (isDesktop) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Secure authentication for enterprise operations.',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        SizedBox(height: isDesktop ? 24 : 12),

                        // Segmented Capsule Switcher (Integrated)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDesktop
                                ? const Color(0xFFF1F5F9)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: isDesktop
                                ? null
                                : Border.all(
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                          ),
                          child: Row(
                            children: [
                              _buildCapsuleTab(
                                UserRole.admin,
                                'ADMIN',
                                isDark: !isDesktop,
                              ),
                              _buildCapsuleTab(
                                UserRole.sales,
                                'SALES',
                                isDark: !isDesktop,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isDesktop ? 24 : 16),

                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Proactive server wakeup indicator
                              ValueListenableBuilder<bool>(
                                valueListenable: ApiClient().isBackendWakingUp,
                                builder: (context, isWakingUp, child) {
                                  if (!isWakingUp)
                                    return const SizedBox.shrink();
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDesktop
                                          ? const Color(0xFFFFF3CD)
                                          : Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDesktop
                                            ? const Color(0xFFFFEBAA)
                                            : Colors.white.withOpacity(0.15),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  isDesktop
                                                      ? const Color(0xFF856404)
                                                      : Colors.white,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '⚡ Server warming up... This may take a few seconds.',
                                            style: TextStyle(
                                              color: isDesktop
                                                  ? const Color(0xFF856404)
                                                  : Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              FocusableAdvancedField(
                                controller: _emailController,
                                hint: 'Identity Identifier',
                                icon: Icons.alternate_email_rounded,
                                isDark: !isDesktop,
                                textInputAction: TextInputAction.next,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your identity identifier';
                                  }
                                  final emailRegex = RegExp(
                                    r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$',
                                  );
                                  if (!emailRegex.hasMatch(val.trim())) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: isDesktop ? 16 : 12),
                              FocusableAdvancedField(
                                controller: _passwordController,
                                hint: 'Security Token',
                                icon: Icons.lock_outline_rounded,
                                isPassword: true,
                                obscure: !_isPasswordVisible,
                                togglePassword: () => setState(
                                  () =>
                                      _isPasswordVisible = !_isPasswordVisible,
                                ),
                                isDark: !isDesktop,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) =>
                                    _handleLogin(_selectedRole),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your security token';
                                  }
                                  if (val.length < 6) {
                                    return 'Security token must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: isDesktop ? 16 : 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _isPersistentSession =
                                          !_isPersistentSession,
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: Checkbox(
                                            value: _isPersistentSession,
                                            onChanged: (v) {
                                              setState(
                                                () => _isPersistentSession =
                                                    v ?? true,
                                              );
                                            },
                                            activeColor: AppTheme.primaryColor,
                                            side: isDesktop
                                                ? null
                                                : BorderSide(
                                                    color: Colors.white
                                                        .withOpacity(0.4),
                                                    width: 1.5,
                                                  ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Keep me signed in',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            color: isDesktop
                                                ? const Color(0xFF64748B)
                                                : Colors.white.withOpacity(0.8),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: isDesktop ? 32 : 20),
                              SizedBox(
                                width: double.infinity,
                                height: isDesktop
                                    ? 54
                                    : 48, // Sleek responsive buttons
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _handleLogin(_selectedRole),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: AppTheme
                                        .primaryColor
                                        .withOpacity(0.6),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.primaryColor.withOpacity(
                                            _isLoading ? 0.6 : 1.0,
                                          ),
                                          const Color(
                                            0xFF1B5E20,
                                          ).withOpacity(_isLoading ? 0.6 : 1.0),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: _isLoading
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: AppTheme.primaryColor
                                                    .withOpacity(0.3),
                                                blurRadius: 15,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                    ),
                                    child: Container(
                                      alignment: Alignment.center,
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              'AUTHORIZE ENTRY',
                                              style: GoogleFonts.outfit(
                                                fontSize: isDesktop ? 14 : 12,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 2,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ), // closes Scaffold
    ); // closes SelectionArea
  }


  Widget _buildCapsuleTab(UserRole role, String label, {bool isDark = false}) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            vertical: isDark
                ? 10
                : (Responsive.isDesktop(context)
                      ? 12
                      : 10), // Adaptive tab height
          ),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isDark
                          ? Colors.white.withOpacity(0.6)
                          : const Color(0xFF64748B)),
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedNeuralMesh extends StatefulWidget {
  const AnimatedNeuralMesh({super.key});

  @override
  State<AnimatedNeuralMesh> createState() => _AnimatedNeuralMeshState();
}

class _AnimatedNeuralMeshState extends State<AnimatedNeuralMesh>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Node> _nodes = [];
  final int _nodeCount = 25; // Reduced for performance

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30), // Slower, more elegant
    )..repeat();

    // Initialize nodes with fixed spread
    for (int i = 0; i < _nodeCount; i++) {
      _nodes.add(_Node(i));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: NeuralMeshPainter(_nodes, _controller.value),
        );
      },
    );
  }
}

class _Node {
  late double x;
  late double y;
  late double vx;
  late double vy;

  _Node(int seed) {
    // Better initial distribution
    x = ((seed * 0.1337) % 1.0);
    y = ((seed * 0.7331) % 1.0);
    vx = (((seed % 3) - 1) * 0.0005);
    vy = (((seed % 2) - 0.5) * 0.0008);
  }

  void update() {
    x += vx;
    y += vy;
    if (x < 0 || x > 1) vx *= -1;
    if (y < 0 || y > 1) vy *= -1;
  }
}

class NeuralMeshPainter extends CustomPainter {
  final List<_Node> nodes;
  final double animationValue;

  NeuralMeshPainter(this.nodes, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.0;

    final dotPaint = Paint()..color = Colors.white.withOpacity(0.3);

    for (var node in nodes) {
      node.update();
      final pos = Offset(node.x * size.width, node.y * size.height);
      canvas.drawCircle(pos, 2, dotPaint);

      for (var other in nodes) {
        final otherPos = Offset(other.x * size.width, other.y * size.height);
        final distance = (pos - otherPos).distance;

        if (distance < 150) {
          paint.color = Colors.white.withOpacity(0.2 * (1 - distance / 150));
          canvas.drawLine(pos, otherPos, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class OrganicClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width * 0.8, size.height);

    // Create an organic curve that pushes into the login area
    path.quadraticBezierTo(
      size.width * 1.0,
      size.height * 0.5,
      size.width * 0.85,
      0,
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;
  final Duration cursorBlinkSpeed;
  final Color? cursorColor;

  const TypewriterText({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 1000),
    this.cursorBlinkSpeed = const Duration(milliseconds: 400),
    this.cursorColor,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with TickerProviderStateMixin {
  late AnimationController _textController;
  late AnimationController _cursorController;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _textController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _characterCount = StepTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOutCubic),
    );

    _cursorController = AnimationController(
      vsync: this,
      duration: widget.cursorBlinkSpeed,
    )..repeat(reverse: true);

    // Dynamic start delay to allow the general screen transition to settle first
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _textController.forward().then((_) {
          if (mounted) {
            _cursorController
                .stop(); // Stop blinking cursor to keep UI clean and static after typed
            setState(() {});
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        final currentText = widget.text.substring(0, _characterCount.value);
        final isFinished = _textController.isCompleted;

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(currentText, style: widget.style),
            if (!isFinished)
              AnimatedBuilder(
                animation: _cursorController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _cursorController.value > 0.5 ? 1.0 : 0.0,
                    child: Text(
                      '|',
                      style: widget.style.copyWith(
                        color:
                            widget.cursorColor ??
                            widget.style.color ??
                            AppTheme.primaryColor,
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class FocusableAdvancedField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscure;
  final VoidCallback? togglePassword;
  final bool isDark;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;

  const FocusableAdvancedField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscure = false,
    this.togglePassword,
    required this.isDark,
    this.validator,
    this.onFieldSubmitted,
    this.textInputAction,
  });

  @override
  State<FocusableAdvancedField> createState() => _FocusableAdvancedFieldState();
}

class _FocusableAdvancedFieldState extends State<FocusableAdvancedField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final Color fillColor = widget.isDark
        ? (widget.controller.text.isNotEmpty || _isFocused
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.06))
        : (_isFocused ? Colors.white : const Color(0xFFF8FAFC));

    final Color borderColor = widget.isDark
        ? (_isFocused ? AppTheme.accentColor : Colors.white.withOpacity(0.12))
        : (_isFocused ? AppTheme.primaryColor : const Color(0xFFE2E8F0));

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscure,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      style: GoogleFonts.outfit(
        fontSize: 16,
        color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: GoogleFonts.outfit(
          color: widget.isDark
              ? Colors.white.withOpacity(0.4)
              : const Color(0xFF94A3B8),
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(
          widget.icon,
          size: 22,
          color: widget.isDark
              ? (_isFocused
                    ? AppTheme.accentColor
                    : Colors.white.withOpacity(0.7))
              : (_isFocused
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withOpacity(0.6)),
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  widget.obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                  color: widget.isDark
                      ? Colors.white.withOpacity(0.5)
                      : const Color(0xFF94A3B8),
                ),
                onPressed: widget.togglePassword,
              )
            : null,
        filled: true,
        fillColor: fillColor,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: widget.isDark ? 12 : (isDesktop ? 15 : 12),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: widget.isDark ? AppTheme.accentColor : AppTheme.primaryColor,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
        ),
        errorStyle: GoogleFonts.outfit(fontSize: 12, color: AppTheme.error),
      ),
    );
  }
}
