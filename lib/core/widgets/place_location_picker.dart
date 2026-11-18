import 'package:flutter_map/flutter_map.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/utils/place_geo_helper.dart';
import 'package:horas/core/widgets/app_button.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

/// Badge atribusi wajib untuk ubin peta OpenStreetMap.
class OsmAttributionBadge extends StatelessWidget {
  const OsmAttributionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        AppStrings.mapAttributionOsm,
        style: typo.micro.copyWith(color: colors.textMuted),
      ),
    );
  }
}

/// Pemilih titik lokasi tempat umum (lapangan olahraga / gereja) di atas peta OpenStreetMap.
class PlaceLocationPickerPage extends StatefulWidget {
  const PlaceLocationPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.fallbackCity,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? fallbackCity;

  /// Menampilkan halaman pemilih titik peta dan mengembalikan [LatLng] saat disimpan.
  static Future<LatLng?> show(
    BuildContext context, {
    double? initialLatitude,
    double? initialLongitude,
    String? fallbackCity,
  }) {
    return Navigator.of(context).push<LatLng>(
      MaterialPageRoute<LatLng>(
        fullscreenDialog: true,
        builder: (_) => PlaceLocationPickerPage(
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
          fallbackCity: fallbackCity,
        ),
      ),
    );
  }

  @override
  State<PlaceLocationPickerPage> createState() =>
      _PlaceLocationPickerPageState();
}

class _PlaceLocationPickerPageState extends State<PlaceLocationPickerPage> {
  final MapController _mapController = MapController();
  late LatLng _currentCenter;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _currentCenter = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    } else {
      final cityCenter = PlaceGeoHelper.cityCenterFor(widget.fallbackCity);
      _currentCenter = LatLng(cityCenter.latitude, cityCenter.longitude);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _centerOnMyLocation() async {
    final res = await PlaceGeoHelper.resolveDeviceOrCityCoordinates(
      context,
      fallbackCity: widget.fallbackCity,
    );
    if (!mounted) return;
    final next = LatLng(res.latitude, res.longitude);
    setState(() => _currentCenter = next);
    _mapController.move(next, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.mapPickLocationTitle),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.mapMyLocationTooltip,
            icon: const Icon(Icons.my_location_outlined),
            onPressed: _centerOnMyLocation,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              color: colors.chipInactive,
              child: Text(
                AppStrings.mapPickLocationHint,
                style: typo.caption.copyWith(color: colors.text),
              ),
            ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentCenter,
                      initialZoom: 15.0,
                      onPositionChanged: (camera, _) {
                        setState(() {
                          _currentCenter = camera.center;
                        });
                      },
                    ),
                    children: <Widget>[
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'id.horas.app',
                      ),
                    ],
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        child: Icon(
                          Icons.location_on,
                          size: AppSizes.iconXl,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: OsmAttributionBadge(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${AppStrings.mapSelectedCoordinatesPrefix}: '
                    '${_currentCenter.latitude.toStringAsFixed(5)}, '
                    '${_currentCenter.longitude.toStringAsFixed(5)}',
                    style: typo.caption.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: AppStrings.mapSaveLocationBtn,
                    leadingIcon: Icons.check_circle_outline,
                    isExpanded: true,
                    onPressed: () => Navigator.of(context).pop(_currentCenter),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
