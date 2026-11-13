# Plan de desarrollo — v1.0 temprana (4 días)

**Proyecto:** Prueba_JuegoFrutas (Godot 4.6.3, GL Compatibility)
**Objetivo del documento:** definir el alcance realista de una versión temprana jugable y agradable a la vista,
por fases y con un máximo de 4 días de trabajo, usando como base lo que ya existe en el repositorio.
**Estado:** documento de planificación. No se implementa nada todavía.

---

## 1. Visión y objetivo

Juego de recolección de frutas controlado con la **posición de la mano detectada por cámara**, pensado como
herramienta de **rehabilitación** donde el movimiento y la coordinación se entrenan jugando en lugar de con
ejercicios repetitivos.

Para que funcione como herramienta terapéutica y no como un juego frustrante, la v1 debe cumplir tres cosas:

1. **Sesiones cortas y claras** (90 segundos), con resultado visible y reinicio inmediato.
2. **Dificultad que sube sola con el tiempo**, sin castigar de más: los errores cuestan vidas, pero el jugador
   puede recuperarlas jugando bien (combo).
3. **Estímulo visual y sonoro suficiente** para que dan ganas de jugar otra partida, sin depender de arte complejo.

La personalización **no entra completa** en estos 4 días, pero sí se deja preparada la capa de datos
(monedas + guardado) y una vitrina mínima opcional, para ampliarla después sin rehacer nada.

---

## 2. Estado actual del proyecto

### 2.1 Inventario de lo que existe

| Archivo / nodo | Qué hace hoy | Estado |
|---|---|---|
| `project.godot` | Proyecto Godot 4.6, escena principal, autoload `Detector` | ✅ |
| `Assets/Scene/Scene_1.tscn` | Escena de juego: jugador, plataforma, cámara, spawner, HUD de cámara | ✅ base |
| `Assets/Character/character_body_2d.tscn` | Jugador `CharacterBody2D` + sprite placeholders + áreas laterales | ✅ base |
| `Assets/Scripts/Mouse.gd` | Movimiento horizontal por UDP (izquierda/derecha/centro) + hover de mouse | ◐ |
| `Fruits/Fruit.tscn` + `Fruits/fruits.gd` | Fruta genérica `Area2D`: se dibuja por código, cae, se autodestruye, detecta recogida | ✅ |
| `Assets/Scripts/FruitSpawner.gd` | Spawn en X aleatoria arriba, presets de color/puntos/radio/velocidad, intervalo aleatorio | ✅ |
| `Assets/Scene/fruit_spawner.tscn` | Nodo spawner con `Timer` | ✅ |
| `Assets/python/detector.py` | MediaPipe: detecta mano, envía control (4242) y video JPEG + metadatos (4243) | ✅ |
| `Assets/Scripts/PythonBridge.gd` | Autoload que lanza y cierra `detector.py` con el juego | ✅ |
| `Assets/Scene/CameraHUD.tscn` + `CameraHUD.gd` | Ventana inferior central con la vista de cámara, estado y variables | ✅ |
| `Assets/Character/l_side.tscn`, `r_side.tscn` | Áreas auxiliares de hover (legado del control por mouse) | ◐ reutilizable |
| `Assets/python/hand_landmarker.task` | Modelo de MediaPipe | ✅ |
| Arte, audio, música | No existe (todo es `icon.svg` y formas dibujadas) | ❌ |

### 2.2 Capacidades del juego

| Capacidad | Estado | Nota |
|---|---|---|
| Ventana con escena principal | ✅ | 1152×648 por defecto, cámara centrada en el origen |
| Cámara + detección de mano | ✅ | Funciona y ya se probó de punta a punta |
| Envío de video al juego | ✅ | 320 px de ancho, ~20 fps, JPEG por UDP |
| Generación aleatoria de frutas | ✅ | 5 tipos por preset, velocidades variables |
| Recolección por contacto | ✅ | Emite señal y busca un HUD (que aún no existe) |
| Movimiento con la mano | ✅ | Ya sigue la posicion real de la mano sujeta al margen |
| Puntaje | ✅  | Ya suman las frutas puntuacion entre 10 -> 15 -> 30, se implemento el HUD |
| Vidas (3) | ❌ | No implementadas |
| Objetos peligrosos | ❌ | No existen |
| Combo / reponer vida | ❌ | No existe |
| Dificultad dinámica | ❌ | Intervalo y velocidad son fijos |
| Menú, pausa, fin de partida | ❌ | La escena arranca directo |
| Fondo y piso con arte | ❌ | Solo un sprite placeholder y una plataforma |
| Sonido / música | ❌ | Sin nodos de audio |
| Animaciones | ❌ | Sin `AnimationPlayer` ni `Tween` |
| Personalización / guardado | ❌ | No hay persistencia |
| Fallback sin cámara (mouse/teclado) | ❌ | Riesgo alto para demos |

