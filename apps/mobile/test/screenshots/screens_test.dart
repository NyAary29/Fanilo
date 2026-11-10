// Captures d'écran des écrans principaux (données FICTIVES), pour revue
// visuelle. Ignoré sans `FANILO_SHOTS_DIR` :
//
//   flutter test test/screenshots \
//     --dart-define=FANILO_SHOTS_DIR=/chemin/sortie \
//     --dart-define=FANILO_FONTS_DIR=$FLUTTER_ROOT/bin/cache/artifacts/material_fonts
//
// Les polices Roboto et Material Icons du SDK Flutter sont chargées pour un
// rendu proche d'Android (sinon, les tests affichent des rectangles).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fanilo_mobile/data/local/database.dart';
import 'package:fanilo_mobile/domain/enums.dart';
import 'package:fanilo_mobile/ui/screens/beneficiary_detail_screen.dart';
import 'package:fanilo_mobile/ui/screens/home_screen.dart';
import 'package:fanilo_mobile/ui/screens/login_screen.dart';
import 'package:fanilo_mobile/ui/screens/registration_screen.dart';
import 'package:fanilo_mobile/ui/screens/visit_flow_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_env.dart';

const _dir = String.fromEnvironment('FANILO_SHOTS_DIR');
const _fonts = String.fromEnvironment('FANILO_FONTS_DIR');
const _shotKey = Key('shot');
const _today = '2026-11-09';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$_fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  const roboto = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
    'Roboto-Italic.ttf',
  ];
  await load('Roboto', roboto);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_dir).createSync(recursive: true);
    File('$_dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void _phone(WidgetTester tester, {double height = 851}) {
  tester.view.physicalSize = Size(393 * 2.75, height * 2.75);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

Future<UiEnv> _env(WidgetTester tester, {bool online = true}) async {
  final env = UiEnv(online: online, today: _today);
  await env.signIn();
  await env.cacheReferences(tester, contents: true);
  env.server.offline = true;
  await env.seed(tester, (store) async {
    await store.applyServer(SyncEntity.site, 'site-demo-1', 1, null,
        {'name': 'Bongolava', 'kind': 'community_zone', 'is_active': true});
    await store.applyServer(SyncEntity.site, 'site-csb', 1, null,
        {'name': 'CSB II Bongolava A', 'kind': 'csb', 'is_active': true});
    await seedPatient(store,
        id: 'b1',
        name: 'Rasoarivelo Marie',
        birthYear: 2002,
        lmpDate: '2026-08-05',
        visits: [(1, '2026-09-10', 'done'), (2, '2026-10-08', 'done'), (3, '2026-11-16', 'planned'), (4, '2026-12-14', 'planned')],
        openAlertId: 'a1');
    await seedPatient(store,
        id: 'b2',
        name: 'Andriamamonjy Lala',
        birthYear: 1999,
        lmpDate: '2026-05-01',
        visits: [(1, '2026-06-01', 'done'), (2, '2026-07-01', 'done'), (3, '2026-11-20', 'planned')]);
    await seedPatient(store,
        id: 'b3',
        name: 'Rakotomalala Hery',
        birthYear: 1996,
        lmpDate: '2026-03-10',
        visits: [(3, '2026-09-02', 'done'), (4, '2026-11-02', 'planned'), (5, '2026-12-01', 'planned')]);
    await seedPatient(store,
        id: 'b4',
        name: 'Razafindratsima Vero',
        birthYear: 2000,
        lmpDate: '2026-02-10',
        visits: [(4, '2026-10-12', 'done'), (5, '2026-11-12', 'planned')]);
    await seedPatient(store,
        id: 'b5',
        name: 'Solofo Fanja',
        birthYear: 2004,
        lmpDate: '2026-09-05',
        visits: [(1, '2026-10-20', 'missed'), (2, '2026-11-25', 'planned')]);
  });
  await tester.runAsync(
      () => env.db.writeState(SyncStateKeys.lastSyncAt, '2026-11-09T05:30:00Z'));
  return env;
}

void main() {
  final skip = _dir.isEmpty || _fonts.isEmpty;

  setUpAll(() async {
    if (!skip) await _loadFonts();
  });

  testWidgets('accueil, visites, alerter', (tester) async {
    _phone(tester, height: 1400);
    final env = await _env(tester);
    await tester.pumpWidget(env.wrap(const HomeScreen(), boundaryKey: _shotKey));
    await env.settle(tester);
    await _shot(tester, '01-accueil');

    await tester.tap(find.byKey(const Key('nav-visits')));
    await env.settle(tester);
    await _shot(tester, '02-mes-visites');

    await tester.tap(find.byKey(const Key('nav-alert')));
    await env.settle(tester);
    await tester.tap(find.byKey(const Key('sign-SIGN_DEMO_01')));
    await tester.pumpAndSettle();
    await _shot(tester, '03-alerter');
    await env.dispose(tester);
  }, skip: skip);

  testWidgets('alerter hors ligne', (tester) async {
    _phone(tester);
    final env = await _env(tester, online: false);
    await tester.pumpWidget(env.wrap(const HomeScreen(), boundaryKey: _shotKey));
    await env.settle(tester);
    await tester.tap(find.byKey(const Key('nav-alert')));
    await env.settle(tester);
    await _shot(tester, '04-alerter-hors-ligne');
    await env.dispose(tester);
  }, skip: skip);

  testWidgets('fiche patiente', (tester) async {
    _phone(tester, height: 1200);
    final env = await _env(tester);
    await tester.pumpWidget(env.wrap(const BeneficiaryDetailScreen(beneficiaryId: 'b1'),
        boundaryKey: _shotKey));
    await env.settle(tester);
    await _shot(tester, '05-fiche-suivi');
    await tester.tap(find.byKey(const Key('view-alert')));
    await env.settle(tester);
    await _shot(tester, '06-fiche-alertes');
    await tester.tap(find.byKey(const Key('tab-history')));
    await env.settle(tester);
    await _shot(tester, '07-fiche-historique');
    await env.dispose(tester);
  }, skip: skip);

  testWidgets('visite du jour', (tester) async {
    _phone(tester, height: 1700);
    final env = await _env(tester);
    await tester.pumpWidget(
        env.wrap(const VisitFlowScreen(beneficiaryId: 'b3'), boundaryKey: _shotKey));
    await env.settle(tester);
    await _shot(tester, '08-visite-debut');
    await tester.tap(find.byKey(const Key('visit-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('danger-no')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('advice-MSG_DEMO_INFO_ANC')));
    await tester.pumpAndSettle();
    await _shot(tester, '09-visite-remplie');
    await env.dispose(tester);
  }, skip: skip);

  testWidgets('connexion et enregistrement', (tester) async {
    _phone(tester);
    final env = await _env(tester);
    await tester.pumpWidget(env.wrap(const LoginScreen(), boundaryKey: _shotKey));
    await env.settle(tester);
    await _shot(tester, '10-connexion');
    await tester.pumpWidget(env.wrap(const RegistrationScreen(), boundaryKey: _shotKey));
    await env.settle(tester);
    await _shot(tester, '11-enregistrement');
    await env.dispose(tester);
  }, skip: skip);
}
