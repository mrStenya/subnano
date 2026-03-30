import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/checkout_notifier.dart';
import '../domain/checkout_state.dart';
import '../../booking/domain/booking_draft_provider.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, required this.scooterId});

  final String scooterId;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  @override
  void initState() {
    super.initState();
    // Reset checkout state when arriving at this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkoutNotifierProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(checkoutNotifierProvider);
    final draft = ref.watch(bookingDraftProvider);

    // Navigate away when completed
    ref.listen<CheckoutState>(checkoutNotifierProvider, (_, next) {
      if (next is CheckoutCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking confirmed! See you on the water.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go(AppRoutes.myBookings);
      }
    });

    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: Text('No booking in progress.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        // Prevent accidental back navigation mid-payment
        automaticallyImplyLeading: checkoutState is CheckoutIdle ||
            checkoutState is CheckoutRentalCancelled ||
            checkoutState is CheckoutDepositCancelled ||
            checkoutState is CheckoutError,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BookingSummaryCard(draft: draft),
            const SizedBox(height: 20),
            _RentalStep(state: checkoutState, draft: draft),
            const SizedBox(height: 12),
            _DepositStep(state: checkoutState),
            const SizedBox(height: 16),
            _ErrorBanner(state: checkoutState),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Booking summary card
// ---------------------------------------------------------------------------
class _BookingSummaryCard extends StatelessWidget {
  const _BookingSummaryCard({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              draft.scooterName.isNotEmpty ? draft.scooterName : 'Scooter',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            _SummaryRow(
              label: 'Pick-up',
              value: AppDateUtils.toDisplay(draft.startDate),
            ),
            _SummaryRow(
              label: 'Return',
              value: AppDateUtils.toDisplay(draft.endDate),
            ),
            _SummaryRow(
              label: 'Duration',
              value:
                  '${draft.rentalDays} ${draft.rentalDays == 1 ? 'day' : 'days'}',
            ),
            _SummaryRow(
              label: 'Rate',
              value: '${CurrencyUtils.formatUsd(draft.pricePerDay)} / day',
            ),
            const Divider(height: 20),
            _SummaryRow(
              label: 'Rental total',
              value: CurrencyUtils.formatUsd(draft.rentalTotal),
              bold: true,
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
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = bold
        ? Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style:
                style?.copyWith(color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — Rental payment
// ---------------------------------------------------------------------------
class _RentalStep extends ConsumerWidget {
  const _RentalStep({required this.state, required this.draft});

  final CheckoutState state;
  final BookingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = state is CheckoutRentalPaid ||
        state is CheckoutAwaitingDepositSheet ||
        state is CheckoutDepositCancelled ||
        state is CheckoutCompleted;

    final loading = state is CheckoutCreatingBooking ||
        state is CheckoutAwaitingRentalSheet;

    final canRetry = state is CheckoutRentalCancelled;

    final enabled = (state is CheckoutIdle || canRetry) && !loading;

    return _StepCard(
      step: 1,
      title: 'Pay rental',
      amount: draft.rentalTotal,
      description: 'Secures your booking dates',
      completed: completed,
      loading: loading,
      enabled: enabled,
      cancelledMessage:
          canRetry ? 'Payment cancelled — tap to try again.' : null,
      onPay: () =>
          ref.read(checkoutNotifierProvider.notifier).startRentalPayment(),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — Deposit payment
// ---------------------------------------------------------------------------
class _DepositStep extends ConsumerWidget {
  const _DepositStep({required this.state});

  final CheckoutState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = state is CheckoutCompleted;

    final loading = state is CheckoutAwaitingDepositSheet;

    final canRetry = state is CheckoutDepositCancelled;

    final unlocked = state is CheckoutRentalPaid ||
        state is CheckoutAwaitingDepositSheet ||
        canRetry;

    final enabled = unlocked && !loading;

    return _StepCard(
      step: 2,
      title: 'Pay security deposit',
      amount: AppConstants.depositAmountUsd,
      description: 'Fully refundable after safe return',
      completed: completed,
      loading: loading,
      enabled: enabled,
      cancelledMessage:
          canRetry ? 'Deposit not paid — tap to complete.' : null,
      onPay: () =>
          ref.read(checkoutNotifierProvider.notifier).startDepositPayment(),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable step card
// ---------------------------------------------------------------------------
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.amount,
    required this.description,
    required this.completed,
    required this.loading,
    required this.enabled,
    required this.onPay,
    this.cancelledMessage,
  });

  final int step;
  final String title;
  final double amount;
  final String description;
  final bool completed;
  final bool loading;
  final bool enabled;
  final VoidCallback onPay;
  final String? cancelledMessage;

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
                // Step indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        completed ? cs.primary : cs.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: completed
                        ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                        : Text(
                            '$step',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: enabled
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: enabled || completed
                              ? cs.onSurface
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        description,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyUtils.formatUsd(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: enabled || completed ? cs.primary : cs.outline,
                  ),
                ),
              ],
            ),

            // Cancelled hint
            if (cancelledMessage != null) ...[
              const SizedBox(height: 8),
              _CancelledHint(message: cancelledMessage!),
            ],

            // Pay button — only show when not yet completed
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
                    : Text(
                        cancelledMessage != null
                            ? 'Retry payment'
                            : 'Pay ${CurrencyUtils.formatUsd(amount)}',
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CancelledHint extends StatelessWidget {
  const _CancelledHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 15, color: cs.tertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: cs.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error banner — shown for unrecoverable errors
// ---------------------------------------------------------------------------
class _ErrorBanner extends ConsumerWidget {
  const _ErrorBanner({required this.state});

  final CheckoutState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state is! CheckoutError) return const SizedBox.shrink();

    final error = state as CheckoutError;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: cs.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error.message,
                  style: TextStyle(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () =>
                ref.read(checkoutNotifierProvider.notifier).reset(),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error),
            ),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
  }
}
