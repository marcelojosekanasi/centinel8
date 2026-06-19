import os
import json
import joblib
import pandas as pd
import numpy as np
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import extract
from sklearn.neural_network import MLPClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from app.core.config import settings
from app.core.models import Incidente

class MLPredictor:
    def __init__(self):
        self.model = None
        self.metrics = {}
        # Mapeo de índices a etiquetas
        self.risk_mapping = {0: "Bajo", 1: "Medio", 2: "Alto"}
        self.reverse_risk_mapping = {"Bajo": 0, "Medio": 1, "Alto": 2}
        
    def load_model(self):
        """Carga el modelo y las métricas desde disco. Si no existen, retorna False."""
        model_dir = os.path.dirname(settings.MODEL_PATH)
        if model_dir and not os.path.exists(model_dir):
            os.makedirs(model_dir, exist_ok=True)
            
        if os.path.exists(settings.MODEL_PATH) and os.path.exists(settings.METRICS_PATH):
            try:
                self.model = joblib.load(settings.MODEL_PATH)
                with open(settings.METRICS_PATH, "r") as f:
                    self.metrics = json.load(f)
                return True
            except Exception as e:
                print(f"Error al cargar el modelo de IA: {e}")
                return False
        return False

    def predict_risk(self, latitud: float, longitud: float, hora: int, dia_semana: int, categoria_id: int) -> str:
        """Predice el nivel de riesgo usando el modelo entrenado."""
        if self.model is None:
            # Si el modelo no está cargado, intentar cargarlo
            if not self.load_model():
                # Si falla, usar una predicción heurística como salvaguarda
                return self._fallback_prediction(latitud, longitud, hora, dia_semana, categoria_id)
        
        try:
            # Preparar vector de características
            x_input = np.array([[hora, dia_semana, categoria_id, latitud, longitud]])
            pred_idx = self.model.predict(x_input)[0]
            return self.risk_mapping.get(pred_idx, "Bajo")
        except Exception as e:
            print(f"Error en la predicción del modelo: {e}")
            return self._fallback_prediction(latitud, longitud, hora, dia_semana, categoria_id)

    def _fallback_prediction(self, latitud: float, longitud: float, hora: int, dia_semana: int, categoria_id: int) -> str:
        """Heurística simple si el modelo no está disponible."""
        # Incidentes nocturnos de categorías violentas (Asalto=3, Robo=1, Agresión=2) en horas críticas (20:00 - 05:00)
        if (hora >= 20 or hora <= 5) and categoria_id in [1, 2, 3]:
            return "Alto"
        elif categoria_id in [1, 2, 3, 4] or (hora >= 18 or hora <= 6):
            return "Medio"
        return "Bajo"

    def train_model(self, db: Session) -> dict:
        """Entrena el modelo MLPClassifier con datos históricos y lo guarda en disco."""
        # 1. Obtener datos de la base de datos
        incidentes = db.query(Incidente).all()
        
        data = []
        if len(incidentes) < 10:
            print("Datos históricos insuficientes. Generando datos sintéticos de Distrito 8 para entrenamiento...")
            # Generar datos sintéticos para entrenamiento inicial si no hay suficientes incidentes
            # Distrito 8 El Alto: Latitudes [-16.55, -16.65], Longitudes [-68.15, -68.25]
            np.random.seed(42)
            n_samples = 200
            horas = np.random.randint(0, 24, n_samples)
            dias = np.random.randint(0, 7, n_samples)
            categorias = np.random.randint(1, 9, n_samples)
            lats = np.random.uniform(-16.65, -16.55, n_samples)
            lngs = np.random.uniform(-68.25, -68.15, n_samples)
            
            riesgos = []
            for h, c in zip(horas, categorias):
                # Generar riesgos realistas basados en la hora y la categoría
                if (h >= 20 or h <= 4) and c in [1, 2, 3]:
                    riesgos.append(2)  # Alto
                elif (h >= 18 or h <= 6) or c in [1, 2, 3, 4]:
                    riesgos.append(1)  # Medio
                else:
                    riesgos.append(0)  # Bajo
                    
            df = pd.DataFrame({
                "hora": horas,
                "dia_semana": dias,
                "categoria_id": categorias,
                "latitud": lats,
                "longitud": lngs,
                "nivel_riesgo_idx": riesgos
            })
        else:
            # Extraer características de la base de datos
            for inc in incidentes:
                hora = inc.fecha_reporte.hour
                dia_semana = inc.fecha_reporte.weekday()
                # Mapear nivel de riesgo a índice numérico
                riesgo_idx = self.reverse_risk_mapping.get(inc.nivel_riesgo, 0)
                
                data.append({
                    "hora": hora,
                    "dia_semana": dia_semana,
                    "categoria_id": inc.categoria_id,
                    "latitud": inc.latitud,
                    "longitud": inc.longitud,
                    "nivel_riesgo_idx": riesgo_idx
                })
            df = pd.DataFrame(data)

        # 2. Separar características y etiquetas
        X = df[["hora", "dia_semana", "categoria_id", "latitud", "longitud"]]
        y = df["nivel_riesgo_idx"]

        # Si solo tenemos una sola clase en y, agregar ejemplos de otras clases para no fallar el entrenamiento
        if len(y.unique()) < 3:
            # Forzar clases 0, 1 y 2 en los datos
            for r_idx in [0, 1, 2]:
                if r_idx not in y.values:
                    X = pd.concat([X, pd.DataFrame([[12, 2, 8, -16.60, -68.20]], columns=X.columns)], ignore_index=True)
                    y = pd.concat([y, pd.Series([r_idx])], ignore_index=True)

        # Split entrenamiento y prueba
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

        # 3. Inicializar y entrenar el MLPClassifier
        # Arquitectura: 2 capas ocultas de 100 y 50 neuronas
        clf = MLPClassifier(
            hidden_layer_sizes=(100, 50),
            activation="relu",
            solver="adam",
            max_iter=500,
            random_state=42
        )
        
        clf.fit(X_train, y_train)

        # 4. Evaluar el modelo
        y_pred = clf.predict(X_test)
        
        # Calcular métricas
        acc = accuracy_score(y_test, y_pred)
        prec = precision_score(y_test, y_pred, average="weighted", zero_division=0)
        rec = recall_score(y_test, y_pred, average="weighted", zero_division=0)
        f1 = f1_score(y_test, y_pred, average="weighted", zero_division=0)

        metrics = {
            "accuracy": float(acc),
            "precision": float(prec),
            "recall": float(rec),
            "f1_score": float(f1),
            "timestamp": datetime.now().isoformat(),
            "entrenado_con_sinteticos": len(incidentes) < 10,
            "total_muestras": int(len(X))
        }

        # 5. Guardar modelo y métricas en disco
        model_dir = os.path.dirname(settings.MODEL_PATH)
        if model_dir and not os.path.exists(model_dir):
            os.makedirs(model_dir, exist_ok=True)

        joblib.dump(clf, settings.MODEL_PATH)
        with open(settings.METRICS_PATH, "w") as f:
            json.dump(metrics, f, indent=4)

        # Cargar en el estado actual de la clase
        self.model = clf
        self.metrics = metrics

        return metrics

predictor = MLPredictor()
# Intentar cargar en la importación (si existe)
predictor.load_model()
