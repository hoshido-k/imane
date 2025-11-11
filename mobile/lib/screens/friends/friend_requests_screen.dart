import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/friend_service.dart';

/// フレンド申請画面
class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final FriendService _friendService = FriendService();

  int _selectedTab = 0; // 0: 受信, 1: 送信
  bool _isLoading = true;

  List<Map<String, dynamic>> _receivedRequests = [];
  List<Map<String, dynamic>> _sentRequests = [];
  Set<String> _processingRequests = {}; // 処理中のリクエストIDを管理

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final received = await _friendService.getReceivedRequests();
      final sent = await _friendService.getSentRequests();

      setState(() {
        _receivedRequests = received;
        _sentRequests = sent;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptRequest(String requestId, String userName) async {
    setState(() {
      _processingRequests.add(requestId);
    });

    try {
      await _friendService.acceptFriendRequest(requestId);

      if (mounted) {
        // リストから削除
        setState(() {
          _receivedRequests.removeWhere((r) => r['request_id'] == requestId);
          _processingRequests.remove(requestId);
        });
      }
    } catch (e) {
      setState(() {
        _processingRequests.remove(requestId);
      });
    }
  }

  Future<void> _rejectRequest(String requestId, String userName) async {
    setState(() {
      _processingRequests.add(requestId);
    });

    try {
      await _friendService.rejectFriendRequest(requestId);

      if (mounted) {
        // リストから削除
        setState(() {
          _receivedRequests.removeWhere((r) => r['request_id'] == requestId);
          _processingRequests.remove(requestId);
        });
      }
    } catch (e) {
      setState(() {
        _processingRequests.remove(requestId);
      });
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final formatter = DateFormat('M月d日');
      return formatter.format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildTabBar(),
            const SizedBox(height: 32),
            Expanded(
              child: _selectedTab == 0
                  ? _buildReceivedRequestsList()
                  : _buildSentRequestsList(),
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
          Expanded(
            child: Column(
              children: [
                const Text(
                  'フレンド申請',
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
                  '受信 ${_receivedRequests.length}件 / 送信 ${_sentRequests.length}件',
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
          // 右側スペーサー（左右対称）
          const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }

  /// タブバー
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 54,
        padding: const EdgeInsets.all(4.5),
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
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                index: 0,
                label: '受信した申請',
                badge: _receivedRequests.length,
              ),
            ),
            Expanded(
              child: _buildTabButton(
                index: 1,
                label: '送信した申請',
                badge: null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// タブボタン
  Widget _buildTabButton({
    required int index,
    required String label,
    int? badge,
  }) {
    final isSelected = _selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF5A4A40),
                height: 1.43,
                letterSpacing: -0.1504,
              ),
            ),
            if (badge != null && badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.primary : Colors.white,
                    height: 1.33,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 受信した申請リスト
  Widget _buildReceivedRequestsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_receivedRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
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
                        children: [
                          Icon(
                            Icons.person_add_disabled,
                            size: 48,
                            color: AppColors.textSecondary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '受信したフレンド申請はありません',
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
                              'フレンド申請が届くと表示されます',
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
                ),
              );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _receivedRequests.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final request = _receivedRequests[index];
          return _buildReceivedRequestCard(request);
        },
      ),
    );
  }

  /// 受信した申請カード
  Widget _buildReceivedRequestCard(Map<String, dynamic> request) {
    final requestId = request['request_id'] ?? '';
    final userName = request['from_user_display_name'] ?? '';
    final username = request['from_user_username'] ?? '';
    final createdAt = request['created_at'] ?? '';
    final isProcessing = _processingRequests.contains(requestId);

    // アバター画像またはイニシャル
    Widget avatar;
    if (request['from_user_profile_image_url'] != null &&
        request['from_user_profile_image_url'].toString().isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: Image.network(
          request['from_user_profile_image_url'],
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar(userName);
          },
        ),
      );
    } else {
      avatar = _buildDefaultAvatar(userName);
    }

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
      child: Column(
        children: [
          // ユーザー情報
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // アバター
              avatar,
              const SizedBox(width: 12),
              // 名前・ID・日付
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(createdAt),
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 承認・拒否ボタン
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed:
                        isProcessing ? null : () => _acceptRequest(requestId, userName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.inputBackground,
                      disabledForegroundColor: AppColors.textSecondary,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isProcessing) ...[
                          const Icon(Icons.person_add_outlined, size: 14),
                          const SizedBox(width: 6),
                        ],
                        if (isProcessing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else
                          const Text(
                            '承認',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.3125,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed:
                        isProcessing ? null : () => _rejectRequest(requestId, userName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.inputBackground,
                      foregroundColor: const Color(0xFF5A4A40),
                      disabledBackgroundColor: AppColors.inputBackground,
                      disabledForegroundColor: AppColors.textSecondary,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_remove_outlined, size: 14),
                        SizedBox(width: 6),
                        Text(
                          '拒否',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.3125,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 送信した申請リスト
  Widget _buildSentRequestsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_sentRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
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
                        children: [
                          Icon(
                            Icons.send_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '送信したフレンド申請はありません',
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
                              '新しいフレンドを検索して申請しましょう',
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
                ),
              );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _sentRequests.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final request = _sentRequests[index];
          return _buildSentRequestCard(request);
        },
      ),
    );
  }

  /// 送信した申請カード
  Widget _buildSentRequestCard(Map<String, dynamic> request) {
    final displayName = request['to_user_display_name'] ?? '不明なユーザー';
    final username = request['to_user_username'] ?? '';
    final createdAt = request['created_at'] ?? '';

    // アバター画像またはイニシャル
    Widget avatar;
    if (request['to_user_profile_image_url'] != null &&
        request['to_user_profile_image_url'].toString().isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: Image.network(
          request['to_user_profile_image_url'],
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
      child: Column(
        children: [
          // ユーザー情報
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // アバター
              avatar,
              const SizedBox(width: 12),
              // 名前・ID・日付
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatDate(createdAt)} に送信',
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
                  ],
                ),
              ),
              // 保留中バッジ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: Color(0xFFF59E0B),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '保留中',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFF59E0B),
                        height: 1.33,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
