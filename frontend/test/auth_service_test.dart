import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecoscrap/models/user_model.dart';
import 'package:ecoscrap/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService Unit & Session Tests', () {
    late AuthService auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      auth = AuthService();
      await auth.init();
    });

    test('Initial auth state is unauthenticated', () {
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(auth.currentRole, isEmpty);
    });

    test('UserModel role getters and attributes work correctly', () {
      final collector = UserModel(
        id: 'user-col-1',
        name: 'Murugan K.',
        phone: '9842100001',
        role: 'COLLECTOR',
        token: 'token_col_123',
        profileData: {
          'collector_code': 'COL-TN-019284',
          'trust_score': 94.5,
        },
      );

      expect(collector.isCollector, isTrue);
      expect(collector.isRecycler, isFalse);
      expect(collector.isAdmin, isFalse);
      expect(collector.collectorCode, equals('COL-TN-019284'));
      expect(collector.trustScore, equals(94.5));

      final recycler = UserModel(
        id: 'user-rec-1',
        name: 'GreenTech',
        phone: '9842100010',
        role: 'RECYCLER',
        token: 'token_rec_123',
        profileData: {
          'registration_no': 'CPCB-TN-REC-2024-8812',
          'org_name': 'GreenTech Solutions',
        },
      );

      expect(recycler.isRecycler, isTrue);
      expect(recycler.isCollector, isFalse);
      expect(recycler.registrationNo, equals('CPCB-TN-REC-2024-8812'));
      expect(recycler.orgName, equals('GreenTech Solutions'));

      final admin = UserModel(
        id: 'user-adm-1',
        name: 'Inspector Arumugam',
        phone: '9842100099',
        role: 'ADMIN',
        token: 'token_adm_123',
        profileData: {
          'officer_id': 'CPCB-TN-OFFICER-001',
        },
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.officerId, equals('CPCB-TN-OFFICER-001'));
    });

    test('Session restoration from SharedPreferences', () async {
      final userMap = {
        'id': 'restored-col-1',
        'name': 'Selvam R.',
        'phone': '9842100002',
        'email': 'selvam@ecoscrap.in',
        'role': 'COLLECTOR',
        'language': 'ta',
        'token': 'restored_token_abc',
        'profile': {
          'collector_code': 'COL-TN-019285',
          'trust_score': 91.0,
        },
      };

      SharedPreferences.setMockInitialValues({
        'ecoscrap_user_session': jsonEncode(userMap),
      });

      final newAuth = AuthService();
      await newAuth.init();

      expect(newAuth.isAuthenticated, isTrue);
      expect(newAuth.currentUser!.name, equals('Selvam R.'));
      expect(newAuth.currentUser!.role, equals('COLLECTOR'));
      expect(newAuth.currentUser!.collectorCode, equals('COL-TN-019285'));

      await newAuth.logout();
      expect(newAuth.isAuthenticated, isFalse);
      expect(newAuth.currentUser, isNull);
    });
  });
}
