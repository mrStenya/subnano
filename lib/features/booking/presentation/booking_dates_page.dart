import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/constants/app_constants.dart';
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

  DateTime get _firstAllowed => DateTime.now().add(const Duration(days: 1));

  int get _days =>
      (_startDate != null && _endDate != null)
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
      // Reset end if it's before or same day as start
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
      lastDate: _startDate!.add(const Duration(days: AppConstants.maxRentalDays)),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  void _proceed(double pricePerDay) {
    if (_startDate == null || _endDate == null) return;

    ref.read(bookingDraftProvider.notifier).update(
          scooterId: widget.scooterId,
          startDate: _startDate!,
          endDate: _endDate!,
          pricePerDay: pricePerDay,
        );

    context.go('/catalog/${widget.scooterId}/checkout');
  }

  @override
  Widget build(BuildContext context) {
    // TODO: read actual price from scooter provider
    const pricePerDay = 150.0;
    final total = _days * pricePerDay;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Dates')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rental period card
            _DateRangeCard(
              startDate: _startDate,
              endDate: _endDate,
              onPickStart: _pickStartDate,
              onPickEnd: _pickEndDate,
            ),
            const SizedBox(height: 24),

            // Summary
            if (_days > 0) ...[
              _SummaryRow(
                label: 'Rental days',
                value: '$_days ${_days == 1 ? 'day' : 'days'}',
              ),
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Price per day',
                value: CurrencyUtils.formatUsd(pricePerDay),
              ),
              const Divider(height: 24),
              _SummaryRow(
                label: 'Rental total',
                value: CurrencyUtils.formatUsd(total),
                bold: true,
              ),
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Security deposit',
                value: CurrencyUtils.formatUsd(AppConstants.depositAmountUsd),
                subtitle: 'Charged separately, refundable',
              ),
            ],

            const Spacer(),
            FilledButton(
              onPressed: (_startDate != null && _endDate != null)
                  ? () => _proceed(pricePerDay)
                  : null,
              child: const Text('Continue to Checkout'),
            ),
          ],
        ),
      ),
    );
  }
}

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
              child: _DatePickerTile(
                label: 'Pick-up date',
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
              child: _DatePickerTile(
                label: 'Return date',
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

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              date != null ? AppDateUtils.toDisplay(date!) : 'Select',
              style: TextStyle(
                fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                color: date != null ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: bold
                    ? Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)
                    : Theme.of(context).textTheme.bodyMedium,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: bold
              ? Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
