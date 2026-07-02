import 'package:flutter/material.dart';

import 'auth.dart';
import 'theme.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await AuthService.signInWithGoogle();
      // The AuthGate stream will swap to HomePage automatically on success.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.actionBlue,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.hearing, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 28),
              Text('Listen My Phone',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(
                'Sign in with Google on both phones with the same account, '
                'so one phone can show the other phone’s notifications.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 40),
              if (_busy)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
