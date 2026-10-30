import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';

class NavItem {
  const NavItem(this.icon, this.activeIcon, this.label, {this.badge = 0});
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
}

/// Floating pill navigation with an animated active indicator.
class TRNavBar extends StatelessWidget {
  const TRNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: TR.line)),
        boxShadow: [
          BoxShadow(
              color: TR.navy.fade(0.06),
              blurRadius: 20,
              offset: const Offset(0, -6)),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => onTap(i),
                semanticLabel: items[i].label,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: i == index ? TR.greenTint : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (c, a) =>
                                ScaleTransition(scale: a, child: c),
                            child: Icon(
                              i == index ? items[i].activeIcon : items[i].icon,
                              key: ValueKey(i == index),
                              size: 24,
                              color: i == index ? TR.green : TR.muted,
                            ),
                          ),
                          if (items[i].badge > 0)
                            Positioned(
                              right: -8,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                    color: TR.danger,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text('${items[i].badge}',
                                    style: TS.small.copyWith(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: TS.small.copyWith(
                          fontSize: 11.5,
                          fontWeight:
                              i == index ? FontWeight.w800 : FontWeight.w600,
                          color: i == index ? TR.green : TR.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
