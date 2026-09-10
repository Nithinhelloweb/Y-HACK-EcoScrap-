import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../storage/sync_queue.dart';
import '../theme/app_theme.dart';
import 'audio_manager.dart';
import 'realtime_voice_service.dart';
import 'voice_controller.dart';
import 'voice_state.dart';
import 'widgets/confirmation_card.dart';
import 'widgets/microphone_button.dart';
import 'widgets/transcription_view.dart';
import 'widgets/voice_status.dart';
import 'widgets/voice_waveform.dart';
import '../widgets/ecoscrap_logo.dart';

class VoiceScreen extends StatefulWidget {
  final ApiService apiService;
  final String initialLanguage;

  const VoiceScreen({
    super.key,
    required this.apiService,
    this.initialLanguage = 'en',
  });

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  late VoiceController _controller;
  final TextEditingController _textInputController = TextEditingController();
  bool _showTextInput = false;

  @override
  void initState() {
    super.initState();
    final audioMgr = AudioManager();
    final voiceSvc = RealtimeVoiceService(baseUrl: widget.apiService.baseUrl);
    final syncQ = SyncQueue()..loadQueue();

    _controller = VoiceController(
      voiceService: voiceSvc,
      audioManager: audioMgr,
      syncQueue: syncQ,
    );

    _controller.initSession(language: widget.initialLanguage);
  }

  @override
  void dispose() {
    _controller.dispose();
    _textInputController.dispose();
    super.dispose();
  }

