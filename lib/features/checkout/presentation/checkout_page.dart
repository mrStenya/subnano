import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/checkout_service.dart';
import '../../booking/domain/booking_draft_provider.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, required this.scooterId});

  final String scooterId;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  bool _payingRental = false;
  bool _payingDeposit = false;
  bool _rentalPaid = false;
  String? _bookingId;
  String? _error;

  Future<void> _payRental() async {
    final draft = ref.read(bookingDraftProvider);
    if (draft == null) return;

    setState(() {
      _payingRental = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(checkoutServiceProvider)
          .createBookingAndPayRental(draft: draft);

      setState(() {
        _rentalPaid = true;
        _bookingId = result.bookingId;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _payingRental = false);
    }
  }

  Future<void> _payDeposit() async {
    if (_bookingId == null) return;

    setState(() {
      _payingDeposit = true;
      _error = null;
    });

    try {
      await ref
          .read(checkoutServiceProvider)
          .chargeDeposit(bookingId: _bookingId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking confirmed!')),
        );
        context.go(AppRoutes.myBookings);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _payingDeposit = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);

    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: Text('No booking in progress')),
      );
    }

    final days = AppDateUtils.rentalDays(draft.startDate, draft.endDate);
    final rentalTotal = days * draft.pricePerDay;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Booking summary card
            _SummaryCard(
              startDate: draft.startDate,
              endDate: draft.endDate,
              days: days,
              pricePerDay: draft.pricePerDay,
              rentalTotal: rentalTotal,
            ),
            const SizedBox(height: 24),

            // Step 1: Pay rental
            _CheckoutStep(
              step: 1,
              title: 'Pay rental',
              amount: rentalTotal,
              description: 'Secures your booking',
              completed: _rentalPaid,
              loading: _payingRental,
              enabled: !_rentalPaid,
              onPay: _payRental,
            ),
            const SizedBox(height: 16),

            // Step 2: Pay deposit
            _CheckoutStep(
              step: 2,
              title: 'Pay security deposit',
              amount: AppConstants.depositAmountUsd,
              description: 'Fully refundable after safe return',
              completed: false,
              loading: _payingDeposit,
              enabled: _rentalPaid && !_payingDeposit,
              onPay: _payDeposit,
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.pricePerDay,
    required this.rentalTotal,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final double pricePerDay;
  final double rentalTotal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Summary',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            _Row(
              label: 'Pick-up',
              value: AppDateUtils.toDisplay(startDate),
            ),
            const SizedBox(height: 8),
            _Row(
              label: 'Return',
              value: AppDateUtils.toDisplay(endDate),
            ),
            const SizedBox(height: 8),
            _Row(
              label: 'Duration',
              value: '$days ${days == 1 ? 'day' : 'days'}',
            ),
            const SizedBox(height: 8),
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
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Text(
          label,
          style: style?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}

class _CheckoutStep extends StatelessWidget {
  const _CheckoutStep({
    required this.step,
    required this.title,
    required this.amount,
    required this.description,
    required this.completed,
    required this.loading,
    required this.enabled,
    required this.onPay,
  });

  final int step;
  final String title;
  final double amount;
  final String description;
  final bool completed;
  final bool loading;
  final bool enabled;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      completed ? cs.primary : cs.surfaceContainerHighest,
                  child: completed
                      ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                      : Text(
                          '$step',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              )),
                    ],
                  ),
                ),
                Text(
                  CurrencyUtils.formatUsd(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (!completed) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: enabled ? onPay : null,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Pay ${CurrencyUtils.formatUsd(amount)}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
