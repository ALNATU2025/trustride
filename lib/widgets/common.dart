import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/icons.dart';
import '../services/photo_service.dart';

import '../core/theme.dart';

/// Adds a soft press-down scale and haptic tick to anything tappable.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

enum BtnKind { primary, dark, outline, ghost, danger, light }

class TRButton extends StatelessWidget {
  const TRButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.kind = BtnKind.primary,
    this.loading = false,
    this.height = 56,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BtnKind kind;
  final bool loading;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Color bg = TR.green;
    Color fg = Colors.white;
    Border? border;
    Gradient? gradient;
    switch (kind) {
      case BtnKind.primary:
        bg = TR.green;
        fg = Colors.white;
        gradient = const LinearGradient(
            colors: [Color(0xFF239142), TR.green],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter);
      case BtnKind.dark:
        bg = TR.navy;
        fg = Colors.white;
        gradient = const LinearGradient(
            colors: [TR.navySoft, TR.navy],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter);
      case BtnKind.outline:
        bg = Colors.white;
        fg = TR.ink;
        border = Border.all(color: TR.border);
      case BtnKind.ghost:
        bg = Colors.transparent;
        fg = TR.navy;
      case BtnKind.danger:
        bg = TR.danger;
        fg = Colors.white;
      case BtnKind.light:
        bg = Colors.white;
        fg = TR.navy;
    }
    final disabled = onPressed == null && !loading;
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: loading
          ? SizedBox(
              key: const ValueKey('l'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
            )
          : Row(
              key: const ValueKey('c'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TS.label.copyWith(color: fg, fontSize: 16)),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, color: fg, size: 18),
                ],
              ],
            ),
    );
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Pressable(
        onTap: loading ? null : onPressed,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: expand ? 0 : 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: gradient == null ? bg : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(height / 2),
            border: border,
            boxShadow: (kind == BtnKind.primary || kind == BtnKind.dark) &&
                    !disabled
                ? [
                    BoxShadow(
                        color: bg.fade(0.32),
                        blurRadius: 18,
                        offset: const Offset(0, 8))
                  ]
                : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.background = TR.field,
    this.color = TR.ink,
    this.size = 46,
    this.shadow = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final Color background;
  final Color color;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          boxShadow: shadow ? TR.shadow() : null,
        ),
        child: Icon(icon, color: color, size: size * 0.44),
      ),
    );
  }
}

class TRBack extends StatelessWidget {
  const TRBack({super.key, this.onTap, this.light = false});
  final VoidCallback? onTap;
  final bool light;

  @override
  Widget build(BuildContext context) => CircleIconButton(
        icon: PhosphorIconsBold.arrowLeft,
        label: 'Back',
        background: light ? Colors.white : TR.field,
        shadow: light,
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
      );
}

/// Round avatar showing a profile photo (base64) or initials.
class Avatar extends StatelessWidget {
  const Avatar(this.initials,
      {super.key,
      this.photo = '',
      this.size = 48,
      this.bg = const Color(0xFFC9D6E3),
      this.fg = TR.navy,
      this.ring = false});
  final String initials;
  final String photo;
  final double size;
  final Color bg;
  final Color fg;
  final bool ring;

  static final Map<int, Uint8List> _cache = {};

  static Uint8List? _bytes(String b64) {
    if (b64.isEmpty) return null;
    final key = b64.hashCode;
    final hit = _cache[key];
    if (hit != null) return hit;
    final bytes = PhotoService.decode(b64);
    if (bytes != null) {
      if (_cache.length > 60) _cache.remove(_cache.keys.first);
      _cache[key] = bytes;
    }
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes(photo);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring ? 3 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ring ? TR.brandGradient : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: ring ? Border.all(color: Colors.white, width: 2) : null,
          image: bytes == null
              ? null
              : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
        ),
        alignment: Alignment.center,
        child: bytes != null
            ? null
            : Text(initials,
                style: TS.label.copyWith(
                    color: fg, fontSize: size * 0.32, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// The TrustRide emblem on a white badge, so it stays visible on any
/// background. Shown in the header of every screen.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 44, this.shadow = true});
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'TrustRide',
        image: true,
        child: Container(
          height: size,
          padding: EdgeInsets.symmetric(horizontal: size * 0.18, vertical: size * 0.14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.32),
            boxShadow: shadow ? TR.shadow(0.8) : null,
          ),
          child: Image.asset('assets/images/logo_mark.png',
              fit: BoxFit.contain, filterQuality: FilterQuality.medium),
        ),
      );
}

/// Title row used at the top of tab screens: logo, title, optional action.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle, this.trailing, this.back = false});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool back;

  @override
  Widget build(BuildContext context) => Row(children: [
        if (back) ...[const TRBack(), const SizedBox(width: 12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TS.h2),
              if (subtitle != null) Text(subtitle!, style: TS.small),
            ],
          ),
        ),
        if (trailing != null) ...[trailing!, const SizedBox(width: 10)],
        const LogoMark(size: 42),
      ]);
}

