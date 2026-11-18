import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/color_constants.dart';

const int kMaxFrequentTexts = 3;
const String kFrequentTextsKey = 'frequent_texts';

/// "Add frequently used text" button plus up to [kMaxFrequentTexts] saved
/// rows. Saved texts live in SharedPreferences until the user deletes them.
class FrequentTexts extends StatefulWidget {
  const FrequentTexts({
    super.key,
    required this.enabled,
    required this.onUse,
  });

  /// Whether the "Use" buttons may be pressed (false in preview / while sending).
  final bool enabled;

  /// Called with the chosen text; the owner puts it on the field and sends it.
  final ValueChanged<String> onUse;

  @override
  State<FrequentTexts> createState() => _FrequentTextsState();
}

class _Entry {
  _Entry(this.text, {this.editing = false})
      : controller = TextEditingController(text: text),
        focus = FocusNode();

  String text;
  bool editing;
  final TextEditingController controller;
  final FocusNode focus;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _FrequentTextsState extends State<FrequentTexts> {
  final List<_Entry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(kFrequentTextsKey) ?? const [];
      if (!mounted) return;
      setState(() {
        _entries.addAll(saved.take(kMaxFrequentTexts).map(_Entry.new));
      });
    } catch (_) {
      // Storage unavailable: start empty rather than crash the screen.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        kFrequentTextsKey,
        _entries.where((e) => e.text.isNotEmpty).map((e) => e.text).toList(),
      );
    } catch (_) {}
  }

  void _add() {
    if (_entries.length >= kMaxFrequentTexts) return;
    final entry = _Entry('', editing: true);
    setState(() => _entries.add(entry));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) entry.focus.requestFocus();
    });
  }

  void _commit(_Entry entry) {
    if (!entry.editing) return;
    final value = entry.controller.text.trim();
    setState(() {
      if (value.isEmpty && entry.text.isEmpty) {
        // Nothing was ever saved for this row: drop it.
        _entries.remove(entry);
        entry.dispose();
      } else {
        if (value.isNotEmpty) entry.text = value;
        entry.controller.text = entry.text;
        entry.editing = false;
      }
    });
    _persist();
  }

  void _edit(_Entry entry) {
    setState(() => entry.editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) entry.focus.requestFocus();
    });
  }

  void _delete(_Entry entry) {
    setState(() => _entries.remove(entry));
    entry.dispose();
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _entries.length < kMaxFrequentTexts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: canAdd ? _add : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: bleMaroon,
              side: BorderSide(color: canAdd ? bleMaroon : blePinkChip, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(
              canAdd
                  ? 'Add frequently used text'
                  : 'Maximum $kMaxFrequentTexts texts saved',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        for (final entry in _entries)
          Padding(
            key: ObjectKey(entry),
            padding: const EdgeInsets.only(top: 10),
            child: _row(entry),
          ),
      ],
    );
  }

  Widget _row(_Entry entry) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: entry.controller,
            focusNode: entry.focus,
            readOnly: !entry.editing,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: bleTextDark, fontWeight: FontWeight.w600),
            onSubmitted: (_) => _commit(entry),
            onTapOutside: (_) {
              if (entry.editing) _commit(entry);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: blePink,
              hintText: 'Type text to save',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: (widget.enabled && !entry.editing && entry.text.isNotEmpty)
              ? () => widget.onUse(entry.text)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: bleMaroon,
            foregroundColor: Colors.white,
            disabledBackgroundColor: blePinkChip,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: const Text('Use', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: bleTextMuted),
          tooltip: 'More',
          onSelected: (v) => v == 'edit' ? _edit(entry) : _delete(entry),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    );
  }
}
