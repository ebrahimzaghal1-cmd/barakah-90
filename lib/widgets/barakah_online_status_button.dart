import 'package:flutter/material.dart';

import '../services/app_hours_service.dart';

class BarakahOnlineStatusButton extends StatefulWidget {
  const BarakahOnlineStatusButton({super.key});

  @override
  State<BarakahOnlineStatusButton> createState() =>
      _BarakahOnlineStatusButtonState();
}

class _BarakahOnlineStatusButtonState extends State<BarakahOnlineStatusButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: .88, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AppHoursStatus?>(
        stream: AppHoursService.watch(),
        builder: (context, snapshot) {
          final status = snapshot.data;
          if (status == null) return const SizedBox.shrink();

          final foreground =
              status.isOpen ? const Color(0xFF167A45) : const Color(0xFFA52626);
          final background =
              status.isOpen ? const Color(0xFFE8F8EF) : const Color(0xFFFFE8E8);

          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: ScaleTransition(
              scale: _pulse,
              child: Material(
                color: background,
                shape: const CircleBorder(),
                elevation: 5,
                shadowColor: foreground.withOpacity(.48),
                child: InkWell(
                  onTap: () => _showDetails(context, status),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: foreground.withOpacity(.38),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: foreground,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

  Future<void> _showDetails(
    BuildContext context,
    AppHoursStatus status,
  ) async {
    final foreground =
        status.isOpen ? const Color(0xFF167A45) : const Color(0xFFA52626);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: foreground.withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status.isOpen
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  color: foreground,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                status.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                status.detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6EE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status.isOpen
                      ? 'موعد الإغلاق: ${status.closingTime}'
                      : 'ساعات العمل: ${status.openingTime} - ${status.closingTime}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
