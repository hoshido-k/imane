import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/friend_service.dart';

/// フレンド一覧画面
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FriendService _friendService = FriendService();

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _filteredFriends = [];
  int _requestCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // フレンド一覧と受信リクエスト数を取得
      final friendsData = await _friendService.getFriends();
      final requests = await _friendService.getReceivedRequests();

      setState(() {
        _friends = friendsData;
        _filteredFriends = friendsData;
        _requestCount = requests.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterFriends(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredFriends = _friends;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredFriends = _friends.where((friend) {
        final name = (friend['friend_display_name'] ?? '').toLowerCase();
        final email = (friend['friend_email'] ?? '').toLowerCase();
        return name.contains(lowercaseQuery) || email.contains(lowercaseQuery);
      }).toList();
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
            _buildSearchBar(),
            const SizedBox(height: 24),
            Expanded(child: _buildFriendsList()),
          ],
        ),
      ),
    );
  }

  /// ヘッダー部分（通知・タイトル・追加ボタン）
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          // 通知アイコン（ベルマーク・バッジ付き）
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              children: [
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
                    icon: const Icon(Icons.notifications_outlined, size: 20),
                    onPressed: () async {
                      await Navigator.of(context).pushNamed('/friends/requests');
                      // 戻ってきたら再読み込み
                      _loadData();
                    },
                    padding: EdgeInsets.zero,
                    color: AppColors.textSecondary,
                  ),
                ),
                // バッジ（通知数）
                if (_requestCount > 0)
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
                      child: Text(
                        _requestCount > 9 ? '9+' : '$_requestCount',
                        style: const TextStyle(
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
          // タイトル・サブタイトル
          Expanded(
            child: Column(
              children: [
                const Text(
                  'フレンド',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 30,
                    fontWeight: FontWeight.w400,
                    color: AppColors.primary,
                    height: 1.2,
                    letterSpacing: 0.3955,
                  ),
                ),
                const SizedBox(height: 4),
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
          // 追加ボタン
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
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
          onChanged: _filterFriends,
        ),
      ),
    );
  }

  /// フレンド一覧
  Widget _buildFriendsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_filteredFriends.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  // Main message
                  Text(
                    _searchController.text.isEmpty
                        ? 'フレンドがいません'
                        : '該当するフレンドが見つかりません',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      letterSpacing: -0.3125,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtitle
                  Text(
                    _searchController.text.isEmpty
                        ? 'フレンドを追加して通知を送ろう'
                        : '別のキーワードで検索してみてください',
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
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _filteredFriends.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final friend = _filteredFriends[index];
          return _buildFriendCard(friend);
        },
      ),
    );
  }

  /// フレンドカード
  Widget _buildFriendCard(Map<String, dynamic> friend) {
    final displayName = friend['friend_display_name'] ?? '';
    final username = friend['friend_username'] ?? '';
    final friendId = friend['friend_user_id'] ?? '';

    // アバター画像またはイニシャル
    Widget avatar;
    if (friend['friend_profile_image_url'] != null &&
        friend['friend_profile_image_url'].toString().isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: Image.network(
          friend['friend_profile_image_url'],
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar(displayName);
          },
        ),
      );
    } else {
      avatar = _buildDefaultAvatar(displayName);
    }

    return Dismissible(
      key: Key(friendId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await _confirmDeleteFriend(displayName);
      },
      onDismissed: (direction) async {
        await _deleteFriend(friendId, displayName);
      },
      child: Container(
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
            avatar,
            const SizedBox(width: 16),
            // 名前とusername
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
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
                      username,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        height: 1.33,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // 削除ボタン
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: () => _showFriendOptions(friendId, displayName),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// フレンドオプションを表示
  void _showFriendOptions(String friendId, String displayName) {
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
              // 表示名
              Text(
                displayName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              // 削除ボタン
              ListTile(
                leading: const Icon(
                  Icons.person_remove,
                  color: Colors.red,
                ),
                title: const Text(
                  'フレンドを削除',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: Colors.red,
                    letterSpacing: -0.3125,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await _confirmDeleteFriend(displayName);
                  if (confirmed == true) {
                    await _deleteFriend(friendId, displayName);
                  }
                },
              ),
              const SizedBox(height: 8),
              // キャンセルボタン
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

  /// フレンド削除の確認ダイアログ
  Future<bool?> _confirmDeleteFriend(String displayName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'フレンドを削除',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            '$displayNameさんをフレンドから削除しますか？',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              letterSpacing: -0.1504,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'キャンセル',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  letterSpacing: -0.3125,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                '削除',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                  letterSpacing: -0.3125,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// フレンドを削除
  Future<void> _deleteFriend(String friendId, String displayName) async {
    try {
      await _friendService.removeFriend(friendId);

      // リストから削除
      setState(() {
        _friends.removeWhere((f) => f['friend_user_id'] == friendId);
        _filteredFriends.removeWhere((f) => f['friend_user_id'] == friendId);
      });

      // スナックバーで通知（オプション）
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$displayNameさんをフレンドから削除しました'),
            backgroundColor: AppColors.textSecondary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[FriendsScreen] Error deleting friend: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('フレンドの削除に失敗しました'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        // リロードして状態を復元
        _loadData();
      }
    }
  }

  /// デフォルトアバター（イニシャル表示）
  Widget _buildDefaultAvatar(String displayName) {
    String initial = '?';
    if (displayName.isNotEmpty) {
      initial = displayName[0].toUpperCase();
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(100),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
