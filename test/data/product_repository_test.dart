import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:product_catalog/core/failure.dart';
import 'package:product_catalog/data/models/product.dart';
import 'package:product_catalog/data/models/product_page.dart';
import 'package:product_catalog/data/product_api.dart';
import 'package:product_catalog/data/product_repository.dart';

/// The repository takes its [ProductApi] through the constructor, so the
/// whole class can be exercised with no network and no HTTP stubbing.
class MockProductApi extends Mock implements ProductApi {}

void main() {
  late MockProductApi api;
  late ProductRepository repository;

  const product = Product(
    id: 1,
    title: 'Test product',
    price: 9.99,
    thumbnail: '',
    description: '',
    rating: 4.5,
    images: <String>[],
  );
  const page = ProductPage(items: [product], total: 1);

  DioException dioError(DioExceptionType type, {int? statusCode}) {
    final options = RequestOptions(path: '/products');
    return DioException(
      requestOptions: options,
      type: type,
      response: statusCode == null
          ? null
          : Response<void>(requestOptions: options, statusCode: statusCode),
    );
  }

  void stubBrowse() {
    when(
      () => api.fetchProducts(
        limit: any(named: 'limit'),
        skip: any(named: 'skip'),
        sortBy: any(named: 'sortBy'),
        order: any(named: 'order'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => page);
  }

  void stubSearch() {
    when(
      () => api.searchProducts(
        query: any(named: 'query'),
        limit: any(named: 'limit'),
        skip: any(named: 'skip'),
        sortBy: any(named: 'sortBy'),
        order: any(named: 'order'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => page);
  }

  void stubCategory() {
    when(
      () => api.fetchCategoryProducts(
        category: any(named: 'category'),
        limit: any(named: 'limit'),
        skip: any(named: 'skip'),
        sortBy: any(named: 'sortBy'),
        order: any(named: 'order'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => page);
  }

  void throwOnBrowse(Object error) {
    when(
      () => api.fetchProducts(
        limit: any(named: 'limit'),
        skip: any(named: 'skip'),
        sortBy: any(named: 'sortBy'),
        order: any(named: 'order'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(error);
  }

  setUpAll(() {
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    api = MockProductApi();
    repository = ProductRepository(api);
  });

  group('loadPage endpoint routing', () {
    test('browses the catalogue when no query is given', () async {
      stubBrowse();

      final result = await repository.loadPage(skip: 0);

      expect(result.items, [product]);
      verify(
        () => api.fetchProducts(
          limit: ProductRepository.pageSize,
          skip: 0,
          cancelToken: null,
        ),
      ).called(1);
      verifyNever(
        () => api.searchProducts(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          skip: any(named: 'skip'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('searches when a query is given, keeping the same paging', () async {
      stubSearch();

      await repository.loadPage(skip: 40, query: 'phone');

      // The skip the caller asked for passes straight through, which is what
      // lets search results paginate exactly like the catalogue.
      verify(
        () => api.searchProducts(
          query: 'phone',
          limit: ProductRepository.pageSize,
          skip: 40,
          cancelToken: null,
        ),
      ).called(1);
      verifyNever(
        () => api.fetchProducts(
          limit: any(named: 'limit'),
          skip: any(named: 'skip'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('filters by category when one is selected', () async {
      stubCategory();

      await repository.loadPage(skip: 20, category: 'smartphones');

      verify(
        () => api.fetchCategoryProducts(
          category: 'smartphones',
          limit: ProductRepository.pageSize,
          skip: 20,
          sortBy: null,
          order: null,
          cancelToken: null,
        ),
      ).called(1);
    });

    test('a search overrides an active category filter', () async {
      stubSearch();
      stubCategory();

      await repository.loadPage(
        skip: 0,
        query: 'phone',
        category: 'smartphones',
      );

      // Searching is understood as looking across the whole catalogue, not
      // within the current filter.
      verify(
        () => api.searchProducts(
          query: 'phone',
          limit: ProductRepository.pageSize,
          skip: 0,
          sortBy: null,
          order: null,
          cancelToken: null,
        ),
      ).called(1);
      verifyNever(
        () => api.fetchCategoryProducts(
          category: any(named: 'category'),
          limit: any(named: 'limit'),
          skip: any(named: 'skip'),
          sortBy: any(named: 'sortBy'),
          order: any(named: 'order'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('sorting by rating passes sortBy and order through', () async {
      stubBrowse();

      await repository.loadPage(skip: 0, sortByRating: true);

      verify(
        () => api.fetchProducts(
          limit: ProductRepository.pageSize,
          skip: 0,
          sortBy: 'rating',
          order: 'desc',
          cancelToken: null,
        ),
      ).called(1);
    });
  });

  group('failure translation', () {
    test('a dropped connection becomes NetworkFailure', () {
      throwOnBrowse(dioError(DioExceptionType.connectionError));

      expect(
        () => repository.loadPage(skip: 0),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a server error becomes ServerFailure carrying the status', () {
      throwOnBrowse(dioError(DioExceptionType.badResponse, statusCode: 503));

      expect(
        () => repository.loadPage(skip: 0),
        throwsA(
          isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 503),
        ),
      );
    });

    test('a cancellation is NOT a Failure', () {
      throwOnBrowse(dioError(DioExceptionType.cancel));

      // The distinction the whole search flow depends on: a superseded
      // request must never reach the UI as an error state.
      expect(
        () => repository.loadPage(skip: 0),
        throwsA(allOf(isA<RequestCancelled>(), isNot(isA<Failure>()))),
      );
    });

    test('an unparseable response becomes UnknownFailure', () {
      throwOnBrowse(const FormatException('not json'));

      expect(
        () => repository.loadPage(skip: 0),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });
}
