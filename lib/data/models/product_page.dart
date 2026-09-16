import 'product.dart';

/// One page of results, plus the total the API reports.
///
/// [total] is what makes pagination terminate: the caller knows it has
/// everything once skip + items.length >= total.
class ProductPage {
  const ProductPage({required this.items, required this.total});

  factory ProductPage.fromJson(Map<String, dynamic> json) {
    return ProductPage(
      items: (json['products'] as List)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
    );
  }

  final List<Product> items;
  final int total;
}
