import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';

/// プロフィール設定画面
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedEmoji = '👨';
  String? _profileImageUrl;
  File? _selectedImage;
  bool _isLoading = true;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  /// ユーザーデータを読み込む
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await _authService.getCurrentUser();

      if (userData != null && mounted) {
        setState(() {
          _nameController.text = userData['display_name'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _userIdController.text = userData['username'] ?? '';
          _profileImageUrl = userData['profile_image_url'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[ProfileScreen] Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 画像選択のオプションを表示
  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'プロフィール画像を選択',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              // カメラで撮影
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text(
                  'カメラで撮影',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    letterSpacing: -0.3125,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              // ギャラリーから選択
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text(
                  'ギャラリーから選択',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    letterSpacing: -0.3125,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
              // キャンセル
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.inputBackground,
                      foregroundColor: AppColors.textSecondary,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: const Text(
                      'キャンセル',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.3125,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 画像を選択
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });

        // 画像をアップロード
        await _uploadProfileImage();
      }
    } catch (e) {
      print('[ProfileScreen] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('画像の選択に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// プロフィール画像をアップロード
  Future<void> _uploadProfileImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // マルチパートリクエストを作成
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8000/api/v1/users/me/profile-image'),
      );

      // 認証トークンを追加
      final token = _authService.apiService._accessToken;
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // 画像ファイルを追加
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _selectedImage!.path,
        ),
      );

      // リクエストを送信
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _profileImageUrl = responseData['profile_image_url'];
          _selectedImage = null;
          _isUploadingImage = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('プロフィール画像を更新しました'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      print('[ProfileScreen] Error uploading image: $e');
      setState(() {
        _isUploadingImage = false;
        _selectedImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('画像のアップロードに失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    // 入力値のバリデーション
    if (_nameController.text.trim().isEmpty) {
      return;
    }
    if (_userIdController.text.trim().isEmpty) {
      return;
    }

    try {
      // プロフィールを更新
      await _authService.apiService.patch(
        '/users/me',
        body: {
          'display_name': _nameController.text.trim(),
          'username': _userIdController.text.trim(),
        },
        requiresAuth: true,
      );

      // 更新成功後、ユーザーデータを再読み込み
      await _loadUserData();
    } catch (e) {
      print('[ProfileScreen] Error saving profile: $e');
      // エラーは静かに処理（ユーザーは再試行可能）
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : SingleChildScrollView(
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Row(
        children: [
          // 戻るボタン
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0, 1),
                  blurRadius: 3,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              color: AppColors.textSecondary,
            ),
          ),
          // タイトル・サブタイトル
          const Expanded(
            child: Column(
              children: [
                Text(
                  'プロフィール設定',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 30,
                    fontWeight: FontWeight.w400,
                    color: AppColors.primary,
                    height: 1.2,
                    letterSpacing: 0.3955,
                  ),
                ),
                SizedBox(height: 4),
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
          // 右側スペーサー（左右対称）
          const SizedBox(width: 40, height: 40),
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
          // ユーザID入力カード
          _buildInputCard(
            icon: Icons.badge_outlined,
            label: 'ユーザID',
            controller: _userIdController,
            helperText: 'フレンドがあなたを検索する際に使用されます',
          ),
          const SizedBox(height: 24),
          // メールアドレス入力カード（読み取り専用）
          _buildInputCard(
            icon: Icons.email_outlined,
            label: 'メールアドレス',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            readOnly: true,
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
            onTap: _showImageSourceOptions,
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
                  child: _isUploadingImage
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        )
                      : _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: Image.file(
                                _selectedImage!,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                            )
                          : _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: Image.network(
                                    _profileImageUrl!,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        alignment: Alignment.center,
                                        child: Text(
                                          _selectedEmoji,
                                          style: const TextStyle(fontSize: 48),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  alignment: Alignment.center,
                                  child: Text(
                                    _selectedEmoji,
                                    style: const TextStyle(fontSize: 48),
                                  ),
                                ),
                ),
                // 編集ボタン
                if (!_isUploadingImage)
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
          Text(
            _isUploadingImage ? 'アップロード中...' : 'アバターをタップして変更',
            style: const TextStyle(
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
    bool readOnly = false,
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
              readOnly: readOnly,
              enableInteractiveSelection: !readOnly,
              contextMenuBuilder: readOnly
                  ? (context, editableTextState) => const SizedBox.shrink()
                  : null,
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
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: readOnly ? AppColors.textSecondary : AppColors.textPlaceholder,
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
