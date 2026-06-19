import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:centinel8/providers/auth_provider.dart';
import 'package:centinel8/services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _recentAlerts = [];
  bool _loadingAlerts = false;
  Map<String, dynamic> _adminStats = {};
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAdmin) {
      _fetchAdminStats();
    } else {
      _fetchRecentAlerts();
    }
  }

  Future<void> _fetchRecentAlerts() async {
    setState(() => _loadingAlerts = true);
    try {
      final alerts = await _apiService.getNotifications();
      setState(() {
        _recentAlerts = alerts.take(4).toList();
        _loadingAlerts = false;
      });
    } catch (_) {
      setState(() => _loadingAlerts = false);
    }
  }

  Future<void> _fetchAdminStats() async {
    setState(() => _loadingStats = true);
    try {
      final stats = await _apiService.getDashboardStats();
      setState(() {
        _adminStats = stats;
        _loadingStats = false;
      });
    } catch (_) {
      setState(() => _loadingStats = false);
    }
  }

  Future<void> _retrainIA() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final metrics = await _apiService.retrainModel();
      if (!mounted) return;
      Navigator.pop(context); // cerrar cargador
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Entrenamiento Completado'),
          content: Text(
            'El modelo MLPClassifier se ha entrenado con éxito.\n\n'
            'Accuracy: ${(metrics["accuracy"] * 100).toStringAsFixed(2)}%\n'
            'Precision: ${(metrics["precision"] * 100).toStringAsFixed(2)}%\n'
            'Recall: ${(metrics["recall"] * 100).toStringAsFixed(2)}%\n'
            'F1-Score: ${(metrics["f1_score"] * 100).toStringAsFixed(2)}%\n'
            'Muestras: ${metrics["total_muestras"]}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            )
          ],
        ),
      );
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al entrenar la IA: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CENTINEL 8'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bienvenida
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      user != null ? user["nombre"][0].toUpperCase() : 'U',
                      style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, ${user != null ? user["nombre"] : "Vecino"}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        authProvider.isAdmin ? 'Administrador - Distrito 8' : 'Vecino - El Alto',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // RENDERIZAR SEGÚN ROL
              if (authProvider.isAdmin) ..._buildAdminDashboard(theme) else ..._buildVecinoDashboard(theme),
            ],
          ),
        ),
      ),
    );
  }

  // --- VISTA VECINO ---
  List<Widget> _buildVecinoDashboard(ThemeData theme) {
    return [
      // Botón de Pánico
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/panic'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade900, Colors.red.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ]
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.ring_volume,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'BOTÓN DE PÁNICO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Presiona en caso de emergencia extrema',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),

      // Acciones secundarias en cuadrícula
      const Text(
        'Acciones del Sistema',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.4,
        children: [
          _buildActionCard(
            theme,
            Icons.add_location_alt_outlined,
            'Reportar Incidente',
            'Reporta robos o accidentes',
            () => Navigator.pushNamed(context, '/report'),
          ),
          _buildActionCard(
            theme,
            Icons.map_outlined,
            'Mapa de Riesgo',
            'Ver zonas y predicciones',
            () => Navigator.pushNamed(context, '/map'),
          ),
          _buildActionCard(
            theme,
            Icons.history,
            'Mis Reportes',
            'Historial personal',
            () => Navigator.pushNamed(context, '/history'),
          ),
          _buildActionCard(
            theme,
            Icons.manage_accounts_outlined,
            'Mi Perfil',
            'Ajustes y cuenta',
            () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      const SizedBox(height: 24),

      // Listado de Alertas Recientes
      const Text(
        'Alertas Vecinales Recientes',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      const SizedBox(height: 12),
      if (_loadingAlerts)
        const Center(child: CircularProgressIndicator())
      else if (_recentAlerts.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'No se registran alertas recientes en tu zona.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentAlerts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = _recentAlerts[index];
            final alerta = item["alerta"];
            final esPanico = alerta["tipo"] == "Panico";
            return Card(
              color: esPanico ? Colors.red.shade50 : null,
              child: ListTile(
                leading: Icon(
                  esPanico ? Icons.notification_important : Icons.warning_amber_rounded,
                  color: esPanico ? Colors.red : Colors.orange,
                ),
                title: Text(
                  alerta["titulo"] ?? "Alerta",
                  style: TextStyle(fontWeight: FontWeight.bold, color: esPanico ? Colors.red.shade900 : null),
                ),
                subtitle: Text(alerta["mensaje"] ?? ""),
                trailing: Text(
                  alerta["fecha_envio"].toString().substring(11, 16),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            );
          },
        ),
    ];
  }

  // --- VISTA ADMINISTRADOR ---
  List<Widget> _buildAdminDashboard(ThemeData theme) {
    final tUsuarios = _adminStats["total_usuarios"] ?? 0;
    final tIncidentes = _adminStats["total_incidentes"] ?? 0;
    final tHoy = _adminStats["incidentes_hoy"] ?? 0;
    
    return [
      // Estadísticas rápidas en horizontal
      const Text(
        'Resumen del Distrito 8',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _buildStatCard(
              theme,
              'Usuarios',
              tUsuarios.toString(),
              Icons.people,
              theme.colorScheme.primaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              theme,
              'Incidentes',
              tIncidentes.toString(),
              Icons.warning_amber,
              Colors.orange.shade100,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              theme,
              'Reportes Hoy',
              tHoy.toString(),
              Icons.today,
              Colors.red.shade100,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),

      // Acciones del Administrador
      const Text(
        'Panel de Operaciones',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.4,
        children: [
          _buildActionCard(
            theme,
            Icons.bar_chart_outlined,
            'Dashboard Completo',
            'Gráficas de incidencias',
            () => Navigator.pushNamed(context, '/dashboard'),
          ),
          _buildActionCard(
            theme,
            Icons.file_download_outlined,
            'Generar Reportes',
            'PDF, Excel y CSV',
            () => Navigator.pushNamed(context, '/reports'),
          ),
          _buildActionCard(
            theme,
            Icons.people,
            'Gestion de Usuarios',
            'Roles, estado y accesos',
            () => Navigator.pushNamed(context, '/admin/users'),
          ),
          _buildActionCard(
            theme,
            Icons.map,        'Mapa de Calor',
            'Zonas y densidad',
            () => Navigator.pushNamed(context, '/map'),
          ),
          _buildActionCard(
            theme,
            Icons.psychology_outlined,
            'Reentrenar IA',
            'Ajustar MLPClassifier',
            _retrainIA,
          ),
          _buildActionCard(
            theme,
            Icons.list_alt,
            'Incidentes Globales',
            'Cambiar estados',
            () => Navigator.pushNamed(context, '/history'),
          ),
          _buildActionCard(
            theme,
            Icons.manage_accounts,
            'Gestionar Perfil',
            'Ajustes personales',
            () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
    ];
  }

  Widget _buildStatCard(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    ThemeData theme,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
