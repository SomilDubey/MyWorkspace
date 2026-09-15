import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pocket_guard/models/expense_account_filter.dart';
import 'package:pocket_guard/openai/openai_config.dart';
import 'package:pocket_guard/theme.dart';
import 'package:pocket_guard/utils/currency_formatter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceExpenseAgentSheet extends StatefulWidget {
  final String userId;
  final BuildContext rootContext;

  // UI-only privacy states (never persisted / never sent to Firestore)
  final bool personalHidden;
  final bool businessHidden;

  final ExpenseAccountFilter accountContext;

  const VoiceExpenseAgentSheet({
    super.key,
    required this.userId,
    required this.rootContext,
    required this.personalHidden,
    required this.businessHidden,
    required this.accountContext,
  });

  @override
  State<VoiceExpenseAgentSheet> createState() => _VoiceExpenseAgentSheetState();
}

class _VoiceExpenseAgentSheetState extends State<VoiceExpenseAgentSheet> {
  final _speech = stt.SpeechToText();
  final _nlp = OpenAIExpenseNlpService();

  bool _isSpeechAvailable = false;
  bool _isListening = false;
  bool _isParsing = false;
  bool _isSaving = false;

  String _transcript = '';
  OpenAIExpenseExtraction _extraction = OpenAIExpenseExtraction.empty();
  String _accountType = '';
  bool _accountTypeExplicitlyChosen = false;
  String? _error;

  String? get _fixedAccountType => widget.accountContext.fixedAccountType;

  String? get _resolvedAccountType {
    final fixed = _fixedAccountType;
    if (fixed != null) return fixed;
    if (_accountType.trim().isEmpty) return null;
    return _accountType;
  }

  bool get _needsAccountChoice => widget.accountContext == ExpenseAccountFilter.all && _extraction.isUsable && _extraction.accountType == null && !_accountTypeExplicitlyChosen;

  bool get _canConfirm => _extraction.isUsable && !_needsAccountChoice;

  bool _shouldHideFor(String accountType) {
    final key = accountType.toLowerCase();
    if (key == 'business') return widget.businessHidden;
    return widget.personalHidden;
  }

  bool get _hideForConfirmCard {
    final acct = _resolvedAccountType;
    if (acct == null) return widget.personalHidden || widget.businessHidden;
    return _shouldHideFor(acct);
  }

