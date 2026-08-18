import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/features/shared/widgets/main_layout.dart';
import 'create_product_page.dart';
import 'create_collection_page.dart';
import '../widgets/products_tab_view.dart';
import '../widgets/collections_tab_view.dart';
import '../widgets/categories_tab_view.dart';
import '../widgets/banners_tab_view.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/products_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/products_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/products_state.dart';
import 'package:animations/animations.dart';

class ProductsPage extends StatefulWidget {
  final bool? isReadOnly;
  const ProductsPage({super.key, this.isReadOnly});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final ScrollController _scrollController = ScrollController();
  String _selectedTab =
      'Products'; // 'Products', 'Collections', or 'Categories'

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ProductsBloc>();
    if (bloc.state.status == ProductsStatus.initial) {
      bloc.add(const LoadProductsEvent());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startAddProduct(BuildContext context) {
    final productsBloc = BlocProvider.of<ProductsBloc>(context);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (routeContext, animation, secondaryAnimation) =>
            MainLayout(
              child: CreateProductPage(
                preloadedCategories: productsBloc.state.categories,
                onSave: (newProduct) {
                  productsBloc.add(const LoadProductsEvent(forceRefresh: true));
                },
              ),
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.scaled,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _startCreateCollection(
    BuildContext context,
    List<Map<String, dynamic>> products,
  ) {
    final productsBloc = BlocProvider.of<ProductsBloc>(context);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (routeContext, animation, secondaryAnimation) =>
            MainLayout(
              child: CreateCollectionPage(
                allProducts: products,
                onSave: (newCol) {
                  productsBloc.add(const LoadProductsEvent(forceRefresh: true));
                },
              ),
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.scaled,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final bool isSales = (widget.isReadOnly ?? false) ||
        (AuthService().currentUserRole == UserRole.sales);

    return SelectionArea(
      child: BlocBuilder<ProductsBloc, ProductsState>(
        builder: (context, state) {
          final products = state.allProducts;
          final collections = state.collections;
          final categories = state.categories;
          final isLoadingProducts = state.status == ProductsStatus.loading;
          final isLoadingCollections = state.status == ProductsStatus.loading;

          final String title = isSales
              ? 'Products'
              : (_selectedTab == 'Products'
                  ? 'Product Catalogue'
                  : _selectedTab == 'Collections'
                  ? 'Product Collections'
                  : _selectedTab == 'Categories'
                  ? 'Product Categories'
                  : 'Carousel Banners');

          final String subtitle = isSales
              ? 'Browse and view available products, technical specifications and pricing details'
              : (_selectedTab == 'Products'
                  ? 'View and manage agricultural products, categories and sub-categories'
                  : _selectedTab == 'Collections'
                  ? 'Organize products into curated thematic groups and bundles'
                  : _selectedTab == 'Categories'
                  ? 'Configure categories and custom sub-categories hierarchy'
                  : 'Upload and manage app home screen carousel banners');

          return SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: AppTheme.getResponsivePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (!isSales && (_selectedTab == 'Products' || _selectedTab == 'Collections')) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (_selectedTab == 'Products') {
                                    _startAddProduct(context);
                                  } else {
                                    _startCreateCollection(context, products);
                                  }
                                },
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(
                                  _selectedTab == 'Products'
                                      ? 'Add Product'
                                      : 'Create Collection',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isSales && (_selectedTab == 'Products' || _selectedTab == 'Collections')) ...[
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (_selectedTab == 'Products') {
                                  _startAddProduct(context);
                                } else {
                                  _startCreateCollection(context, products);
                                }
                              },
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(
                                _selectedTab == 'Products'
                                    ? 'Add Product'
                                    : 'Create Collection',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                const SizedBox(height: 16),

                // Tab Selector (Only shown for Admin, hidden for Sales)
                if (!isSales) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSegmentButton(
                            title: 'Products',
                            isActive: _selectedTab == 'Products',
                            onTap: () => setState(() => _selectedTab = 'Products'),
                          ),
                          _buildSegmentButton(
                            title: 'Collections',
                            isActive: _selectedTab == 'Collections',
                            onTap: () =>
                                setState(() => _selectedTab = 'Collections'),
                          ),
                          _buildSegmentButton(
                            title: 'Categories',
                            isActive: _selectedTab == 'Categories',
                            onTap: () =>
                                setState(() => _selectedTab = 'Categories'),
                          ),
                          _buildSegmentButton(
                            title: 'Banners',
                            isActive: _selectedTab == 'Banners',
                            onTap: () =>
                                setState(() => _selectedTab = 'Banners'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingLarge),
                ],

                // Content View
                if (isSales)
                  ProductsTabView(
                    products: products,
                    backendCategories: categories,
                    isLoadingProducts: isLoadingProducts,
                    isReadOnly: true,
                    onRefresh: () {
                      context.read<ProductsBloc>().add(
                        const LoadProductsEvent(forceRefresh: true),
                      );
                    },
                  )
                else
                  IndexedStack(
                    index: _selectedTab == 'Products'
                        ? 0
                        : _selectedTab == 'Collections'
                        ? 1
                        : _selectedTab == 'Categories'
                        ? 2
                        : 3,
                    children: [
                      ProductsTabView(
                        products: products,
                        backendCategories: categories,
                        isLoadingProducts: isLoadingProducts,
                        isReadOnly: false,
                        onRefresh: () {
                          context.read<ProductsBloc>().add(
                            const LoadProductsEvent(forceRefresh: true),
                          );
                        },
                      ),
                      CollectionsTabView(
                        collections: collections,
                        products: products,
                        isLoadingCollections: isLoadingCollections,
                        onRefresh: () {
                          context.read<ProductsBloc>().add(
                            const LoadProductsEvent(forceRefresh: true),
                          );
                        },
                      ),
                      CategoriesTabView(
                        categories: categories,
                        products: products,
                        onRefresh: () {
                          context.read<ProductsBloc>().add(
                            const LoadProductsEvent(forceRefresh: true),
                          );
                        },
                      ),
                      BannersTabView(
                        onRefresh: () {
                          context.read<ProductsBloc>().add(
                            const LoadProductsEvent(forceRefresh: true),
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
