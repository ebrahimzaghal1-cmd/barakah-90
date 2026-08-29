import 'package:flutter/material.dart';

class BarakahReaction {
  final String id;
  final String label;
  final String imagePath;

  const BarakahReaction({
    required this.id,
    required this.label,
    required this.imagePath,
  });
}

const List<BarakahReaction> barakahReactions = [
  BarakahReaction(
    id: 'happy',
    label: 'سعيد',
    imagePath: 'assets/images/reactions/happy.png',
  ),
  BarakahReaction(
    id: 'love',
    label: 'أحبّه',
    imagePath: 'assets/images/reactions/love.png',
  ),
  BarakahReaction(
    id: 'excellent',
    label: 'ممتاز',
    imagePath: 'assets/images/reactions/excellent.png',
  ),
  BarakahReaction(
    id: 'excited',
    label: 'متحمس',
    imagePath: 'assets/images/reactions/excited.png',
  ),
  BarakahReaction(
    id: 'surprised',
    label: 'مندهش',
    imagePath: 'assets/images/reactions/surprised.png',
  ),
  BarakahReaction(
    id: 'sad',
    label: 'حزين',
    imagePath: 'assets/images/reactions/sad.png',
  ),
];

class BarakahReactions extends StatefulWidget {
  final Future<void> Function(BarakahReaction reaction)? onChanged;
  final String? selectedId;

  const BarakahReactions({
    super.key,
    this.onChanged,
    this.selectedId,
  });

  @override
  State<BarakahReactions> createState() => _BarakahReactionsState();
}

class _BarakahReactionsState extends State<BarakahReactions> {
  String? selectedId;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    selectedId = widget.selectedId;
  }

  @override
  void didUpdateWidget(covariant BarakahReactions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!saving && oldWidget.selectedId != widget.selectedId) {
      selectedId = widget.selectedId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: 105,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: barakahReactions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final reaction = barakahReactions[index];
            final selected = selectedId == reaction.id;

            return GestureDetector(
              onTap: saving
                  ? null
                  : () async {
                      final previousId = selectedId;
                      setState(() {
                        selectedId = reaction.id;
                        saving = true;
                      });

                      try {
                        await widget.onChanged?.call(reaction);
                      } catch (_) {
                        if (mounted) {
                          setState(() => selectedId = previousId);
                        }
                      } finally {
                        if (mounted) {
                          setState(() => saving = false);
                        }
                      }
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 82,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFFD43B)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF0B2A59)
                        : const Color(0xFFE7D7A5),
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Image.asset(
                        reaction.imagePath,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      reaction.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? const Color(0xFF0B2A59)
                            : const Color(0xFF223655),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
