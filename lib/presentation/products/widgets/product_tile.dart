import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/models/product.dart';

/// One row of the catalogue: thumbnail, title, price.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: product.thumbnail,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              Container(color: theme.colorScheme.surfaceContainerHighest),
          errorWidget: (context, url, error) => Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 20,
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ),
      title: Text(
        product.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            // TODO(izzah): format per locale with `intl` instead of a hard $.
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            // Rating belongs in the list, not only on the detail screen: it
            // is the signal people scan alongside price when deciding what
            // to open, and it is already in the response.
            Icon(
              Icons.star_rounded,
              size: 15,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(width: 2),
            Text(
              product.rating.toStringAsFixed(1),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