  @override
  void initState() {
    super.initState();
    final fixed = _fixedAccountType;
    if (fixed != null) {
      _accountType = fixed;
      _accountTypeExplicitlyChosen = true;
    } else if (widget.accountContext == ExpenseAccountFilter.all) {
      _accountType = 'personal';
      _accountTypeExplicitlyChosen = true;
    }
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onError: (err) => debugPrint('Speech error: $err'),
        onStatus: (status) => debugPrint('Speech status: $status'),
      );
      if (!mounted) return;
      setState(() {
        _isSpeechAvailable = ok;
        if (!ok) _error = 'Microphone permission denied or speech not supported on this device.';
      });
    } catch (e, st) {
      debugPrint('Speech init failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _isSpeechAvailable = false;
        _error = 'Could not initialize voice input. Please check microphone permission and try again.';
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      if (_transcript.trim().isNotEmpty) {
        await _parseTranscript();
      }
      return;
    }

    setState(() {
      _error = null;
      _transcript = '';
      _extraction = OpenAIExpenseExtraction.empty();
      final fixed = _fixedAccountType;
      if (fixed != null) {
        _accountType = fixed;
        _accountTypeExplicitlyChosen = true;
      } else if (widget.accountContext == ExpenseAccountFilter.all) {
        _accountType = _accountType.isEmpty ? 'personal' : _accountType;
        _accountTypeExplicitlyChosen = true;
      }
    });

    if (!_isSpeechAvailable) {
      setState(() => _error = 'Microphone permission denied or speech not supported.');
      return;
    }

    bool didStart = false;
    try {
      didStart = await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 3),
          cancelOnError: true,
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
        ),
        onResult: (result) {
          if (!mounted) return;

          setState(() => _transcript = result.recognizedWords.trim());

          if (result.finalResult) {
            Future.microtask(() async {
              if (!mounted) return;
              final transcript = _transcript.trim();
              if (transcript.isEmpty) return;
              setState(() => _isListening = false);
              await _speech.stop();
              await _parseTranscript();
            });
          }
        },
      );
    } catch (e, st) {
      debugPrint('Speech listen failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _error = 'Could not start microphone. Please allow microphone permission and try again.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isListening = didStart;
      if (!didStart) _error = 'Could not start microphone. Please allow microphone permission and try again.';
    });
  }

  Future<void> _parseTranscript() async {
    final text = _transcript.trim();
    if (text.isEmpty) {
      setState(() => _error = 'I didn\'t catch that. Try again.');
      return;
    }

    setState(() {
      _isParsing = true;
      _error = null;
      _extraction = OpenAIExpenseExtraction.empty();
    });

    try {
      final extraction = await _nlp.extractExpense(utterance: text, nowLocal: DateTime.now());
      if (!mounted) return;

      setState(() {
        _extraction = extraction;
        final fixed = _fixedAccountType;
        if (fixed != null) {
          _accountType = fixed;
          _accountTypeExplicitlyChosen = true;
        } else if (widget.accountContext == ExpenseAccountFilter.all) {
          final inferred = extraction.accountType;
          if (inferred != null && inferred.isNotEmpty) {
            _accountType = inferred;
            _accountTypeExplicitlyChosen = true;
          }
        }

        if (!extraction.isUsable) {
          _error = 'Couldn\'t confidently extract amount + category. Try saying: "Food 120 paneer".';
        } else if (_needsAccountChoice) {
          _error = 'Personal or Business?';
        }
      });
    } catch (e, st) {
      debugPrint('Parse transcript failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() => _error = 'AI parsing failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  Future<void> _saveExtractedExpense() async {
    if (_isSaving) return;

    final messenger = ScaffoldMessenger.of(widget.rootContext);

    if (!_extraction.isUsable) {
      messenger.showSnackBar(const SnackBar(content: Text('Please try again — missing amount or category.')));
      return;
    }

    final accountType = _resolvedAccountType;
    if (accountType == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Personal or Business?')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Not logged in');

      final date = _extraction.date ?? DateTime.now();
      final dateOnly = DateTime(date.year, date.month, date.day);

      final data = <String, dynamic>{
        'amount': _extraction.amount,
        'category': _extraction.category,
        'accountType': accountType,
        'source': 'ai',
        'date': Timestamp.fromDate(dateOnly),
        'createdAt': FieldValue.serverTimestamp(),
      };
      final note = _extraction.note?.trim();
      if (note != null && note.isNotEmpty) data['note'] = note;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('expenses').add(data);

      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Expense added successfully')));
    } catch (e, st) {
      debugPrint('Voice save expense failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Failed to save expense. Please try again.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _reset() {
    setState(() {
      _error = null;
      _transcript = '';
      _extraction = OpenAIExpenseExtraction.empty();
      final fixed = _fixedAccountType;
      if (fixed != null) {
        _accountType = fixed;
        _accountTypeExplicitlyChosen = true;
      } else if (widget.accountContext == ExpenseAccountFilter.all) {
        _accountType = 'personal';
        _accountTypeExplicitlyChosen = true;
      } else {
        _accountType = '';
        _accountTypeExplicitlyChosen = false;
      }
    });
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(999)),
                ),
              ),
              Row(
                children: [
                  Expanded(child: Text('Voice Expense', style: context.textStyles.headlineSmall?.semiBold)),
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary), tooltip: 'Close'),
                ],
              ),
              const SizedBox(height: 10),
              Text('Try: "Add 20 rupees to snacks" • "Business ke liye 180 travel" • "15 chai"', style: context.textStyles.bodyMedium?.withColor(AppColors.textSecondary)),
              const SizedBox(height: 16),
              if (widget.accountContext == ExpenseAccountFilter.all) ...[
                Text('Account Type', style: context.textStyles.titleMedium?.semiBold),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'personal', label: Text('Personal')),
                    ButtonSegment(value: 'business', label: Text('Business')),
                  ],
                  selected: _accountType.isEmpty ? <String>{'personal'} : <String>{_accountType},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    if (s.isEmpty) return;
                    setState(() {
                      _accountType = s.first;
                      _accountTypeExplicitlyChosen = true;
                      if (_extraction.isUsable) _error = null;
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) return AppColors.credTeal;
                      return Theme.of(context).colorScheme.surfaceContainerHighest;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) return AppColors.darkBackground;
                      return AppColors.textPrimary;
                    }),
                    side: WidgetStateProperty.all(BorderSide(color: Colors.white.withValues(alpha: 0.10))),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              _VoiceMicButton(isEnabled: _isSpeechAvailable && !_isParsing && !_isSaving, isListening: _isListening, onPressed: _toggleListening),
              const SizedBox(height: 16),
              _TranscriptCard(transcript: _transcript, isBusy: _isParsing),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _InlineError(text: _error!),
              ],
              if (_canConfirm) ...[
                const SizedBox(height: 14),
                _CompactConfirmCard(extraction: _extraction, accountType: _resolvedAccountType!, hideAmounts: _hideForConfirmCard),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _reset,
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary),
                        child: const Text('No'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveExtractedExpense,
                        child: Text(_isSaving ? 'Saving…' : 'Yes'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceMicButton extends StatelessWidget {
  final bool isEnabled;
  final bool isListening;
  final VoidCallback onPressed;

  const _VoiceMicButton({required this.isEnabled, required this.isListening, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final baseColor = isListening ? AppColors.lossRed : AppColors.credTeal;
    final bg = baseColor.withValues(alpha: isEnabled ? 1.0 : 0.35);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: baseColor.withValues(alpha: isListening ? 0.65 : 0.25), width: 1.2),
      ),
      child: ElevatedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: AppColors.darkBackground,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        icon: Icon(isListening ? Icons.stop_rounded : Icons.mic_rounded, color: AppColors.darkBackground),
        label: Text(isListening ? 'Stop listening' : 'Start listening'),
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  final String transcript;
  final bool isBusy;

  const _TranscriptCard({required this.transcript, required this.isBusy});

  @override
  Widget build(BuildContext context) {
    final text = transcript.trim().isEmpty ? 'Transcript will appear here…' : transcript.trim();

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isBusy ? Icons.auto_awesome_rounded : Icons.record_voice_over_rounded, color: AppColors.credTeal),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: context.textStyles.bodyMedium?.semiBold, softWrap: true)),
        ],
      ),
    );
  }
}

