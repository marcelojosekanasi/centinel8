import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:centinel8/providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _ciController = TextEditingController();
  final _celularController = TextEditingController();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _ciController.dispose();
    _celularController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      _nombreController.text.trim(),
      _apellidoController.text.trim(),
      _ciController.text.trim(),
      _celularController.text.trim(),
      _correoController.text.trim(),
      _contrasenaController.text,
    );

    if (!mounted) return;

    if (success) {
      // Registrar redirecciona directo a Home mediante autologin
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Error al registrar usuario'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Vecino'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Únete a la Red de Seguridad',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tus datos están protegidos y son confidenciales',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Nombre
                TextFormField(
                  controller: _nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => (val == null || val.isEmpty) ? 'Ingrese su nombre' : null,
                ),
                const SizedBox(height: 16),

                // Apellido
                TextFormField(
                  controller: _apellidoController,
                  decoration: InputDecoration(
                    labelText: 'Apellido',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => (val == null || val.isEmpty) ? 'Ingrese su apellido' : null,
                ),
                const SizedBox(height: 16),

                // Cédula de Identidad (CI)
                TextFormField(
                  controller: _ciController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cédula de Identidad (CI)',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => (val == null || val.isEmpty) ? 'Ingrese su documento de identidad' : null,
                ),
                const SizedBox(height: 16),

                // Celular
                TextFormField(
                  controller: _celularController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Número de Celular',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => (val == null || val.isEmpty) ? 'Ingrese su celular' : null,
                ),
                const SizedBox(height: 16),

                // Correo
                TextFormField(
                  controller: _correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Ingrese su correo';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                      return 'Ingrese un correo válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Contraseña
                TextFormField(
                  controller: _contrasenaController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Ingrese una contraseña';
                    if (val.length < 6) return 'Debe tener mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Botón
                authProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        child: const Text('REGISTRARSE'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
