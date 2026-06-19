import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:centinel8/services/api_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'download_helper_stub.dart' if (dart.library.html) 'download_helper_web.dart' as downloader;

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final ApiService _apiService = ApiService();

  int? _selectedCategory;
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  String _selectedFormat = "pdf";
  bool _exporting = false;

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

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);

    final startStr = _startDate != null ? DateFormat("yyyy-MM-dd").format(_startDate!) : null;
    final endStr = _endDate != null ? DateFormat("yyyy-MM-dd").format(_endDate!) : null;

    try {
      final response = await _apiService.downloadReport(
        format: _selectedFormat,
        categoryId: _selectedCategory,
        status: _selectedStatus,
        dateStart: startStr,
        dateEnd: endStr,
      );

      if (!mounted) return;
      setState(() => _exporting = false);

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final ext = _selectedFormat == 'excel' ? 'xlsx' : _selectedFormat;
        final fileName = 'centinel8_reporte.$ext';

        if (kIsWeb) {
          downloader.downloadFile(bytes, fileName);
        } else {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          await OpenFile.open(file.path);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte descargado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw 'Error codigo de servidor ${response.statusCode}';
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("dd/MM/yyyy");

    return Scaffold(
      appBar: AppBar(title: const Text('Exportador de Reportes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filtros del Reporte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas las categorias')),
                        ..._categories.map((c) {
                          return DropdownMenuItem(value: c["id"] as int, child: Text(c["name"] as String));
                        })
                      ],
                      onChanged: (val) => setState(() => _selectedCategory = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(labelText: 'Estado', prefixIcon: Icon(Icons.info_outline)),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Todos los estados')),
                        DropdownMenuItem(value: "Pendiente", child: Text('Pendiente')),
                        DropdownMenuItem(value: "En proceso", child: Text('En proceso')),
                        DropdownMenuItem(value: "Atendido", child: Text('Atendido')),
                        DropdownMenuItem(value: "Cerrado", child: Text('Cerrado')),
                      ],
                      onChanged: (val) => setState(() => _selectedStatus = val),
                    ),
                    const SizedBox(height: 16),
                    const Text('Rango de Fechas', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _selectStartDate,
                            child: Text(_startDate == null ? 'Desde' : dateFmt.format(_startDate!)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _selectEndDate,
                            child: Text(_endDate == null ? 'Hasta' : dateFmt.format(_endDate!)),
                          ),
                        ),
                      ],
                    ),
                    if (_startDate != null || _endDate != null)
                      TextButton(
                        onPressed: () => setState(() { _startDate = null; _endDate = null; }),
                        child: const Text('Limpiar fechas'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Formato del Archivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildFormatRadio("pdf", "PDF Documento"),
                        _buildFormatRadio("excel", "Excel Hoja"),
                        _buildFormatRadio("csv", "CSV Datos"),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _exporting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.file_download),
                    label: const Text('DESCARGAR REPORTE'),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatRadio(String val, String label) {
    return Expanded(
      child: Row(
        children: [
          Radio<String>(
            value: val,
            groupValue: _selectedFormat,
            onChanged: (value) {
              if (value != null) setState(() => _selectedFormat = value);
            },
          ),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}