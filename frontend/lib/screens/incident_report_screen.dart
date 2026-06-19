import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:centinel8/services/api_service.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _HomeScreenState {} // Placeholder to satisfy naming convention dependencies if any

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _dirController = TextEditingController();
  final ApiService _apiService = ApiService();

  int _selectedCategory = 1;
  double _lat = -16.582; // Senkata El Alto
  double _lng = -68.185;
  bool _loadingLocation = false;
  bool _submitting = false;
  
  final MapController _mapController = MapController();

  final List<Map<String, dynamic>> _categories = [
    {"id": 1, "name": "Robo"},
    {"id": 2, "name": "Agresión"},
    {"id": 3, "name": "Asalto"},
    {"id": 4, "name": "Violencia"},
    {"id": 5, "name": "Vandalismo"},
    {"id": 6, "name": "Accidente"},
    {"id": 7, "name": "Emergencia médica"},
    {"id": 8, "name": "Otro"},
  ];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    _descController.dispose();
    _dirController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    setState(() => _loadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Los servicios de ubicación están desactivados.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Permisos de ubicación denegados.';
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _dirController.text = "Coordenadas: $_lat, $_lng";
        _loadingLocation = false;
      });

      _mapController.move(LatLng(_lat, _lng), 15);
    } catch (e) {
      setState(() => _loadingLocation = false);
      // Fallback a coordenadas por defecto (Senkata)
      _dirController.text = "Av. 6 de Marzo, Senkata, El Alto";
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final res = await _apiService.createIncident(
        categoryId: _selectedCategory,
        descripcion: _descController.text.trim(),
        latitud: _lat,
        longitud: _lng,
        direccion: _dirController.text.trim(),
        imageFile: null, // Opcional, nulo en simulación básica
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      // Mostrar modal premium con la predicción de la IA
      final riesgo = res["nivel_riesgo"] ?? "Bajo";
      Color colorRiesgo = Colors.green;
      if (riesgo == "Alto") colorRiesgo = Colors.red;
      if (riesgo == "Medio") colorRiesgo = Colors.orange;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text('Reporte Registrado'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Su reporte ha sido enviado con éxito.'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorRiesgo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorRiesgo, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Text('PREDICCIÓN RIESGO IA (MLP)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      riesgo.toUpperCase(),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorRiesgo),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // cerrar modal
                Navigator.pop(context); // volver a Home
              },
              child: const Text('Entendido'),
            )
          ],
        ),
      );

    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar reporte: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Reporte')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selección de Categoría
              DropdownButtonFormField<int>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Categoría del Incidente',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: _categories.map((c) {
                  return DropdownMenuItem<int>(
                    value: c["id"] as int,
                    child: Text(c["name"] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCategory = val);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción del Incidente',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Por favor describa lo ocurrido';
                  if (val.length < 10) return 'Ingrese al menos 10 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dirección / Referencia
              TextFormField(
                controller: _dirController,
                decoration: InputDecoration(
                  labelText: 'Dirección o Referencia',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Ingrese una dirección' : null,
              ),
              const SizedBox(height: 16),

              // Mapa Interactivo para Ubicación
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ubicación del Incidente', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: _determinePosition,
                    tooltip: 'Obtener GPS actual',
                  )
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(_lat, _lng),
                        initialZoom: 14.0,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _lat = point.latitude;
                            _lng = point.longitude;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.centinel8.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_lat, _lng),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_loadingLocation)
                      Container(
                        color: Colors.white70,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nota: Toca el mapa para reposicionar el marcador.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Botón de Envío
              _submitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submit,
                      child: const Text('ENVIAR REPORTE VECINAL'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
