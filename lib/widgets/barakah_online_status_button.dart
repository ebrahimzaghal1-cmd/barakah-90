import 'package:flutter/material.dart';

import '../services/app_hours_service.dart';

class BarakahOnlineStatusButton extends StatelessWidget {
  const BarakahOnlineStatusButton({super.key});

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
            child: Material(
              color: background,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () => _showDetails(context, status),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: foreground.withOpacity(.24)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: foreground,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: foreground.withOpacity(.28),
                              blurRadius: 7,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status.isOpen ? 'أونلاين' : 'أوفلاين',
                        style: TextStyle(
                          color: foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: foreground,
                        size: 19,
                      ),
                    ],
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
