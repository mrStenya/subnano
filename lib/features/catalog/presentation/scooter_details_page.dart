import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../../shared/widgets/price_tag.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/catalog_repository.dart';

class ScooterDetailsPage extends ConsumerWidget {
  const ScooterDetailsPage({super.key, required this.scooterId});

  final String scooterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scooterAsync = ref.watch(scooterDetailProvider(scooterId));

    return Scaffold(
      body: scooterAsync.when(
        loading: () => const Scaffold(body: LoadingWidget()),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: AppErrorWidget(message: 'Failed to load scooter'),
        ),
        data: (scooter) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(scooter.name),
                background: scooter.imageUrl != null
                    ? Image.network(scooter.imageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.water, size: 80),
                      ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Price
                  Row(
                    children: [
                      PriceTag(
                        amount: scooter.pricePerDay,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      _AvailabilityBadge(
                        available:
                            scooter.status.name == 'available',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (scooter.description != null) ...[
                    Text(
                      scooter.description!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Specs
                  _SectionHeader(title: 'Specifications'),
                  const SizedBox(height: 8),
                  _SpecsGrid(scooter: scooter),
                  const SizedBox(height: 20),

                  // Deposit info
                  _DepositCard(
                    depositAmount: AppConstants.depositAmountUsd,
                  ),
                  const SizedBox(height: 80), // space for FAB
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: scooterAsync.whenOrNull(
        data: (scooter) => scooter.status.name == 'available'
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

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        available ? Icons.check_circle : Icons.cancel,
        size: 16,
        color: available ? cs.primary : cs.error,
      ),
      label: Text(available ? 'Available' : 'Not available'),
      backgroundColor: available
          ? cs.primary.withOpacity(0.1)
          : cs.error.withOpacity(0.1),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

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

  final dynamic scooter;

  @override
  Widget build(BuildContext context) {
    final specs = <_Spec>[
      if (scooter.maxDepthM != null)
        _Spec('Max depth', '${scooter.maxDepthM} m', Icons.arrow_downward),
      if (scooter.maxSpeedKnots != null)
        _Spec('Max speed', '${scooter.maxSpeedKnots} kn', Icons.speed),
      if (scooter.batteryHours != null)
        _Spec('Battery', '${scooter.batteryHours} h', Icons.battery_full),
      if (scooter.weightKg != null)
        _Spec('Weight', '${scooter.weightKg} kg', Icons.fitness_center),
    ];

    if (specs.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: specs.map((s) => _SpecTile(spec: s)).toList(),
    );
  }
}

class _Spec {
  const _Spec(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({required this.spec});

  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              Text(spec.value,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(spec.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      )),
            ],
          ),
        ],
      ),
    );
  }
}

class _DepositCard extends StatelessWidget {
  const _DepositCard({required this.depositAmount});

  final double depositAmount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cs.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security deposit required',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${depositAmount.toStringAsFixed(0)} held separately. '
                  'Released after safe return.',
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
