import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../../shared/widgets/price_tag.dart';
import '../domain/catalog_repository.dart';
import '../../../shared/models/scooter.dart';

class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scootersAsync = ref.watch(scooterListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Scooters'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Filter',
            onPressed: () {
              // TODO: show filter bottom sheet
            },
          ),
        ],
      ),
      body: scootersAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: 'Failed to load scooters',
          onRetry: () => ref.invalidate(scooterListProvider),
        ),
        data: (scooters) => scooters.isEmpty
            ? const Center(child: Text('No scooters available'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: scooters.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _ScooterCard(scooter: scooters[i]),
              ),
      ),
    );
  }
}

class _ScooterCard extends StatelessWidget {
  const _ScooterCard({required this.scooter});

  final Scooter scooter;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/catalog/${scooter.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scooter image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: scooter.imageUrl != null
                  ? Image.network(
                      scooter.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderImage(),
                    )
                  : _PlaceholderImage(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          scooter.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _StatusChip(status: scooter.status),
                    ],
                  ),
                  if (scooter.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      scooter.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PriceTag(amount: scooter.pricePerDay),
                      const Spacer(),
                      if (scooter.maxDepthM != null)
                        _SpecBadge(
                          icon: Icons.arrow_downward,
                          label: '${scooter.maxDepthM}m depth',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.water,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ScooterStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      ScooterStatus.available => ('Available', cs.primary),
      ScooterStatus.rented => ('Rented', cs.error),
      ScooterStatus.maintenance => ('Maintenance', cs.tertiary),
      ScooterStatus.retired => ('Retired', cs.outlineVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SpecBadge extends StatelessWidget {
  const _SpecBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
