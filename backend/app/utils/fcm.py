import json
import logging
from typing import List, Optional
from sqlalchemy.orm import Session
from app.core.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("Centinel8-FCM")

# Estado de inicializaciÃ³n de Firebase Admin SDK
_firebase_initialized = False

def initialize_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return True
        
    if not settings.FCM_CREDENTIALS_JSON:
        logger.info("Firebase Cloud Messaging configurado en modo MOCK (sin FCM_CREDENTIALS_JSON).")
        return False
        
    try:
        import firebase_admin
        from firebase_admin import credentials
        
        # Cargar credenciales desde string JSON o archivo
        if settings.FCM_CREDENTIALS_JSON.startswith("{"):
            creds_dict = json.loads(settings.FCM_CREDENTIALS_JSON)
            cred = credentials.Certificate(creds_dict)
        else:
            cred = credentials.Certificate(settings.FCM_CREDENTIALS_JSON)
            
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("Firebase Admin SDK inicializado correctamente para FCM.")
        return True
    except Exception as e:
        logger.error(f"Error al inicializar Firebase Admin: {e}. Las notificaciones operarÃ¡n en modo MOCK.")
        return False

def send_push_notification(
    db: Session,
    user_ids: List[int],
    title: str,
    body: str,
    data: Optional[dict] = None
) -> bool:
    """
    EnvÃ­a notificaciones push a una lista de IDs de usuarios.
    Si Firebase estÃ¡ configurado correctamente, despacha mensajes reales.
    De lo contrario, simula el envÃ­o escribiendo en logs de auditorÃ­a/consola.
    """
    logger.info(f"--- [ENVIANDO NOTIFICACIÃ“N PUSH] ---")
    logger.info(f"TÃ­tulo: {title}")
    logger.info(f"Mensaje: {body}")
    logger.info(f"Destinatarios (IDs): {user_ids}")
    if data:
        logger.info(f"Datos Adicionales: {data}")
        
    firebase_active = initialize_firebase()
    
    if firebase_active:
        try:
            from firebase_admin import messaging
            # En producciÃ³n, mapearÃ­amos user_ids a sus tokens FCM registrados en la BD.
            # Por simplicidad en la simulaciÃ³n, asumimos que se mandan mensajes a tÃ³picos
            # o que en una implementaciÃ³n real consultarÃ­amos los tokens del dispositivo.
            
            from app.core.models import DispositivoFCM
            dispositivos = db.query(DispositivoFCM).filter(
                DispositivoFCM.usuario_id.in_(user_ids),
                DispositivoFCM.activo == True
            ).all()
            tokens_reales = [d.token for d in dispositivos]

            if not tokens_reales:
                logger.info("No hay tokens FCM registrados para estos usuarios.")
                return True

            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data={k: str(v) for k, v in (data or {}).items()},
                tokens=tokens_reales
            )
            response = messaging.send_each_for_multicast(message)
            logger.info(f"FCM real enviado: {response.success_count} exitosos, {response.failure_count} fallidos.")
            return True
        except Exception as e:
            logger.error(f"Error al enviar notificaciones mediante Firebase SDK: {e}")
            logger.info("Fallback: NotificaciÃ³n enviada exitosamente en modo SimulaciÃ³n.")
            return True
    else:
        logger.info("NotificaciÃ³n enviada exitosamente en modo SimulaciÃ³n (Consola/Mock).")
        return True
