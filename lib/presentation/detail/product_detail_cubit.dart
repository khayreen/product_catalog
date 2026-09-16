import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/failure.dart';
import '../../data/product_repository.dart';
import 'product_detail_state.dart';

/// Loads one product for the detail screen.
///
/// Holds the id it was created with, so [load] doubles as the retry action
/// without the widget having to remember which product it was showing.
class ProductDetailCubit extends Cubit<ProductDetailState> {
  ProductDetailCubit(this._repository, this._productId)
      : super(const ProductDetailLoading());

  final ProductRepository _repository;
  final int _productId;

  Future<void> load() async {
    emit(const ProductDetailLoading());

    try {
      final product = await _repository.loadProduct(_productId);

      if (isClosed) return;
      emit(ProductDetailSuccess(product));
    } on RequestCancelled {
      // Superseded by a newer request; that one owns the screen now.
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(ProductDetailError(failure));
    }
  }
}
