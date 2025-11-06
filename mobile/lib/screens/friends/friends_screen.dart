import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// フレンド一覧画面
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();

  // ダミーデータ（後でAPIから取得）
  final List<Map<String, dynamic>> _friends = [
    {'id': '1', 'name': '田中 太郎', 'emoji': '👨'},
    {'id': '2', 'name': '佐藤 花子', 'emoji': '👩'},
    {'id': '3', 'name': '鈴木 次郎', 'emoji': '👨‍💼'},
    {'id': '4', 'name': '高橋 美咲', 'emoji': '👩‍💼'},
    {'id': '5', 'name': '渡辺 健太', 'emoji': '👨‍🎓'},
    {'id': '6', 'name': '伊藤 あゆみ', 'emoji': '👩‍🎓'},
    {'id': '7', 'name': '山田 一郎', 'emoji': '👨‍💻'},
    {'id': '8', 'name': '中村 舞', 'emoji': '👩‍🎨'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const SizedBox(height: 24),
            Expanded(child: _buildFriendsList()),
          ],
        ),
      ),
    );
  }

  /// ヘッダー部分（戻るボタン・タイトル・通知・追加ボタン）
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
              borderRadius: BorderRadius.circular(100),
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
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 16),
          // タイトル・サブタイトル
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'フレンド管理',
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
                  '${_friends.length}人のフレンド',
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
          ),
          // 通知アイコン（ベルマーク・バッジ付き）
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
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
                  child: IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 20),
                    onPressed: () {
                      Navigator.of(context).pushNamed('/friends/requests');
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
                // バッジ（通知数）
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '3',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        height: 1.33,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 追加ボタン
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(100),
              boxShadow: AppColors.buttonShadow,
            ),
            child: IconButton(
              icon: const Icon(Icons.person_add, size: 20, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pushNamed('/friends/add');
              },
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  /// 検索バー
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.inputBorder),
          borderRadius: BorderRadius.circular(100),
        ),
        child: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '名前・ID・メールで検索',
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
          onChanged: (value) {
            // TODO: 検索処理を実装
            setState(() {});
          },
        ),
      ),
    );
  }

  /// フレンド一覧
  Widget _buildFriendsList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _friends.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return _buildFriendCard(friend);
      },
    );
  }

  /// フレンドカード
  Widget _buildFriendCard(Map<String, dynamic> friend) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
              friend['emoji'],
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
                  friend['name'],
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF3D3D3D),
                    height: 1.43,
                    letterSpacing: -0.1504,
                  ),
                ),
                const SizedBox(height: 7.5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'ID: ${friend['id']}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.33,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
