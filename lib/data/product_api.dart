import 'package:dio/dio.dart';

import 'models/product.dart';
import 'models/product_page.dart';

/// Wraps the HTTP endpoints and nothing else — no paging policy, no
/// caching, no error handling. Those belong to the repository above it.
class ProductApi {
  const ProductApi(this._dio);

  final Dio _dio;

  Future<ProductPage> fetchProducts({
    required int limit,
    required int skip,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/products',
      queryParameters: <String, dynamic>{'limit': limit, 'skip': skip},
      cancelToken: cancelToken,
    );
    return ProductPage.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<ProductPage> searchProducts({
    required String query,
    required int limit,
    required int skip,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/products/search',
      queryParameters: <String, dynamic>{
        'q': query,
        'limit': limit,
        'skip': skip,
      },
      cancelToken: cancelToken,
    );
    return ProductPage.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<Product> fetchProduct(int id, {CancelToken? cancelToken}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/products/$id',
      cancelToken: cancelToken,
    );
    return Product.fromJson(response.data ?? const <String, dynamic>{});
  }
}
