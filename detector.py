"""Captura de cámara y detección de manos para integrar en la interfaz Tkinter."""
from pathlib import Path
import time

import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

MODEL_FILE = Path(__file__).resolve().with_name("hand_landmarker.task")


def dibujar_deteccion(frame, detection_result):
    """Dibuja el estado y los puntos detectados sobre un frame BGR."""
    alto, ancho = frame.shape[:2]
    if not detection_result.hand_landmarks:
        texto, color = "Buscando mano...", (0, 0, 255)
    else:
        texto, color = "Mano detectada", (0, 200, 0)
        for hand_landmarks in detection_result.hand_landmarks:
            for punto in hand_landmarks:
                x, y = int(punto.x * ancho), int(punto.y * alto)
                cv2.circle(frame, (x, y), 4, (0, 255, 0), -1)
    cv2.putText(frame, texto, (10, 28), cv2.FONT_HERSHEY_SIMPLEX,
                0.7, color, 2, cv2.LINE_AA)
    return frame


class MiCamara:
    """Entrega fotogramas de cámara ya procesados, sin crear ventanas OpenCV."""

    def __init__(self, indice=0):
        if not MODEL_FILE.exists():
            raise FileNotFoundError(f"No se encontró el modelo: {MODEL_FILE}")
        self.landmarker = None
        self.cap = cv2.VideoCapture(indice)
        if not self.cap.isOpened():
            self.cap.release()
            raise RuntimeError("No se pudo abrir la cámara.")

        base_options = python.BaseOptions(model_asset_path=str(MODEL_FILE))
        options = vision.HandLandmarkerOptions(
            base_options=base_options,
            num_hands=2,
            min_hand_detection_confidence=0.5,
            min_tracking_confidence=0.5,
            running_mode=vision.RunningMode.VIDEO,
        )
        self.landmarker = vision.HandLandmarker.create_from_options(options)
        self.ultimo_timestamp = -1

    def obtener_fotograma(self):
        """Retorna (éxito, frame BGR) para mostrar dentro de la ventana principal."""
        success, frame = self.cap.read()
        if not success:
            return False, None

        frame = cv2.flip(frame, 1)
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        imagen = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        timestamp = max(int(time.monotonic() * 1000), self.ultimo_timestamp + 1)
        self.ultimo_timestamp = timestamp
        resultado = self.landmarker.detect_for_video(imagen, timestamp)
        return True, dibujar_deteccion(frame, resultado)

    def liberar(self):
        if self.cap is not None:
            self.cap.release()
            self.cap = None
        if self.landmarker is not None:
            self.landmarker.close()
            self.landmarker = None
