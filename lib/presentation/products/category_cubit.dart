import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/failure.dart';
import '../../data/models/product_category.dart';
import '../../data/product_repository.dart';

/// The categories available in the filter bar.
///
/// A plain `Cubit<List<ProductCategory>>` rather than a sealed state,
/// because this one genuinely has no states worth distinguishing: the
/// filter bar is chrome. If the categories never arrive, the bar simply
/// does not appear and everything else still works - so an empty list is a
/// perfectly good way to say "nothing to show here".
class CategoryCubit extends Cubit<List<ProductCategory>> {
  CategoryCubit(this._repository) : super(const <ProductCategory>[]);

  final ProductRepository _repository;

  Future<void> load() async {
    try {
      final categories = await _repository.loadCategories();
      if (isClosed) return;
      emit(categories);
    } on Failure {
      // Deliberately silent. Losing the filter bar is a degraded experience,
      // not a broken one, and an error banner over a working product list
      // would be worse than the missing chips.
    } on RequestCancelled {
      // Nothing to do.
    }
  }
}
