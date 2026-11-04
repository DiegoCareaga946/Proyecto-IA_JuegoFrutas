"""Ventana principal del juego con la cámara integrada en la esquina superior izquierda."""
import tkinter as tk
from tkinter import ttk

import cv2
from PIL import Image, ImageTk

from detector import MiCamara

ANCHO_CAMARA = 320
ALTO_CAMARA = 240


class JuegoFrutasApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Juego de recolección de frutas")
        self.root.geometry("1000x650")
        self.root.minsize(800, 520)
        self.cerrando = False
        self.after_id = None
        self.camara = None
        self.foto = None

        contenedor = ttk.Frame(root, padding=16)
        contenedor.pack(fill="both", expand=True)
        contenedor.columnconfigure(1, weight=1)
        contenedor.rowconfigure(1, weight=1)

        ttk.Label(contenedor, text="Vista de la mano", font=("Segoe UI", 12, "bold")).grid(
            row=0, column=0, sticky="w", pady=(0, 6)
        )
        self.video = ttk.Label(contenedor, text="Iniciando cámara...", anchor="center")
        self.video.grid(row=1, column=0, sticky="nw")

        ttk.Label(contenedor, text="Recolección de frutas", font=("Segoe UI", 16, "bold")).grid(
            row=0, column=1, sticky="w", padx=(20, 0), pady=(0, 6)
        )
        self.escena = tk.Canvas(contenedor, background="#dff4ff", highlightthickness=0)
        self.escena.grid(row=1, column=1, sticky="nsew", padx=(20, 0))
        self.escena.create_text(
            20, 30, anchor="nw",
            text="El área de juego aparecerá aquí.",
            fill="#25445a", font=("Segoe UI", 14),
        )

        self.estado = ttk.Label(contenedor, text="Conecta tu mano frente a la cámara.")
        self.estado.grid(row=2, column=0, columnspan=2, sticky="w", pady=(12, 0))
        self.root.protocol("WM_DELETE_WINDOW", self.cerrar)

        try:
            self.camara = MiCamara()
        except (RuntimeError, FileNotFoundError) as error:
            self.video.configure(text=str(error), width=42, wraplength=ANCHO_CAMARA)
            self.estado.configure(text="No se pudo iniciar la detección.")
            return
        self.actualizar_video()

    def actualizar_video(self):
        if self.cerrando or self.camara is None:
            return
        success, frame = self.camara.obtener_fotograma()
        if success:
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            imagen = Image.fromarray(frame).resize((ANCHO_CAMARA, ALTO_CAMARA))
            self.foto = ImageTk.PhotoImage(imagen)
            self.video.configure(image=self.foto, text="")
        else:
            self.video.configure(text="No se recibió imagen de la cámara.", image="")
        self.after_id = self.root.after(15, self.actualizar_video)

    def cerrar(self):
        self.cerrando = True
        if self.after_id is not None:
            self.root.after_cancel(self.after_id)
            self.after_id = None
        if self.camara is not None:
            self.camara.liberar()
            self.camara = None
        self.root.destroy()


if __name__ == "__main__":
    ventana = tk.Tk()
    app = JuegoFrutasApp(ventana)
    ventana.mainloop()
