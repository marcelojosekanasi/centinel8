import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:centinel8/services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic> _stats = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final data = await _apiService.getDashboardStats();
      setState(() {
        _stats = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar estadísticas: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Administrativo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stats.isEmpty
              ? const Center(child: Text('No hay datos estadísticos.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tarjetas de Totales
                      Row(
                        children: [
                          Expanded(
                            child: _buildTotalCard(
                              'Total Vecinos',
                              _stats["total_usuarios"].toString(),
                              Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTotalCard(
                              'Total Incidentes',
                              _stats["total_incidentes"].toString(),
                              Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTotalCard(
                        'Total Consultas de Predicción IA (MLP)',
                        _stats["predicciones_totales"].toString(),
                        Colors.teal.shade800,
                      ),
                      const SizedBox(height: 24),

                      // Gráfico: Incidentes por Categoría (Pie Chart)
                      const Text(
                        'Distribución por Categorías',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            height: 220,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: _getCategorySections(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCategoryLegend(),
                      const SizedBox(height: 24),

                      // Gráfico: Incidentes por Estado (Bar Chart)
                      const Text(
                        'Incidentes por Estado de Gestión',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            height: 200,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: (_getMaxStatusCount() + 5).toDouble(),
                                barGroups: _getStatusBarGroups(),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        switch (value.toInt()) {
                                          case 0:
                                            return const Text('Pend', style: TextStyle(fontSize: 10));
                                          case 1:
                                            return const Text('Proc', style: TextStyle(fontSize: 10));
                                          case 2:
                                            return const Text('Atend', style: TextStyle(fontSize: 10));
                                          case 3:
                                            return const Text('Cerr', style: TextStyle(fontSize: 10));
                                          default:
                                            return const Text('');
                                        }
                                      },
                                    ),
                                  ),
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTotalCard(String title, String value, Color color) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _getCategorySections() {
    final Map<String, dynamic> cats = _stats["incidentes_por_categoria"] ?? {};
    final List<Color> colors = [
      Colors.red,
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.yellow.shade800,
      Colors.teal,
      Colors.green,
      Colors.grey
    ];

    int index = 0;
    return cats.entries.map((e) {
      final val = (e.value as int).toDouble();
      final color = colors[index % colors.length];
      index++;
      
      return PieChartSectionData(
        color: color,
        value: val,
        title: val > 0 ? val.toInt().toString() : '',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Widget _buildCategoryLegend() {
    final Map<String, dynamic> cats = _stats["incidentes_por_categoria"] ?? {};
    final List<Color> colors = [
      Colors.red,
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.yellow.shade800,
      Colors.teal,
      Colors.green,
      Colors.grey
    ];

    int index = 0;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: cats.entries.map((e) {
        final color = colors[index % colors.length];
        index++;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, color: color),
            const SizedBox(width: 4),
            Text('${e.key} (${e.value})', style: const TextStyle(fontSize: 11)),
          ],
        );
      }).toList(),
    );
  }

  int _getMaxStatusCount() {
    final Map<String, dynamic> st = _stats["incidentes_por_estado"] ?? {};
    int maxVal = 10;
    for (var val in st.values) {
      if (val is int && val > maxVal) maxVal = val;
    }
    return maxVal;
  }

  List<BarChartGroupData> _getStatusBarGroups() {
    final Map<String, dynamic> st = _stats["incidentes_por_estado"] ?? {};
    final list = [
      st["Pendiente"] ?? 0,
      st["En proceso"] ?? 0,
      st["Atendido"] ?? 0,
      st["Cerrado"] ?? 0,
    ];

    final colors = [Colors.red, Colors.orange, Colors.green, Colors.grey];

    return List.generate(4, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (list[i] as int).toDouble(),
            color: colors[i],
            width: 22,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          )
        ],
      );
    });
  }
}
