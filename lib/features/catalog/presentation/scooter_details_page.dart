import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../../shared/widgets/price_tag.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../shared/models/scooter.dart';
import '../domain/catalog_repository.dart';

class ScooterDetailsPage extends ConsumerWidget {
  const ScooterDetailsPage({super.key, required this.scooterId});

  final String scooterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scooterAsync = ref.watch(scooterDetailProvider(scooterId));

    return Scaffold(
      body: scooterAsync.when(
        loading: () => _DetailsLoadingSkeleton(scooterId: scooterId),
        error: (e, _) => CustomScrollView(
          slivers: [
            SliverAppBar(pinned: true, title: const Text('Scooter')),
            SliverFillRemaining(
              child: AppErrorWidget(
                message: 'Could not load scooter details.',
                onRetry: () =>
                    ref.invalidate(scooterDetailProvider(scooterId)),
              ),
            ),
          ],
        ),
        data: (scooter) => _DetailsContent(
          scooter: scooter,
          scooterId: scooterId,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main content — shown when data is ready
// ---------------------------------------------------------------------------
class _DetailsContent extends StatelessWidget {
  const _DetailsContent({
    required this.scooter,
    required this.scooterId,
  });

  final Scooter scooter;
  final String scooterId;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _HeroAppBar(scooter: scooter),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _PriceRow(scooter: scooter),
              const SizedBox(height: 16),
              if (scooter.description != null) ...[
                Text(
                  scooter.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
              ],
              _SectionLabel('Specifications'),
              const SizedBox(height: 10),
              _SpecsGrid(scooter: scooter),
              const SizedBox(height: 20),
              _SectionLabel('Pickup location'),
              const SizedBox(height: 10),
              _PickupPointCard(scooter: scooter),
              const SizedBox(height: 20),
              _DepositCard(amount: AppConstants.depositAmountUsd),
            ]),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero SliverAppBar with image
// ---------------------------------------------------------------------------
class _HeroAppBar extends StatelessWidget {
  const _HeroAppBar({required this.scooter});

  final Scooter scooter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          scooter.name,
          style: const TextStyle(shadows: [
            Shadow(color: Colors.black54, blurRadius: 4),
          ]),
        ),
        background: scooter.imageUrl != null
            ? Image.network(
                scooter.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ImagePlaceholder(cs: cs),
              )
            : _ImagePlaceholder(cs: cs),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.water, size: 96, color: cs.onSurfaceVariant),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Price + availability row
// ---------------------------------------------------------------------------
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.scooter});

  final Scooter scooter;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PriceTag(
          amount: scooter.pricePerDay,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        _AvailabilityChip(status: scooter.status),
      ],
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.status});

  final ScooterStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (status) {
      ScooterStatus.available => ('Available', Icons.check_circle_outline, cs.primary),
      ScooterStatus.rented => ('Rented', Icons.cancel_outlined, cs.error),
      ScooterStatus.maintenance => ('In maintenance', Icons.build_outlined, cs.tertiary),
      ScooterStatus.retired => ('Retired', Icons.block_outlined, cs.outline),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

// ---------------------------------------------------------------------------
// Specifications grid
// ---------------------------------------------------------------------------
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _SpecsGrid extends StatelessWidget {
  const _SpecsGrid({required this.scooter});

  final Scooter scooter;

  @override
  Widget build(BuildContext context) {
    // Build only specs that have data
    final specs = <({String label, String value, IconData icon})>[
      if (scooter.maxDepthM != null)
        (label: 'Max depth', value: '${scooter.maxDepthM} m', icon: Icons.arrow_downward),
      if (scooter.maxSpeedKnots != null)
        (label: 'Max speed', value: '${scooter.maxSpeedKnots} kn', icon: Icons.speed),
      if (scooter.batteryHours != null)
        (label: 'Battery', value: '${scooter.batteryHours} h', icon: Icons.battery_full),
      if (scooter.weightKg != null)
        (label: 'Weight', value: '${scooter.weightKg} kg', icon: Icons.fitness_center),
    ];

    if (specs.isEmpty) {
      return Text(
        'No specifications available.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: specs.map((s) => _SpecTile(s)).toList(),
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile(this.spec);

  final ({String label, String value, IconData icon}) spec;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spec.value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                spec.label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pickup point card
// ---------------------------------------------------------------------------
class _PickupPointCard extends StatelessWidget {
  const _PickupPointCard({required this.scooter});

  final Scooter scooter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasLocation =
        scooter.pickupPointName != null || scooter.pickupPointAddress != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: hasLocation
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (scooter.pickupPointName != null)
                        Text(
                          scooter.pickupPointName!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      if (scooter.pickupPointAddress != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          scooter.pickupPointAddress!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  )
                : Text(
                    'Pickup location to be confirmed',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Deposit info card
// ---------------------------------------------------------------------------
class _DepositCard extends StatelessWidget {
  const _DepositCard({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.secondary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: cs.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security deposit — ${CurrencyUtils.formatUsd(amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Charged separately after rental payment. '
                  'Fully refunded after confirmed safe return.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSecondaryContainer.withOpacity(0.8),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FAB — shown at Scaffold level so it sits above the CustomScrollView
// ---------------------------------------------------------------------------
extension ScooterDetailsPageFab on ScooterDetailsPage {
  Widget? buildFab(BuildContext context, AsyncValue<Scooter> scooterAsync) {
    return scooterAsync.whenOrNull(
      data: (scooter) => scooter.isAvailable
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/catalog/$scooterId/dates'),
              icon: const Icon(Icons.calendar_today),
              label: const Text('Book Now'),
            )
          : null,
    );
  }
}

// We override the build of ScooterDetailsPage to wire the FAB correctly.
// The cleanest way in this structure is to keep it as a StatelessWidget
// and use Scaffold's floatingActionButton.
//
// Re-export a corrected version so the router can use it directly:
class ScooterDetailsPageWrapper extends ConsumerWidget {
  const ScooterDetailsPageWrapper({super.key, required this.scooterId});

  final String scooterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scooterAsync = ref.watch(scooterDetailProvider(scooterId));

    return Scaffold(
      body: scooterAsync.when(
        loading: () => _DetailsLoadingSkeleton(scooterId: scooterId),
        error: (e, _) => CustomScrollView(
          slivers: [
            SliverAppBar(pinned: true, title: const Text('Scooter')),
            SliverFillRemaining(
              child: AppErrorWidget(
                message: 'Could not load scooter details.',
                onRetry: () =>
                    ref.invalidate(scooterDetailProvider(scooterId)),
              ),
            ),
          ],
        ),
        data: (scooter) => _DetailsContent(
          scooter: scooter,
          scooterId: scooterId,
        ),
      ),
      floatingActionButton: scooterAsync.whenOrNull(
        data: (scooter) => scooter.isAvailable
            ? FloatingActionButton.extended(
                onPressed: () => context.go('/catalog/$scooterId/dates'),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Book Now'),
              )
            : null,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------
class _DetailsLoadingSkeleton extends StatelessWidget {
  const _DetailsLoadingSkeleton({required this.scooterId});

  final String scooterId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: cs.surfaceContainerHighest,
      highlightColor: cs.surface,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: Colors.white),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Container(height: 32, width: 160, color: Colors.white),
                const SizedBox(height: 16),
                Container(height: 14, color: Colors.white),
                const SizedBox(height: 6),
                Container(height: 14, width: 260, color: Colors.white),
                const SizedBox(height: 24),
                Container(height: 80, decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                )),
                const SizedBox(height: 16),
                Container(height: 70, decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
