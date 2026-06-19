import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.core.config import settings

def send_recovery_email(email_to: str, token: str, nombre: str = "Usuario"):
    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = "Recuperacion de Contrasena - CENTINEL 8"
        msg["From"] = settings.EMAILS_FROM_EMAIL
        msg["To"] = email_to

        html = f"""
        <html>
        <body style="font-family: Arial, sans-serif; background-color: #0a0a0a; color: #ffffff; padding: 30px;">
            <div style="max-width: 500px; margin: auto; background-color: #1a1a1a; border-radius: 10px; padding: 30px;">
                <h1 style="color: #2196F3; text-align: center;">CENTINEL 8</h1>
                <h2 style="color: #ffffff;">Recuperacion de Contrasena</h2>
                <p>Hola <strong>{nombre}</strong>,</p>
                <p>Recibimos una solicitud para restablecer tu contrasena.</p>
                <p>Tu token de recuperacion es:</p>
                <div style="background-color: #2196F3; padding: 15px; border-radius: 5px; text-align: center; font-size: 18px; font-weight: bold; letter-spacing: 2px;">
                    {token}
                </div>
                <p style="color: #aaaaaa; font-size: 12px; margin-top: 20px;">Este token expira en 1 hora. Si no solicitaste este cambio, ignora este correo.</p>
                <hr style="border-color: #333333;">
                <p style="color: #666666; font-size: 11px; text-align: center;">Sistema de Alerta Vecinal - Distrito 8, El Alto, Bolivia</p>
            </div>
        </body>
        </html>
        """

        part = MIMEText(html, "html")
        msg.attach(part)

        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            server.starttls()
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.sendmail(settings.EMAILS_FROM_EMAIL, email_to, msg.as_string())

        print(f"Correo de recuperacion enviado a {email_to}")
        return True
    except Exception as e:
        print(f"Error enviando correo: {e}")
        return False
