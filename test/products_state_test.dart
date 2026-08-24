import 'package:flutter_test/flutter_test.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/products_state.dart';

void main() {
  group('ProductsState Tests', () {
    test('default state has correct initial values', () {
      const state = ProductsState();
      expect(state.status, equals(ProductsStatus.initial));
      expect(state.allProducts, isEmpty);
      expect(state.filteredProducts, isEmpty);
      expect(state.collections, isEmpty);
      expect(state.categories, isEmpty);
      expect(state.searchQuery, isEmpty);
      expect(state.selectedCategory, isEmpty);
    });

    test('copyWith updates fields correctly', () {
      const state = ProductsState();
      final p1 = {'_id': 'P1', 'title': 'Urea Fertilizer 50kg', 'category': 'Fertilizer'};
      final p2 = {'_id': 'P2', 'title': 'Chlorpyrifos Insecticide 1L', 'category': 'Insecticides'};

      final updated = state.copyWith(
        status: ProductsStatus.success,
        allProducts: [p1, p2],
        filteredProducts: [p1],
        searchQuery: 'Urea',
        selectedCategory: 'Fertilizer',
      );

      expect(updated.status, equals(ProductsStatus.success));
      expect(updated.allProducts.length, equals(2));
      expect(updated.filteredProducts.length, equals(1));
      expect(updated.searchQuery, equals('Urea'));
      expect(updated.selectedCategory, equals('Fertilizer'));
    });
  });
}