---

## 3. Diseño jugable propuesto (con ajustes)

### 3.1 Ciclo jugable

```
Menú → Partida (90 s) → Resultado → Menú / Otra vez
              ↑
   pausa (Esc) → continuar / salir
```

- **Partida de 90 s.** Suficiente para notar la curva de dificultad y corta para no agotar al paciente.
- Al terminar: puntaje, frutas, mejor racha, vidas restantes, monedas ganadas, mejor puntaje histórico.
- **Reinicio en un clic** (o con la mano, ver 3.6).

### 3.2 Decisión: personaje (confirmado por el equipo)

El jugador será un **personaje** que se desplaza horizontalmente, no una canasta. Implicaciones para 4 días:

- La lógica es la misma que con cualquier otro sprite: sigue la mano y atrapa frutas por contacto.
- El costo extra está en la animación. Para la v1 alcanza con **idle (2–4 frames) + desplazamiento
  (4 frames) + daño (1) + festejo (2)**, resueltos con `Sprite2D`/`AnimatedSprite2D`.
- Ciclo de caminata completo, salto y transiciones quedan **fuera de la v1** (backlog).
- La personalización futura pasa a ser **skins de personaje** (igual de simple que con canasta).
- El sprite actual es un placeholder (`icon.svg` escalado): se reemplaza sin tocar la lógica de movimiento.

Los tamaños y formatos exactos están en la **sección 11 (Especificación de assets)**.

### 3.3 Reglas base

| Regla | Decisión propuesta | Motivo |
|---|---|---|
| Vidas | 3, máximo 3 | Pedido del equipo; pocas para sesiones cortas |
| Daño | Solo los objetos peligrosos quitan vida | Castigar frutas perdidas es muy punitivo en rehabilitación |
| Fruta perdida | Rompe la racha, no quita vida | Mantiene la tensión sin castigar el error motriz |
| Invulnerabilidad | 1.5 s tras recibir daño | Evita perder las 3 vidas por un solo choque |
| Combo | 10 frutas seguidas sin daño → +1 vida (si hay menos de 3) | Da una meta clara y recuperación |
| Puntaje | 10/15/20/25/30 según fruta + bonus por racha | Valores ya definidos en los presets |
| Monedas | 1 moneda por cada 100 puntos | Economía simple para personalización |
| Fin de partida | Se acaba el tiempo o se llega a 0 vidas | Dos formas de terminar, ambas con resultado |

### 3.4 Dificultad dinámica (por tiempo de partida)

Cuatro tramos dentro de los 90 s. Los valores son un punto de partida para *playtest*, no una verdad final.

| Tramo | Tiempo | Intervalo entre frutas | Velocidad de caída | % de peligros | Máx. simultáneas |
|---|---|---|---|---|---|
| 1 | 0–20 s | 1.1 – 1.5 s | 140 – 170 | 0 % | 3 |
| 2 | 20–45 s | 0.8 – 1.2 s | 160 – 200 | 12 % | 4 |
| 3 | 45–70 s | 0.6 – 0.9 s | 180 – 230 | 20 % | 4 |
| 4 | 70–90 s | 0.45 – 0.75 s | 210 – 270 | 28 % | 5 |

Reglas de implementación del director de dificultad:

- Un solo lugar decide los parámetros (`difficulty`), no el spawner por su cuenta.
- Los tramos se interpolan (rampa suave) para que el jugador no sienta "saltos".
- El tramo 1 es intencionalmente fácil: sirve de calentamiento y de calibración de la mano.
- Opcional (post-v1): ajuste adaptativo si el jugador va muy bien o muy mal.

### 3.5 Objetos peligrosos

Máximo **1 tipo** en la v1: una bomba (círculo oscuro con mecha y brillo, misma física de caída).
Diferenciación por **forma y sonido**, no solo por color (accesibilidad para daltonismo).

