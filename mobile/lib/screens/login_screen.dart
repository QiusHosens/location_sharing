import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late TabController _tab;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phoneCtrl.text.length < 11) { setState(() => _error = '请输入正确的手机号'); return; }
    if (_passwordCtrl.text.isEmpty) { setState(() => _error = '请输入密码'); return; }
    setState(() { _loading = true; _error = null; });
    var ok = false;
    try {
      ok = _tab.index == 0
          ? await ref.read(authProvider.notifier).login(_phoneCtrl.text, _passwordCtrl.text)
          : await ref.read(authProvider.notifier).register(_phoneCtrl.text, _passwordCtrl.text);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;
    if (ok) {
      context.go('/');
    } else {
      setState(() => _error = _tab.index == 0 ? '登录失败（请检查网络与接口地址）' : '注册失败（请检查网络与接口地址）');
    }
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
              const SizedBox(height: 24),
              TabBar(controller: _tab, onTap: (_) => setState(() => _error = null), tabs: const [Tab(text: '登录'), Tab(text: '注册')]),
              const SizedBox(height: 16),
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red))),
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone, maxLength: 15),
              const SizedBox(height: 16),
              TextField(controller: _passwordCtrl, decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder()),
                obscureText: true),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity,
                child: FilledButton(onPressed: _loading ? null : _submit, child: Text(_loading ? '提交中...' : '提交'))),
            ]),
          ),
        ),
      ),
    );
  }
}
