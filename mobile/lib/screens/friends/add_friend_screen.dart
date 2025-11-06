import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// フレンド追加画面
class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearched = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _hasSearched = true;
      // TODO: 実際のAPI検索を実装
      // 今はダミーで空の結果を表示
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchSection(),
            const SizedBox(height: 24),
            Expanded(
              child: _hasSearched ? _buildSearchResults() : _buildEmptyState(),
            ),
          ],
        ),
      ),
    );
  }

  /// ヘッダー部分
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
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
                  'フレンドを追加',
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
                  'IDまたは名前で検索',
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

  /// 検索セクション
  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        children: [
          // 検索入力
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.inputBorder),
              borderRadius: BorderRadius.circular(100),
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'ユーザーIDまたは名前を入力',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPlaceholder,
                  letterSpacing: -0.3125,
                ),
                prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          const SizedBox(height: 12),
          // 検索ボタン
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _performSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ).copyWith(
                elevation: MaterialStateProperty.all(0),
                shadowColor: MaterialStateProperty.all(Colors.transparent),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '検索',
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
          ),
        ],
      ),
    );
  }

  /// 検索前の空状態
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Icon(
                Icons.person_add_outlined,
                size: 24,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'フレンドを検索',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                letterSpacing: -0.3125,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'ユーザーIDまたは名前を入力して検索してください',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 検索結果表示
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_search,
                size: 48,
                color: AppColors.textSecondary.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                '検索結果が見つかりませんでした',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  letterSpacing: -0.3125,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '別のIDまたは名前で検索してください',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // TODO: 検索結果がある場合のリスト表示
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserCard(user);
      },
    );
  }

  /// ユーザーカード
  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // アバター
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(100),
            ),
            alignment: Alignment.center,
            child: Text(
              user['emoji'] ?? '👤',
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          // 名前とID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? '',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF3D3D3D),
                    height: 1.43,
                    letterSpacing: -0.1504,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${user['id']}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 追加ボタン
          ElevatedButton(
            onPressed: () {
              // TODO: フレンド追加処理
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }
}
