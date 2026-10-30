import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';

/// Credit (or correct) a rider's wallet after receiving cash or mobile money.
class AdminWallet extends StatefulWidget {
  const AdminWallet({super.key});
  @override
  State<AdminWallet> createState() => _AdminWalletState();
}

class _AdminWalletState extends State<AdminWallet> {
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController(text: 'Cash top-up at office');
  AppUser? _user;
  bool _finding = false;
  bool _saving = false;
  String? _error;
  Stream<List<WalletTx>>? _tx;

  @override
  void dispose() {
    _phone.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    setState(() {
      _finding = true;
      _error = null;
      _user = null;
    });
    try {
      final u = await Db.findUserByPhone(AuthService.normalise(_phone.text));
      if (!mounted) return;
      setState(() {
        _user = u;
        _tx = u == null ? null : Db.walletStream(u.uid);
        if (u == null) _error = 'No rider with that number. They must sign up in the app first.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  Future<void> _credit({bool deduct = false}) async {
    final u = _user;
    final amt = double.tryParse(_amount.text.trim());
    if (u == null || amt == null || amt <= 0) {
      showToast(context, 'Enter an amount in Leones', icon: PhosphorIconsFill.warning);
      return;
    }
    final signed = deduct ? -amt : amt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
            '${deduct ? 'Deduct' : 'Add'} ${TR.le(amt, decimals: true)} ${deduct ? 'from' : 'to'} ${u.name}?',
            style: TS.h3),
        content: Text('Note: ${_note.text.trim()}', style: TS.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Cancel', style: TS.label.copyWith(color: TR.muted))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Confirm', style: TS.label.copyWith(color: TR.green))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await Db.adminTopUp(
        uid: u.uid,
        amount: signed,
        note: _note.text.trim(),
        adminId: AppScope.read(context).authUser!.uid,
      );
      _amount.clear();
      await _find();
      if (mounted) showToast(context, 'Wallet updated');
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const AdminHeader(
            title: 'Wallet top-ups',
            subtitle: 'Credit a rider after you receive their cash or mobile money'),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Find rider by phone number', style: TS.label),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      onSubmitted: (_) => _find(),
                      decoration: const InputDecoration(
                          prefixText: '+232 ', hintText: '76 000 000'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TRButton(
                      label: 'Find',
                      expand: false,
                      height: 52,
                      loading: _finding,
                      onPressed: _find),
                ]),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TS.small.copyWith(color: TR.danger)),
                ],
                if (u != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: TR.surface, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Avatar(u.initials, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name, style: TS.label),
                            Text(u.phone, style: TS.small),
                          ],
                        ),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Balance', style: TS.small.copyWith(fontSize: 12)),
                        Text(TR.le(u.wallet, decimals: true), style: TS.h3.copyWith(color: TR.navy)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(prefixText: 'Le ', hintText: 'Amount'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _note,
                        decoration: const InputDecoration(hintText: 'Note (e.g. receipt number)'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    TRButton(
                        label: 'Add credit',
                        icon: PhosphorIconsBold.plus,
                        expand: false,
                        loading: _saving,
                        onPressed: () => _credit()),
                    TRButton(
                        label: 'Deduct (correction)',
                        kind: BtnKind.outline,
                        expand: false,
                        onPressed: _saving ? null : () => _credit(deduct: true)),
                  ]),
                  const SizedBox(height: 18),
                  const Caps('Recent wallet activity'),
                  StreamBuilder<List<WalletTx>>(
                    stream: _tx,
                    builder: (context, snap) {
                      final list = snap.data ?? const <WalletTx>[];
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text('No activity yet.', style: TS.small),
                        );
                      }
                      return Column(children: [
                        for (final t in list.take(15))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(t.note.isEmpty ? t.type : t.note, style: TS.label.copyWith(fontSize: 14)),
                            subtitle: Text(dateLabel(t.createdAt), style: TS.small),
                            trailing: Text(
                                '${t.amount >= 0 ? '+' : '−'}${TR.le(t.amount.abs(), decimals: true)}',
                                style: TS.label.copyWith(
                                    color: t.amount >= 0 ? const Color(0xFF1F6B2E) : TR.ink)),
                          ),
                      ]);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
