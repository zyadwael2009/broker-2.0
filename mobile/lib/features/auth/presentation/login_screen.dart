import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../data/models.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  String _phoneE164 = '';

  @override
  void dispose() {
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
    final ok = await ref.read(authControllerProvider.notifier).login(
          LoginRequest(phone: _phoneE164, password: _passwordCtrl.text),
        );
    if (!mounted) return;
    // Successful login mutates auth state → router redirect handles
    // the navigation to `landingFor(role)`. Calling `context.go` here
    // would cause a double-navigation flash for non-buyers.
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
      appBar: AppBar(title: Text(t.signIn)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Phone numbers read left-to-right even in RTL contexts.
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
                  controller: _passwordCtrl,
                  decoration: InputDecoration(labelText: t.password),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.length < 8) ? t.passwordMin8 : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.submitting ? null : _submit,
                  child: state.submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t.signIn),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: state.submitting
                      ? null
                      : () => context.push(Routes.forgotPassword),
                  child: Text(t.forgotPassword),
                ),
                TextButton(
                  onPressed: state.submitting
                      ? null
                      : () => context.go(Routes.register),
                  child: Text(t.loginPromptRegister),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
