import 'package:flutter/material.dart';
import 'package:centinel8/services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _users = [];
  bool _loading = true;

  final _roles = {1: 'Vecino', 2: 'Administrador', 3: 'Policia'};
  final _roleColors = {1: Colors.blue, 2: Colors.red, 3: Colors.green};

  @override
  void initState() { super.initState(); _loadUsers(); }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getAdminUsers();
      setState(() { _users = data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _toggleStatus(int userId, String currentStatus) async {
    try {
      await _api.toggleUserStatus(userId);
      _loadUsers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(currentStatus == 'Activo' ? 'Usuario desactivado' : 'Usuario activado'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteUser(int userId, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text('¿Eliminar a $nombre? Esta accion no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _api.deleteUser(userId);
        _loadUsers();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario eliminado'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _changeRole(int userId, int currentRole) async {
    final newRole = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar Rol'),
        content: Column(mainAxisSize: MainAxisSize.min, children: _roles.entries.map((e) =>
          ListTile(
            title: Text(e.value),
            leading: Radio<int>(value: e.key, groupValue: currentRole, onChanged: (v) => Navigator.pop(ctx, v)),
          )
        ).toList()),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))],
      ),
    );
    if (newRole != null && newRole != currentRole) {
      try {
        await _api.updateUserRole(userId, newRole);
        _loadUsers();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol actualizado'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion de Usuarios'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers)]),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _users.isEmpty
          ? const Center(child: Text('No hay usuarios registrados.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _users.length,
              itemBuilder: (ctx, i) {
                final u = _users[i];
                final rolId = u['rol_id'] as int;
                final estado = u['estado'] as String;
                final activo = estado == 'Activo';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _roleColors[rolId] ?? Colors.grey,
                      child: Text('${u['nombre'][0]}${u['apellido'][0]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text('${u['nombre']} ${u['apellido']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u['correo']),
                      Row(children: [
                        Chip(label: Text(_roles[rolId] ?? 'Desconocido'), backgroundColor: (_roleColors[rolId] ?? Colors.grey).withOpacity(0.2), padding: EdgeInsets.zero),
                        const SizedBox(width: 8),
                        Chip(label: Text(estado), backgroundColor: activo ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2), padding: EdgeInsets.zero),
                      ]),
                    ]),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'toggle') _toggleStatus(u['id'], estado);
                        if (val == 'role') _changeRole(u['id'], rolId);
                        if (val == 'delete') _deleteUser(u['id'], '${u['nombre']} ${u['apellido']}');
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(value: 'toggle', child: Text(activo ? 'Desactivar' : 'Activar')),
                        const PopupMenuItem(value: 'role', child: Text('Cambiar Rol')),
                        const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
