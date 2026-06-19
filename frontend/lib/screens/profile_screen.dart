import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:centinel8/providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _celularController;
  late TextEditingController _correoController;

  final _currPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _updatingProfile = false;
  bool _updatingPassword = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nombreController = TextEditingController(text: user?["nombre"] ?? "");
    _apellidoController = TextEditingController(text: user?["apellido"] ?? "");
    _celularController = TextEditingController(text: user?["celular"] ?? "");
    _correoController = TextEditingController(text: user?["correo"] ?? "");
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _celularController.dispose();
    _correoController.dispose();
    _currPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _updatingProfile = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.updateProfile(
      _nombreController.text.trim(),
      _apellidoController.text.trim(),
      _celularController.text.trim(),
      _correoController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _updatingProfile = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Datos de perfil actualizados' : authProvider.errorMessage ?? 'Error al actualizar'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _updatingPassword = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.changePassword(
      _currPasswordController.text,
      _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _updatingPassword = false);

    if (success) {
      _currPasswordController.clear();
      _newPasswordController.clear();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Contraseña actualizada correctamente' : authProvider.errorMessage ?? 'Error al actualizar'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Cabecera Perfil
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        user != null ? user["nombre"][0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user?["nombre"]} ${user?["apellido"]}',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer),
                          ),
                          Text(
                            'CI: ${user?["ci"]}',
                            style: TextStyle(color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Formulario Datos
            Form(
              key: _profileFormKey,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Información del Ciudadano', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person)),
                        validator: (val) => (val == null || val.isEmpty) ? 'Ingrese su nombre' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _apellidoController,
                        decoration: const InputDecoration(labelText: 'Apellido', prefixIcon: Icon(Icons.person)),
                        validator: (val) => (val == null || val.isEmpty) ? 'Ingrese su apellido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _celularController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Celular', prefixIcon: Icon(Icons.phone)),
                        validator: (val) => (val == null || val.isEmpty) ? 'Ingrese su celular' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _correoController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email)),
                        validator: (val) => (val == null || val.isEmpty) ? 'Ingrese su correo' : null,
                      ),
                      const SizedBox(height: 20),
                      _updatingProfile
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _updateProfile,
                              child: const Text('ACTUALIZAR PERFIL'),
                            ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Formulario Contraseña
            Form(
              key: _passwordFormKey,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Seguridad de la Cuenta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _currPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Contraseña Actual', prefixIcon: Icon(Icons.lock_open)),
                        validator: (val) => (val == null || val.isEmpty) ? 'Ingrese su contraseña actual' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Nueva Contraseña', prefixIcon: Icon(Icons.lock_outline)),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Ingrese una nueva contraseña';
                          if (val.length < 6) return 'Debe tener mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _updatingPassword
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _changePassword,
                              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
                              child: const Text('CAMBIAR CONTRASEÑA', style: TextStyle(color: Colors.black)),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