/// Bottom sheet to take or choose a photo. Returns base64 JPEG or null.
Future<String?> pickPhotoSheet(BuildContext context) async {
  final camera = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (c) => BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 16),
          Text('Profile photo', style: TS.h3),
          const SizedBox(height: 4),
          Text('A clear photo of your face helps drivers and riders recognise you.',
              style: TS.small),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const IconBubble(PhosphorIconsFill.camera, color: TR.green, bg: TR.greenTint),
            title: Text('Take a photo', style: TS.label),
            onTap: () => Navigator.pop(c, true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const IconBubble(PhosphorIconsFill.image),
            title: Text('Choose from gallery', style: TS.label),
            onTap: () => Navigator.pop(c, false),
          ),
        ],
      ),
    ),
  );
  if (camera == null) return null;
  return PhotoService.pick(camera: camera);
}

enum PillKind { success, warning, danger, info, neutral }

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.kind = PillKind.success, this.icon});
  final String text;
  final PillKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      PillKind.success => (TR.greenTint, const Color(0xFF1F6B2E)),
      PillKind.warning => (TR.amberTint, TR.amberInk),
      PillKind.danger => (TR.dangerTint, const Color(0xFFA12222)),
      PillKind.info => (const Color(0xFFE6EEF8), TR.navy),
      PillKind.neutral => (TR.field, TR.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TS.small.copyWith(
                  color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class Caps extends StatelessWidget {
  const Caps(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: TS.caps);
}

class TRCard extends StatelessWidget {
  const TRCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.radius = 20,
    this.shadow = true,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadow ? TR.shadow(0.6) : null,
        ),
        child: child,
      );
}

/// A tappable option that animates between selected and unselected states.
class SelectTile extends StatelessWidget {
  const SelectTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.radius = 16,
  });
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: padding,
          decoration: BoxDecoration(
            color: selected ? TR.greenTint : Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
                color: selected ? TR.green : TR.line, width: selected ? 2 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: TR.green.fade(0.14),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ]
                : null,
          ),
          child: child,
        ),
      );
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
              color: TR.border, borderRadius: BorderRadius.circular(3)),
        ),
      );
}

/// White rounded sheet anchored to the bottom over a map.
class BottomPanel extends StatelessWidget {
  const BottomPanel({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ??
            EdgeInsets.fromLTRB(
                20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
                color: TR.navy.fade(0.14),
                blurRadius: 30,
                offset: const Offset(0, -8)),
          ],
        ),
        child: child,
      );
}

class BrandWord extends StatelessWidget {
  const BrandWord({super.key, this.size = 20, this.light = false});
  final double size;
  final bool light;
  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(
              text: 'Trust',
              style: TextStyle(color: light ? Colors.white : TR.navy)),
          TextSpan(
              text: 'Ride',
              style: TextStyle(color: light ? TR.greenBright : TR.green)),
        ]),
        style: TS.h3.copyWith(fontSize: size, fontWeight: FontWeight.w800),
      );
}

class PayDot extends StatelessWidget {
  const PayDot(this.color, this.icon, {super.key, this.size = 40});
  final Color color;
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.fade(0.12),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

class IconBubble extends StatelessWidget {
  const IconBubble(this.icon,
      {super.key, this.color = TR.navy, this.bg = TR.field, this.size = 42});
  final IconData icon;
  final Color color;
  final Color bg;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: size * 0.46),
      );
}

/// The two-dot "from → to" rail used on trip cards.
class RouteRail extends StatelessWidget {
  const RouteRail({super.key, this.height = 26});
  final double height;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: TR.green, shape: BoxShape.circle)),
          Container(
              width: 2,
              height: height,
              margin: const EdgeInsets.symmetric(vertical: 3),
              color: const Color(0xFFC9D6E3)),
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: TR.navy, borderRadius: BorderRadius.circular(2))),
        ],
      );
}

void showToast(BuildContext context, String message, {IconData? icon}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon ?? PhosphorIconsFill.checkCircle,
            color: TR.greenBright, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: TS.label.copyWith(color: Colors.white, fontSize: 14))),
      ]),
    ));
}

/// Icon for a ride type id (okada, keke, car, ac, xl).
IconData rideIcon(String id) => switch (id) {
      'okada' => PhosphorIconsFill.motorcycle,
      'keke' => PhosphorIconsFill.scooter,
      'ac' => PhosphorIconsFill.snowflake,
      'xl' => PhosphorIconsFill.van,
      _ => PhosphorIconsFill.carProfile,
    };

/// Friendly message for any error thrown by services.
String errorText(Object e) {
  final s = e.toString();
  if (s.contains('permission-denied')) {
    return 'You don’t have permission to do that.';
  }
  if (s.contains('unavailable') || s.contains('network')) {
    return 'No connection. Check your internet and try again.';
  }
  return s.replaceFirst('Exception: ', '').replaceFirst(RegExp(r'^\[.*?\]\s*'), '');
}

String timeAgo(DateTime? t) {
  if (t == null) return 'just now';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

String dateLabel(DateTime? t) {
  if (t == null) return 'Pending';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final now = DateTime.now();
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (t.year == now.year && t.month == now.month && t.day == now.day) {
    return 'Today, $hm';
  }
  final y = now.subtract(const Duration(days: 1));
  if (t.year == y.year && t.month == y.month && t.day == y.day) {
    return 'Yesterday, $hm';
  }
  return '${t.day} ${months[t.month - 1]}, $hm';
}

/// Empty / loading / error placeholder used in lists.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body = ''});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBubble(icon, size: 64, color: TR.green, bg: TR.greenTint),
            const SizedBox(height: 12),
            Text(title, style: TS.h3, textAlign: TextAlign.center),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(body, style: TS.small, textAlign: TextAlign.center),
            ],
          ],
        ),
      );
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: TR.green),
        ),
      );
}
