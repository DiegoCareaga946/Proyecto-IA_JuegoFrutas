"""Captura de cámara y detección de manos para enviar controles a Godot."""
from pathlib import Path
import json
import socket
import struct
import time

import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision


MODEL_FILE = Path(__file__).resolve().with_name("hand_landmarker.task")

# Controles: "izquierda" / "derecha" / "centro" (lo escucha Mouse.gd).
DESTINO = ("127.0.0.1", 4242)

# Video para el HUD del juego (lo escucha CameraHUD.gd).
DESTINO_VIDEO = ("127.0.0.1", 4243)
CABECERA_FRAME = struct.Struct("<3sIHH")  # "FRM" + seq + trozo + total
CABECERA_META = b"MTA"
TROZO_MAX = 60000
FPS_VIDEO = 20
ANCHO_VIDEO = 320
CALIDAD_JPEG = 60


def dibujar_deteccion(frame, detection_result):
    """Dibuja el estado y los puntos detectados sobre un fotograma BGR."""
    alto, ancho = frame.shape[:2]

    if not detection_result.hand_landmarks:
        texto, color = "Buscando mano...", (0, 0, 255)
    else:
        texto, color = "Mano detectada", (0, 200, 0)
        for hand_landmarks in detection_result.hand_landmarks:
            for punto in hand_landmarks:
                x = int(punto.x * ancho)
                y = int(punto.y * alto)
                cv2.circle(frame, (x, y), 4, (0, 255, 0), -1)

    cv2.putText(
        frame,
        texto,
        (10, 28),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        color,
        2,
        cv2.LINE_AA,
    )
    return frame


class MiCamara:
    """Captura fotogramas, detecta la mano y envía su lado a Godot."""

    def __init__(self, indice=0):
        if not MODEL_FILE.exists():
            raise FileNotFoundError(f"No se encontró el modelo: {MODEL_FILE}")

        self.udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.udp_video = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.cap = cv2.VideoCapture(indice)

        if not self.cap.isOpened():
            self.cap.release()
            self.udp.close()
            self.udp_video.close()
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

        self.seq = 0
        self.tiempo_ultimo_video = 0.0
        self.fps_video = 0.0

    def obtener_fotograma(self):
        """Retorna (éxito, fotograma BGR) y envía el control a Godot."""
        success, frame = self.cap.read()
        if not success:
            return False, None

        # Voltea la imagen como espejo antes de detectar la mano.
        frame = cv2.flip(frame, 1)
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        imagen = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

        timestamp = max(
            int(time.monotonic() * 1000),
            self.ultimo_timestamp + 1,
        )
        self.ultimo_timestamp = timestamp

        resultado = self.landmarker.detect_for_video(imagen, timestamp)

        mano = bool(resultado.hand_landmarks)
        lado = "centro"
        palma_x = 0.0

        if mano:
            puntos = resultado.hand_landmarks[0]
            palma_x = sum(puntos[i].x for i in (0, 5, 9, 13, 17)) / 5

            if palma_x < 0.45:
                lado = "izquierda"
            elif palma_x > 0.55:
                lado = "derecha"
            else:
                lado = "centro"

        self.udp.sendto(lado.encode("utf-8"), DESTINO)

        frame = dibujar_deteccion(frame, resultado)
        self._enviar_video(frame, mano, lado, palma_x)

        return True, frame

    def _enviar_video(self, frame, mano, lado, palma_x):
        """Envía metadatos y el fotograma en JPEG por UDP, limitado a FPS_VIDEO."""
        ahora = time.monotonic()
        if self.tiempo_ultimo_video > 0.0:
            intervalo = ahora - self.tiempo_ultimo_video
            if intervalo < 1.0 / FPS_VIDEO:
                return
            fps_actual = 1.0 / intervalo
            self.fps_video = (
                fps_actual
                if self.fps_video == 0.0
                else self.fps_video * 0.9 + fps_actual * 0.1
            )
        self.tiempo_ultimo_video = ahora

        alto, ancho = frame.shape[:2]
        if ancho > ANCHO_VIDEO:
            escala = ANCHO_VIDEO / ancho
            frame = cv2.resize(frame, (ANCHO_VIDEO, int(alto * escala)))

        alto, ancho = frame.shape[:2]
        meta = {
            "mano": mano,
            "lado": lado,
            "palma_x": round(palma_x, 3),
            "fps": round(self.fps_video, 1),
            "ancho": ancho,
            "alto": alto,
        }
        self.udp_video.sendto(
            CABECERA_META + json.dumps(meta).encode("utf-8"),
            DESTINO_VIDEO,
        )

        ok, buffer = cv2.imencode(
            ".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), CALIDAD_JPEG]
        )
        if not ok:
            return

        datos = buffer.tobytes()
        self.seq = (self.seq + 1) & 0xFFFFFFFF
        total = (len(datos) + TROZO_MAX - 1) // TROZO_MAX

        for i in range(total):
            cabecera = CABECERA_FRAME.pack(b"FRM", self.seq, i, total)
            inicio = i * TROZO_MAX
            self.udp_video.sendto(
                cabecera + datos[inicio : inicio + TROZO_MAX],
                DESTINO_VIDEO,
            )

    def liberar(self):
        """Libera la cámara, el detector y los sockets UDP."""
        if self.cap is not None:
            self.cap.release()
            self.cap = None

        if self.landmarker is not None:
            self.landmarker.close()
            self.landmarker = None

        if self.udp is not None:
            self.udp.close()
            self.udp = None

        if self.udp_video is not None:
            self.udp_video.close()
            self.udp_video = None


# Este bloque está fuera de la clase MiCamara.
if __name__ == "__main__":
    camara = MiCamara()

    try:
        while True:
            success, _frame = camara.obtener_fotograma()
            if not success:
                break
    except KeyboardInterrupt:
        pass
    finally:
        camara.liberar()
