import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/models/feedback_draft.dart';
import 'package:finance_ai_app/screens/profile/widgets/profile_sheet_frame.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

/// "Đánh giá ứng dụng" (T9 spec 3.10, M2): five large stars, suggestion chips that are joined into the comment, the
/// comment field and Send.
Future<void> showFeedbackSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FeedbackSheet(host: context),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.host});

  /// Where the result toast goes once the sheet is closed.
  final BuildContext host;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  static const int _maxStars = 5;
  static const double _starSize = 40;

  final TextEditingController _comment = TextEditingController();
  int _stars = _maxStars;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // The chips show whether they are in the comment, also after the user edits it by hand.
    _comment.addListener(_onCommentChanged);
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _onCommentChanged() => setState(() {});

  void _addChip(String chip) {
    final text = FeedbackDraft.addChip(_comment.text, chip);
    _comment.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final ok = await RemoteApiHelper.instance.submitAppReview(
      _stars,
      _comment.text.trim(),
    );
    // The user may have closed the sheet while it was sending: the result is still told on the page below.
    if (mounted) Navigator.pop(context);
    final host = widget.host;
    if (!host.mounted) return;
    final loc = host.loc;
    if (ok) {
      AppToast.success(host, loc.feedbackThanks);
    } else {
      AppToast.error(host, loc.feedbackFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final chips = [
      loc.feedbackChipEasy,
      loc.feedbackChipScan,
      loc.feedbackChipLooks,
      loc.feedbackChipMore,
    ];
    return ProfileSheetFrame(
      title: loc.feedbackTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= _maxStars; star++)
                IconButton(
                  tooltip: loc.feedbackStarLabel(star),
                  onPressed: _sending
                      ? null
                      : () => setState(() => _stars = star),
                  icon: Icon(
                    star <= _stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: _starSize,
                    color: star <= _stars
                        ? colors.primary
                        : colors.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in chips)
                _Chip(
                  label: chip,
                  selected: FeedbackDraft.hasChip(_comment.text, chip),
                  onTap: _sending ? null : () => _addChip(chip),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _comment,
            enabled: !_sending,
            maxLines: 3,
            style: const TextStyle(fontSize: AppTextSize.body),
            decoration: InputDecoration(
              hintText: loc.feedbackHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _sending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : Text(
                      loc.feedbackSubmit,
                      style: const TextStyle(
                        fontSize: AppTextSize.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primary : colors.primaryContainer,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.onPrimary : colors.primary,
              fontSize: AppTextSize.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
