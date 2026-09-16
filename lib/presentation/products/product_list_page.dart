import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'product_list_cubit.dart';
import 'product_list_state.dart';
import 'widgets/product_tile.dart';

/// The catalogue screen.
///
/// The whole body is one `switch` over [ProductListState]. Because that
/// class is sealed, the analyzer rejects this file if a state has no
/// branch — the four required states cannot quietly go missing.
class ProductListPage extends StatelessWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: BlocBuilder<ProductListCubit, ProductListState>(
        builder: (context, state) {
          return switch (state) {
            ProductListLoading() => const LoadingView(),
            ProductListError(:final failure) => ErrorView(
              message: failure.message,
              onRetry: () => context.read<ProductListCubit>().loadFirstPage(),
            ),
            ProductListEmpty(:final query) => EmptyView(
              message: query.isEmpty
                  ? 'No products to show yet.'
                  : 'No products match "$query".',
            ),
            ProductListSuccess(:final products) => ListView.separated(
              itemCount: products.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 88),
              itemBuilder: (context, index) =>
                  ProductTile(product: products[index]),
            ),
          };
        },
      ),
    );
  }
}