- Al impactar: −1 vida, parpadeo del jugador, flash rojo breve, sonido grave, racha a 0.
- Segunda variante (fruta podrida) solo si sobra tiempo: mismo comportamiento, otro dibujo.
- Regla de generación: % definido por el tramo; nunca dos peligros seguidos en el tramo 1–2.

### 3.6 Control por mano (cambio de fondo necesario)

Hoy `detector.py` envía solo `"izquierda" / "derecha" / "centro"`. Para que el personaje **siga la posición
de la mano** se propone:

- Enviar `palma_x` normalizado (0–1) en cada captura, no solo el lado.
- Mapear `palma_x` al rango horizontal del área de juego con márgenes.
- **Suavizado** (interpolación exponencial) para eliminar el temblor del detector.
- **Zona muerta** del 3–5 % en los extremos.
- **Pérdida de mano:** el jugador se detiene donde está (no salta al centro ni a un extremo).
- **Calibración opcional:** durante los primeros 3 s el juego pide estirar la mano a ambos lados y guarda
  los límites reales del paciente. Es barato y mejora mucho la sensación.
- En menús y pantalla de resultados, la mano funciona como "cursor" por zonas (izquierda/centro/derecha),
  reutilizando el protocolo actual.

### 3.7 Enfoque rehabilitación (requisitos no funcionales)

- Amplitud de movimiento útil: el rango calibrado se estira a todo el ancho jugable (no exigir estiramientos extremos).
- Sin castigos sonoros agresivos; el error se comunica con un sonido neutro y un flash suave.
- **Modo suave** (sin objetos peligrosos) activable en ajustes: útil en etapas tempranas de rehabilitación.
- Descanso: aviso discreto cada 3 partidas ("puedes descansar").
- Registro local de sesión (opcional si hay tiempo): duración, frutas, impactos, rango alcanzado.

### 3.8 Personalización: espacio reservado

No se implementa completa en 4 días, pero se deja preparada:

- **Monedas** ganadas por partida y acumuladas en `user://perfil.cfg`.
- **Skins de personaje** (3) y **paletas de fondo** (2) desbloqueables por monedas.
- Tienda mínima con 2 ítems; el resto queda como catálogo ampliable.
- Nada de compras reales: solo progreso del jugador.

Si el día 4 se queda corto, **se corta la tienda** y se conservan monedas + guardado, que es lo caro.

---

## 4. Alcance de los 4 días

### 4.1 Lo que entra (Must)

| # | Funcionalidad |
|---|---|
| 1 | Movimiento continuo por posición de mano + calibración básica |
| 2 | Fallback con mouse/teclado si no hay cámara |
| 3 | Estados de juego: menú, jugando, pausa, resultado |
| 4 | Puntaje, 3 vidas, combo de 10 → +1 vida |
| 5 | Objetos peligrosos (1 tipo) con daño e invulnerabilidad |
| 6 | Dificultad dinámica por tramos |
| 7 | HUD legible: puntos, vidas, tiempo, racha |
| 8 | Fondo estático + piso con arte simple y coherente |
| 9 | Música de fondo + 6 efectos de sonido |
| 10 | Animaciones mínimas: pop de fruta, flash de daño, idle + desplazamiento del personaje |
| 11 | Guardado local (mejor puntaje, monedas, ajustes) |

### 4.2 Lo que entra solo si hay tiempo (Should / Could)

| Prioridad | Funcionalidad |
|---|---|
| Should | Tienda mínima con 2 skins/paletas |
| Should | Pantalla de resultado con estadísticas de la partida |
| Could | Segunda variante de peligro (fruta podrida) |
| Could | Registro de sesión exportable (CSV) |
| Could | Modo suave + ajustes de sensibilidad en menú |

### 4.3 Lo que NO entra (post-v1)

- Animaciones completas de personaje / ciclo de caminata.
- Múltiples escenarios, fondos animados o parallax.
- Tutorial guiado con voz.
- Ranking en línea, cuentas, nube.
- Versión móvil/táctil.
- Sistema de niveles o misiones diarias.
- Arte definitivo.

---

## 5. Plan por días

> Supuesto: **1 desarrollador Godot** a ~6 h/día + **apoyo de arte/audio** en paralelo (~3–4 h/día) +
> **1 sesión de validación con terapeuta/usuario** al final del día 3. Total ~24 h de desarrollo.
> Si el equipo es de una sola persona sin apoyo de arte, ver "líneas de corte" en la sección 7.

### Día 1 — Núcleo jugable