class _CompactConfirmCard extends StatelessWidget {
  final OpenAIExpenseExtraction extraction;
  final String accountType;
  final bool hideAmounts;

  const _CompactConfirmCard({required this.extraction, required this.accountType, required this.hideAmounts});

  @override
  Widget build(BuildContext context) {
    final amountText = hideAmounts ? '₹••••' : CurrencyFormatter.format(extraction.amount ?? 0);
    final acct = accountType == 'business' ? 'Business' : 'Personal';
    final category = extraction.category ?? '—';

    final note = extraction.note?.trim();
    final noteSuffix = (note == null || note.isEmpty) ? '' : ' • ${note[0].toUpperCase()}${note.substring(1)}';

    final date = extraction.date ?? DateTime.now();
    final dateText = DateFormat('d MMM').format(date);

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: AppColors.credTeal.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.credTeal.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add $amountText to $acct → $category?$noteSuffix', style: context.textStyles.titleMedium?.semiBold),
          const SizedBox(height: 8),
          Text('Date: $dateText', style: context.textStyles.bodySmall?.withColor(AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String text;

  const _InlineError({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingSm,
      decoration: BoxDecoration(
        color: AppColors.lossRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.lossRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.lossRed, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: context.textStyles.bodySmall?.withColor(AppColors.lossRed))),
        ],
      ),
    );
  }
}
