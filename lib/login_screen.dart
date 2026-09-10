import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';
import 'auth_validation.dart';
import 'brand.dart';
import 'dashboard_screen.dart';

// Escolhe quais campos aparecem: login ou cadastro.
enum _AuthMode { login, register }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth});
  final AuthService? auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthService _auth = widget.auth ?? AuthService();
  // A chave valida o formulário; os controllers guardam o texto dos campos.
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  bool get _isLogin => _mode == _AuthMode.login;
  bool get _isRegister => _mode == _AuthMode.register;

  @override
  void dispose() {
    // Libera os campos da memória ao fechar a tela.
    for (final controller in [_name, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  // Troca a tela, mantendo o e-mail e limpando as senhas.
  void _changeMode(_AuthMode mode) {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final email = _email.text;
    _form.currentState?.reset();
    setState(() {
      _email.text = email;
      _mode = mode;
      _error = null;
      _notice = null;
      _password.clear();
      _confirm.clear();

      _hidePassword = true;
      _hideConfirmation = true;
    });
  }

  // Valida os campos e bloqueia cliques repetidos enquanto aguarda a resposta.
  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_isLogin) {
        final name = await _auth.signIn(
          email: _email.text,
          password: _password.text,
        );
        if (!mounted) return;
        TextInput.finishAutofillContext();
        // Abre o painel e remove o login do caminho de volta.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => DashboardScreen(
              name: name,
              email: _email.text.trim().toLowerCase(),
              onLogout: (dashboardContext) => Navigator.of(dashboardContext)
                  .pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => LoginScreen(auth: _auth),
                    ),
                    (_) => false,
                  ),
            ),
          ),
          (_) => false,
        );
      } else {
        await _auth.register(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
        if (!mounted) return;
        setState(() => _busy = false);
        _changeMode(_AuthMode.login);
        setState(() => _notice = 'Conta criada! Entre com seu e-mail e senha.');
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Não foi possível acessar as contas salvas. Verifique se o navegador permite armazenar dados e tente novamente.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Mantém a mesma aparência em todos os campos.
  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    errorMaxLines: 3,
  );

  // Reaproveita o campo de senha para a confirmação do cadastro.
  Widget _passwordField({bool confirmation = false}) {
    final hidden = confirmation ? _hideConfirmation : _hidePassword;
    return TextFormField(
      key: ValueKey(confirmation ? 'confirm' : 'password'),
      controller: confirmation ? _confirm : _password,
      obscureText: hidden,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: confirmation
          ? null
          : [_isLogin ? AutofillHints.password : AutofillHints.newPassword],
      textInputAction: !_isLogin && !confirmation
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: (_) {
        if (_isLogin || confirmation) _submit();
      },
      decoration:
          _decoration(
            confirmation ? 'Confirmar senha' : 'Senha',
            Icons.lock_outline,
          ).copyWith(
            helperText: !_isLogin && !confirmation
                ? 'Use pelo menos 8 caracteres.'
                : null,
            suffixIcon: IconButton(
              tooltip: hidden ? 'Mostrar senha' : 'Ocultar senha',
              onPressed: () => setState(() {
                if (confirmation) {
                  _hideConfirmation = !hidden;
                } else {
                  _hidePassword = !hidden;
                }
              }),
              icon: Icon(
                hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
      validator: (value) {
        if (confirmation)
          return value == _password.text ? null : 'As senhas não coincidem.';
        return _isLogin
            ? (value == null || value.isEmpty ? 'Informe sua senha.' : null)
            : validateNewPassword(value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? 'Bem-vindo de volta!' : 'Crie sua conta';
    final action = _isLogin ? 'Entrar' : 'Criar conta';
    return Scaffold(
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
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: brandColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isLogin
                                    ? 'Entre com seu e-mail e senha.'
                                    : 'Preencha seus dados para começar.',
                              ),
                              const SizedBox(height: 24),
                              if (_error != null || _notice != null) ...[
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _error ?? _notice!,
                                    style: TextStyle(
                                      color: _error != null
                                          ? Colors.red.shade800
                                          : Colors.green.shade800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (_isRegister) ...[
                                TextFormField(
                                  key: const ValueKey('name'),
                                  controller: _name,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  decoration: _decoration(
                                    'Nome',
                                    Icons.person_outline,
                                  ),
                                  validator: validateName,
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
                              _passwordField(),
                              if (!_isLogin) ...[
                                const SizedBox(height: 16),
                                _passwordField(confirmation: true),
                              ],
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
                                    : Text(action),
                              ),
                              if (_isLogin) ...[
                                const SizedBox(height: 16),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text('Não possui conta?'),
                                    TextButton(
                                      onPressed: () =>
                                          _changeMode(_AuthMode.register),
                                      style: TextButton.styleFrom(
                                        foregroundColor: brandColor,
                                      ),
                                      child: const Text('Crie agora'),
                                    ),
                                  ],
                                ),
                              ],
                              if (!_isLogin)
                                TextButton(
                                  onPressed: () => _changeMode(_AuthMode.login),
                                  child: const Text('Voltar para o login'),
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
    );
  }
}
