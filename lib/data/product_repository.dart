import 'package:dio/dio.dart';

import '../core/failure.dart';
import 'models/product.dart';
import 'models/product_category.dart';
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

  /// Loads the page starting at [skip], browsing, searching or filtered to
  /// one category, optionally sorted by rating.
  ///
  /// Three endpoints, one method. They all return the same envelope, so the
  /// choice is made here, once, and everything above this line paginates
  /// identically no matter which of the three is running.
  ///
  /// Precedence: a non-empty [query] wins over [category] - searching is
  /// understood as looking across the whole catalogue, not within the
  /// current filter.
  ///
  /// Throws a [Failure] the UI can show, or [RequestCancelled] if a newer
  /// request superseded this one.
  Future<ProductPage> loadPage({
    required int skip,
    String query = '',
    String? category,
    bool sortByRating = false,
    CancelToken? cancelToken,
  }) {
    final sortBy = sortByRating ? 'rating' : null;
    final order = sortByRating ? 'desc' : null;

    return _guard(() {
      if (query.isNotEmpty) {
        return _api.searchProducts(
          query: query,
          limit: pageSize,
          skip: skip,
          sortBy: sortBy,
          order: order,
          cancelToken: cancelToken,
        );
      }

      if (category != null) {
        return _api.fetchCategoryProducts(
          category: category,
          limit: pageSize,
          skip: skip,
          sortBy: sortBy,
          order: order,
          cancelToken: cancelToken,
        );
      }

      return _api.fetchProducts(
        limit: pageSize,
        skip: skip,
        sortBy: sortBy,
        order: order,
        cancelToken: cancelToken,
      );
    });
  }

  /// The categories available for filtering.
  Future<List<ProductCategory>> loadCategories({CancelToken? cancelToken}) {
    return _guard(() => _api.fetchCategories(cancelToken: cancelToken));
  }

  /// Loads one product by id.
  Future<Product> loadProduct(int id, {CancelToken? cancelToken}) {
    return _guard(() => _api.fetchProduct(id, cancelToken: cancelToken));
  }

  /// Runs [request], converting anything it throws into an app-level type.
  ///
  /// Every repository method goes through here so no call site can forget
  /// to translate, and no raw `DioException` can leak upwards.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _translate(error);
    } catch (_) {
      // A parsing error, most likely: the request succeeded but the body
      // was not the shape we expected.
      throw const UnknownFailure();
    }
  }

  Exception _translate(DioException error) => switch (error.type) {
    DioExceptionType.cancel => const RequestCancelled(),
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => const NetworkFailure(),
    DioExceptionType.badResponse => ServerFailure(error.response?.statusCode),
    _ => const UnknownFailure(),
  };
}
