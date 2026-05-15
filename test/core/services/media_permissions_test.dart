// image_picker package uses the system photo picker on Android 13+
// which does NOT require READ_MEDIA_IMAGES or READ_EXTERNAL_STORAGE.
// These permissions should not be in the manifest to avoid over-permissioning.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Media permissions', () {
    test(
      'manifest should not declare READ_MEDIA_IMAGES when using image_picker',
      () {
        final manifest = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();

        expect(
          manifest,
          isNot(contains('android.permission.READ_MEDIA_IMAGES')),
          reason:
              'image_picker uses the system photo picker on Android 13+ '
              'which does not require READ_MEDIA_IMAGES. Remove this '
              'over-permissioned declaration.',
        );

        expect(
          manifest,
          isNot(contains('android.permission.READ_EXTERNAL_STORAGE')),
          reason:
              'image_picker handles storage access internally. '
              'READ_EXTERNAL_STORAGE is unnecessary.',
        );
      },
    );
  });
}
