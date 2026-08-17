import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../data/models.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _phoneE164 = '';
  String _role = 'buyer';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppL10n.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_phoneE164.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.phoneRequired)),
      );
      return;
    }
    final ok = await ref.read(authControllerProvider.notifier).register(
          RegisterRequest(
            phone: _phoneE164,
            password: _passwordCtrl.text,
            fullName: _nameCtrl.text.trim(),
            role: _role,
            email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          ),
        );
    if (!mounted) return;
    // Router redirect handles the successful-nav path via role landing;
    // calling context.go here would cause a double-navigation flash.
    if (!ok) {
      final err = ref.read(authControllerProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.createAccount)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: t.fullName),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? t.namePleaseEnter
                      : null,
                ),
                const SizedBox(height: 16),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: IntlPhoneField(
                    decoration: InputDecoration(labelText: t.phone),
                    initialCountryCode: 'EG',
                    onChanged: (phone) => _phoneE164 = phone.completeNumber,
                    invalidNumberMessage: t.phoneInvalid,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(labelText: t.email),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(labelText: t.password),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 8)
                      ? t.passwordMin8
                      : null,
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'buyer', label: Text(t.roleBuyer)),
                    ButtonSegment(value: 'broker', label: Text(t.roleBroker)),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                if (_role == 'broker') ...[
                  const SizedBox(height: 12),
                  Text(
                    t.brokerDisclaimer,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.submitting ? null : _submit,
                  child: state.submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t.createAccount),
                ),
                const SizedBox(height: 10),
                // Passive-acceptance notice — PDPL only requires an
                // explicit checkbox for *sensitive* data (broker docs).
                // Account creation itself is fine with this treatment.
                Text(
                  t.signupTermsNotice,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: state.submitting
                      ? null
                      : () => context.go(Routes.login),
                  child: Text(t.registerPromptLogin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
