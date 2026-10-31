import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/icons.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/db.dart';
import '../widgets/common.dart';

/// Arguments for the chat route.
class ChatArgs {
  const ChatArgs({
    required this.tripId,
    required this.otherName,
    required this.otherPhone,
    this.otherPhoto = '',
  });
  final String tripId;
  final String otherName;
  final String otherPhone;
  final String otherPhoto;
}

/// Rider ↔ driver chat for one trip.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.args});
  final ChatArgs args;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final Stream<List<ChatMessage>> _msgs = Db.chatStream(widget.args.tripId);
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  static const _quick = [
    'I’m on my way',
    'I’m at the pickup point',
    'Please call me',
    'Running 5 minutes late',
    'Thank you!',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    final uid = AppScope.read(context).authUser?.uid;
    if (uid == null) return;
    setState(() => _sending = true);
    try {
      await Db.sendMessage(widget.args.tripId, uid, text);
      if (preset == null) _ctrl.clear();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = AppScope.of(context).authUser?.uid ?? '';
    final a = widget.args;
    return Scaffold(
      backgroundColor: TR.surface,
      body: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(color: Colors.white, boxShadow: TR.shadow(0.4)),
            child: Row(children: [
              const TRBack(),
              const SizedBox(width: 10),
              Avatar(initialsOf(a.otherName), photo: a.otherPhoto, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.label),
                    Text('Trip chat', style: TS.small.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              CircleIconButton(
                icon: PhosphorIconsFill.phone,
                label: 'Call',
                onTap: () => launchUrl(Uri(scheme: 'tel', path: a.otherPhone)),
              ),
              const SizedBox(width: 8),
              const LogoMark(size: 40, shadow: false),
            ]),
          ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _msgs,
              builder: (context, snap) {
                if (snap.hasError) {
                  return EmptyState(
                      icon: PhosphorIconsFill.warning,
                      title: 'Chat unavailable',
                      body: errorText(snap.error!));
                }
                final list = snap.data ?? const <ChatMessage>[];
                if (list.isEmpty) {
                  return const Center(
                    child: EmptyState(
                      icon: PhosphorIconsFill.chatCircleDots,
                      title: 'Say hello',
                      body: 'Messages are only visible to you and your driver or rider.',
                    ),
                  );
                }
                _toBottom();
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final m = list[i];
                    final mine = m.from == me;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: mine ? TR.brandGradient : null,
                          color: mine ? null : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(mine ? 18 : 4),
                            bottomRight: Radius.circular(mine ? 4 : 18),
                          ),
                          boxShadow: mine ? null : TR.shadow(0.3),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(m.text,
                                style: TS.body.copyWith(
                                    color: mine ? Colors.white : TR.ink, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(
                                m.createdAt == null
                                    ? 'Sending…'
                                    : '${m.createdAt!.hour.toString().padLeft(2, '0')}:${m.createdAt!.minute.toString().padLeft(2, '0')}',
                                style: TS.small.copyWith(
                                    fontSize: 10.5,
                                    color: mine ? const Color(0xFFD6E2F0) : TR.subtle)),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2);
                  },
                );
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final q in _quick)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(q, style: TS.label.copyWith(fontSize: 12.5)),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: TR.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      onPressed: () => _send(q),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: Colors.white,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    counterText: '',
                    fillColor: TR.field,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: TR.navy)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: PhosphorIconsFill.paperPlaneRight,
                label: 'Send',
                background: TR.green,
                color: Colors.white,
                size: 48,
                onTap: () => _send(),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
