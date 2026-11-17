# Prompt maestro para crear tu app de bienestar

Copia el bloque en tu asistente de programación. Puedes adjuntar un logotipo o indicar la URL de una referencia visual.

```text
Actúa como desarrollador sénior de Flutter especializado en Bluetooth LE, almacenamiento local y accesibilidad. Construye una app móvil de bienestar que permita sincronizar una pulsera compatible y consultar sus métricas en el teléfono.

IDENTIDAD
- Nombre de la app: [NOMBRE ELEGIDO POR EL USUARIO].
- Logotipo: [ARCHIVO O URL ELEGIDOS POR EL USUARIO] o [CREA UN LOGOTIPO ORIGINAL].
- Identidad de referencia, si quiero conservarla: [NOMBRE EXACTO] y [ARCHIVO DEL LOGOTIPO]. Permite reutilizar ambos tal cual si te confirmo que tengo permiso para usarlos.
- Plataformas: [IPHONE, ANDROID O AMBAS]. Modelo y firmware de la pulsera: [MODELO Y FIRMWARE].
- Pregúntame por los campos pendientes antes de fijar la marca, los identificadores de bundle y paquete, o el alcance del dispositivo. Elige por defecto una interfaz original con tema claro y oscuro.

BASE TÉCNICA
- Crea un proyecto nuevo Flutter/Dart. Usa como referencias OpenStrap Edge, OpenStrap Protocol y OpenStrap Analytics. Si hay una base con licencia compatible, verifica sus dependencias y reutiliza los módulos abiertos de BLE y métricas con versiones fijadas. Conserva atribuciones, avisos e historial cuando derives código. Documenta las fuentes y los términos de redistribución.
- Mantén separados Bluetooth, decodificación, persistencia local SQLite, cálculo y UI. Guarda cada lote antes de confirmarlo, maneja sincronizaciones parciales y duplicados, y muestra el estado de permisos, conexión, historial y señal. Usa la interfaz documentada del dispositivo y trata el firmware que requiere autorización del fabricante como una limitación de compatibilidad.
- Los datos de salud permanecen en el teléfono por defecto. Desactiva telemetría y servicios remotos por defecto. Usa datos sintéticos para demos y pruebas. Mantén claves, firma y registros personales fuera del repositorio.

PANTALLAS
- Hoy: recuperación, sueño, esfuerzo, energía estimada a lo largo del día y desglose de actividad frente a carga en reposo. Explica qué señales sustentan cada estimación.
- Sueño: duración, horario y tendencias; muestra fases solo si el dato está disponible.
- Enfoque: sesiones de trabajo y trading iniciadas por el usuario. Si hay pulso en vivo, compáralo con la referencia personal. Permite marcar operaciones, registrar su resultado y revisar la sesión. Incluye una pausa respiratoria con hápticos iniciada manualmente y usa el teléfono como alternativa si la pulsera no ofrece esa capacidad.
- Salud: pulso en reposo, HRV, resumen cardiovascular, tendencia de ocho semanas y estimación de edad corporal si hay una ventana de datos suficiente. Describe fórmulas y límites. Identifica las estimaciones como indicadores de bienestar y señala de forma expresa cuándo faltan datos.

ENTREGA Y VALIDACIÓN
- Implementa primero una demo navegable con datos sintéticos, luego conexión real y sincronización. Conserva un modo demo claramente identificado.
- Añade pruebas de cálculo, datos ausentes, persistencia, reconexión y UI. Ejecuta análisis y pruebas. Documenta los resultados y deja identificadas las verificaciones que requieran un teléfono o pulsera reales.
- Deja un README con origen, licencia, limitaciones por firmware y pasos reproducibles para configurar dependencias, firmar en iOS y compilar en Android. Incluye instrucciones para sustituir nombre, iconos, tema y bundle ID. Entrega comandos verificados y una lista de archivos clave.
```
