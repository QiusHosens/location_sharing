import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  int _step = 0;
  String? _error;
  bool _loading = false;

  Future<void> _sendCode() async {
    if (_phoneCtrl.text.length < 11) { setState(() => _error = '请输入正确的手机号'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).sendCode(_phoneCtrl.text);
      setState(() => _step = 1);
    } catch (e) {
      setState(() => _error = '发送验证码失败');
    } finally { setState(() => _loading = false); }
  }

  Future<void> _verify() async {
    if (_codeCtrl.text.length != 6) { setState(() => _error = '请输入6位验证码'); return; }
    setState(() { _loading = true; _error = null; });
    final ok = await ref.read(authProvider.notifier).verifyCode(_phoneCtrl.text, _codeCtrl.text);
    if (ok) { context.go('/'); } else { setState(() { _error = '验证码错误'; _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_on, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text('定位共享', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('家人位置，安心守护', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              const SizedBox(height: 32),
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red))),
              if (_step == 0) ...[
                TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone, maxLength: 15),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: FilledButton(onPressed: _loading ? null : _sendCode, child: Text(_loading ? '发送中...' : '获取验证码'))),
              ] else ...[
                Text('验证码已发送至 \', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: '验证码', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number, maxLength: 6),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: FilledButton(onPressed: _loading ? null : _verify, child: Text(_loading ? '登录中...' : '登录'))),
                TextButton(onPressed: _sendCode, child: const Text('重新发送')),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