| Tarea | Horas | Detalle |
|---|---|---|
| Control continuo por mano | 2.0 | `palma_x` por UDP, mapeo a rango, suavizado, zona muerta, pérdida de mano |
| Calibración de rango | 0.5 | 3 s al inicio, límites guardados |
| Fallback mouse/teclado | 0.5 | Permite jugar y demostrar sin cámara |
| `Game` (autoload): estados, puntaje, vidas, señales | 1.5 | Única fuente de verdad |
| HUD de juego | 1.0 | Puntos, 3 vidas, temporizador, racha |
| Fin de partida + reinicio | 0.5 | Overlay simple, sin arte final |

**Entregable:** se puede jugar una partida de 90 s de principio a fin, con puntaje, vidas y reinicio.
**Criterio de aceptación:** mover la mano izquierda/derecha mueve el personaje de forma fluida; al terminar el
tiempo aparece el resultado y se puede volver a jugar sin reiniciar el juego.

### Día 2 — Riesgo y curva

| Tarea | Horas | Detalle |
|---|---|---|
| Objeto peligroso (bomba) | 1.5 | Misma base que la fruta, marcado como peligro |
| Daño, invulnerabilidad y feedback | 1.0 | −1 vida, 1.5 s de gracia, flash + sonido |
| Combo y reposición de vida | 1.0 | 10 seguidas → +1 vida, contador visible |
| `DifficultyDirector` | 2.0 | Tramos, intervalos, velocidades, % de peligros |
| Playtest y ajuste de números | 0.5 | Solo valores, no funciones nuevas |

**Entregable:** partida completa con riesgo creciente y recompensa por racha.
**Criterio de aceptación:** la partida se nota más difícil a los 60 s que a los 10 s; perder las 3 vidas
termina la partida; llegar a 10 frutas seguidas devuelve una vida.

### Día 3 — Presentación

| Tarea | Horas | Detalle |
|---|---|---|
| Fondo estático + piso | 2.0 | Cielo/degradado, huerto simple, línea de piso, sombra del personaje |
| Personaje: arte base + idle/desplazamiento | 1.0 | 4–6 frames en total, pivote en los pies |
| Coherencia visual de frutas | 0.5 | Paleta, contorno, sombra suave, tamaños legibles |
| Música + 6 SFX | 1.5 | Recolectar, combo, daño, vida extra, botón, fin |
| Animaciones mínimas | 1.0 | Tween: pop de fruta, bob del personaje, flash, parpadeo de invulnerabilidad |

**Entregable:** la versión "se ve y se siente" como un juego, no como un prototipo.
**Criterio de aceptación:** sin audio el juego se entiende, con audio se disfruta; no hay elementos visuales
que se confundan con el fondo; 60 fps estables.

### Día 4 — Pulido, personalización mínima y cierre

| Tarea | Horas | Detalle |
|---|---|---|
| Guardado local | 1.0 | Mejor puntaje, monedas, ajustes, skin elegida |
| Tienda mínima (si hay tiempo) | 2.0 | 2 ítems, compra con monedas, aplicar skin |
| Menú de inicio + resultado | 1.0 | Nombre, jugar, ajustes, mejor puntaje |
| QA + build exportado | 1.5 | Prueba en 2 resoluciones, detector empaquetado, sin errores en consola |
| Ajustes finales de balance y textos | 0.5 | Ortografía, valores, volumen |

**Entregable:** build ejecutable que se puede entregar a un terapeuta y jugar sin el editor de Godot.
**Criterio de aceptación:** doble clic en el ejecutable → menú → partida → resultado → otra partida, sin
intervención técnica y sin errores visibles.

### Dependencias y paralelización

- Día 1 es bloqueante para todo lo demás.
- Arte/audio del día 3 puede empezar el día 1 en paralelo (entrega de assets).
- La tienda depende del guardado (día 4); si falla el guardado, la tienda se corta.

---

## 6. Arquitectura técnica propuesta

### 6.1 Autoloads

| Autoload | Responsabilidad |
|---|---|
| `Detector` | Ya existe: lanza y cierra `detector.py` |
| `Game` | Estado de partida, puntaje, vidas, racha, señales (`score_changed`, `life_lost`, `game_over`) |
| `Datos` | Lectura/escritura de `user://perfil.cfg` (mejor puntaje, monedas, ajustes, skins) |
| `Audio` | Reproducción de SFX y música, volumen por bus |

