class Product {
  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.thumbnail,
    required this.description,
    required this.rating,
    required this.images,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      title: json['title'] as String,
      thumbnail: json['thumbnail'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      rating: (json['rating'] as num).toDouble(),
      images: (json['images'] as List).map((e) => e as String).toList(),
    );
  }

  final int id;
  final String title;
  final double price;
  final String thumbnail;
  final String description;
  final double rating;
  final List<String> images;
}
