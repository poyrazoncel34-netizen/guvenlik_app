// Overlays drawn on top of the map tile layer: the provider attribution and
// the bottom warning banners. Split out of lib/screens/map_page.dart, which sits at its
// size ratchet; the attribution and the fallback banner are moved verbatim.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/config/app_environment.dart';
import '../core/design_tokens.dart';
import '../core/network/map_tile_availability.dart';
import '../core/utils/formatters.dart';
import '../core/utils/map_utils.dart';

/// The map's bottom overlays as ONE upward-growing stack: warning banners,
/// then the attribution, then the controls card.
///
/// They used to be three independently positioned layers (bottom 220 / 130 /
/// 24). With large text the controls card grew over the attribution, which
/// OSMF forbids, and the banners could cover it from above. The minimum
/// heights below reproduce those offsets exactly at default text size, so
/// nothing moves there; at larger sizes the stack grows instead of
/// overlapping. Placed with left 12 / right 16: the attribution sits at 12,
/// everything else is indented 4 to keep its old 16 inset.
class MapBottomStack extends StatelessWidget {
  const MapBottomStack({
    super.key,
    required this.banners,
    required this.attribution,
    required this.controls,
  });

  static const double _bannerSlotMinHeight = 220 - 24;
  static const double _controlsSlotMinHeight = 130 - 24;
  static const EdgeInsets _inset = EdgeInsets.only(left: 4);

  final List<Widget> banners;
  final Widget? attribution;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < banners.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Padding(padding: _inset, child: banners[i]),
        ],
        // Containers with an alignment and no decoration are hit-transparent
        // outside their child, so the empty slot space still pans the map.
        Container(
          constraints: const BoxConstraints(minHeight: _bannerSlotMinHeight),
          alignment: Alignment.bottomLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?attribution,
              Container(
                constraints: const BoxConstraints(
                  minHeight: _controlsSlotMinHeight,
                ),
                alignment: Alignment.bottomLeft,
                padding: _inset,
                child: SizedBox(width: double.infinity, child: controls),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tile provider credit line. OSMF requires it to be visible without user
/// interaction and never hidden beneath other UI; see [MapBottomStack].
class MapTileAttribution extends StatelessWidget {
  const MapTileAttribution({
    super.key,
    this.text = AppEnvironment.defaultMapTileAttribution,
    this.url = AppEnvironment.defaultMapTileAttributionUrl,
  });

  final String text;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$text copyright link',
      button: true,
      child: GestureDetector(
        onTap: () => openMapAttributionPage(url),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

/// "The map can't be loaded right now", in the same warning style as the
/// fallback-location banner below it.
class MapTilesUnavailableBanner extends StatelessWidget {
  const MapTilesUnavailableBanner({super.key, required this.outage});

  final MapTileOutage outage;

  @override
  Widget build(BuildContext context) {
    final detailKey = switch (outage) {
      MapTileOutage.blocked => 'map_tiles_unavailable_blocked',
      MapTileOutage.network => 'map_tiles_unavailable_network',
    };
    // MergeSemantics: a live region whose texts stay separate child nodes has
    // no label of its own and announces nothing.
    return MergeSemantics(
      child: Semantics(
        liveRegion: true,
        child: _WarningBanner(
          title: 'map_tiles_unavailable'.tr(),
          detail: detailKey.tr(),
        ),
      ),
    );
  }
}

/// Shown when the map is centred on a last-known or fallback position.
class MapFallbackLocationBanner extends StatelessWidget {
  const MapFallbackLocationBanner({
    super.key,
    required this.hasLocation,
    this.checkedAt,
  });

  final bool hasLocation;
  final DateTime? checkedAt;

  @override
  Widget build(BuildContext context) {
    final checkedAt = this.checkedAt;
    final measured = checkedAt?.toLocal();
    return _WarningBanner(
      title:
          (hasLocation ? "map_fallback_location" : "map_location_unavailable")
              .tr(),
      detail: checkedAt == null || measured == null
          ? null
          : 'map_fallback_location_time'.tr(
              namedArgs: {
                'time':
                    '${measured.day}.${measured.month}.${measured.year} ${Formatters.clockHm(checkedAt)}',
              },
            ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: IconSizes.action,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
