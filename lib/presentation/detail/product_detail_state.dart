import '../../core/failure.dart';
import '../../data/models/product.dart';

/// Every state the detail screen can be in.
///
/// Note there is no empty state here, and that is a decision rather than an
/// omission: a request for one product either returns it or fails. "Empty"
/// is only meaningful for a collection, so modelling it would mean carrying
/// a case that can never occur - and the exhaustive `switch` would force
/// the screen to render something for it.
sealed class ProductDetailState {
  const ProductDetailState();
}

class ProductDetailLoading extends ProductDetailState {
  const ProductDetailLoading();
}

class ProductDetailError extends ProductDetailState {
  const ProductDetailError(this.failure);

  final Failure failure;
}

class ProductDetailSuccess extends ProductDetailState {
  const ProductDetailSuccess(this.product);

  final Product product;
}
