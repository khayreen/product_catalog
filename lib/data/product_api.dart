import 'package:dio/dio.dart';

import 'models/product.dart';
import 'models/product_category.dart';
import 'models/product_page.dart';

/// A thin wrapper over the DummyJSON HTTP endpoints.
///
/// This class knows about URLs, query parameters and response envelopes -
/// and nothing else. No paging policy, no caching, no translating failures
/// into something the UI can show. Those decisions belong to the repository
/// above it, which is what keeps this file boring enough to trust.
///
/// [Dio] arrives through the constructor rather than being created here, so
/// a test can pass a stubbed client without any network access.
class ProductApi {
  const ProductApi(this._dio);

  final Dio _dio;

  /// The query parameters every listing endpoint shares.
  ///
  /// All three listing endpoints take the same paging and sorting
  /// parameters, so building them in one place keeps the three methods
  /// below down to a path and a return type.
  Map<String, dynamic> _listParams({
    required int limit,
    required int skip,
    String? sortBy,
    String? order,
  }) {
    return <String, dynamic>{
      'limit': limit,
      'skip': skip,
      if (sortBy != null) 'sortBy': sortBy,
      if (order != null) 'order': order,
    };
  }

  /// `GET /products`
  Future<ProductPage> fetchProducts({
    required int limit,
    required int skip,
    String? sortBy,
    String? order,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/products',
      queryParameters: _listParams(
        limit: limit,
        skip: skip,
        sortBy: sortBy,
        order: order,
      ),
      cancelToken: cancelToken,
    );
    return ProductPage.fromJson(response.data ?? const <String, dynamic>{});
  }

  /// `GET /products/search`
  ///
  /// Returns the same `{products, total, skip, limit}` envelope the list
  /// endpoint does, which is what lets search and browse share one paging
  /// path instead of each growing its own.
  Future<ProductPage> searchProducts({
    required String query,
    required int limit,
    required int skip,
    String? sortBy,
    String? order,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/products/search',
      queryParameters: <String, dynamic>{
        'q': query,
        ..._listParams(
          limit: limit,
          skip: skip,
          sortBy: sortBy,
          order: order,
        ),
      },
      cancelToken: cancelToken,
    );
    return ProductPage.fromJson(response.data ?? const <String, dynamic>{});
  }

  /// `GET /products/category/{slug}`
  ///
  /// Same envelope again, with `total` scoped to the category - so a
  /// filtered list paginates and terminates exactly like an unfiltered one.
  Future<ProductPage> fetchCategoryProducts({
    required String category,
    required int limit,
    required int skip,
    String? sortBy,
    String? order,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/products/category/$category',
      queryParameters: _listParams(
        limit: limit,
        skip: skip,
        sortBy: sortBy,
        order: order,
      ),
      cancelToken: cancelToken,
    );
    return ProductPage.fromJson(response.data ?? const <String, dynamic>{});
  }

  /// `GET /products/categories`
  ///
  /// A bare JSON array rather than an envelope - the one endpoint here that
  /// does not follow the pattern.
  Future<List<ProductCategory>> fetchCategories({
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/products/categories',
      cancelToken: cancelToken,
    );
    return (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ProductCategory.fromJson)
        .toList(growable: false);
  }

  /// `GET /products/{id}`
  ///
  /// Returns the full product rather than reusing the one already in the
  /// list: the detail screen needs the complete description, and re-fetching
  /// means the screen works when opened directly rather than only after
  /// scrolling past it.
  Future<Product> fetchProduct(int id, {CancelToken? cancelToken}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/products/$id',
      cancelToken: cancelToken,
    );
    return Product.fromJson(response.data ?? const <String, dynamic>{});
  }
}
