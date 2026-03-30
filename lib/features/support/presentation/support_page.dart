import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/support_service.dart';

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _category = 'general';
  bool _submitting = false;
  bool _submitted = false;

  static const _categories = [
    ('general', 'General question'),
    ('booking', 'Booking issue'),
    ('payment', 'Payment problem'),
    ('damage', 'Damage report'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      await ref.read(supportServiceProvider).createTicket(
            category: _category,
            subject: _subjectCtrl.text.trim(),
            message: _messageCtrl.text.trim(),
          );
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: _submitted ? _SuccessView() : _FormView(
        formKey: _formKey,
        categories: _categories,
        selectedCategory: _category,
        onCategoryChanged: (v) => setState(() => _category = v),
        subjectCtrl: _subjectCtrl,
        messageCtrl: _messageCtrl,
        submitting: _submitting,
        onSubmit: _submit,
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.formKey,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.subjectCtrl,
    required this.messageCtrl,
    required this.submitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final List<(String, String)> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController subjectCtrl;
  final TextEditingController messageCtrl;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // FAQ / quick links
            _FaqSection(),
            const SizedBox(height: 24),

            Text(
              'Contact Us',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: categories
                  .map((c) => DropdownMenuItem(
                        value: c.$1,
                        child: Text(c.$2),
                      ))
                  .toList(),
              onChanged: (v) => onCategoryChanged(v!),
            ),
            const SizedBox(height: 12),

            // Subject
            TextFormField(
              controller: subjectCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Subject'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Message
            TextFormField(
              controller: messageCtrl,
              maxLines: 5,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 10) ? 'Min 10 characters' : null,
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: submitting ? null : onSubmit,
              child: submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send message'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const faqs = [
      ('How do I cancel a booking?', 'You can cancel in My Bookings up to 48h before pick-up.'),
      ('When is the deposit returned?', 'Within 3-5 business days after confirmed return.'),
      ('What documents do I need?', 'Diving certification and valid government ID.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequently Asked Questions',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...faqs.map(
          (faq) => ExpansionTile(
            title: Text(faq.$1,
                style: Theme.of(context).textTheme.bodyMedium),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  faq.$2,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Message sent!',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "We'll get back to you within 24 hours.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
