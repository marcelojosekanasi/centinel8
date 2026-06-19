content = open("C:/proyecto integrador/frontend/lib/screens/admin_reports_screen.dart", "r", encoding="utf-8").read()

old = """import 'dart:io';
import 'package:flutter/material.dart';"""

new = """import 'dart:html' as html;
import 'package:flutter/material.dart';"""

content = content.replace(old, new, 1)

old2 = """        if (response.statusCode == 200) {
        // En una app móvil real, escribiríamos los bytes a un archivo y usaríamos open_file
        // final bytes = response.bodyBytes;
        // Para la simulación demostramos descarga exitosa.
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.download_done, color: Colors.green),
                SizedBox(width: 8),
                Text('Reporte Generado'),
              ],
            ),
            content: Text(
              'El archivo en formato ${_selectedFormat.toUpperCase()} ha sido procesado por el backend.\\n\\n'
              'TamaÃ±o: ${(response.bodyBytes.length / 1024).toStringAsFixed(2)} KB\\n'
              'Guardado simulado en la carpeta de descargas del dispositivo.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              )
            ],
          ),
        );"""

new2 = """        if (response.statusCode == 200) {
        // Descarga real del archivo en el navegador web
        final bytes = response.bodyBytes;
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'centinel8_reporte.${_selectedFormat == 'excel' ? 'xlsx' : _selectedFormat}')
          ..click();
        html.Url.revokeObjectUrl(url);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte descargado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );"""

content = content.replace(old2, new2, 1)
open("C:/proyecto integrador/frontend/lib/screens/admin_reports_screen.dart", "w", encoding="utf-8").write(content)
print("Hecho")