### 6.2 Escenas

```
Menu.tscn            → botones + ajustes + mejor puntaje
Game.tscn            → la actual Scene_1, renombrada y ordenada
  Player (personaje)
  FruitSpawner
  DifficultyDirector
  Fondo / Piso
  UI/HUD.tscn        → puntos, vidas, tiempo, racha
  UI/CameraHUD.tscn  → vista de cámara (ya existe)
  UI/Pausa.tscn
  UI/Resultado.tscn
Tienda.tscn          → opcional día 4
```

### 6.3 Protocolo UDP (propuesta)

| Puerto | Contenido | Frecuencia |
|---|---|---|
| 4242 | Control: `{"x": 0.42, "mano": true}` (o texto legado `izquierda/derecha/centro`) | FPS de cámara (~30) |
| 4243 | Video JPEG + metadatos (ya implementado) | 20 fps |

El control debe ir **separado del video**: si el video se baja a 10 fps para ahorrar CPU, el movimiento
no debe perder fluidez.

### 6.4 Layout: conflicto a resolver

El `CameraHUD` actual mide **380×266** y está anclado abajo al centro; la zona de captura (personaje y piso)
también está abajo al centro. Si no se ajusta, **el panel tapa al jugador**.

Propuesta: reducir el panel a ~**300×200** (video ~284×132) y subir la línea de piso a la altura de la
mitad inferior, dejando el espacio del panel libre. Alternativa: mantener el tamaño y permitir ocultarlo
con **F1** (útil de todos modos para partidas grabadas o para el terapeuta).

### 6.5 Capas de colisión sugeridas

| Capa | Uso |
|---|---|
| 1 | Jugador |
| 2 | Frutas recogibles |
| 3 | Peligros |
| 4 | Piso / mundo |

Evita tener que corregir máscaras a mitad de semana.

---

## 7. Riesgos y líneas de corte

| Riesgo | Probabilidad | Mitigación | Si ocurre |
|---|---|---|---|
| Latencia/temblor del detector | Media | Suavizado, zona muerta, calibración | Bajar sensibilidad y filtrar más |
| Cámara no disponible en la demo | Media | Fallback mouse/teclado (día 1) | Se demuestra igual |
| Pérdida de paquetes UDP | Baja | Interpolación y descarte de datos viejos | Aumentar tolerancia |
| Arte no entregado a tiempo | Alta | Estilo plano por código, paleta fija | Se usa el estilo procedural actual, más pulido |
| La tienda se lleva más de 2 h | Media | Se corta; quedan monedas + guardado | Post-v1 |
| Falta de tiempo para audio | Media | 3 SFX mínimos (recoger, daño, fin) | Se corta la música, no los SFX |
| Panel de cámara tapa el juego | Alta | Rediseño de layout (6.4) | Ocultar con F1 por defecto en partida |

**Orden de sacrificio si el cronograma se atrasa:**

1. Tienda / personalización visual (se conserva el guardado).
2. Segunda variante de peligro.
3. Animaciones (quedan solo pop y flash).
4. Música (quedan SFX).
5. Pantalla de resultado detallada (queda un overlay con puntaje y botón).

**Nunca se sacrifica:** control por mano, vidas, dificultad dinámica, HUD, reinicio, fallback sin cámara.

---

## 8. QA y definición de terminado

### 8.1 Checklist funcional

- [ ] Partida completa de 90 s sin errores en consola.
- [ ] 3 vidas visibles y funcionales; daño reduce exactamente 1 y da 1.5 s de gracia.
- [ ] 10 frutas seguidas devuelven 1 vida (sin pasar de 3).
- [ ] Los peligros no aparecen en el tramo 1 y aumentan por tramo.
- [ ] El puntaje y la racha coinciden con lo que se ve en pantalla.
- [ ] Reinicio y salida al menú funcionan en cualquier momento.
- [ ] Pérdida de mano: el jugador se detiene, no salta.
- [ ] Sin cámara: el juego arranca y se puede jugar con mouse/teclado.
- [ ] Ajustes de volumen persisten al reiniciar.

### 8.2 Checklist visual y de rendimiento

- [ ] HUD legible a 1280×720 y 1920×1080.
- [ ] El panel de cámara no tapa al jugador ni las frutas.
- [ ] 60 fps estables en el equipo objetivo (medido con el monitor de depuración).
- [ ] Sin textos de depuración (`print`) en la versión final.
- [ ] Paleta coherente: fondo, frutas y HUD comparten 4–6 colores base.

