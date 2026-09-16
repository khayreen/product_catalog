import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/failure.dart';
import '../../data/models/product.dart';
import '../../data/product_repository.dart';
import 'product_list_state.dart';

/// Drives the product list: which page to ask for next, what the user is
/// searching for, and which state the screen should be in.
///
/// Both search mechanics live here rather than in the widget — the debounce
/// timer and the cancellation token — so the text field stays a plain
/// TextField with an onChanged.
class ProductListCubit extends Cubit<ProductListState> {
  ProductListCubit(this._repository) : super(const ProductListLoading());

  static const Duration _debounceDuration = Duration(milliseconds: 400);

  final ProductRepository _repository;

  Timer? _debounce;
  CancelToken? _inFlight;
  String _query = '';
  String? _category;
  bool _sortByRating = false;

  /// The category currently filtered to, or null for the whole catalogue.
  String? get category => _category;

  /// Whether the list is sorted by rating, highest first.
  bool get sortByRating => _sortByRating;

  /// Loads the first page for the current query. Also the retry action —
  /// which is why retry genuinely re-runs the request.
  ///
  /// [showLoading] is false when products are already on screen and should
  /// stay there — a search or a pull-to-refresh. In that case the existing
  /// list is kept and marked busy instead of being replaced by a spinner.
  /// With nothing worth preserving, the loading state is shown as normal.
  Future<void> loadFirstPage({bool showLoading = true}) async {
    final previous = state;
    final token = _beginRequest();

    if (!showLoading && previous is ProductListSuccess) {
      emit(previous.copyWith(isBusy: true));
    } else {
      emit(const ProductListLoading());
    }

    try {
      final page = await _repository.loadPage(
        skip: 0,
        query: _query,
        category: _category,
        sortByRating: _sortByRating,
        cancelToken: token,
      );

      if (isClosed || token.isCancelled) return;

      if (page.items.isEmpty) {
        emit(ProductListEmpty(query: _query));
        return;
      }

      emit(
        ProductListSuccess(
          products: page.items,
          hasReachedEnd: page.items.length >= page.total,
        ),
      );
    } on RequestCancelled {
      // A newer request replaced this one. Not an error.
    } on Failure catch (failure) {
      if (isClosed || token.isCancelled) return;
      emit(ProductListError(failure));
    }
  }

  /// Appends the next page, if there is one and we are not already fetching.
  Future<void> loadNextPage() async {
    final current = state;
    if (current is! ProductListSuccess) return;
    if (current.isLoadingMore || current.hasReachedEnd) return;

    emit(current.copyWith(isLoadingMore: true));

    try {
      final page = await _repository.loadPage(
        skip: current.products.length,
        query: _query,
        category: _category,
        sortByRating: _sortByRating,
      );

      if (isClosed) return;

      final combined = <Product>[...current.products, ...page.items];

      emit(
        current.copyWith(
          products: combined,
          isLoadingMore: false,
          hasReachedEnd: combined.length >= page.total,
        ),
      );
    } on RequestCancelled {
      if (isClosed) return;
      emit(current.copyWith(isLoadingMore: false));
    } on Failure {
      // Never clear products already on screen because page five failed.
      if (isClosed) return;
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  /// Pull-to-refresh: reload page one, keeping the current list on screen
  /// while it happens.
  ///
  /// Returns the future the RefreshIndicator awaits, so its spinner stays
  /// until the new page has actually arrived.
  Future<void> refresh() => loadFirstPage(showLoading: false);

  /// Called on every keystroke. Each one cancels the pending timer and
  /// starts another, so a burst of typing produces exactly one request.
  void onQueryChanged(String query) {
    final next = query.trim();
    if (next == _query) return;

    _query = next;
    _debounce?.cancel();
    // showLoading: false — results already on screen stay there while the
    // new ones are fetched, so the list does not flash on every keystroke.
    _debounce =
        Timer(_debounceDuration, () => loadFirstPage(showLoading: false));
  }

  /// Filters to one category, or clears the filter when [slug] is null.
  ///
  /// Goes straight to the network rather than filtering what is already
  /// loaded: only the first page is in memory, so filtering locally would
  /// search 20 products out of 194 and quietly miss the rest.
  void setCategory(String? slug) {
    if (slug == _category) return;

    _category = slug;
    loadFirstPage(showLoading: false);
  }

  /// Sorts by rating, highest first, or returns to the API's own order.
  void setSortByRating({required bool enabled}) {
    if (enabled == _sortByRating) return;

    _sortByRating = enabled;
    loadFirstPage(showLoading: false);
  }

  /// Cancels any in-flight request and returns a fresh token.
  ///
  /// This is what debounce cannot do: a slow request for "pho" can still be
  /// in the air when "phone" is sent, and without cancelling it, whichever
  /// lands last wins.
  CancelToken _beginRequest() {
    _inFlight?.cancel();
    final token = CancelToken();
    _inFlight = token;
    return token;
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _inFlight?.cancel();
    return super.close();
  }
}
