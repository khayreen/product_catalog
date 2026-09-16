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

  /// Loads the first page for the current query. Also the retry action —
  /// which is why retry genuinely re-runs the request.
  ///
  /// [showLoading] is false for a pull-to-refresh: the RefreshIndicator is
  /// already showing its own spinner, and emitting ProductListLoading would
  /// replace the list — and the indicator with it — mid-gesture.
  Future<void> loadFirstPage({bool showLoading = true}) async {
    final token = _beginRequest();
    if (showLoading) emit(const ProductListLoading());

    try {
      final page = await _repository.loadPage(
        skip: 0,
        query: _query,
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
    _debounce = Timer(_debounceDuration, () => loadFirstPage());
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
