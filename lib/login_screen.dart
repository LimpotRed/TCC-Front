import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';
import 'auth_validation.dart';
import 'brand.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth});
  final AuthService? auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthService _auth = widget.auth ?? AuthService();
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  final _visibilityButtonFocus = FocusNode(
    skipTraversal: true,
    canRequestFocus: false,
  );
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    _visibilityButtonFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = await _auth.signIn(
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => DashboardScreen(
            auth: _auth,
            name: name,
            email: _email.text.trim().toLowerCase(),
            onLogout: (dashboardContext) {
              _auth.signOut();
              Navigator.of(dashboardContext).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => LoginScreen(auth: _auth),
                ),
                (_) => false,
              );
            },
          ),
        ),
        (_) => false,
      );
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Não foi possível acessar o servidor. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    errorMaxLines: 3,
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light(useMaterial3: true)
          .copyWith(colorScheme: ColorScheme.fromSeed(seedColor: brandColor)),
      child: Scaffold(
        backgroundColor: splashBackground,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    const GhydroLogo(),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: AutofillGroup(
                        child: Form(
                          key: _form,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: AbsorbPointer(
                            absorbing: _busy,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Bem-vindo de volta!',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: brandColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text('Entre com seu e-mail e senha.'),
                                const SizedBox(height: 24),
                                if (_error != null) ...[
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Colors.red.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                TextFormField(
                                  key: const ValueKey('email'),
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: _decoration(
                                    'E-mail',
                                    Icons.mail_outline,
                                  ),
                                  validator: validateEmail,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: const ValueKey('password'),
                                  controller: _password,
                                  focusNode: _passwordFocus,
                                  obscureText: _hidePassword,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration:
                                      _decoration(
                                        'Senha',
                                        Icons.lock_outline,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          focusNode: _visibilityButtonFocus,
                                          tooltip: _hidePassword
                                              ? 'Mostrar senha'
                                              : 'Ocultar senha',
                                          onPressed: () => setState(
                                            () =>
                                                _hidePassword = !_hidePassword,
                                          ),
                                          icon: Icon(
                                            _hidePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? 'Informe sua senha.'
                                      : null,
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: brandColor,
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  onPressed: _busy ? null : _submit,
                                  child: _busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            semanticsLabel: 'Aguarde',
                                          ),
                                        )
                                      : const Text('Entrar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
