import 'package:dio/dio.dart';

import '../core/failure.dart';
import 'models/product.dart';
import 'models/product_page.dart';
import 'product_api.dart';

/// The seam between the network and the rest of the app.
///
/// Two jobs: it owns the paging policy, and it translates transport errors
/// into [Failure]s the UI can render. Nothing above this file imports dio.
class ProductRepository {
  const ProductRepository(this._api);

  /// One page of results. Divides the API's 194 products into 10 pages.
  static const int pageSize = 20;

  final ProductApi _api;

  Future<ProductPage> loadPage({
    required int skip,
    String query = '',
    CancelToken? cancelToken,
  }) {
    return _guard(() {
      if (query.isEmpty) {
        return _api.fetchProducts(
          limit: pageSize,
          skip: skip,
          cancelToken: cancelToken,
        );
      }
      return _api.searchProducts(
        query: query,
        limit: pageSize,
        skip: skip,
        cancelToken: cancelToken,
      );
    });
  }

  Future<Product> loadProduct(int id, {CancelToken? cancelToken}) {
    return _guard(() => _api.fetchProduct(id, cancelToken: cancelToken));
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _translate(error);
    } catch (_) {
      throw const UnknownFailure();
    }
  }

  Exception _translate(DioException error) => switch (error.type) {
        DioExceptionType.cancel => const RequestCancelled(),
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          const NetworkFailure(),
        DioExceptionType.badResponse =>
          ServerFailure(error.response?.statusCode),
        _ => const UnknownFailure(),
      };
}