### 8.3 Validación con usuario (día 3)

Sesión de 15–20 minutos con una persona del perfil objetivo o el terapeuta:

- ¿Se entiende qué hay que hacer sin explicación?
- ¿El movimiento se siente natural o "pegajoso"?
- ¿La cámara resulta invasiva o molesta en pantalla?
- ¿El cansancio aparece antes de los 90 s?

Se ajustan **solo números** (velocidad, sensibilidad, duración, tamaño de frutas), no se agregan funciones.

---

## 9. Backlog posterior (después de los 4 días)

| Prioridad | Ítem |
|---|---|
| Alta | Sistema de animación completo (caminata, salto, celebraciones), partículas de recolección |
| Alta | Reporte de sesión para el terapeuta (CSV/PDF: duración, aciertos, impactos, rango) |
| Alta | Modo suave y perfiles de paciente (rangos de calibración guardados) |
| Media | Tienda ampliada: 6–10 skins, paletas de fondo, desbloqueos por hitos |
| Media | Más escenarios estáticos (huerto, cocina, mercado) |
| Media | Tutorial guiado y recordatorios de descanso |
| Media | Ajuste adaptativo de dificultad según desempeño |
| Baja | Ranking local por paciente, logros |
| Baja | Versión táctil / móvil, sincronización en la nube |

---

## 10. Anexos

### 10.1 Parámetros iniciales sugeridos (para el playtest)

| Parámetro | Valor |
|---|---|
| Duración de partida | 90 s |
| Vidas | 3 |
| Invulnerabilidad tras daño | 1.5 s |
| Frutas para recuperar vida | 10 seguidas |
| Velocidad del jugador | 420–520 px/s (movimiento continuo, no por velocidad fija) |
| Suavizado del control | factor ~12 por segundo |
| Margen lateral del área de juego | 60 px |
| Monedas | 1 por cada 100 puntos |

### 10.2 Fuentes de arte y audio (CC0 recomendadas)

- **Kenney.nl** — packs de frutas, UI, iconos (CC0).
- **OpenGameArt.org** — música de fondo y efectos (verificar licencia por archivo).
- **Freesound.org** — efectos puntuales (filtrar CC0).
- **Google Fonts** — tipografía para el HUD (licencia OFL).

Registrar la licencia de cada asset en `Assets/Audio/CREDITOS.md` y `Assets/Art/CREDITOS.md`.

### 10.3 Estructura de carpetas propuesta

```
Assets/
  Art/Fondos/  Art/UI/  Art/Personaje/  Art/Frutas/
  Audio/Musica/  Audio/SFX/
  Character/  Scene/  Scripts/  python/
Documentacion/
```

### 10.4 Ritual diario de 15 minutos

1. Demo de 2 minutos al final del día, jugada en vivo.
2. Se actualiza este documento marcando lo hecho y lo cortado.
3. Se decide si se activa alguna línea de corte para el día siguiente.

---

## 11. Especificación de assets (tamaños, formato y nitidez)

> Decisión del equipo: **el jugador es un personaje**. Esta sección define qué pedirle al artista/ilustrador
> para que nada se vea borroso ni desproporcionado.

### 11.1 Reglas base

- **Resolución de diseño:** 1152 × 648 (la ventana actual). Todos los tamaños de la tabla están en
  "px de pantalla" a esa resolución.
- **Exportar al doble (×2):** cubre 1920×1080 y ventanas maximizadas sin pixelarse. Si algún día se apunta
  a 4K, exportar ×3.
- **`Sprite2D.scale` siempre en (1, 1):** el tamaño se define en el archivo, nunca escalando el nodo.
  (Hoy el placeholder usa `scale = 0.40625`; al reemplazarlo hay que volver a 1.)
- **Filtro de textura:** `Linear`. En hojas de sprites, **mipmaps desactivados** para que no se mezclen
  frames vecinos. Solo si algún día se pasa a pixel art: `Nearest` + escala entera y todo el juego a 320×180.
- **Formato:** PNG con transparencia para personaje, frutas y UI; WebP/JPEG de calidad alta para fondos.
- **Pivote del personaje:** pies, centro-abajo. Todos los frames de una animación con el **mismo tamaño de
  lienzo**, aunque el dibujo no lo llene.
