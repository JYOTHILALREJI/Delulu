import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  final _searchController = TextEditingController();
  Marker? _marker;
  double? _latitude;
  double? _longitude;
  String? _locationName;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _isLoading = true);
    try {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        setState(() => _isLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      String locName = 'Current Location';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        locName = '${p.locality}, ${p.administrativeArea}';
      }

      final pos = LatLng(position.latitude, position.longitude);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationName = locName;
        _isLoading = false;
        _marker = Marker(markerId: const MarkerId('selected'), position: pos);
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onMapTap(LatLng pos) async {
    setState(() => _isLoading = true);
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String locName = 'Selected Location';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        locName = '${p.locality}, ${p.administrativeArea}';
      }
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationName = locName;
        _isLoading = false;
        _marker = Marker(markerId: const MarkerId('selected'), position: pos);
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final results = await locationFromAddress(query);
      if (results.isNotEmpty) {
        final loc = results.first;
        final pos = LatLng(loc.latitude, loc.longitude);
        final placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
        String locName = query;
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          locName = '${p.locality}, ${p.administrativeArea}';
        }
        setState(() {
          _latitude = loc.latitude;
          _longitude = loc.longitude;
          _locationName = locName;
          _isLoading = false;
          _marker = Marker(markerId: const MarkerId('selected'), position: pos);
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not found')),
        );
      }
    }
  }

  Future<void> _saveLocation() async {
    if (_latitude == null || _longitude == null) return;
    setState(() => _isSaving = true);
    try {
      await ApiService.saveProfile({
        'live_location_enabled': true,
        'latitude': _latitude,
        'longitude': _longitude,
        'location_name': _locationName ?? '',
      });
      if (mounted) Navigator.pop(context, true); // return true = saved
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save location. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static const String _mapStyle = '''[{"elementType":"geometry","stylers":[{"color":"#212121"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},{"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},{"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},{"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}]''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(Icons.close, color: Colors.white70, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Location',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Tap on map or search to set your zone',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _searchLocation,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search city, area...',
                    hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Colors.white30, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Map
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(_latitude ?? 20, _longitude ?? 77),
                          zoom: _latitude != null ? 14 : 4,
                        ),
                        onMapCreated: (c) => _mapController = c,
                        onTap: _onMapTap,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        markers: _marker != null ? {_marker!} : {},
                        style: _mapStyle,
                      ),
                      // Locate me FAB
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton(
                          heroTag: 'locate_me',
                          onPressed: _detectLocation,
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.my_location, color: Colors.black),
                        ),
                      ),
                      if (_isLoading)
                        Container(
                          color: Colors.black38,
                          child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Selected location bar + save button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_locationName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _locationName!,
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_latitude == null || _isSaving) ? null : _saveLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.white12,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text(
                              'SAVE LOCATION',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1),
                            ),
                    ),
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
