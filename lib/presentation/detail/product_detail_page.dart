import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/product.dart';
import '../../data/product_repository.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'product_detail_cubit.dart';
import 'product_detail_state.dart';

/// The detail screen's entry point.
///
/// It takes only an id, not a [Product]: the screen fetches its own data, so
/// it does not depend on the list having already loaded that product. The
/// cubit is built here, reading the repository the app provided above
/// [MaterialApp] - which is why a pushed route can still reach it.
class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProductDetailCubit(context.read<ProductRepository>(), productId)
            ..load(),
      child: const _ProductDetailView(),
    );
  }
}

class _ProductDetailView extends StatelessWidget {
  const _ProductDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: BlocBuilder<ProductDetailCubit, ProductDetailState>(
        builder: (context, state) {
          return switch (state) {
            ProductDetailLoading() => const LoadingView(),
            ProductDetailError(:final failure) => ErrorView(
                message: failure.message,
                onRetry: () => context.read<ProductDetailCubit>().load(),
              ),
            ProductDetailSuccess(:final product) => _DetailBody(
                product: product,
              ),
          };
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl =
        product.images.isNotEmpty ? product.images.first : product.thumbnail;

    return ListView(
      children: [
        SizedBox(
          height: 300,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            errorWidget: (context, url, error) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.image_not_supported_outlined,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    // TODO(izzah): format with `intl` and the device locale.
                    'RM ${product.price.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.star_rounded,
                    size: 20,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    product.rating.toStringAsFixed(1),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Description', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                product.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
