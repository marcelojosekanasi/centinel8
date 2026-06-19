content = open("/app/app/api/v1/endpoints/auth.py", "r").read()
old = """    # SimulaciÃ³n de correo
    print(f"--- [MOCK CORREO RECUPERACION] ---")
    print(f"Para: {user.correo}")
    print(f"Token de restablecimiento: {token}")
    print(f"Enlace simulado: http://localhost:8000/api/v1/auth/reset-password?token={token}")
    print(f"----------------------------------")"""
new = """    # Enviar correo real
    from app.utils.email import send_recovery_email
    send_recovery_email(email_to=user.correo, token=token, nombre=user.nombre)"""
content = content.replace(old, new, 1)
open("/app/app/api/v1/endpoints/auth.py", "w").write(content)
print("Hecho")
