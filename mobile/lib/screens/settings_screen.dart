import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../api/client.dart';
import '../api/user_api.dart';
import '../providers/auth_provider.dart';

const _accentBlue = Color(0xFF1877F2);

/// 设计：顶栏「位置共享」+ 通知；标题「设置与个人中心」；头像/昵称/手机；退出登录；版本与条款
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final UserApi _api = UserApi();
  final _nicknameCtrl = TextEditingController();
  final _nicknameFocus = FocusNode();

  String? _phone;
  String? _avatarUrl;

  /// 与 pubspec.yaml version 对齐（展示用）
  static const _kDisplayVersion = '0.1.0';

  @override
  void initState() {
    super.initState();
    _phone = ref.read(authProvider).phone;
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _api.getProfile();
      if (!mounted) return;
      setState(() {
        _nicknameCtrl.text = p['nickname']?.toString() ?? '';
        _avatarUrl = ApiClient().resolveMediaUrl(p['avatar_url']?.toString());
        _phone = p['phone']?.toString() ?? _phone;
      });
    } catch (_) {}
  }

  String _maskPhoneDisplay(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final t = raw.replaceAll(RegExp(r'\s'), '');
    if (t.length == 11 && RegExp(r'^\d{11}$').hasMatch(t)) {
      return '+86 ${t.substring(0, 3)} **** ${t.substring(7)}';
    }
    if (t.length >= 8) {
      return '${t.substring(0, 3)} **** ${t.substring(t.length - 4)}';
    }
    return raw;
  }

  Future<void> _saveNickname() async {
    try {
      await _api.updateProfile(nickname: _nicknameCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败')));
    }
  }

  Future<void> _onAvatarTap() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (x == null || !mounted) return;
    try {
      final data = await _api.uploadAvatar(x.path);
      if (!mounted) return;
      setState(() {
        _avatarUrl = ApiClient().resolveMediaUrl(data['avatar_url']?.toString());
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像已更新')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('上传失败')));
    }
  }

  void _onLegalTap(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title（内容即将接入）')),
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final letter = (auth.phone ?? auth.userId ?? '?').toString();
    final initial = letter.isNotEmpty ? letter[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      initial,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '位置共享',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Color(0xFF111827)),
                    tooltip: '通知',
                    onPressed: () => context.go('/notifications'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                '设置与个人中心',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.black12,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _onAvatarTap,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                        ? Image.network(
                                            _avatarUrl!,
                                            width: 112,
                                            height: 112,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _avatarPlaceholder(initial),
                                          )
                                        : _avatarPlaceholder(initial),
                                  ),
                                  Positioned(
                                    right: -4,
                                    bottom: -4,
                                    child: Material(
                                      color: _accentBlue,
                                      shape: const CircleBorder(),
                                      elevation: 2,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: _onAvatarTap,
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(Icons.edit, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '点击更换头像',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 28),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '用户昵称',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nicknameCtrl,
                              focusNode: _nicknameFocus,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _saveNickname(),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF3F4F6),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.edit_outlined, color: Colors.grey.shade700, size: 20),
                                  tooltip: '编辑昵称',
                                  onPressed: () => _nicknameFocus.requestFocus(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '手机号码',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _maskPhoneDisplay(_phone),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Color(0xFFE53935)),
                      label: const Text('退出登录', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE53935), width: 1.2),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 0,
                        children: [
                          Text(
                            '版本 $_kDisplayVersion • ',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          GestureDetector(
                            onTap: () => _onLegalTap('隐私政策'),
                            child: Text(
                              '隐私政策',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                            ),
                          ),
                          Text(' 与 ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          GestureDetector(
                            onTap: () => _onLegalTap('服务条款'),
                            child: Text(
                              '服务条款',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(String initial) {
    return Container(
      width: 112,
      height: 112,
      color: const Color(0xFF37474F),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}
