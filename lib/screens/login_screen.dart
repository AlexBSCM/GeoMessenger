import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _emailController = TextEditingController(text: 'test@test.com');
  final _passController = TextEditingController(text: '123456');
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _usePhone = false;
  bool _codeSent = false;
  bool _loading = false;

  Future<void> _loginWithEmail() async {
    setState(() => _loading = true);
    await _auth.signInWithEmail(
      _emailController.text.trim(),
      _passController.text.trim(),
    );
    setState(() => _loading = false);
  }

  Future<void> _sendCode() async {
    setState(() => _loading = true);
    await _auth.sendPhoneCode(_phoneController.text.trim());
    setState(() {
      _codeSent = true;
      _loading = false;
    });
  }

  Future<void> _verifyCode() async {
    setState(() => _loading = true);
    await _auth.verifyPhoneCode(_codeController.text.trim());
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geo Messenger')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome!', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            if (!_usePhone) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _loginWithEmail,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Login / Register'),
                ),
              ),
            ] else ...[
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '+11111111111',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              if (_codeSent) ...[
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'SMS Code',
                    hintText: '123456',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyCode,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Verify Code'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendCode,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Send Code'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => setState(() {
                _usePhone = !_usePhone;
                _codeSent = false;
              }),
              child: Text(_usePhone ? 'Use Email instead' : 'Use Phone instead'),
            ),
          ],
        ),
      ),
    );
  }
}
