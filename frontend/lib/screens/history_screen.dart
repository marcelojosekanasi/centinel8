import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:centinel8/providers/auth_provider.dart';
import 'package:centinel8/services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _incidents = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // Vecino carga historial personal (personal=true), Admin general (personal=false)
      final list = await _apiService.getIncidents(
        personal: !authProvider.isAdmin,
      );
      setState(() {
        _incidents = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar historial: $e')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Pendiente":
        return Colors.red.shade800;
      case "En proceso":
        return Colors.orange.shade800;
      case "Atendido":
        return Colors.green.shade800;
      case "Cerrado":
        return Colors.grey.shade700;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Historial de Incidentes' : 'Mis Incidentes Reportados'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _incidents.isEmpty
                ? const Center(
                    child: Text(
                      'No se registran incidentes en el historial.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _incidents.length,
                    itemBuilder: (context, index) {
                      final inc = _incidents[index];
                      final id = inc["id"];
                      final cat = inc["categoria"]?["nombre"] ?? "Otro";
                      final desc = inc["descripcion"];
                      final date = inc["fecha_reporte"].toString().substring(0, 10);
                      final state = inc["estado"];
                      final risk = inc["nivel_riesgo"] ?? "Bajo";

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () {
                            if (isAdmin) {
                              _showAdminEditModal(inc);
                            } else {
                              _showDetailModal(inc);
                            }
                          },
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(state).withOpacity(0.15),
                            foregroundColor: _getStatusColor(state),
                            child: Icon(_getIncidentIcon(cat)),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(state),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  state,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Riesgo: $risk',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: risk == "Alto" ? Colors.red : (risk == "Medio" ? Colors.orange : Colors.green),
                                    ),
                                  ),
                                  Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  IconData _getIncidentIcon(String category) {
    switch (category) {
      case "Robo":
        return Icons.shopping_bag_outlined;
      case "Agresión":
        return Icons.transfer_within_a_station;
      case "Asalto":
        return Icons.dangerous;
      case "Violencia":
        return Icons.back_hand;
      case "Vandalismo":
        return Icons.format_paint;
      case "Accidente":
        return Icons.car_crash;
      case "Emergencia médica":
        return Icons.medical_services_outlined;
      default:
        return Icons.warning_amber;
    }
  }

  void _showDetailModal(Map<String, dynamic> inc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                inc["categoria"]?["nombre"] ?? "Reporte",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 12),
              Text(inc["descripcion"] ?? ""),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.location_pin, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(inc["direccion"] ?? "", style: const TextStyle(color: Colors.grey))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Riesgo Estimado: ${inc["nivel_riesgo"]}', style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showAdminEditModal(Map<String, dynamic> inc) {
    String selectedStatus = inc["estado"];
    String selectedRisk = inc["nivel_riesgo"] ?? "Bajo";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 24.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Gestionar Reporte #${inc["id"]}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text('Categoría: ${inc["categoria"]?["nombre"]}'),
                  Text('Detalle: ${inc["descripcion"]}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  
                  // Selector de Estado
                  const Text('Estado del Incidente', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: selectedStatus,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "Pendiente", child: Text('Pendiente')),
                      DropdownMenuItem(value: "En proceso", child: Text('En proceso')),
                      DropdownMenuItem(value: "Atendido", child: Text('Atendido')),
                      DropdownMenuItem(value: "Cerrado", child: Text('Cerrado')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedStatus = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Selector de Riesgo
                  const Text('Riesgo (Validación Admin)', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: selectedRisk,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "Bajo", child: Text('Bajo')),
                      DropdownMenuItem(value: "Medio", child: Text('Medio')),
                      DropdownMenuItem(value: "Alto", child: Text('Alto')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedRisk = val);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context); // cerrar modal
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );
                      
                      try {
                        await _apiService.updateIncidentStatus(inc["id"], selectedStatus, selectedRisk);
                        if (!mounted) return;
                        Navigator.pop(context); // cerrar cargador
                        _loadHistory();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Estado actualizado con éxito'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: const Text('GUARDAR CAMBIOS'),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }
}
