import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/currency_utils.dart';
import '../domain/orders_repository.dart';
import '../../../shared/models/booking.dart';

class BookingDetailsPage extends ConsumerWidget {
  const BookingDetailsPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: bookingAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(message: 'Failed to load booking'),
        data: (booking) => _BookingDetails(booking: booking),
      ),
    );
  }
}

class _BookingDetails extends StatelessWidget {
  const _BookingDetails({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status banner
          _StatusBanner(status: booking.status),
          const SizedBox(height: 20),

          // Booking ID
          _DetailCard(
            title: 'Booking Reference',
            children: [
              _DetailRow(label: 'ID', value: booking.id.substring(0, 8).toUpperCase()),
              _DetailRow(
                label: 'Created',
                value: AppDateUtils.toDisplay(booking.createdAt),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scooter & Dates
          _DetailCard(
            title: 'Rental Details',
            children: [
              if (booking.scooterName != null)
                _DetailRow(label: 'Scooter', value: booking.scooterName!),
              _DetailRow(
                label: 'Pick-up',
                value: AppDateUtils.toDisplay(booking.startDate),
              ),
              _DetailRow(
                label: 'Return',
                value: AppDateUtils.toDisplay(booking.endDate),
              ),
              _DetailRow(
                label: 'Duration',
                value: '${AppDateUtils.rentalDays(booking.startDate, booking.endDate)} days',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Payment
          _DetailCard(
            title: 'Payment',
            children: [
              _DetailRow(
                label: 'Rental total',
                value: CurrencyUtils.formatUsd(booking.totalAmount),
              ),
              _DetailRow(
                label: 'Deposit',
                value: CurrencyUtils.formatUsd(booking.depositAmount ?? 0),
                subtitle: booking.depositReturned == true
                    ? 'Returned'
                    : 'Held — released after return',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pickup point
          if (booking.pickupPointName != null) ...[
            _DetailCard(
              title: 'Pickup Point',
              children: [
                _DetailRow(
                  label: 'Location',
                  value: booking.pickupPointName!,
                ),
                if (booking.pickupPointAddress != null)
                  _DetailRow(
                    label: 'Address',
                    value: booking.pickupPointAddress!,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Actions depending on status
          if (booking.status == BookingStatus.confirmed ||
              booking.status == BookingStatus.active)
            OutlinedButton.icon(
              onPressed: () {
                // TODO: open support ticket for this booking
              },
              icon: const Icon(Icons.headset_mic_outlined),
              label: const Text('Contact Support'),
            ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (status) {
      BookingStatus.draft => ('Draft — complete payment to confirm', Icons.pending_outlined, cs.outline),
      BookingStatus.confirmed => ('Confirmed — ready for pick-up', Icons.check_circle_outline, cs.primary),
      BookingStatus.active => ('Active — enjoy your dive!', Icons.water, cs.secondary),
      BookingStatus.completed => ('Completed', Icons.done_all, cs.tertiary),
      BookingStatus.cancelled => ('Cancelled', Icons.cancel_outlined, cs.error),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.subtitle});

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        )),
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
        ],
      ),
    );
  }
}