  void _sendManualText(String text) {
    if (text.trim().isEmpty) return;
    _controller.processSpokenText(text.trim());
    _textInputController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;

        return Scaffold(
          backgroundColor: AppTheme.getBg(context),
          appBar: AppBar(
            backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                const EcoScrapLogo(size: 32, borderRadius: 8),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'EcoScrap Voice Assistant',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                      const Text(
                        'Multilingual • Groq AI & Neural Speech',
                        style: TextStyle(fontSize: 10, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Language Selector Dropdown
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.collectorColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.translate_rounded, size: 14, color: AppTheme.collectorColor),
                      const SizedBox(width: 4),
                      Text(
                        _controller.selectedLanguage.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.collectorColor),
                      ),
                    ],
                  ),
                ),
                onSelected: (lang) => _controller.setLanguage(lang),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'en', child: Text('English')),
                  const PopupMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)')),
                  const PopupMenuItem(value: 'hi', child: Text('हिंदी (Hindi)')),
                ],
              ),
              // Hands-Free Mode Toggle
              IconButton(
                icon: Icon(
                  state.isHandsFree ? Icons.record_voice_over_rounded : Icons.touch_app_rounded,
                  color: state.isHandsFree ? AppTheme.alertAmber : AppTheme.getTextSecondary(context),
                  size: 20,
                ),
                tooltip: state.isHandsFree ? 'Hands-Free Mode ON' : 'Push-To-Talk Mode ON',
                onPressed: () => _controller.toggleHandsFree(!state.isHandsFree),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Top Status bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      VoiceStatusPill(status: state.status),
                      Text(
                        state.isHandsFree ? 'Mode: Hands-Free' : 'Mode: Push-To-Talk',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Central Area: Waveform, Transcription, Confirmation Cards
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Dynamic Voice Waveform
                      VoiceWaveform(
                        status: state.status,
                        audioLevel: state.audioLevel,
                      ),
                      const SizedBox(height: 14),

                      // Live Transcription & Assistant Response
                      TranscriptionView(
                        userTranscript: state.liveTranscription,
                        assistantResponse: state.assistantResponse,
                        detectedLanguage: state.detectedLanguage,
                      ),

                      // Structured Confirmation / Entities Card
                      ConfirmationCard(
                        items: state.detectedEntities,
                        weightKg: state.weightKg,
                        executedAction: state.executedAction,
                        executedResult: state.executedResult,
                        requiresConfirmation: state.requiresConfirmation,
                        confirmationPrompt: state.confirmationPrompt,
                        onConfirm: () => _controller.confirmAction(),
                        onCancel: () => _controller.cancelAction(),
                      ),

                      const SizedBox(height: 20),

                      // Instant Test Prompt Chips
                      Row(
                        children: [
                          Expanded(child: Divider(color: AppTheme.getBorder(context))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'Sample Voice Prompts',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.getTextMuted(context)),
                            ),
                          ),
                          Expanded(child: Divider(color: AppTheme.getBorder(context))),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPromptChip(
                            label: 'English: "3 laptops & 2 bags copper wire"',
                            text: 'I have three old laptops and two bags of copper wire',
                            lang: 'en',
                          ),
                          _buildPromptChip(
                            label: 'Tamil: "இரண்டு பழைய லேப்டாப்"',
                            text: 'என்னிடம் இரண்டு பழைய லேப்டாப் இருக்கு',
                            lang: 'ta',
                          ),
                          _buildPromptChip(
                            label: 'Hindi: "तीन कंप्यूटर हैं"',
                            text: 'मेरे पास तीन कंप्यूटर और तांबे का तार है',
                            lang: 'hi',
                          ),
                          _buildPromptChip(
                            label: 'Pricing: "Highest price offer?"',
                            text: 'Who is offering the highest price?',
                            lang: 'en',
                          ),
                          _buildPromptChip(
                            label: 'Safety: "Can I break open battery?"',
                            text: 'Can I break open this battery to extract cells?',
                            lang: 'en',
                          ),
                          _buildPromptChip(
                            label: 'Payment: "Where is my payment?"',
                            text: 'Where is my payment and settlement reference?',
                            lang: 'en',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Bottom Action Area: Microphone Button & Guidance
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    border: Border(top: BorderSide(color: isDark ? AppTheme.borderSubtle : AppTheme.borderLight)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status guidance caption
                      Text(
                        state.isHandsFree
                            ? (state.status == VoiceStatus.listening ? 'Tap mic to stop listening' : 'Tap mic to talk hands-free')
                            : (state.status == VoiceStatus.listening ? 'Release mic to process' : 'Hold mic to speak'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: state.status == VoiceStatus.listening ? AppTheme.alertAmber : AppTheme.getTextSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Large Central Mic Button
                      MicrophoneButton(
                        status: state.status,
                        isHandsFree: state.isHandsFree,
                        onPressDown: () => _controller.onMicPress(),
                        onPressUp: () => _controller.onMicRelease(),
                        onTapHandsFree: () {
                          if (state.status == VoiceStatus.listening) {
                            _controller.onMicRelease();
                          } else {
                            _controller.onMicPress();
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // Optional Text Input Box Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            icon: Icon(
                              _showTextInput ? Icons.keyboard_hide_rounded : Icons.keyboard_rounded,
                              size: 16,
                              color: AppTheme.getTextSecondary(context),
                            ),
                            label: Text(
                              _showTextInput ? 'Hide keyboard' : 'Type prompt instead',
                              style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context)),
                            ),
                            onPressed: () => setState(() => _showTextInput = !_showTextInput),
                          ),
                        ],
                      ),

                      if (_showTextInput) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textInputController,
                                decoration: InputDecoration(
                                  hintText: 'Type scrap query in EN, TA, or HI...',
                                  hintStyle: TextStyle(fontSize: 12, color: AppTheme.getTextMuted(context)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  filled: true,
                                  fillColor: isDark ? AppTheme.bgDark : const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: _sendManualText,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send_rounded, color: AppTheme.collectorColor),
                              onPressed: () => _sendManualText(_textInputController.text),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromptChip({
    required String label,
    required String text,
    required String lang,
  }) {
    final isDark = AppTheme.isDark(context);

    return InkWell(
      onTap: () {
        _controller.setLanguage(lang);
        _controller.processSpokenText(text);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.collectorColor.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.collectorColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.record_voice_over_rounded, size: 13, color: AppTheme.collectorColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppTheme.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
