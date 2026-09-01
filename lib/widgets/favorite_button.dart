import 'package:flutter/material.dart';

import '../services/favorites_service.dart';
import '../services/firebase_state.dart';
import '../theme/app_theme.dart';

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.itemId,
    required this.item,
    this.backgroundColor = const Color(0xD90B1B31),
    this.iconSize = 20,
  });

  final String itemId;
  final Map<String, dynamic> item;
  final Color backgroundColor;
  final double iconSize;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  FavoritesService? _favorites;
  bool _busy = false;

  FavoritesService get _service => _favorites ??= FavoritesService();

  Future<void> _toggle(String userId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final added = await _service.toggle(
        userId: userId,
        itemId: widget.itemId,
        item: widget.item,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              added ? 'تمت الإضافة إلى المفضلة' : 'تمت الإزالة من المفضلة'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديث المفضلة. حاول مرة أخرى.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseState.isReady || widget.itemId.isEmpty) {
      return _icon(isFavorite: false, onPressed: _requestLogin);
    }
    final user = _service.currentUser;
    if (user == null) {
      return _icon(isFavorite: false, onPressed: _requestLogin);
    }
    return StreamBuilder<bool>(
      stream: _service.watchIsFavorite(user.uid, widget.itemId),
      builder: (context, snapshot) => _icon(
        isFavorite: snapshot.data ?? false,
        onPressed: _busy ? null : () => _toggle(user.uid),
      ),
    );
  }

  void _requestLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سجّل الدخول أولاً لاستخدام المفضلة.')),
    );
  }

  Widget _icon({required bool isFavorite, required VoidCallback? onPressed}) =>
      Material(
        color: widget.backgroundColor,
        shape: const CircleBorder(),
        child: IconButton(
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
          onPressed: onPressed,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border,
                  size: widget.iconSize,
                  color: isFavorite ? Colors.redAccent : AppTheme.coolYellow,
                ),
        ),
      );
}
