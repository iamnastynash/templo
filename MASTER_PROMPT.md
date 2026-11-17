# Master prompt: tu propia app para la WHOOP 4.0

Copia todo lo que hay debajo de la línea y pégaselo a tu modelo de IA favorito (Claude, ChatGPT, Gemini…). Funciona mejor con un asistente que pueda usar tu terminal (por ejemplo Claude Code, Cursor o Codex). Puedes escribirle en tu idioma.

---

```text
Quiero construir mi propia app de iPhone para usar mi banda WHOOP 4.0 sin pagar
la membresía de WHOOP. Todo debe calcularse en mi teléfono, sin nube. Guíame paso
a paso y haz tú el trabajo en mi ordenador. Háblame siempre en mi idioma y explica
cada paso en palabras sencillas.

## 0. Antes de empezar, pregúntame

1. NOMBRE de la app. Ofréceme dos caminos:
   a) Elijo yo un nombre (dame 10 ideas cortas si no se me ocurre ninguno).
   b) Uso el nombre y el icono del repositorio público del que copié este
      prompt (te paso el enlace; están en su README y en assets/images/icon.png).
2. ICONO. Ofréceme:
   a) Diseñar uno nuevo: enséñame al menos 6 propuestas en una página HTML con
      SVG, a tamaño grande y a tamaño de pantalla de inicio, y déjame elegir.
   b) Usar el icono de ese mismo repositorio.
3. COLORES. Propón 3 o 4 paletas (un acento principal, un color para "algo
   cambió", un fondo claro y uno oscuro) o acepta la mía.
4. Mi edad, mi iPhone y su versión de iOS, y si tengo cuenta de Apple de pago.

Usa {APP_NAME} para el nombre elegido en todo lo que sigue.

## 1. La base: OpenStrap Edge

No escribas el Bluetooth desde cero. Haz un fork o clona
https://github.com/OpenStrap/edge (Flutter, AGPL-3.0). Ya resuelve: emparejar la
banda, descargar el historial, decodificar los datos y calcular recuperación,
sueño, HRV, esfuerzo y estrés en el teléfono.

- Lee su AGENTS.md antes de tocar nada y respeta sus reglas, sobre todo:
  NUNCA inventar un dato (si falta, se muestra "—" y se dice por qué), nada de
  cálculos pesados en el hilo de la interfaz, y comprobar `mounted` antes de usar
  el contexto después de un `await`.
- Usa la versión de Flutter que fija su CI (.github/workflows/test.yml).
- Comprueba que todo compila y que `flutter test` pasa ANTES de cambiar nada.
  Anota qué tests ya fallaban.
- Antes de emparejar: desvincula la banda de la app de WHOOP y desinstálala
  (puede actualizar el firmware y bloquear los datos).

## 2. Quita la marca de OpenStrap (lo pide su política de marca)

- Cambia "OpenStrap" por {APP_NAME} en todos los textos visibles: los ficheros
  .arb de todos los idiomas (y regenera con `flutter gen-l10n`), los textos de
  respaldo en el código Dart, los textos de permisos de ios/Runner/Info.plist,
  los widgets de iOS y las etiquetas de Android. NO cambies identificadores
  internos (nombres de paquetes, canales de plataforma, targets de Xcode,
  formatos de copias de seguridad): se rompería la app.
- Edita Info.plist como texto, no con PlistBuddy (borra comentarios que un test
  necesita).
- Corta toda conexión con sus servicios: no inicialices Firebase (es el proyecto
  de ellos; la app ya funciona sin él), quita "informes de fallos", "reportar un
  problema", "contribuir mis datos de salud" y los enlaces a su Discord, Reddit,
  GitHub y donaciones.
- Cambia los iconos (iOS, alternativo en blanco y negro, Android, imágenes de la
  app) y el nombre visible (CFBundleDisplayName, android:label).
- Deja el archivo LICENSE y una línea en Ajustes: "Basado en OpenStrap (AGPL-3.0)".

## 3. Diseño

- Ajusta los tokens del sistema de diseño (lib/ui2/theme.dart) a mi paleta, con
  modo claro y oscuro. Mantén el "solver" de contraste del proyecto: el texto
  tiene que pasar WCAG AA (4.5:1) y su test de contraste debe seguir en verde.
- Minimalista: un número protagonista grande por pantalla, como mucho tres datos
  de apoyo y una frase que diga qué hacer.
- Gráficas: curva suave, brillo suave, relleno que se desvanece hacia abajo, una
  animación que dibuja la línea una sola vez (sin bucles, y nada si el iPhone
  tiene "Reducir movimiento"). Colorea cada punto por lo BUENO que es su valor en
  una escala rojo → naranja → amarillo → verde lima (pulso en reposo bajo es
  bueno, HRV alta es buena, 8 h de sueño es bueno).
- Antes de programar cada pantalla, enséñame un mockup en HTML (modo día y
  noche) y espera mi aprobación.

## 4. Funciones nuevas (todas con datos que la banda ya da)

1. Salud cardiovascular (0–100), últimas 14 noches, 5 componentes:
   pulso en reposo (bueno ≤55, malo ≥70 lpm), HRV nocturna (bueno ≥60, malo
   ≤35 ms), consistencia del pulso (desviación entre noches: bueno ≤2, malo
   ≥6 lpm), caída nocturna del pulso (bueno ≥14 %, malo ≤2 %) y recuperación tras
   esfuerzo (bueno ≥20, malo ≤5 lpm). Cada uno a 0–100 lineal entre sus anclas;
   el puntaje es su media. Sin puntaje con menos de 7 noches o menos de 3
   componentes. Etiqueta Mejorando / Estable / Bajando comparando con las 14
   noches anteriores (umbral 3 puntos). NO uses SpO₂: la WHOOP 4.0 no da una
   lectura fiable.
2. Tendencia de 8 semanas: pulso en reposo, HRV y sueño, primera semana frente
   a la última, con media móvil de 7 lecturas en la gráfica.
3. Energía (estimación, dilo en pantalla): empieza en la recuperación al
   despertar (sin recuperación, no hay energía); cada minuto despierto resta un
   poco, más con esfuerzo (pulso ≥ reposo+20 moviéndose) o estrés (pulso ≥
   reposo+15 quieto); suma un poco en calma o durmiendo la siesta. Muestra qué
   la movió (sueño, sesiones, entrenamientos, reseteos).
4. Esfuerzo bueno frente a estrés: porcentaje del día, línea del tiempo y
   tramos de 10 minutos o más. Un minuto sin dato de movimiento no se clasifica.
5. Consejo del día: una frase basada en los datos de hoy.
6. Pestaña Enfoque (añádela AL FINAL de las pestañas para no romper las guías):
   - Sesiones de Trabajo y de Trading que NO cuentan como ejercicio ni se
     exportan a Apple Health.
   - Trading: botones "Entré en un trade" / "Salí", ganada o perdida, semáforo
     con el pulso en vivo frente a tu base despierto (calma hasta +5, alerta hasta
     +12, acelerado por encima), resumen con pico y media por trade, y con 20
     trades marcados una frase que compare el pulso al entrar en ganados y
     perdidos.
   - Guarda solo agregados (medias de 30 s), nunca el flujo en vivo crudo.
7. Reseteo: 60 s de respiración 4 s / 6 s guiada por la vibración de la banda.
   Solo cuando el usuario lo pulsa; la banda nunca vibra sola. Al final muestra
   cuánto bajó el pulso.
8. Edad del cuerpo (estimación): edad real más unos años acotados por hábito
   (VO2max, pulso en reposo, HRV, horas y regularidad del sueño, ejercicio
   semanal, estrés) en las últimas 4 semanas. Sin estimación con menos de 3
   hábitos o sin edad. Muestra qué suma y qué resta años.

Para cada función: lógica pura en lib/compute/, tests de unidad, pantalla con
tests de widget, y registra en sus tablas cualquier preferencia guardada nueva
(los tests de backup lo exigen).

## 5. Comprobar y entregar

- `flutter analyze` sin errores y `flutter test` sin fallos nuevos.
- Compila para el simulador y enséñame capturas en modo día y noche.
- Prepara la firma: copia ios/Config/Signing.xcconfig.example a
  Signing.xcconfig con identificadores únicos y mi Team ID (no lo subas a git).
- Instálala en mi iPhone con `flutter run --release -d <id>` y explícame cómo
  confiar en el desarrollador y activar el Modo desarrollador.
- Si mi iPhone tiene iOS 26, necesito Xcode 26 (macOS 15.6 o más nuevo).
- Guarda el trabajo en git con commits claros y no publiques mis datos
  personales (usa mi correo "noreply" de GitHub).

Recuerda: la licencia es AGPL-3.0. Si comparto mi versión, tengo que compartir
también su código. No es un dispositivo médico y no está afiliada con WHOOP.
```
