import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/widgets/partuturan_badge.dart';
import 'package:horas/domain/models/sub_ethnic.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/partuturan/partuturan_engine.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  late PartuturanRuleSet tobaRuleSet;
  late PartuturanEngine engineWithDraft;
  late PartuturanEngine engineProdNoDraft;

  setUpAll(() {
    final jsonString = File('assets/partuturan/toba.v0.json')
        .readAsStringSync();
    tobaRuleSet = PartuturanRuleSet.fromJsonString(jsonString);
    engineWithDraft = PartuturanEngine(
      ruleSetsBySubSuku: <String, PartuturanRuleSet>{'toba': tobaRuleSet},
      allowDraftRules: true,
    );
    engineProdNoDraft = PartuturanEngine(
      ruleSetsBySubSuku: <String, PartuturanRuleSet>{'toba': tobaRuleSet},
      allowDraftRules: false,
    );
  });

  group(
    'Bagian F - Mesin Partuturan Data-Driven (TAR-R5, TAR-R6, AC-03, AC-04)',
    () {
      test('AC-03: Pengguna Toba, target bermarga sama dengan marga ibunya, satu generasi di atas, tanpa jalur terkonfirmasi -> Kemungkinan: Tulang (bukan fakta)', () {
        final result = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Simanjuntak',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Sitorus',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Sitorus',
            targetGender: UserGender.male,
            generationInfo: GenerationInfo(
              delta: 1,
              source: GenerationSource.sundut,
            ),
          ),
        );

        expect(result.modeNetral, isFalse);
        expect(result.confidence, PartuturanConfidence.sedang);
        expect(result.istilah, 'Tulang');
        expect(result.displayBadgeText, 'Kemungkinan: Tulang');
        expect(result.displayBadgeText, isNot('Dia adalah Tulangmu'));
        expect(result.isEstimate, isTrue);
        expect(result.estimateLabel, AppStrings.termPerkiraan);
        expect(result.isDraftRule, isTrue);
      });

      test('AC-04: Sub-suku tanpa aturan tervalidasi (atau allowDraftRules=false saat validated=false) berjalan di mode netral tanpa badge, Semarga tetap aktif', () {
        // Sub-suku Karo (belum ada aturan)
        final karoRes = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Ginting',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Sembiring',
            subEthnic: SubEthnic.karo,
            targetMarga: 'Ginting',
            targetGender: UserGender.male,
            generationInfo: GenerationInfo(
              delta: 0,
              source: GenerationSource.sundut,
            ),
          ),
        );
        expect(karoRes.modeNetral, isTrue);
        expect(karoRes.displayBadgeText, isNull);
        expect(karoRes.isSemarga, isTrue);

        // Build prod (allowDraftRules: false) dengan toba.v0.json (validated: false) -> mode netral
        final prodDraftRes = engineProdNoDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Simanjuntak',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Sitorus',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Simanjuntak',
            targetGender: UserGender.male,
            generationInfo: GenerationInfo(
              delta: 0,
              source: GenerationSource.sundut,
            ),
          ),
        );
        expect(prodDraftRes.modeNetral, isTrue);
        expect(prodDraftRes.displayBadgeText, isNull);
        expect(prodDraftRes.isSemarga, isTrue);
      });

      test('Keyakinan naik ke Tinggi setelah klaim dikonfirmasi kedua pihak (TAR-R5, TAR-R7)', () {
        final result = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Simanjuntak',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Sitorus',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Sitorus',
            targetGender: UserGender.male,
            generationInfo: GenerationInfo(
              delta: 1,
              source: GenerationSource.sundut,
            ),
            confirmedKinshipTerm: 'Tulang',
          ),
        );

        expect(result.confidence, PartuturanConfidence.tinggi);
        expect(result.displayBadgeText, 'Dia adalah Tulangmu');
        expect(result.isEstimate, isFalse);
      });

      test('Data kurang (marga ibu kosong atau generasi tidak diketahui) menghasilkan tingkat Rendah dengan pertanyaan pelengkap', () {
        final noMotherMarga = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Simanjuntak',
            viewerGender: UserGender.male,
            subEthnic: SubEthnic.toba,
            targetMarga: 'Sitorus',
            targetGender: UserGender.male,
            generationInfo: GenerationInfo(
              delta: 1,
              source: GenerationSource.tahunLahir,
            ),
          ),
        );
        expect(noMotherMarga.confidence, PartuturanConfidence.rendah);
        expect(noMotherMarga.displayBadgeText, AppStrings.partuturanLowLabel);
        expect(noMotherMarga.pertanyaanPelengkap, isNotNull);
        expect(noMotherMarga.pertanyaanPelengkap, isNotEmpty);

        final unknownGen = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Simanjuntak',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Sitorus',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Sitorus',
            targetGender: UserGender.male,
            generationInfo: GenerationInfo.unknown(),
          ),
        );
        expect(unknownGen.confidence, PartuturanConfidence.rendah);
        expect(unknownGen.displayBadgeText, AppStrings.partuturanLowLabel);
        expect(unknownGen.pertanyaanPelengkap, isNotEmpty);
      });

      testWidgets(
        'PartuturanBadge dan SemargaLabel merender sesuai tingkat keyakinan dan mode netral',
        (tester) async {
          const highRes = PartuturanResult(
            confidence: PartuturanConfidence.tinggi,
            istilah: 'Tulang',
            penjelasanJalur: 'Terkonfirmasi',
            versiAturan: '0.1.0-draft',
            modeNetral: false,
            isDraftRule: true,
          );
          const medRes = PartuturanResult(
            confidence: PartuturanConfidence.sedang,
            istilah: 'Tulang',
            penjelasanJalur: 'Inferensi',
            versiAturan: '0.1.0-draft',
            modeNetral: false,
            isDraftRule: true,
          );
          const neutralRes = PartuturanResult(
            confidence: PartuturanConfidence.rendah,
            penjelasanJalur: '',
            versiAturan: 'neutral',
            modeNetral: true,
            isSemarga: true,
          );

          await pumpHorasWidget(
            tester,
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PartuturanBadge(result: highRes, showDraftIndicator: true),
                PartuturanBadge(result: medRes),
                PartuturanBadge(result: neutralRes),
                SemargaLabel(),
              ],
            ),
          );

          expect(find.text('Dia adalah Tulangmu'), findsOneWidget);
          expect(find.text('Kemungkinan: Tulang'), findsOneWidget);
          expect(
            find.text(AppStrings.partuturanDraftRuleBadge),
            findsOneWidget,
          );
          expect(find.text(AppStrings.semargaFullLabel), findsOneWidget);
        },
      );

      test('Tabel 9 Prioritas Rumus Panggilan (Situmorang & Boru Ibu Siregar: Parra, Anggi, Haha, Pariban, Periksa generasi, Bapa Uda, Bapa Tua, Namboru, Nantulang)', () {
        // Prioritas 1: Marga sama (Situmorang), laki-laki, selisih <= 5 tahun -> Parra
        final p1 = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Situmorang',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Siregar',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Situmorang',
            targetGender: UserGender.male,
            generationInfo: GenerationInfo(
              delta: 0,
              ageDifferenceYears: 3,
              source: GenerationSource.tahunLahir,
            ),
          ),
        );
        expect(p1.istilah, 'Parra');

        // Prioritas 2: Marga sama, laki-laki lebih muda > 5 tahun -> Anggi
        final p2 = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Situmorang',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Siregar',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Situmorang',
            targetGender: UserGender.male,
            generationInfo: GenerationInfo(
              delta: 0,
              ageDifferenceYears: -7,
              source: GenerationSource.tahunLahir,
            ),
          ),
        );
        expect(p2.istilah, 'Anggi');

        // Prioritas 3: Marga sama, laki-laki lebih tua > 5 tahun -> Haha
        final p3 = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Situmorang',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Siregar',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Situmorang',
            targetGender: UserGender.male,
            generationInfo: GenerationInfo(
              delta: 0,
              ageDifferenceYears: 8,
              source: GenerationSource.tahunLahir,
            ),
          ),
        );
        expect(p3.istilah, 'Haha');

        // Prioritas 4: Marga ibu sama (Siregar), perempuan, selisih umur <= 7 tahun -> Pariban
        final p4 = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Situmorang',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Siregar',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Siregar',
            targetGender: UserGender.female,
            targetMotherMarga: 'Siregar',
            generationInfo: GenerationInfo(
              delta: 0,
              ageDifferenceYears: 4,
              source: GenerationSource.tahunLahir,
            ),
          ),
        );
        expect(p4.istilah, 'Pariban');

        // Prioritas 5: Marga ibu sama (Siregar), perempuan, selisih umur > 7 tahun -> Periksa generasi dan silsilah
        final p5 = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Situmorang',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Siregar',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Nasution',
            targetGender: UserGender.female,
            targetMotherMarga: 'Siregar',
            generationInfo: GenerationInfo(
              delta: 0,
              ageDifferenceYears: 10,
              source: GenerationSource.tahunLahir,
            ),
          ),
        );
        expect(p5.istilah, 'Periksa generasi dan silsilah');

        // Prioritas 6: Adik laki-laki ayah -> Bapa Uda
        final p6 = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Situmorang',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Siregar',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Situmorang',
            targetGender: UserGender.male,
            specificBranch: 'adik_ayah',
            generationInfo: GenerationInfo(
              delta: 1,
              source: GenerationSource.sundut,
            ),
          ),
        );
        expect(p6.istilah, 'Bapa Uda');

        // Prioritas 7: Abang laki-laki ayah -> Bapa Tua
        final p7 = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Situmorang',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Siregar',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Situmorang',
            targetGender: UserGender.male,
            specificBranch: 'abang_ayah',
            generationInfo: GenerationInfo(
              delta: 1,
              source: GenerationSource.sundut,
            ),
          ),
        );
        expect(p7.istilah, 'Bapa Tua');

        // Prioritas 8: Saudara perempuan ayah -> Namboru
        final p8 = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Situmorang',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Siregar',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Situmorang',
            targetGender: UserGender.female,
            generationInfo: GenerationInfo(
              delta: 1,
              source: GenerationSource.sundut,
            ),
          ),
        );
        expect(p8.istilah, 'Namboru');

        // Prioritas 9: Istri saudara laki-laki ibu -> Nantulang
        final p9 = engineWithDraft.evaluate(
          const PartuturanEvaluationInput(
            viewerMarga: 'Situmorang',
            viewerGender: UserGender.male,
            viewerMotherMarga: 'Siregar',
            subEthnic: SubEthnic.toba,
            targetMarga: 'Siregar',
            targetGender: UserGender.female,
            specificBranch: 'istri_tulang',
            generationInfo: GenerationInfo(
              delta: 1,
              source: GenerationSource.sundut,
            ),
          ),
        );
        expect(p9.istilah, 'Nantulang');
      });
    },
  );
}
