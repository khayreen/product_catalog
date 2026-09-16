import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/api_client.dart';
import 'data/product_api.dart';
import 'data/product_repository.dart';
import 'presentation/products/product_list_cubit.dart';
import 'presentation/products/product_list_page.dart';

void main() {
  // The dependency chain is assembled once, here, and passed downwards.
  final repository = ProductRepository(ProductApi(createApiClient()));

  runApp(ProductCatalogApp(repository: repository));
}

class ProductCatalogApp extends StatelessWidget {
  const ProductCatalogApp({super.key, required this.repository});

  final ProductRepository repository;

  @override
  Widget build(BuildContext context) {
    // RepositoryProvider sits ABOVE MaterialApp deliberately. MaterialApp
    // owns the Navigator, and a pushed route is a sibling of `home`, not a
    // child — a provider inside `home` would be invisible to the detail
    // screen in step 10.
    return RepositoryProvider<ProductRepository>.value(
      value: repository,
      child: MaterialApp(
        title: 'Product Catalog',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF2A36C9),
        ),
        home: BlocProvider(
          create: (_) => ProductListCubit(repository)..loadFirstPage(),
          child: const ProductListPage(),
        ),
      ),
    );
  }
}
