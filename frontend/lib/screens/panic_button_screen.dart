import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:centinel8/services/api_service.dart';

class PanicButtonScreen extends StatefulWidget {
  const PanicButtonScreen({super.key});

  @override
  State<PanicButtonScreen> createState() => _PanicButtonScreenState();
}

class _PanicButtonScreenState extends State<PanicButtonScreen> {
  final ApiService _apiService = ApiService();
  bool _triggered = false;
  bool _sending = false;
  String _statusMessage = "Capturando tu ubicación GPS...";
  
  double _lat = -16.582;
  double _lng = -68.185;

  @override
  void initState() {
    super.initState();
    // Ejecutar la secuencia de pánico automáticamente al entrar
    _triggerAutomaticPanic();
  }

  Future<void> _triggerAutomaticPanic() async {
    setState(() {
      _sending = true;
      _statusMessage = "Obteniendo coordenadas GPS de emergencia...";
    });

    try {
      // Intentar obtener ubicación ultra-rápida (tiempo límite 1.5s)
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(milliseconds: 1500),
      );
      _lat = position.latitude;
      _lng = position.longitude;
    } catch (_) {
      // Fallback inmediato si el GPS demora más de 1.5s (requisito <2 segundos total)
      // Usamos el bounding box de Senkata, El Alto por defecto
    }

    if (!mounted) return;
    setState(() {
      _statusMessage = "Enviando señal de auxilio a la Central y Vecinos...";
    });

    try {
      final address = "Alerta de Pánico en: $_lat, $_lng (Distrito 8 El Alto)";
      
      // Llamar al endpoint optimizado de pánico
      await _apiService.triggerPanic(
        latitud: _lat,
        longitud: _lng,
        direccion: address,
      );

      if (!mounted) return;
      setState(() {
        _triggered = true;
        _sending = false;
        _statusMessage = "¡ALERTA ENVIADA CON ÉXITO!\nLas autoridades y vecinos cercanos han sido notificados.";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _statusMessage = "Error en el envío de señal: ${e.toString().replaceAll("HttpException: ", "")}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _triggered ? Colors.red.shade900 : Colors.black,
      appBar: AppBar(
        title: const Text('BOTÓN DE PÁNICO'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Círculo animado gigante
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_sending)
                    const SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        strokeWidth: 8,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    ),
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      color: _triggered ? Colors.white : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: Icon(
                      _triggered ? Icons.check : Icons.emergency_share,
                      size: 80,
                      color: _triggered ? Colors.red.shade900 : Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              
              // Estado
              Text(
                _triggered ? '¡ALERTA ACTIVADA!' : 'SEÑAL DE AUXILIO',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),

              // Botón de Volver
              if (!_sending)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver al Inicio'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
