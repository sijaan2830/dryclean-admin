import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/firebase_auth_provider.dart';
import '../theme/admin_ui.dart';

/// Admin console sign-in: brand panel on the left, form on the right.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return Consumer<FirebaseAuthProvider>(
      builder: (context, auth, _) {
        final form = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (!wide) ...[
                  Row(children: [
                    _Mark(size: 44),
                    const SizedBox(width: 12),
                    Text('DryClean Plus', style: AC.h(18)),
                  ]),
                  const SizedBox(height: 32),
                ],
                Text('Sign in to the console', style: AC.h(26)),
                const SizedBox(height: 6),
                Text('Use your administrator email and password.', style: AC.t(14.5, c: AC.mut)),
                const SizedBox(height: 28),
                Text('Email', style: AC.t(13, w: FontWeight.w700)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'you@company.com', prefixIcon: Icon(Icons.mail_outline_rounded, size: 20)),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Text('Password', style: AC.t(13, w: FontWeight.w700))),
                  TextButton(onPressed: _handleForgotPassword, style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: EdgeInsets.zero), child: const Text('Forgot password?')),
                ]),
                const SizedBox(height: 2),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => auth.isLoading ? null : _handleLogin(),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AC.dangerBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.error_outline_rounded, color: AC.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(auth.errorMessage!, style: AC.t(13.5, c: const Color(0xFF991B1B), w: FontWeight.w600))),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: auth.isLoading ? null : _handleLogin,
                    child: auth.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Sign in'), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 19)]),
                  ),
                ),
                const SizedBox(height: 22),
                Row(children: [
                  const Icon(Icons.verified_user_outlined, size: 16, color: AC.faint),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Restricted area. Access is limited to DryClean Plus administrators.', style: AC.t(12.5, c: AC.faint))),
                ]),
              ]),
            ),
          ),
        );

        return Scaffold(
          backgroundColor: AC.surface,
          body: Row(children: [
            if (wide) const Expanded(flex: 11, child: _BrandPanel()),
            Expanded(
              flex: 10,
              child: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: form))),
            ),
          ]),
        );
      },
    );
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<FirebaseAuthProvider>(context, listen: false);
    await auth.signIn(_emailController.text.trim(), _passwordController.text);
    // AuthWrapper switches to the console as soon as the user is signed in.
  }

  void _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      adminToast(context, 'Enter your email address first.');
      return;
    }
    await Provider.of<FirebaseAuthProvider>(context, listen: false).resetPassword(email);
    if (mounted) adminToast(context, 'If that account exists, a reset link is on its way.');
  }
}

class _Mark extends StatelessWidget {
  final double size;
  const _Mark({this.size = 52});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: AC.gold, borderRadius: BorderRadius.circular(size * .3)),
        alignment: Alignment.center,
        child: Text('DC+', style: AC.h(size * .33, c: AC.forest)),
      );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();
  @override
  Widget build(BuildContext context) {
    Widget feature(IconData i, String t, String d) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: .12))), child: Icon(i, color: AC.gold, size: 20)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: AC.t(15, c: Colors.white, w: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(d, style: AC.t(13.5, c: Colors.white.withValues(alpha: .65), height: 1.45)),
              ]),
            ),
          ]),
        );
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AC.forest2, AC.forest, AC.deep])),
      child: Stack(children: [
        Positioned(right: -120, top: -120, child: Container(width: 380, height: 380, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .04)))),
        Positioned(left: -80, bottom: -140, child: Container(width: 340, height: 340, decoration: BoxDecoration(shape: BoxShape.circle, color: AC.gold.withValues(alpha: .06)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 48, 56, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const _Mark(),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('DryClean Plus', style: AC.h(19, c: Colors.white)),
                Text('Admin console', style: AC.t(13, c: AC.mint2.withValues(alpha: .7), w: FontWeight.w600)),
              ]),
            ]),
            const Spacer(),
            Text('Run the whole business\nfrom one place.', style: AC.h(38, c: Colors.white).copyWith(height: 1.15, letterSpacing: -1)),
            const SizedBox(height: 14),
            Text('Orders, drivers, the facility and your website — live, in one console.', style: AC.t(16, c: Colors.white.withValues(alpha: .7), height: 1.5)),
            const SizedBox(height: 36),
            feature(Icons.bolt_rounded, 'Real-time operations', 'Every order, driver and bag updates the moment it moves.'),
            feature(Icons.local_shipping_outlined, 'Dispatch & live fleet', 'Assign pickups and deliveries, follow every van on the map.'),
            feature(Icons.language_rounded, 'Website control', 'Notices, delivery fees, home-page text and contact details — no developer needed.'),
            const Spacer(),
            Text('© ${DateTime.now().year} DryClean Plus · London', style: AC.t(12.5, c: Colors.white.withValues(alpha: .45))),
          ]),
        ),
      ]),
    );
  }
}
