import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../detail/product_detail_page.dart';
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
      appBar: AppBar(
        title: const Text('Products'),
        // The field lives in the AppBar, OUTSIDE the BlocBuilder below, so
        // it is not rebuilt on every state change — which would drop the
        // keyboard focus mid-word.
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(64),
          child: _SearchField(),
        ),
      ),
      body: BlocBuilder<ProductListCubit, ProductListState>(
        builder: (context, state) {
          return switch (state) {
            ProductListLoading() => const LoadingView(),
            ProductListError(:final failure) => ErrorView(
                message: failure.message,
                onRetry: () =>
                    context.read<ProductListCubit>().loadFirstPage(),
              ),
            ProductListEmpty(:final query) => EmptyView(
                message: query.isEmpty
                    ? 'No products to show yet.'
                    : 'No products match "$query".',
              ),
            ProductListSuccess() => _ProductListView(state: state),
          };
        },
      ),
    );
  }
}

/// The search box.
///
/// Deliberately thin: it forwards each keystroke to the cubit and nothing
/// more. The debouncing and the cancelling of superseded requests both live
/// in [ProductListCubit], so this widget has no timing logic to get wrong.
class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onChanged: context.read<ProductListCubit>().onQueryChanged,
        decoration: InputDecoration(
          hintText: 'Search products',
          prefixIcon: const Icon(Icons.search),
          // Only offer the clear button when there is something to clear.
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear search',
                onPressed: () {
                  _controller.clear();
                  context.read<ProductListCubit>().onQueryChanged('');
                },
              );
            },
          ),
          isDense: true,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// The success state's list, which owns the scroll controller that drives
/// pagination.
///
/// Stateful only because a [ScrollController] must be created and disposed
/// with the widget; the products themselves still come from the cubit.
class _ProductListView extends StatefulWidget {
  const _ProductListView({required this.state});

  final ProductListSuccess state;

  @override
  State<_ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<_ProductListView> {
  /// How close to the bottom, in pixels, before the next page is requested.
  static const double _loadMoreThreshold = 400;

  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  /// Fires on every scroll frame — dozens of times a second.
  ///
  /// That is deliberate and safe: the widget stays naive and asks every
  /// frame, while [ProductListCubit.loadNextPage] holds the guards that
  /// decide whether the request is actually worth making.
  void _onScroll() {
    if (!_controller.hasClients) return;

    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      context.read<ProductListCubit>().loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.state.products;
    final showFooter = widget.state.isLoadingMore;

    return ListView.separated(
      controller: _controller,
      itemCount: products.length + (showFooter ? 1 : 0),
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 88),
      itemBuilder: (context, index) {
        if (index >= products.length) {
          return const _LoadMoreFooter();
        }

        final product = products[index];
        return ProductTile(
          product: product,
          // The route carries only the id — the detail screen fetches its
          // own data rather than trusting what the list happens to hold.
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProductDetailPage(productId: product.id),
            ),
          ),
        );
      },
    );
  }
}

/// The second loading moment: a small indicator under the products, while
/// the list stays on screen and scrollable. Deliberately nothing like the
/// full-screen [LoadingView] used for the first fetch.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
