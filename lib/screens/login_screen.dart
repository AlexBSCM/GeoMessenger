import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _loginController = TextEditingController();
  final _passController = TextEditingController(text: '123456');
  bool _loading = false;
  bool _obscurePass = true;

  String _errorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Неверный пароль';
      case 'user-not-found':
      case 'invalid-email':
        return 'Неверный логин';
      case 'account-not-allowed':
        return 'Этот логин пока не разрешён';
      case 'weak-password':
        return 'Пароль должен быть не короче 6 символов';
      case 'network-request-failed':
        return 'Ошибка сети. Проверьте подключение';
      default:
        return 'Ошибка входа (${e.code})';
    }
  }

  Future<void> _login() async {
    final login = _loginController.text.trim();
    final password = _passController.text;
    if (login.isEmpty || password.isEmpty) return;

    setState(() => _loading = true);
    try {
      await _auth.signInWithLogin(login, password);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось войти')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Гео Мессенджер')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Добро пожаловать!', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            TextField(
              controller: _loginController,
              decoration: const InputDecoration(
                labelText: 'Логин',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passController,
              decoration: InputDecoration(
                labelText: 'Пароль',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                  tooltip: _obscurePass ? 'Показать пароль' : 'Скрыть пароль',
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              obscureText: _obscurePass,
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Войти'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Впервые? Введите логин и пароль — аккаунт будет создан автоматически.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
