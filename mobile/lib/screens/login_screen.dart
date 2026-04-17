import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

/// 与设计稿一致的品牌色（主蓝）
const _kBrandBlue = Color(0xFF1976D2);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isLogin = true;
  String? _error;
  bool _loading = false;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;

  static final _passwordPattern = RegExp(r'^[a-zA-Z0-9]{6,16}$');

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _switchMode(bool login) {
    setState(() {
      _isLogin = login;
      _error = null;
      _confirmPasswordCtrl.clear();
      _agreedToTerms = false;
    });
  }

  bool _validatePhone() {
    final p = _phoneCtrl.text.trim();
    if (p.length != 11 || !RegExp(r'^\d{11}$').hasMatch(p)) {
      setState(() => _error = '请输入11位手机号码');
      return false;
    }
    return true;
  }

  bool _validateLoginPassword() {
    if (_passwordCtrl.text.isEmpty) {
      setState(() => _error = '请输入登录密码');
      return false;
    }
    return true;
  }

  bool _validateRegisterPasswords() {
    final pwd = _passwordCtrl.text;
    if (!_passwordPattern.hasMatch(pwd)) {
      setState(() => _error = '密码需为6-16位字母与数字组合');
      return false;
    }
    if (pwd != _confirmPasswordCtrl.text) {
      setState(() => _error = '两次输入的密码不一致');
      return false;
    }
    if (!_agreedToTerms) {
      setState(() => _error = '请阅读并同意服务条款与隐私政策');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validatePhone()) return;
    if (_isLogin) {
      if (!_validateLoginPassword()) return;
    } else {
      if (!_validateRegisterPasswords()) return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final err = _isLogin
        ? await ref
            .read(authProvider.notifier)
            .login(_phoneCtrl.text.trim(), _passwordCtrl.text)
        : await ref
            .read(authProvider.notifier)
            .register(_phoneCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      context.go('/');
    } else {
      setState(() => _error = err);
    }
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _isLogin ? _buildLogin(context) : _buildRegister(context),
        ),
      ),
    );
  }

  Widget _buildLogin(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _buildLoginHeader(),
        const SizedBox(height: 28),
        Material(
          elevation: 3,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '欢迎回来',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827)),
                ),
                const SizedBox(height: 24),
                const Text('手机号',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDecoration(
                    hint: '输入您的手机号码',
                    prefixIcon: Icon(Icons.smartphone_outlined,
                        color: Colors.grey.shade600, size: 22),
                  ).copyWith(counterText: ''),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('密码',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: _fieldDecoration(
                    hint: '输入您的登录密码',
                    prefixIcon: Icon(Icons.lock_outline,
                        color: Colors.grey.shade600, size: 22),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kBrandBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('登录',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => _switchMode(false),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                children: const [
                  TextSpan(text: '还没有账号？'),
                  TextSpan(
                    text: '去注册',
                    style: TextStyle(
                        color: _kBrandBlue, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLoginHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kBrandBlue.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.verified_user, size: 48, color: _kBrandBlue),
        ),
        const SizedBox(height: 16),
        const Text(
          '定位共享',
          style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827)),
        ),
      ],
    );
  }

  Widget _buildRegister(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 28, color: _kBrandBlue),
            const SizedBox(width: 8),
            const Text(
              '定位共享',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kBrandBlue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_add_alt_1, size: 40, color: _kBrandBlue),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '注册新账号',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827)),
        ),
        const SizedBox(height: 8),
        Text(
          '开启您的守护之旅，共享安心每一刻',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 14, height: 1.4, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 28),
        const Text('手机号',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _fieldDecoration(
            hint: '请输入11位手机号码',
            prefixIcon: Icon(Icons.smartphone_outlined,
                color: Colors.grey.shade600, size: 22),
          ).copyWith(counterText: ''),
        ),
        const SizedBox(height: 16),
        const Text('设置密码',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          decoration: _fieldDecoration(
            hint: '6-16位字母与数字组合',
            prefixIcon:
                Icon(Icons.lock_outline, color: Colors.grey.shade600, size: 22),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('确认密码',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmPasswordCtrl,
          obscureText: _obscureConfirm,
          decoration: _fieldDecoration(
            hint: '请再次输入密码',
            prefixIcon: Icon(Icons.verified_user_outlined,
                color: Colors.grey.shade600, size: 22),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _agreedToTerms,
                activeColor: _kBrandBlue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => setState(() {
                  _agreedToTerms = v ?? false;
                  _error = null;
                }),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _agreedToTerms = !_agreedToTerms;
                  _error = null;
                }),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Colors.grey.shade800),
                    children: const [
                      TextSpan(text: '我已阅读并同意 '),
                      TextSpan(
                          text: '服务条款',
                          style: TextStyle(
                              color: _kBrandBlue, fontWeight: FontWeight.w600)),
                      TextSpan(text: ' 与 '),
                      TextSpan(
                          text: '隐私政策',
                          style: TextStyle(
                              color: _kBrandBlue, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _kBrandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('注册',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => _switchMode(true),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                children: const [
                  TextSpan(text: '已有账号？'),
                  TextSpan(
                    text: '去登录',
                    style: TextStyle(
                        color: _kBrandBlue, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Center(
        //   child: TextButton.icon(
        //     onPressed: () {
        //       ScaffoldMessenger.of(context).showSnackBar(
        //         const SnackBar(content: Text('如遇问题请联系客服或稍后再试')),
        //       );
        //     },
        //     icon:
        //         Icon(Icons.help_outline, size: 18, color: Colors.grey.shade600),
        //     label: Text('注册遇到问题',
        //         style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        //     style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
        //   ),
        // ),
        const SizedBox(height: 24),
      ],
    );
  }
}
