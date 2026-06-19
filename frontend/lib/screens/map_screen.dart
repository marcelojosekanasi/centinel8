import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:centinel8/services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();
  
  List<dynamic> _incidents = [];
  bool _loading = false;
  bool _showHeatmap = false;
  
  int? _filterCategory;
  String? _filterStatus;
  
  double _centerLat = -16.582;
  double _centerLng = -68.185;

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
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    setState(() => _loading = true);
    try {
      final list = await _apiService.getIncidents(
        categoryId: _filterCategory,
        status: _filterStatus,
      );
      setState(() {
        _incidents = list;
        _loading = false;
        
        // Centrar mapa en el primer incidente si existe
        if (_incidents.isNotEmpty) {
          _centerLat = _incidents[0]["latitud"];
          _centerLng = _incidents[0]["longitud"];
          _mapController.move(LatLng(_centerLat, _centerLng), 14);
        }
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar incidentes en el mapa: $e')),
      );
    }
  }

  Color _getMarkerColor(String state, String risk) {
    if (risk == "Alto") return Colors.red;
    if (risk == "Medio") return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    // Generar marcadores
    List<Marker> markers = _incidents.map((inc) {
      final lat = inc["latitud"] as double;
      final lng = inc["longitud"] as double;
      final color = _getMarkerColor(inc["estado"], inc["nivel_riesgo"]);
      
      return Marker(
        point: LatLng(lat, lng),
        width: 45,
        height: 45,
        child: GestureDetector(
          onTap: () => _showIncidentDetail(inc),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              Icon(
                Icons.location_pin,
                color: color,
                size: 28,
              ),
            ],
          ),
        ),
      );
    }).toList();

    // Generar círculos de calor dinámicos (Heatmap simulado con CircleOverlays)
    List<CircleMarker> heatCircles = [];
    if (_showHeatmap) {
      heatCircles = _incidents.map((inc) {
        final lat = inc["latitud"] as double;
        final lng = inc["longitud"] as double;
        final risk = inc["nivel_riesgo"] as String;
        
        Color baseColor = Colors.green;
        if (risk == "Alto") baseColor = Colors.red;
        if (risk == "Medio") baseColor = Colors.yellow;

        return CircleMarker(
          point: LatLng(lat, lng),
          color: baseColor.withOpacity(0.18),
          useRadiusInMeter: true,
          radius: 250, // Radio de 250 metros
        );
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Riesgo Vecinal'),
        actions: [
          IconButton(
            icon: Icon(_showHeatmap ? Icons.density_medium : Icons.blur_on),
            tooltip: _showHeatmap ? 'Ocultar Mapa Calor' : 'Mostrar Mapa Calor',
            onPressed: () {
              setState(() => _showHeatmap = !_showHeatmap);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                // Filtro Categoría
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _filterCategory,
                    hint: const Text('Categoría'),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Todas las categorías'),
                      ),
                      ..._categories.map((c) {
                        return DropdownMenuItem<int>(
                          value: c["id"] as int,
                          child: Text(c["name"] as String),
                        );
                      })
                    ],
                    onChanged: (val) {
                      setState(() {
                        _filterCategory = val;
                      });
                      _loadIncidents();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Filtro Estado
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _filterStatus,
                    hint: const Text('Estado'),
                    items: const [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todos los estados'),
                      ),
                      DropdownMenuItem<String>(
                        value: "Pendiente",
                        child: Text('Pendiente'),
                      ),
                      DropdownMenuItem<String>(
                        value: "En proceso",
                        child: Text('En proceso'),
                      ),
                      DropdownMenuItem<String>(
                        value: "Atendido",
                        child: Text('Atendido'),
                      ),
                      DropdownMenuItem<String>(
                        value: "Cerrado",
                        child: Text('Cerrado'),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _filterStatus = val;
                      });
                      _loadIncidents();
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Mapa
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_centerLat, _centerLng),
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.centinel8.app',
                    ),
                    if (_showHeatmap)
                      CircleLayer(
                        circles: heatCircles,
                      ),
                    MarkerLayer(
                      markers: markers,
                    ),
                  ],
                ),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showIncidentDetail(Map<String, dynamic> inc) {
    final theme = Theme.of(context);
    final risk = inc["nivel_riesgo"] ?? "Bajo";
    final state = inc["estado"] ?? "Pendiente";
    
    Color rColor = Colors.green;
    if (risk == "Alto") rColor = Colors.red;
    if (risk == "Medio") rColor = Colors.orange;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: rColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: rColor),
                    ),
                    child: Text(
                      'Riesgo: $risk',
                      style: TextStyle(color: rColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    state,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                inc["categoria"]?["nombre"] ?? "Incidente",
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                inc["descripcion"] ?? "",
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      inc["direccion"] ?? "",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    inc["fecha_reporte"].toString().substring(0, 16).replaceAll("T", " "),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
