import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// プロフィール設定画面
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController(text: '山田 太郎');
  final TextEditingController _emailController = TextEditingController(text: 'yamada@example.com');
  final TextEditingController _userIdController = TextEditingController(text: 'yamada123');

  String _selectedEmoji = '👨';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'アバターを選択',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  '👨', '👩', '👨‍💼', '👩‍💼', '👨‍🎓', '👩‍🎓', '👨‍💻', '👩‍🎨',
                  '👦', '👧', '🧑', '👴', '👵', '🧔', '👱‍♀️', '👱‍♂️',
                ].map((emoji) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedEmoji = emoji;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _selectedEmoji == emoji
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: _selectedEmoji == emoji
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _saveProfile() {
    // TODO: プロフィール保存処理を実装
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('プロフィールを保存しました'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildBody(),
            ],
          ),
        ),
      ),
    );
  }

  /// ヘッダー部分
  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Row(
        children: [
          // タイトル・サブタイトル
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'プロフィール設定',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.primary,
                    height: 1.5,
                    letterSpacing: 0.4875,
                  ),
                ),
                Text(
                  'あなたの情報を編集',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.33,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ボディ部分
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // アバター選択カード
          _buildAvatarCard(),
          const SizedBox(height: 24),
          // 名前入力カード
          _buildInputCard(
            icon: Icons.person_outline,
            label: '名前',
            controller: _nameController,
          ),
          const SizedBox(height: 24),
          // メールアドレス入力カード
          _buildInputCard(
            icon: Icons.email_outlined,
            label: 'メールアドレス',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          // ユーザーID入力カード
          _buildInputCard(
            icon: Icons.badge_outlined,
            label: 'ユーザーID',
            controller: _userIdController,
            helperText: 'フレンドがあなたを検索する際に使用されます',
          ),
          const SizedBox(height: 24),
          // 保存ボタン
          _buildSaveButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// アバター選択カード
  Widget _buildAvatarCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 1),
            blurRadius: 2,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Column(
        children: [
          // アバター
          GestureDetector(
            onTap: _showEmojiPicker,
            child: Stack(
              children: [
                // アバター本体
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: AppColors.buttonShadow,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _selectedEmoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
                // 編集ボタン
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: AppColors.buttonShadow,
                    ),
                    child: const Icon(
                      Icons.photo_camera,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 説明文
          const Text(
            'アバターをタップして変更',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.33,
            ),
          ),
        ],
      ),
    );
  }

  /// 入力フィールドカード
  Widget _buildInputCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    String? helperText,
    TextInputType? keyboardType,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 1),
            blurRadius: 2,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ラベル
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.1504,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 入力フィールド
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              border: Border.all(color: AppColors.inputBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPlaceholder,
                  letterSpacing: -0.3125,
                ),
              ),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textPlaceholder,
                letterSpacing: -0.3125,
              ),
            ),
          ),
          // ヘルプテキスト
          if (helperText != null) ...[
            const SizedBox(height: 8),
            Text(
              helperText,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.33,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 保存ボタン
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save_outlined, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text(
              '保存する',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                letterSpacing: -0.3125,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
