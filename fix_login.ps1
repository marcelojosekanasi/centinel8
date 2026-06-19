$file = 'C:\proyecto integrador\frontend\lib\screens\login_screen.dart'
$content = Get-Content $file -Raw -Encoding UTF8
$old = '                  // Enlace a Registro'
$new = '                  // Enlace a Recuperar Contrasena' + [char]10 + '                  Align(' + [char]10 + '                    alignment: Alignment.centerRight,' + [char]10 + '                    child: GestureDetector(' + [char]10 + '                      onTap: () {' + [char]10 + '                        Navigator.pushNamed(context, ' + [char]39 + '/forgot-password' + [char]39 + ');' + [char]10 + '                      },' + [char]10 + '                      child: Text(' + [char]10 + '                        ' + [char]39 + [char]191 + 'Olvidaste tu contrase' + [char]241 + 'a?' + [char]39 + ',' + [char]10 + '                        style: TextStyle(' + [char]10 + '                          color: theme.colorScheme.primary,' + [char]10 + '                          fontWeight: FontWeight.w500,' + [char]10 + '                        ),' + [char]10 + '                      ),' + [char]10 + '                    ),' + [char]10 + '                  ),' + [char]10 + '                  const SizedBox(height: 16),' + [char]10 + [char]10 + '                  // Enlace a Registro'
$content = $content.Replace($old, $new)
$content | Set-Content $file -Encoding UTF8 -NoNewline
Write-Host 'Listo'
