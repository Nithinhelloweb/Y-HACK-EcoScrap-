import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoscrap/models/voice_command.dart';
import 'package:ecoscrap/models/collection.dart';
import 'package:ecoscrap/voice/voice_state.dart';
import 'package:ecoscrap/voice/widgets/voice_status.dart';
import 'package:ecoscrap/voice/widgets/confirmation_card.dart';
import 'package:ecoscrap/voice/widgets/microphone_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceAssistant Model Unit Tests', () {
    test('VoiceEntityItem.fromJson parses correctly', () {
      final json = {
        'name': 'Laptop Motherboard',
        'normalized_type': 'PCB',
        'quantity': 3,
        'unit': 'pieces',
      };
      final item = VoiceEntityItem.fromJson(json);
      expect(item.name, 'Laptop Motherboard');
      expect(item.normalizedType, 'PCB');
      expect(item.quantity, 3.0);
      expect(item.unit, 'pieces');
    });

    test('VoiceCommandResult.fromJson parses full server response', () {
      final json = {
        'session_id': 'sess_12345',
        'intent': 'CREATE_COLLECTION',
        'detected_language': 'ta',
        'entities': {
          'items': [
            {'name': 'laptop', 'normalized_type': 'LAPTOP', 'quantity': 2, 'unit': 'units'},
            {'name': 'battery', 'normalized_type': 'BATTERY', 'quantity': 1, 'unit': 'units'},
          ],
          'weight_kg': 4.5,
        },
        'missing_fields': ['source_type'],
        'spoken_response': 'நான் 2 லேப்டாப்களை சேர்த்துள்ளேன்.',
        'action_executed': 'create_collection',
        'action_result': {'collection_id': 'col_999'},
        'requires_confirmation': true,
        'confirmation_prompt': 'Do you want to submit this draft?',
        'ui_payload': {'draft_id': 'col_999'},
      };

      final res = VoiceCommandResult.fromJson(json);
      expect(res.sessionId, 'sess_12345');
      expect(res.intent, 'CREATE_COLLECTION');
      expect(res.detectedLanguage, 'ta');
      expect(res.items.length, 2);
      expect(res.items.first.name, 'laptop');
      expect(res.items.first.quantity, 2.0);
      expect(res.weightKg, 4.5);
      expect(res.missingFields, contains('source_type'));
      expect(res.spokenResponse, 'நான் 2 லேப்டாப்களை சேர்த்துள்ளேன்.');
      expect(res.actionExecuted, 'create_collection');
      expect(res.actionResult?['collection_id'], 'col_999');
      expect(res.requiresConfirmation, isTrue);
      expect(res.confirmationPrompt, 'Do you want to submit this draft?');
    });

    test('VoiceSessionModel.fromJson parses ephemeral session tokens', () {
      final json = {
        'session_id': 'sess_rt_abc',
        'session_token': 'ecoscrap_rt_secret_token',
        'user_id': 'user_murugan_01',
        'collector_id': 'COL-TN-01',
        'language': 'ta',
        'input_mode': 'push_to_talk',
        'status': 'ACTIVE',
        'expires_at': '2026-09-11T12:00:00Z',
        'tool_manifest': [
          {'name': 'create_collection', 'description': 'Create collection draft'}
        ],
      };

      final session = VoiceSessionModel.fromJson(json);
      expect(session.sessionId, 'sess_rt_abc');
      expect(session.sessionToken, 'ecoscrap_rt_secret_token');
      expect(session.userId, 'user_murugan_01');
      expect(session.collectorId, 'COL-TN-01');
      expect(session.language, 'ta');
      expect(session.status, 'ACTIVE');
      expect(session.toolManifest.length, 1);
      expect(session.toolManifest.first['name'], 'create_collection');
    });

    test('CollectionModel and CollectionItemModel serialize and deserialize', () {
      final now = DateTime.now();
      final collection = CollectionModel(
        id: 'col_demo_1',
        collectionCode: 'COL-2026-0001',
        collectorId: 'user_murugan_01',
        sourceType: 'household',
        status: 'DRAFT',
        totalItemsCount: 3.0,
        notes: 'Collected from central bus stand',
        createdAt: now,
        items: [
          CollectionItemModel(
            id: 'item_1',
            name: 'CRT Monitor',
            normalizedType: 'CRT_MONITOR',
            quantity: 1.0,
            estimatedWeightKg: 8.5,
          ),
          CollectionItemModel(
            name: 'Copper Wire',
            normalizedType: 'COPPER_CABLE',
            quantity: 2.0,
            unit: 'kg',
            estimatedWeightKg: 2.0,
          ),
        ],
      );

      final json = collection.toJson();
      expect(json['id'], 'col_demo_1');
      expect(json['collection_code'], 'COL-2026-0001');
      expect((json['items'] as List).length, 2);

      final restored = CollectionModel.fromJson(json);
      expect(restored.id, collection.id);
      expect(restored.items.length, 2);
      expect(restored.items[0].name, 'CRT Monitor');
      expect(restored.items[1].unit, 'kg');
    });

    test('VoiceSessionState copyWith and VoiceStatus helpers', () {
      const state = VoiceSessionState();
      expect(state.status, VoiceStatus.idle);
      expect(state.detectedLanguage, 'en');
      expect(VoiceStatus.idle.displayName, 'IDLE');
      expect(VoiceStatus.listening.displayName, 'LISTENING');
      expect(VoiceStatus.processing.displayName, 'PROCESSING');
      expect(VoiceStatus.executing.displayName, 'EXECUTING');
      expect(VoiceStatus.speaking.displayName, 'SPEAKING');
      expect(VoiceStatus.error.displayName, 'ERROR');
      expect(VoiceStatus.offline.displayName, 'OFFLINE');

      final updated = state.copyWith(
        status: VoiceStatus.listening,
        detectedLanguage: 'hi',
        liveTranscription: 'दो लैपटॉप',
        audioLevel: 0.75,
      );

      expect(updated.status, VoiceStatus.listening);
      expect(updated.detectedLanguage, 'hi');
      expect(updated.liveTranscription, 'दो लैपटॉप');
      expect(updated.audioLevel, 0.75);
    });
  });

  group('VoiceAssistant Widget Tests', () {
    testWidgets('VoiceStatusPill displays correct status indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: VoiceStatusPill(status: VoiceStatus.listening),
            ),
          ),
        ),
      );

      expect(find.text('LISTENING'), findsOneWidget);
      expect(find.byIcon(Icons.hearing_rounded), findsOneWidget);
    });

    testWidgets('ConfirmationCard renders entities and triggers callbacks', (WidgetTester tester) async {
      bool confirmed = false;
      bool cancelled = false;

      final items = [
        VoiceEntityItem(name: 'Server RAM', normalizedType: 'RAM', quantity: 4),
        VoiceEntityItem(name: 'Lithium Battery', normalizedType: 'BATTERY', quantity: 2),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmationCard(
              items: items,
              weightKg: 3.2,
              requiresConfirmation: true,
              confirmationPrompt: 'Accept bid of ₹4,200 for this lot?',
              onConfirm: () => confirmed = true,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      expect(find.text('Confirmation Required'), findsOneWidget);
      expect(find.text('4 × Server RAM'), findsOneWidget);
      expect(find.text('2 × Lithium Battery'), findsOneWidget);
      expect(find.text('Estimated Weight: 3.2 kg'), findsOneWidget);
      expect(find.text('Accept bid of ₹4,200 for this lot?'), findsOneWidget);

      // Tap Confirm
      await tester.tap(find.text('Confirm'));
      expect(confirmed, isTrue);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      expect(cancelled, isTrue);
    });

    testWidgets('MicrophoneButton responds to user gestures', (WidgetTester tester) async {
      bool pressedDown = false;
      bool pressedUp = false;
      bool handsFreeTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MicrophoneButton(
                status: VoiceStatus.idle,
                isHandsFree: false,
                onPressDown: () => pressedDown = true,
                onPressUp: () => pressedUp = true,
                onTapHandsFree: () => handsFreeTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

      // Test push-to-talk press down and up
      final gesture = await tester.startGesture(tester.getCenter(find.byType(MicrophoneButton)));
      expect(pressedDown, isTrue);

      await gesture.up();
      expect(pressedUp, isTrue);
      expect(handsFreeTapped, isFalse);
    });
  });
}
