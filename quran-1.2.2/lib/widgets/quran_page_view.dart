import 'package:flutter/material.dart';
import 'package:quran/quran.dart';

class QuranPageView extends StatelessWidget {
  final PageController controller;
  final void Function(int)? onPageChanged;
  final List<Widget> children;

  const QuranPageView({
    Key? key,
    required this.controller,
    this.onPageChanged,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollUpdateNotification) {
          final int currentPage = controller.page?.round() ?? 1;

          // Only handle scroll prevention for page 1
          if (currentPage == 1) {
            final double velocity = notification.metrics.pixels -
                notification.metrics.minScrollExtent;
            // Allow small overscroll but prevent full page transition
            if (velocity < -50) {
              controller.animateTo(
                notification.metrics.minScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
              return true;
            }
          }
        }
        return false;
      },
      child: PageView(
        controller: controller,
        onPageChanged: onPageChanged,
        physics:
            const BouncingScrollPhysics(), // Use bouncing physics for smoother feel
        children: children,
      ),
    );
  }
}
