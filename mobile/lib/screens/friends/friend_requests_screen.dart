import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// フレンド申請画面
class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  int _selectedTab = 0; // 0: 受信, 1: 送信

  // ダミーデータ（受信した申請）
  final List<Map<String, dynamic>> _receivedRequests = [
    {
      'id': '201',
      'name': '佐々木 優',
      'emoji': '👨‍💼',
      'date': '11月5日',
    },
    {
      'id': '202',
      'name': '中川 舞',
      'emoji': '👩‍🎨',
      'date': '11月4日',
    },
    {
      'id': '203',
      'name': '林 健太',
      'emoji': '👨‍🎓',
      'date': '11月3日',
    },
  ];

  // ダミーデータ（送信した申請）
  final List<Map<String, dynamic>> _sentRequests = [
    {
      'id': '301',
      'name': '斎藤 美咲',
      'emoji': '👩‍💼',
      'date': '11月5日',
    },
    {
      'id': '302',
      'name': '森田 大輔',
      'emoji': '👨‍💻',
      'date': '11月2日',
    },
  ];

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
                  'フレンド申請',
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _receivedRequests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final request = _receivedRequests[index];
        return _buildReceivedRequestCard(request);
      },
    );
  }

  /// 受信した申請カード
  Widget _buildReceivedRequestCard(Map<String, dynamic> request) {
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(100),
                ),
                alignment: Alignment.center,
                child: Text(
                  request['emoji'],
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              // 名前・ID・日付
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['name'],
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
                        'ID: ${request['id']}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.33,
                        ),
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
                          request['date'],
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
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: 承認処理
                    },
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
                        Icon(Icons.person_add_outlined, size: 16),
                        SizedBox(width: 8),
                        Text(
                          '承認',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
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
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: 拒否処理
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.inputBackground,
                      foregroundColor: const Color(0xFF5A4A40),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_remove_outlined, size: 16),
                        SizedBox(width: 8),
                        Text(
                          '拒否',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _sentRequests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final request = _sentRequests[index];
        return _buildSentRequestCard(request);
      },
    );
  }

  /// 送信した申請カード
  Widget _buildSentRequestCard(Map<String, dynamic> request) {
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(100),
                ),
                alignment: Alignment.center,
                child: Text(
                  request['emoji'],
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              // 名前・ID・日付
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['name'],
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
                        'ID: ${request['id']}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.33,
                        ),
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
                          '${request['date']} に送信',
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
          const SizedBox(height: 12),
          // 申請を取り消すボタン
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () {
                // TODO: 申請取り消し処理
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.inputBackground,
                foregroundColor: const Color(0xFF5A4A40),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close, size: 16),
                  SizedBox(width: 8),
                  Text(
                    '申請を取り消す',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
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
}
