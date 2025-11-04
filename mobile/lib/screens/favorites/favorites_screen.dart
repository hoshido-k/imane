import 'package:flutter/material.dart';
import '../../models/favorite_location.dart';
import '../../services/api_service.dart';

/// Favorite locations screen
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ApiService _apiService = ApiService();
  List<FavoriteLocation> _favorites = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  /// Load favorites from API
  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.get('/favorites');
      final List<dynamic> favoritesJson = response['favorites'] ?? response;

      setState(() {
        _favorites = favoritesJson
            .map((json) => FavoriteLocation.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'お気に入りの読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  /// Delete favorite
  Future<void> _deleteFavorite(FavoriteLocation favorite) async {
    if (favorite.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${favorite.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.delete('/favorites/${favorite.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除しました')),
        );
        _loadFavorites();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お気に入り場所'),
        backgroundColor: Colors.orange,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFavorites,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_border, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'お気に入りの場所がありません',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'スケジュール作成時に保存できます',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final favorite = _favorites[index];
          return _FavoriteCard(
            favorite: favorite,
            onDelete: () => _deleteFavorite(favorite),
          );
        },
      ),
    );
  }
}

/// Favorite card widget
class _FavoriteCard extends StatelessWidget {
  final FavoriteLocation favorite;
  final VoidCallback onDelete;

  const _FavoriteCard({
    required this.favorite,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.star, color: Colors.orange.shade700),
        ),
        title: Text(
          favorite.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    favorite.address,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${favorite.coords.latitude.toStringAsFixed(6)}, ${favorite.coords.longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Courier',
                color: Colors.grey,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDelete,
        ),
        onTap: () {
          // TODO: Show on map or use for schedule
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${favorite.name}を選択しました')),
          );
        },
      ),
    );
  }
}
