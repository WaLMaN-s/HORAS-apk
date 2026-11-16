import 'package:flutter_test/flutter_test.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/domain/models/models.dart';

/// Kunci terlarang yang TIDAK BOLEH muncul pada DTO orang lain (SEK-R2, AC-07, Prompt 2 Bagian A).
const Set<String> _kForbiddenPrivacyKeys = <String>{
  'phone',
  'phonee164',
  'phonenumber',
  'nomorhp',
  'nohp',
  'telepon',
  'birthyear',
  'tahunlahir',
  'dateofbirth',
  'tanggallahir',
  'age',
  'usia',
  'exactage',
  'lat',
  'lng',
  'latitude',
  'longitude',
  'koordinat',
  'coordinates',
  'gps',
  'distancekm',
  'distancemeters',
  'jarakkm',
  'jarakpresisi',
};

void _expectNoForbiddenKeys(Object? jsonNode, {String path = 'root'}) {
  if (jsonNode is Map<Object?, Object?>) {
    for (final entry in jsonNode.entries) {
      final key = entry.key.toString();
      expect(
        _kForbiddenPrivacyKeys.contains(key.toLowerCase()),
        isFalse,
        reason: 'Forbidden privacy key "$key" found at $path.$key',
      );
      _expectNoForbiddenKeys(entry.value, path: '$path.$key');
    }
  } else if (jsonNode is List<Object?>) {
    for (var i = 0; i < jsonNode.length; i++) {
      _expectNoForbiddenKeys(jsonNode[i], path: '$path[$i]');
    }
  }
}

void main() {
  group('Bagian A - Privasi DTO Orang Lain (SEK-R2, AC-07)', () {
    late MockStore store;

    setUp(() {
      store = MockStore(
        appConfig: const AppConfig(
          env: AppEnvironment.dev,
          useMockBackend: true,
          allowDraftRules: true,
        ),
        enableNetworkLatency: false,
      );
    });

    test('PersonSummary dan seluruh DTO yang dilihat orang lain tidak pernah memuat kunci terlarang', () {
      final viewer = store.usersById['u-01']!;
      for (final target in store.usersById.values) {
        if (target.id == viewer.id) continue;
        final summary = store.toPersonSummary(target, viewer: viewer);
        final json = summary.toJson();
        _expectNoForbiddenKeys(json, path: 'PersonSummary(${target.id})');
        expect(
          json['proximity'],
          anyOf(
            AreaProximity.diKotamu.jsonCode,
            AreaProximity.diKecamatanmu.jsonCode,
          ),
        );
      }

      for (final post in store.posts) {
        _expectNoForbiddenKeys(post.toJson(), path: 'Post(${post.id})');
      }
      for (final cmt in store.comments) {
        _expectNoForbiddenKeys(cmt.toJson(), path: 'Comment(${cmt.id})');
      }
      for (final conn in store.connections) {
        _expectNoForbiddenKeys(conn.toJson(), path: 'Connection(${conn.id})');
      }
      for (final creq in store.connectionRequests) {
        _expectNoForbiddenKeys(
          creq.toJson(),
          path: 'ConnectionRequest(${creq.id})',
        );
      }
      for (final mem in store.memberships) {
        _expectNoForbiddenKeys(mem.toJson(), path: 'Membership(${mem.id})');
      }
      for (final ses in store.sessions) {
        _expectNoForbiddenKeys(ses.toJson(), path: 'PlaySession(${ses.id})');
      }
      for (final part in store.participants) {
        _expectNoForbiddenKeys(part.toJson(), path: 'Participant(${part.id})');
      }
      for (final ps in store.paymentShares) {
        _expectNoForbiddenKeys(ps.toJson(), path: 'PaymentShare(${ps.id})');
      }
      for (final conv in store.conversations) {
        _expectNoForbiddenKeys(conv.toJson(), path: 'Conversation(${conv.id})');
      }
    });
  });
}
