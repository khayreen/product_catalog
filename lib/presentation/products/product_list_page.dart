import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/product_category.dart';
import '../detail/product_detail_page.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'category_cubit.dart';
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
        actions: const [_SortAction()],
        // The field lives in the AppBar, OUTSIDE the BlocBuilder below, so
        // it is not rebuilt on every state change — which would drop the
        // keyboard focus mid-word.
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(66),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_SearchField(), _BusyBar()],
          ),
        ),
      ),
      // The filter bar sits outside the BlocBuilder so the chips stay put
      // while the list below them swaps between states.
      body: Column(
        children: [
          const _CategoryBar(),
          Expanded(
            child: BlocBuilder<ProductListCubit, ProductListState>(
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
                          ? 'Nothing here. Try another category.'
                          : 'No products match "$query".',
                    ),
                  ProductListSuccess() => _ProductListView(state: state),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Sorts the list by rating, highest first.
///
/// Its own widget so toggling it rebuilds an icon rather than the screen.
class _SortAction extends StatefulWidget {
  const _SortAction();

  @override
  State<_SortAction> createState() => _SortActionState();
}

class _SortActionState extends State<_SortAction> {
  bool _enabled = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IconButton(
      tooltip: _enabled ? 'Sorted by rating' : 'Sort by rating',
      isSelected: _enabled,
      icon: const Icon(Icons.star_border_rounded),
      selectedIcon: Icon(
        Icons.star_rounded,
        color: theme.colorScheme.tertiary,
      ),
      onPressed: () {
        setState(() => _enabled = !_enabled);
        context
            .read<ProductListCubit>()
            .setSortByRating(enabled: _enabled);
      },
    );
  }
}

/// A horizontally scrolling row of category chips, with "All" first.
///
/// Renders nothing at all until the categories arrive, and nothing ever if
/// they fail — the catalogue still works without it, so an empty bar is
/// better than an error in its place.
class _CategoryBar extends StatefulWidget {
  const _CategoryBar();

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryCubit, List<ProductCategory>>(
      builder: (context, categories) {
        if (categories.isEmpty) return const SizedBox.shrink();

        // Built eagerly into a Row rather than lazily by a ListView.
        // There are only ~25 chips, and a Material FilterChip is expensive
        // enough to build that constructing them mid-scroll shows as jank.
        // Building once and scrolling a static Row is visibly smoother.
        return RepaintBoundary(
          child: SizedBox(
            height: 52,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              // A little resistance at the ends reads better than a hard
              // stop when the row is dragged past its extent.
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Row(
                children: [
                  _chip(context, null, 'All'),
                  for (final category in categories) ...[
                    const SizedBox(width: 8),
                    _chip(context, category.slug, category.name),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(BuildContext context, String? slug, String label) {
    return FilterChip(
      label: Text(label),
      selected: _selected == slug,
      // The chip's own ink splash is enough feedback; the check mark makes
      // the row jump sideways as the chip widens.
      showCheckmark: false,
      onSelected: (_) {
        setState(() => _selected = slug);
        context.read<ProductListCubit>().setCategory(slug);
      },
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

/// A hairline progress bar under the search field.
///
/// This is the third loading moment. The first fetch owns the whole screen;
/// loading another page shows a footer spinner; searching while results are
/// already up shows this, and nothing moves. Replacing the list on every
/// keystroke made a working search feel broken.
///
/// It sits in its own BlocBuilder so that rebuilding it never rebuilds the
/// text field above, which would drop the keyboard focus mid-word.
class _BusyBar extends StatelessWidget {
  const _BusyBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductListCubit, ProductListState>(
      buildWhen: (previous, current) => _isBusy(previous) != _isBusy(current),
      builder: (context, state) {
        return SizedBox(
          height: 2,
          child: _isBusy(state)
              ? const LinearProgressIndicator(minHeight: 2)
              : null,
        );
      },
    );
  }

  static bool _isBusy(ProductListState state) =>
      state is ProductListSuccess && state.isBusy;
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

  /// How far down before the scroll-to-top button is worth offering —
  /// roughly two screens, so it never appears during ordinary browsing.
  static const double _showTopButtonAfter = 1200;

  final ScrollController _controller = ScrollController();

  bool _showTopButton = false;

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

    // Only rebuild when the answer actually changes — this runs on every
    // scroll frame, so calling setState unconditionally would rebuild the
    // whole list dozens of times a second.
    final shouldShow = position.pixels > _showTopButtonAfter;
    if (shouldShow != _showTopButton) {
      setState(() => _showTopButton = shouldShow);
    }
  }

  void _scrollToTop() {
    _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.state.products;
    final showFooter = widget.state.isLoadingMore;

    return Stack(
      children: [
        RefreshIndicator(
          // Returning the cubit's future keeps the spinner turning until the
          // new page has actually arrived, rather than snapping away.
          onRefresh: () => context.read<ProductListCubit>().refresh(),
          child: ListView.separated(
        controller: _controller,
            // Lets the gesture start even when the list is too short to
            // scroll, which is the case after a narrow search.
            physics: const AlwaysScrollableScrollPhysics(),
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
                // The route carries only the id — the detail screen fetches
                // its own data rather than trusting what the list holds.
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProductDetailPage(productId: product.id),
                  ),
                ),
              );
            },
          ),
        ),
        // Appears only once scrolling far enough that reaching the top by
        // hand would be tedious — 194 products is a long way back.
        Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedScale(
            scale: _showTopButton ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: FloatingActionButton.small(
              onPressed: _scrollToTop,
              tooltip: 'Back to top',
              child: const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        ),
      ],
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
