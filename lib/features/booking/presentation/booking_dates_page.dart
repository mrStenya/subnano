import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../../shared/models/scooter.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../domain/booking_draft_provider.dart';

class BookingDatesPage extends ConsumerStatefulWidget {
  const BookingDatesPage({super.key, required this.scooterId});

  final String scooterId;

  @override
  ConsumerState<BookingDatesPage> createState() => _BookingDatesPageState();
}

class _BookingDatesPageState extends ConsumerState<BookingDatesPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _checkingAvailability = false;
  String? _availabilityError;

  DateTime get _firstAllowed => DateTime.now().add(const Duration(days: 1));

  int get _days => (_startDate != null && _endDate != null)
      ? AppDateUtils.rentalDays(_startDate!, _endDate!)
      : 0;

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? _firstAllowed,
      firstDate: _firstAllowed,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      _availabilityError = null;
      if (_endDate != null && !_endDate!.isAfter(picked)) {
        _endDate = null;
      }
    });
  }

  Future<void> _pickEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a start date first')),
      );
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!.add(const Duration(days: 1)),
      firstDate: _startDate!.add(const Duration(days: 1)),
      lastDate: _startDate!
          .add(const Duration(days: AppConstants.maxRentalDays)),
    );
    if (picked == null) return;
    setState(() {
      _endDate = picked;
      _availabilityError = null;
    });
    // Auto-check availability when both dates are set
    await _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    if (_startDate == null || _endDate == null) return;
    setState(() {
      _checkingAvailability = true;
      _availabilityError = null;
    });
    try {
      final available = await ref
          .read(catalogRepositoryProvider)
          .checkAvailability(
            scooterId: widget.scooterId,
            startDate: _startDate!,
            endDate: _endDate!,
          );
      if (!available) {
        setState(() => _availabilityError =
            'This scooter is already booked for the selected dates. '
            'Please choose different dates.');
      }
    } catch (_) {
      // Non-fatal — let the user proceed; server will validate on booking creation
    } finally {
      if (mounted) setState(() => _checkingAvailability = false);
    }
  }

  void _proceed(Scooter scooter) {
    if (_startDate == null || _endDate == null) return;
    if (_availabilityError != null) return;

    ref.read(bookingDraftProvider.notifier).set(
          scooterId: widget.scooterId,
          scooterName: scooter.name,
          startDate: _startDate!,
          endDate: _endDate!,
          pricePerDay: scooter.pricePerDay,
        );

    context.go('/catalog/${widget.scooterId}/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final scooterAsync = ref.watch(scooterDetailProvider(widget.scooterId));

    return Scaffold(
      appBar: AppBar(title: const Text('Select Dates')),
      body: scooterAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: 'Could not load scooter.',
          onRetry: () =>
              ref.invalidate(scooterDetailProvider(widget.scooterId)),
        ),
        data: (scooter) => _Body(
          scooter: scooter,
          startDate: _startDate,
          endDate: _endDate,
          days: _days,
          checkingAvailability: _checkingAvailability,
          availabilityError: _availabilityError,
          onPickStart: _pickStartDate,
          onPickEnd: _pickEndDate,
          onProceed: () => _proceed(scooter),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — extracted to keep State clean
// ---------------------------------------------------------------------------
class _Body extends StatelessWidget {
  const _Body({
    required this.scooter,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.checkingAvailability,
    required this.availabilityError,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onProceed,
  });

  final Scooter scooter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int days;
  final bool checkingAvailability;
  final String? availabilityError;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onProceed;

  bool get _canProceed =>
      startDate != null &&
      endDate != null &&
      !checkingAvailability &&
      availabilityError == null;

  @override
  Widget build(BuildContext context) {
    final rentalTotal = days * scooter.pricePerDay;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scooter name header
          Text(
            scooter.name,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyUtils.formatUsd(scooter.pricePerDay) + ' / day',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 20),

          // Date pickers
          _DateRangeCard(
            startDate: startDate,
            endDate: endDate,
            onPickStart: onPickStart,
            onPickEnd: onPickEnd,
          ),

          // Availability feedback
          if (checkingAvailability) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Checking availability…'),
              ],
            ),
          ],
          if (availabilityError != null) ...[
            const SizedBox(height: 12),
            _InlineError(message: availabilityError!),
          ],

          const SizedBox(height: 24),

          // Price summary
          if (days > 0) ...[
            _SummaryTable(
              days: days,
              pricePerDay: scooter.pricePerDay,
              rentalTotal: rentalTotal,
              depositAmount: AppConstants.depositAmountUsd,
            ),
            const SizedBox(height: 20),
          ],

          const Spacer(),
          FilledButton(
            onPressed: _canProceed ? onProceed : null,
            child: const Text('Continue to Checkout'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date range picker card
// ---------------------------------------------------------------------------
class _DateRangeCard extends StatelessWidget {
  const _DateRangeCard({
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _DateTile(
                label: 'Pick-up',
                date: startDate,
                onTap: onPickStart,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            Expanded(
              child: _DateTile(
                label: 'Return',
                date: endDate,
                onTap: onPickEnd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDate = date != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasDate
              ? cs.primaryContainer.withOpacity(0.5)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: hasDate
              ? Border.all(color: cs.primary.withOpacity(0.4))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              hasDate ? AppDateUtils.toDisplay(date!) : 'Select',
              style: TextStyle(
                fontWeight:
                    hasDate ? FontWeight.w600 : FontWeight.normal,
                color: hasDate ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary table
// ---------------------------------------------------------------------------
class _SummaryTable extends StatelessWidget {
  const _SummaryTable({
    required this.days,
    required this.pricePerDay,
    required this.rentalTotal,
    required this.depositAmount,
  });

  final int days;
  final double pricePerDay;
  final double rentalTotal;
  final double depositAmount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Row(
          label: 'Rental days',
          value: '$days ${days == 1 ? 'day' : 'days'}',
        ),
        const SizedBox(height: 6),
        _Row(
          label: 'Rate',
          value: '${CurrencyUtils.formatUsd(pricePerDay)} / day',
        ),
        const Divider(height: 20),
        _Row(
          label: 'Rental total',
          value: CurrencyUtils.formatUsd(rentalTotal),
          bold: true,
        ),
        const SizedBox(height: 6),
        _Row(
          label: 'Security deposit',
          value: CurrencyUtils.formatUsd(depositAmount),
          subtitle: 'Charged separately · refundable',
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.bold = false,
    this.subtitle,
  });

  final String label;
  final String value;
  final bool bold;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textStyle = bold
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: textStyle),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        ),
        Text(value, style: textStyle),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Inline error
// ---------------------------------------------------------------------------
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: cs.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
