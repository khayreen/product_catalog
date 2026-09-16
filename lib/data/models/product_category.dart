/// One category, as the filter bar needs it.
///
/// The API returns a `url` alongside these two, but the app builds its own
/// requests from [slug], so it is not kept.
class ProductCategory {
  const ProductCategory({required this.slug, required this.name});

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  /// What the endpoint expects: `/products/category/{slug}`.
  final String slug;

  /// What the user sees on the chip.
  final String name;
}
