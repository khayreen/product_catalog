# Product Catalog

A small Flutter product catalog built against the public
[DummyJSON](https://dummyjson.com) API: a paginated product list, a detail
screen, and debounced search.

## Running it

Built with **Flutter 3.32.0 / Dart 3.8.0** (stable).

```bash
flutter pub get
flutter run
```

No API key or `.env` file is needed — DummyJSON is public.

```bash
flutter analyze    # static analysis, currently clean
```

Verified in Chrome (`flutter run -d chrome`) and on an Android emulator
(API 36).

## Architecture

Three layers, each depending only on the one below it:

```
lib/
  core/            api_client.dart          Dio instance: base URL, timeouts
                   failure.dart             the error types the UI may see
  data/            models/                  Product, ProductPage
                   product_api.dart         the three endpoints, nothing else
                   product_repository.dart  paging policy + error translation
  presentation/    products/                list: state, cubit, page, tile
                   detail/                  detail: state, cubit, page
                   widgets/                 loading / error / empty, shared
```

Two rules hold the boundaries in place:

- **Nothing above `data/` imports `dio`.** The repository is the only place a
  `DioException` exists. Above it, failures are `NetworkFailure`,
  `ServerFailure` or `UnknownFailure`, each carrying a message already written
  for a person. Swapping `dio` for `http`, or DummyJSON for a real backend,
  touches the data layer and nothing else.
- **Nothing in `data/models/` imports Flutter.** That keeps the data layer
  independent of the UI and testable without a widget harness.

Dependencies are assembled once in `main.dart` and passed down — no service
locator, no global state.

### State management

`flutter_bloc`, using `Cubit` rather than full `Bloc`: the screens have a few
triggers (load, load more, search, retry) and no need for an event stream
between them.

The four required UI states are modelled as a **sealed class**, not boolean
flags:

```dart
sealed class ProductListState {}
class ProductListLoading extends ProductListState {}
class ProductListError   extends ProductListState { final Failure failure; }
class ProductListEmpty   extends ProductListState { final String query; }
class ProductListSuccess extends ProductListState {
  final List<Product> products;
  final bool isLoadingMore;
  final bool hasReachedEnd;
}
```

The screen body is a single `switch` over that type. Because the class is
sealed, the analyzer rejects the file if any state has no branch — a missing
state is a build error rather than a blank screen found in review.

`isLoadingMore` and `hasReachedEnd` are fields of the success state rather than
states of their own: fetching page three is a success that happens to be busy.
That keeps the list visible and scrollable while the footer spinner turns, and
it is why the two loading moments look different — a centred spinner for the
first fetch, a small footer indicator for later pages.

## Decisions and trade-offs

**Search is server-side.** `/products/search` returns the same
`{products, total, skip, limit}` envelope as the list endpoint, so
`ProductRepository.loadPage` picks the endpoint from the query and everything
above it paginates identically whether the user is browsing or searching — one
code path, one scroll controller. Client-side filtering would only have
searched the products already loaded, which for a paginated list is not really
search.

**Debounce and cancellation are separate mechanisms.** A 400 ms debounce
controls how many requests are sent. Cancellation controls which answer wins: a
slow request for `pho` can still be in flight when `phone` is sent, and without
a `CancelToken` whichever lands last would win. `RequestCancelled` is
deliberately not a `Failure`, so a superseded request can never surface as an
error state.

**Navigation passes a product id, not a `Product`.** The detail screen fetches
its own data, so it works when opened directly rather than only after the list
has loaded that product. The cost is one extra request per tap; the benefit is
a screen that does not depend on another screen's state.

**A failed *additional* page does not clear the list.** A first-page failure is
an error state with a retry. A page-five failure drops back to the products
already on screen — losing 80 products the user is reading because one later
page timed out would be worse than the failure itself.

**Pagination stops using the API's `total`.** `ProductPage` keeps `total` so
the cubit knows it has everything once `products.length >= total`, instead of
firing a wasted request to discover an empty array.

**No `freezed` or `json_serializable`.** Both would be right on a larger
codebase. For two small models they would add a build step and generated files
for little gain, so `fromJson` is written by hand.

**Defensive number parsing.** `price` and `rating` are read as `num` before
converting to `double`. Dart decodes `5` as `int` and `9.99` as `double`, so
`as double` would throw at runtime on a whole-number price.

## Not finished

- [ ] No unit tests. The repository is the natural place to start — it takes
      its `ProductApi` through the constructor, so it can be tested with a mock
      and no network.
- [ ] No pull-to-refresh.
- [ ] A failed additional page fails silently: the footer spinner stops and
      nothing is said. It should show a message with a retry.
- [ ] Prices are formatted with a hard-coded `$`. Should use `intl` and the
      device locale.
- [ ] The detail screen shows a single image rather than a gallery, and
      refetches on every tap — no caching.
- [ ] If a search returns fewer results than fill the screen, the scroll
      listener never fires, so any further pages are unreachable. Not visible
      with DummyJSON's data, but wrong.
- [ ] Dark theme is inherited from Material defaults and has not been designed.

## AI assistance

I used Claude (Claude Code) throughout this assessment. It planned the
architecture with me and wrote most of the implementation, which I then put
into the project file by file — creating each file, pasting the code in,
running `flutter analyze` and checking the app in the browser after every
step. Some later files were written directly into the project by the
assistant. I made the decisions on stack, project structure and scope, and
verified each feature worked before committing it.

I understand the code and the reasoning behind each decision documented
above. The parts I would most want to revisit are the silent failure on an
additional page, and the missing test coverage on the repository.