- **Recomendado en `project.godot`:** `display/window/stretch/mode = canvas_items` y
  `aspect = expand`, para que la ventana escale el lienzo completo en vez de mostrar más mundo.

### 11.2 Tabla de tamaños

| Asset | Tamaño en pantalla (base 1152×648) | Exportar | Formato | Notas |
|---|---|---|---|---|
| **Personaje** (hoja de sprites) | Frame **96 × 128** | **192 × 256** | PNG alfa | Cuerpo de ~64–72 × 96–110 dentro del lienzo; margen para brazos y saltos |
| Personaje — frames | idle 2–4, desplazamiento 4, daño 1, festejo 2 | igual | PNG alfa | Todos con el mismo lienzo de 96×128; pivote en los pies |
| **Fruta** (cada tipo) | 36–60 (2 × radio del preset) | **128 × 128** todas | PNG alfa | Un lienzo común de 128 y escalar por preset, o exportar cada una a 2× de su diámetro |
| **Peligro** (bomba) | 56–64 | **128 × 128** | PNG alfa | Silueta inconfundible; si tiene mecha animada, hoja de 4 frames |
| **Corazón / vida** | 24 × 24 | **48 × 48** | PNG alfa o SVG | 3 estados: lleno, vacío, ganado |
| **Moneda** | 24 × 24 | **48 × 48** | PNG alfa o SVG | — |
| **Iconos de UI** (pausa, sonido, casa) | 24 × 24 | **48 × 48** | SVG preferido | Godot rasteriza el SVG al importar |
| **Marco del panel de cámara** | 300 × 200 | **600 × 400** | PNG con 9-slice | Márgenes de 24 px para estirar sin deformar |
| **Fondo de juego** | 1152 × 648 | **2304 × 1296** | WebP/PNG | Sin texto; zona importante en el centro 1152×648; prever recorte lateral |
| **Piso / plataforma** | 1152 × 160 | **2304 × 320** | PNG | Repetible horizontalmente; sin sombra "horneada" que delate el tile |
| **Fondo de menú** | 1152 × 648 | **2304 × 1296** | WebP | — |
| **Logo / icono** | 512 × 512 | **1024 × 1024** | PNG | Además 128×128 para el icono del ejecutable |
| **Fuente de UI** | 16 / 20 / 24 / 32 px | — | TTF | Licencia OFL; nunca texto dentro de imágenes |

### 11.3 Nombres de archivo

```
Art/Personaje/personaje_idle_01.png
Art/Personaje/personaje_walk_01.png
Art/Personaje/personaje_hurt_01.png
Art/Frutas/fruta_manzana.png
Art/Frutas/fruta_sandia.png
Art/Fondos/fondo_huerto.webp
Art/Fondos/piso_madera.png
Art/UI/ui_corazon_lleno.png
Art/UI/ui_moneda.png
```

Todo en minúsculas, sin espacios ni acentos (evita problemas en export y en Git).

### 11.4 Checklist anti-borrosidad

- [ ] El asset se exportó al **doble** del tamaño en pantalla.
- [ ] `scale` del `Sprite2D` en (1, 1); el `CharacterBody2D` raíz **nunca** se escala.
- [ ] Filtro Linear (o Nearest si es pixel art) y mipmaps off en hojas de sprites.
- [ ] Mismo tamaño de lienzo en todos los frames de una animación.
- [ ] Pivote en los pies y `offset` coherente; el `CollisionShape2D` coincide con el cuerpo visible.
- [ ] Se probó a **1280×720**, **1920×1080** y ventana maximizada.
- [ ] El fondo cubre pantallas 16:9 y ultrawide sin bordes negros.
- [ ] Textos y números van en `Label`, no dibujados en la imagen.
- [ ] Mismo grosor de contorno y misma paleta entre personaje, frutas y peligros.

### 11.5 Presupuesto de arte para los 4 días

| Prioridad | Assets |
|---|---|
| **Obligatorio** | Personaje (idle + desplazamiento), 5 frutas, 1 peligro, fondo + piso, corazón, moneda, marco del panel |
| **Deseable** | Iconos de UI, fondo de menú, logo, 2 frames de daño/festejo |
| **Post-v1** | Caminata completa, salto, skins, partículas ilustradas, escenarios alternativos |

Si el arte no llega a tiempo, se mantiene el estilo procedural actual (formas + paleta) y se reemplaza
después: la lógica no depende de los archivos, solo del tamaño y del pivote.
