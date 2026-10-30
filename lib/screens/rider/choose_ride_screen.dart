import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/data.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/map_view.dart';

class ChooseRideScreen extends StatelessWidget {
  const ChooseRideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: h * 0.42,
            child: const TRMap(mode: MapMode.route),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                const TRBack(light: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: TR.shadow(),
                    ),
                    child: Row(children: [
                      const Icon(PhosphorIconsFill.flagCheckered,
                          size: 18, color: TR.navy),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.destination.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TS.label.copyWith(fontSize: 14)),
                      ),
                      Text('${s.destination.km} km · ${s.tripMinutes} min',
                          style: TS.small.copyWith(fontSize: 12)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: h * 0.38,
            child: BottomPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 12),
                  Text('Choose a ride', style: TS.h3),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: Mock.rides.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = Mock.rides[i];
                        final sel = r.id == s.rideId;
                        return SelectTile(
                          selected: sel,
                          onTap: () => s.setRide(r.id),
                          child: Row(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 54,
                              height: 44,
                              decoration: BoxDecoration(
                                color: sel ? TR.green : TR.field,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(r.icon,
                                  color: sel ? Colors.white : TR.navy,
                                  size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(r.name, style: TS.label),
                                    const SizedBox(width: 6),
                                    const Icon(PhosphorIconsFill.user,
                                        size: 12, color: TR.subtle),
                                    Text(' ${r.seats}',
                                        style: TS.small.copyWith(fontSize: 12)),
                                  ]),
                                  Text('${r.etaMin} min away · ${r.note}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TS.small.copyWith(fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(TR.le(r.fareFor(s.destination.km)),
                                style: TS.label.copyWith(fontSize: 16)),
                          ]),
                        )
                            .animate()
                            .fadeIn(delay: (60 * i).ms)
                            .slideY(begin: 0.3, curve: Curves.easeOutCubic);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Pressable(
                      onTap: () => showPaymentSheet(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          PayDot(s.payment.color, s.payment.icon, size: 32),
                          const SizedBox(width: 8),
                          Text(s.payment.name,
                              style: TS.label.copyWith(fontSize: 14)),
                          const SizedBox(width: 4),
                          const Icon(PhosphorIconsBold.caretDown,
                              size: 14, color: TR.muted),
                        ]),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => showToast(
                          context, 'Promo TRUST10 applied — 10% off',
                          icon: PhosphorIconsFill.ticket),
                      icon: const Icon(PhosphorIconsBold.ticket,
                          size: 16, color: TR.navy),
                      label: Text('Promo',
                          style: TS.label.copyWith(color: TR.navy, fontSize: 14)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TRButton(
                    label: 'Book ${s.ride.name} · ${TR.le(s.fare)}',
                    onPressed: () =>
                        Navigator.of(context).pushNamed(R.finding),
                  ),
                ],
              ),
            ).animate().slideY(
                begin: 0.25, duration: 450.ms, curve: Curves.easeOutCubic),
          ),
        ],
      ),
    );
  }
}

/// Shared payment picker, also used on the receipt screen.
Future<void> showPaymentSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) {
      final s = AppScope.read(context);
      return ListenableBuilder(
        listenable: s,
        builder: (context, _) => BottomPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 14),
              Text('Pay with', style: TS.h3),
              const SizedBox(height: 12),
              for (final m in Mock.payMethods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectTile(
                    selected: s.paymentId == m.id,
                    onTap: () {
                      s.setPayment(m.id);
                      Navigator.of(context).pop();
                    },
                    child: Row(children: [
                      PayDot(m.color, m.icon, size: 36),
                      const SizedBox(width: 12),
                      Expanded(child: Text(m.name, style: TS.label)),
                      Text(
                          m.id == 'wallet'
                              ? TR.le(s.wallet, decimals: true)
                              : m.detail,
                          style: TS.small),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
