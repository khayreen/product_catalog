import '../../core/failure.dart';
import '../../data/models/product.dart';

/// Every state the product list can be in - and, because the class is
/// `sealed`, the complete set of them.
///
/// The four states the app must distinguish are not flags checked with `if`
/// statements scattered through `build`. They are the type. A `switch` over
/// this class is checked for exhaustiveness at compile time, so a missing
/// branch is a build error rather than a blank screen.
sealed class ProductListState {
  const ProductListState();
}

/// The first load. Nothing is on screen yet.
class ProductListLoading extends ProductListState {
  const ProductListLoading();
}

/// The first load failed. The screen offers a retry.
class ProductListError extends ProductListState {
  const ProductListError(this.failure);

  final Failure failure;
}

/// The request succeeded and returned nothing.
///
/// Deliberately not an error: a search matching no products is a perfectly
/// successful request with an honest answer. [query] is carried so the
/// screen can name what found nothing.
class ProductListEmpty extends ProductListState {
  const ProductListEmpty({this.query = ''});

  final String query;
}

/// Products are on screen.
///
/// [isLoadingMore] and [hasReachedEnd] are fields here rather than states of
/// their own because fetching page three is not a loading state - it is a
/// success that happens to be busy. That is what keeps the list visible and
/// scrollable while the footer spinner turns.
class ProductListSuccess extends ProductListState {
  const ProductListSuccess({
    required this.products,
    this.isLoadingMore = false,
    this.hasReachedEnd = false,
    this.isBusy = false,
  });

  final List<Product> products;
  final bool isLoadingMore;
  final bool hasReachedEnd;

  /// A new first page is on its way - a search, or a refresh - while these
  /// products stay on screen.
  ///
  /// The third loading moment, and it needs its own treatment: replacing the
  /// list with a spinner on every keystroke makes a working search feel
  /// broken. So the results stay put and a thin bar under the search field
  /// carries the feedback instead.
  final bool isBusy;

  ProductListSuccess copyWith({
    List<Product>? products,
    bool? isLoadingMore,
    bool? hasReachedEnd,
    bool? isBusy,
  }) {
    return ProductListSuccess(
      products: products ?? this.products,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}
