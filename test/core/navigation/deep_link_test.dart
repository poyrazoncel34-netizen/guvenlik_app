// MP-26-008 -- one validated destination model for every external entry.
//
// The threat this covers is not "a broken link"; it is a link that reaches a
// screen ahead of a gate. In a duress model whose entire auth story is a local
// PIN, a deep link that lands on the contact list before the unlock screen is a
// security defect, not a navigation bug. So the assertions below are about
// REFUSAL and ORDERING at least as much as about routing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/feature_access_matrix.dart';
import 'package:guvenlik_app/core/navigation/app_destination.dart';
import 'package:guvenlik_app/core/navigation/deep_link_channel.dart';
import 'package:guvenlik_app/core/navigation/deep_link_parser.dart';
import 'package:guvenlik_app/core/navigation/pending_destination_service.dart';

DeepLinkResult parse(String raw) => DeepLinkParser.parse(Uri.tryParse(raw));

void main() {
  group('accepted links', () {
    test('every destination round-trips through build and parse', () {
      for (final destination in AppDestination.values) {
        final uri = DeepLinkParser.build(destination);
        final result = DeepLinkParser.parse(uri);
        expect(result, isA<DeepLinkAccepted>(),
            reason: '${destination.slug} did not survive its own builder');
        expect((result as DeepLinkAccepted).destination, destination);
      }
    });

    test('the bare host is the front door', () {
      expect(parse('korubeni://open'),
          const DeepLinkAccepted(AppDestination.home));
      expect(parse('korubeni://open/'),
          const DeepLinkAccepted(AppDestination.home));
    });

    test('an allowlisted parameter survives with its value', () {
      final result = parse('korubeni://open/timeline?event=evt_123-abc');
      expect(result, isA<DeepLinkAccepted>());
      expect((result as DeepLinkAccepted).parameters,
          <String, String>{'event': 'evt_123-abc'});
    });

    test('slugs are distinct, so no two destinations collide', () {
      final slugs = AppDestination.values.map((d) => d.slug).toList();
      expect(slugs.toSet(), hasLength(slugs.length));
    });
  });

  group('rejected links -- the whole hostile-input surface', () {
    test('a foreign scheme is refused', () {
      for (final raw in <String>[
        'https://poyrazoncel34-netizen.github.io/guvenlik_app',
        'http://open/home',
        'korubenix://open/home',
        'javascript:alert(1)',
        'file:///etc/passwd',
      ]) {
        final result = parse(raw);
        expect(result, isA<DeepLinkRejected>(), reason: raw);
        expect((result as DeepLinkRejected).reason,
            DeepLinkRejection.foreignUri, reason: raw);
      }
    });

    test('a foreign HOST on our own scheme is refused', () {
      final result = parse('korubeni://evil/home');
      expect((result as DeepLinkRejected).reason, DeepLinkRejection.foreignUri);
    });

    test('an unknown destination is refused', () {
      for (final raw in <String>[
        'korubeni://open/admin',
        'korubeni://open/panic',
        'korubeni://open/dial',
        'korubeni://open/HOME',
      ]) {
        final result = parse(raw);
        expect(result, isA<DeepLinkRejected>(), reason: raw);
        expect((result as DeepLinkRejected).reason,
            DeepLinkRejection.unknownDestination, reason: raw);
      }
    });

    test('there is NO destination that arms, dials, cancels or unlocks', () {
      const forbidden = <String>[
        'arm', 'dial', 'call', 'panic', 'sos', 'cancel', 'unlock', 'pin',
        'trigger', 'emergency',
      ];
      for (final destination in AppDestination.values) {
        for (final word in forbidden) {
          expect(destination.slug.toLowerCase().contains(word), isFalse,
              reason: '${destination.slug} sounds like a safety ACTION; an '
                  'external link may show a surface, never perform one');
        }
      }
    });

    test('a path deeper than one segment is refused', () {
      final deep = parse('korubeni://open/home/extra');
      expect((deep as DeepLinkRejected).reason, DeepLinkRejection.pathTooDeep);
    });

    test('an unexpected parameter is refused, not ignored', () {
      final a = parse('korubeni://open/home?admin=1');
      expect((a as DeepLinkRejected).reason, DeepLinkRejection.unknownParameter);
      final b = parse('korubeni://open/timeline?event=a&extra=b');
      expect((b as DeepLinkRejected).reason, DeepLinkRejection.unknownParameter);
    });

    test('a malformed parameter VALUE is refused', () {
      for (final value in <String>[
        '', "a'; DROP TABLE activity_events;--", '../../etc/passwd',
        '<script>', 'a b',
      ]) {
        final uri = Uri(
          scheme: 'korubeni',
          host: 'open',
          pathSegments: <String>['timeline'],
          queryParameters: <String, String>{'event': value},
        );
        expect(DeepLinkParser.parse(uri), isA<DeepLinkRejected>(),
            reason: 'value=$value');
      }
      final tooLong = 'a' * 65;
      final result = parse('korubeni://open/timeline?event=$tooLong');
      expect((result as DeepLinkRejected).reason,
          DeepLinkRejection.malformedParameter);
    });

    test('an oversized URI is refused before it is parsed', () {
      final huge = 'korubeni://open/home?event=${'x' * 600}';
      expect((parse(huge) as DeepLinkRejected).reason,
          DeepLinkRejection.oversized);
    });

    test('a null or unparseable URI is refused without throwing', () {
      expect(DeepLinkParser.parse(null), isA<DeepLinkRejected>());
      expect(DeepLinkChannel.parseRaw(null), isNull);
      expect(DeepLinkChannel.parseRaw(''), isNull);
      expect(DeepLinkChannel.parseRaw('x' * 600), isNull);
    });

    test('a rejection never records the raw URI', () {
      final rejected =
          parse('https://example.com/?token=secret') as DeepLinkRejected;
      expect(rejected.detail, isNot(contains('secret')));
      expect(rejected.toString(), isNot(contains('secret')));
    });
  });

  group('the gate model', () {
    test('every gated destination names the SAME feature the in-app tap uses',
        () {
      expect(AppDestination.safetyTimeline.gatedFeature,
          PremiumFeature.timeline);
      expect(AppDestination.checkIn.gatedFeature, PremiumFeature.checkIn);
      expect(AppDestination.contacts.gatedFeature, PremiumFeature.contacts);
      expect(AppDestination.home.gatedFeature, isNull);
    });

    test('the parser cannot navigate: it has no Navigator or context', () {
      final src = File('lib/core/navigation/deep_link_parser.dart')
          .readAsStringSync();
      for (final forbidden in <String>[
        'Navigator', 'BuildContext', 'runApp', 'SharedPreferences',
      ]) {
        expect(src, isNot(contains(forbidden)),
            reason: 'the parser must stay a pure function over a Uri');
      }
    });

    test('the router asks SubscriptionGate, not its own opinion', () {
      final src = File('lib/core/navigation/destination_router.dart')
          .readAsStringSync();
      expect(src, contains('SubscriptionGate.ensureAccess'));
      for (final bypass in <String>['isPro', 'canUse', 'entitlementDecision']) {
        expect(src, isNot(contains(bypass)),
            reason: 'a link must not develop a second opinion about access');
      }
    });
  });

  group('parking, ordering and bursts', () {
    late PendingDestinationService service;

    setUp(() => service = PendingDestinationService());

    test('a valid link is PARKED, never navigated by the link layer', () {
      final result = service.submitUri(Uri.parse('korubeni://open/settings'));
      expect(result, isA<DeepLinkAccepted>());
      expect(service.hasPending, isTrue);
      expect(service.pending?.destination, AppDestination.settings);
      expect(service.pendingSource, ExternalEntrySource.deepLink);
    });

    test('a rejected link parks nothing and is recorded', () {
      service.submitUri(Uri.parse('korubeni://open/admin'));
      expect(service.hasPending, isFalse);
      expect(service.rejections, hasLength(1));
      expect(service.rejections.single.reason,
          DeepLinkRejection.unknownDestination);
    });

    test('consume is single-shot: a destination cannot re-fire on rebuild', () {
      service.submitUri(Uri.parse('korubeni://open/map'));
      expect(service.consume()?.destination, AppDestination.map);
      expect(service.consume(), isNull);
      expect(service.hasPending, isFalse);
    });

    test('DUPLICATE links collapse to one destination', () {
      for (var i = 0; i < 5; i++) {
        service.submitUri(Uri.parse('korubeni://open/settings'));
      }
      expect(service.consume()?.destination, AppDestination.settings);
      expect(service.consume(), isNull);
    });

    test('RAPID differing links leave the latest, not a queue', () {
      service.submitUri(Uri.parse('korubeni://open/home'));
      service.submitUri(Uri.parse('korubeni://open/map'));
      service.submitUri(Uri.parse('korubeni://open/settings'));
      expect(service.consume()?.destination, AppDestination.settings);
      expect(service.consume(), isNull,
          reason: 'a queue would fire three navigations after unlock');
    });

    test('a hostile burst of rejections stays bounded', () {
      for (var i = 0; i < 200; i++) {
        service.submitUri(Uri.parse('korubeni://open/bad$i'));
      }
      expect(service.rejections,
          hasLength(PendingDestinationService.maxRecordedRejections));
      expect(service.hasPending, isFalse);
    });

    test('clear drops everything, so a reset cannot leave a destination', () {
      service.submitUri(Uri.parse('korubeni://open/contacts'));
      service.submitUri(Uri.parse('korubeni://open/nope'));
      service.clear();
      expect(service.hasPending, isFalse);
      expect(service.rejections, isEmpty);
    });

    test('a notification submits through the SAME park', () {
      service.submitDestination(
        AppDestination.safetyTimeline,
        parameters: <String, String>{'event': 'evt_9'},
        source: ExternalEntrySource.notification,
      );
      expect(service.pending?.destination, AppDestination.safetyTimeline);
      expect(service.pending?.parameters['event'], 'evt_9');
      expect(service.pendingSource, ExternalEntrySource.notification);
    });

    test('a notification with a hostile parameter is refused too', () {
      service.submitDestination(
        AppDestination.safetyTimeline,
        parameters: <String, String>{'event': 'bad value'},
      );
      expect(service.hasPending, isFalse);
      expect(service.rejections.single.reason,
          DeepLinkRejection.malformedParameter);
    });
  });

  group('gate ordering is a property of construction, not a conditional', () {
    test('only MainNavigation consumes a parked destination', () {
      final consumers = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('pending_destination_service.dart')) continue;
        if (entity
            .readAsStringSync()
            .contains('PendingDestinationService.instance.consume()')) {
          consumers.add(entity.path);
        }
      }
      expect(consumers, <String>['lib/screens/main_navigation.dart'],
          reason: 'a second consumer could run before the PIN gate');
    });

    test('MainNavigation is built only after consent, onboarding and the PIN',
        () {
      final splash = File('lib/screens/splash_screen.dart').readAsStringSync();
      final consent = splash.indexOf('UnifiedConsentScreen(');
      final onboarding = splash.indexOf('OnboardingScreen(');
      final unlock = splash.indexOf('AppUnlockScreen(');
      for (final gate in <int>[consent, onboarding, unlock]) {
        expect(gate, isNot(-1), reason: 'a startup gate disappeared');
      }
      final fallthrough =
          splash.lastIndexOf('nextScreen = const MainNavigation();');
      expect(fallthrough, greaterThan(unlock),
          reason: 'MainNavigation must be the else-branch of the PIN gate');
    });

    test('MainActivity parks the link and does nothing else with it', () {
      final kotlin = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt',
      ).readAsStringSync();
      final start = kotlin.indexOf('private fun captureDeepLink');
      expect(start, isNot(-1));
      final body = kotlin.substring(start, kotlin.indexOf('\n    }', start));
      expect(body, contains('DEEP_LINK_SCHEME'));
      expect(body, contains('DEEP_LINK_MAX_LENGTH'));
      for (final action in <String>[
        'startActivity',
        'PanicRequestStore',
      ]) {
        expect(body, isNot(contains(action)),
            reason: 'the Activity must only RECORD the link');
      }
    });

    test('the manifest filter admits the custom scheme only', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:scheme="korubeni"'));
      expect(manifest, contains('android:host="open"'));
      expect(manifest, isNot(contains('android:autoVerify="true"')));
      expect(manifest, isNot(contains('android:scheme="https"')));
    });
  });

  group('every arrival path is collected', () {
    late String nav;
    late String kotlin;

    setUpAll(() {
      nav = File('lib/screens/main_navigation.dart').readAsStringSync();
      kotlin = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt',
      ).readAsStringSync();
    });

    test('COLD START: onCreate captures, and the first frame collects', () {
      expect(kotlin, contains('super.onCreate(savedInstanceState)\n        captureDeepLink(intent)'));
      expect(nav, contains('addPostFrameCallback'));
      final frameCallback = nav.indexOf('addPostFrameCallback');
      final collect = nav.indexOf('_collectAndRouteExternalEntry()', frameCallback);
      expect(collect, greaterThan(frameCallback));
    });

    test('WARM / BACKGROUNDED: onNewIntent captures, resume collects', () {
      final onNewIntent = kotlin.indexOf('override fun onNewIntent');
      final capture = kotlin.indexOf('captureDeepLink(intent)', onNewIntent);
      expect(capture, greaterThan(onNewIntent));
      expect(nav, contains('AppLifecycleState.resumed'));
      final resumed = nav.indexOf('state == AppLifecycleState.resumed');
      final collect = nav.indexOf('_collectAndRouteExternalEntry()', resumed);
      expect(collect, greaterThan(resumed));
    });

    test('LOCKED: nothing collects until MainNavigation exists', () {
      // MainNavigation registers the observer in initState, so no lifecycle
      // event can trigger collection while the unlock screen is up -- there is
      // no observer yet.
      final initState = nav.indexOf('void initState()');
      final addObserver = nav.indexOf('WidgetsBinding.instance.addObserver(this)');
      final dispose = nav.indexOf('void dispose()');
      expect(addObserver, greaterThan(initState));
      expect(addObserver, lessThan(dispose));
      expect(nav, contains('WidgetsBinding.instance.removeObserver(this)'));
    });

    test('a re-entrancy guard stops a burst from routing twice', () {
      expect(nav, contains('if (_routing || !mounted) return;'));
      expect(nav, contains('_routing = false;'));
    });
  });
}
