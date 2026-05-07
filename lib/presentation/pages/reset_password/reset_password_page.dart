import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/data/repositories/auth_repository.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? initialToken;
  const ResetPasswordPage({super.key, this.initialToken});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) {
      _tokenController.text = widget.initialToken!;
    } else {
      // Try to read token from URL (web) if present
      try {
        final params = Uri.base.queryParameters;
        if (params.containsKey('token')) {
          _tokenController.text = params['token']!;
        } else {
          // Also check fragment (hash) for token when using Flutter web hash routing
          final frag = Uri.base.fragment; // e.g. '/reset-password?token=...'
          if (frag.isNotEmpty) {
            try {
              final fragUri = Uri.parse(frag.startsWith('/') ? frag : '/$frag');
              final t = fragUri.queryParameters['token'];
              if (t != null) _tokenController.text = t;
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.4;
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                child: TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(labelText: 'Token'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: width,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: width,
                child: TextField(
                  controller: _passwordConfirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: width,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          final token = _tokenController.text.trim();
                          final pw = _passwordController.text;
                          final pwc = _passwordConfirmController.text;
                          if (token.isEmpty || pw.isEmpty || pwc.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Completa todos los campos'),
                              ),
                            );
                            return;
                          }
                          if (pw != pwc) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Las contraseñas no coinciden'),
                              ),
                            );
                            return;
                          }
                          setState(() => _loading = true);
                          try {
                            final repo = context.read<AuthRepository>();
                            final res = await repo.confirmPasswordReset(
                              token: token,
                              password: pw,
                              passwordConfirmation: pwc,
                            );
                            final ok =
                                res['ok'] == true || res['success'] == true;
                            final message =
                                res['message'] as String? ??
                                (ok
                                    ? 'Contraseña restablecida correctamente'
                                    : 'Error al restablecer contraseña');
                            if (!context.mounted) return;
                            showDialog(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: Text(ok ? 'Éxito' : 'Error'),
                                content: Text(message),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                      if (ok) {
                                        Navigator.of(
                                          context,
                                        ).popUntil((route) => route.isFirst);
                                      }
                                    },
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          } catch (e) {
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Error'),
                                  content: Text(e.toString()),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
