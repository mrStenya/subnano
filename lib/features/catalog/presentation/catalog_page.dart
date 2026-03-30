import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../../shared/widgets/price_tag.dart';
import '../domain/catalog_repository.dart';
import '../../../shared/models/scooter.dart';

// Tracks whether the "available only" filter is active
final _availableOnlyProvider = StateProvider<bool>((ref) => false);

class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableOnly = ref.watch(_availableOnlyProvider);
    final scootersAsync = ref.watch(scooterListProvider(availableOnly));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scooters'),
        bottom: _FilterBar(availableOnly: availableOnly),
      ),
      body: scootersAsync.when(
        loading: () => const _ShimmerList(),
        error: (e, _) => AppErrorWidget(
          message: 'Could not load scooters.\nCheck your connection.',
          onRetry: () => ref.invalidate(scooterListProvider(availableOnly)),
        ),
        data: (scooters) => scooters.isEmpty
            ? _EmptyState(availableOnly: availableOnly)
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(scooterListProvider(availableOnly)),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: scooters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ScooterCard(scooter: scooters[i]),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bar (PreferredSize AppBar bottom)
// ---------------------------------------------------------------------------
class _FilterBar extends ConsumerWidget implements PreferredSizeWidget {
  const _FilterBar({required this.availableOnly});

  final bool availableOnly;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          FilterChip(
            label: const Text('Available only'),
            selected: availableOnly,
            onSelected: (v) =>
                ref.read(_availableOnlyProvider.notifier).state = v,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer skeleton — shown while loading
// ---------------------------------------------------------------------------
class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surface;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => _ShimmerCard(),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          Container(
            height: 180,
            color: Colors.white,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 16, width: 160, color: Colors.white),
                const SizedBox(height: 8),
                Container(height: 12, width: double.infinity, color: Colors.white),
                const SizedBox(height: 4),
                Container(height: 12, width: 200, color: Colors.white),
                const SizedBox(height: 12),
                Container(height: 16, width: 80, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.availableOnly});

  final bool availableOnly;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_outlined, size: 72, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(
              availableOnly
                  ? 'No scooters available right now'
                  : 'No scooters in catalog',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              availableOnly
                  ? 'Try removing the "Available only" filter.'
                  : 'Check back soon — we\'re adding new models.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scooter card
// ---------------------------------------------------------------------------
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
            _ScooterImage(imageUrl: scooter.imageUrl),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          scooter.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(status: scooter.status),
                    ],
                  ),
                  if (scooter.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      scooter.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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
                          label: '${scooter.maxDepthM}m',
                        ),
                      if (scooter.batteryHours != null) ...[
                        const SizedBox(width: 8),
                        _SpecBadge(
                          icon: Icons.battery_full,
                          label: '${scooter.batteryHours}h',
                        ),
                      ],
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

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------
class _ScooterImage extends StatelessWidget {
  const _ScooterImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (imageUrl == null) return _Placeholder(cs: cs);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Shimmer.fromColors(
                baseColor: cs.surfaceContainerHighest,
                highlightColor: cs.surface,
                child: Container(color: Colors.white),
              ),
        errorBuilder: (_, __, ___) => _Placeholder(cs: cs),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.water, size: 48, color: cs.onSurfaceVariant),
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
      ScooterStatus.retired => ('Retired', cs.outline),
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
