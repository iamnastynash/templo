# Métricas de Templo

## Revisar una sesión de Enfoque

- El indicador de Enfoque usa tu pulso habitual como referencia. Entra en Alerta cuando la lectura llega al umbral mayor entre 80 lpm y tu base +12. Entra en Acelerado a partir del mayor entre 95 lpm y tu base +22. Son umbrales de la interfaz para esta actividad.

- La línea usa el pulso sincronizado de la banda principal cuando cubre al menos el 65 % de la sesión. En los demás casos usa promedios guardados durante la sesión. Entrada, salida y reseteo se marcan en sus instantes reales.
- La referencia de una operación es la mediana del minuto anterior con poco movimiento. Si faltan muestras, se puede mostrar el pulso que estaba en pantalla al entrar por separado del cálculo de la vuelta. La vuelta exige señal posterior a la salida, poco movimiento y al menos 10 segundos dentro de ±5 lpm, antes de otra operación y dentro de cinco minutos. Sin una subida superior a 5 lpm no hay un episodio de recuperación que cronometrar.
- La carga de pulso integra la parte por encima de la referencia, en lpm·min. Excluye intervalos sin señal. La referencia toma primero el minuto previo en reposo, después el reseteo reciente y, si hay suficientes lecturas, el inicio de la sesión anterior al primer trade. El resumen muestra el tiempo cubierto.
- Las comparaciones semanales muestran medianas y recuentos para Trabajo y Trading, noches por debajo o encima de tu mediana, trades ganados y perdidos, y reseteos antes y después. Un día se agrupa por el recuento de operaciones marcadas, sin inferir P&L. Las asociaciones son descriptivas.

## Respiración, diario y noche

- La tarjeta de Respiración guiada marca cuatro segundos de inhalación y seis de exhalación durante un minuto. La app usa vibración de banda cuando hay enlace y vibración del teléfono cuando no. Guarda el pulso inicial si está disponible y el promedio final solo si recibe suficientes lecturas. Puedes iniciar Trading tras completar el minuto.
- La comparación de fase toma la mediana de la diferencia de pulso derivado de intervalos entre latidos en ciclos con datos a ambos lados. Requiere al menos cuatro ciclos. La pantalla de coherencia cardíaca conserva su propia duración y sus criterios de señal.
- El diario rápido reutiliza el diario local y compara el sueño registrado la noche siguiente a días con la etiqueta frente a días registrados sin ella. Requiere al menos tres noches por grupo.
- La comparación nocturna usa la mediana y la desviación absoluta mediana de hasta 28 noches previas, con un mínimo de siete datos y un margen específico por métrica.
- Pulso al mismo ritmo compara kilómetros completos con GPS y pulso suficiente, trazado y dirección similares y una diferencia de ritmo de hasta 20 s/km. La comparación entre mitades compara kilómetros de ritmo similar dentro de la carrera seleccionada.

## Oxígeno y compatibilidad

Templo puede guardar el valor entregado por un oxímetro que anuncie el servicio de [Pulse Oximeter Service](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/PLXS_v1.0.1/out/en/index-en.html), una entrada manual o mostrar las mediciones importadas de WHOOP desde el gráfico de SpO₂. Las lecturas Bluetooth y manuales guardan su fuente y el momento en que Templo las recibió o anotó. El decodificador descarta valores especiales y mediciones marcadas como inválidas, de demostración o con señal cuestionable.

El diagnóstico de señal de WHOOP cuenta las muestras rojo/IR sincronizadas de un tramo reciente y las diferencias entre canales. Los datos expuestos por el [decodificador de OpenStrap](https://github.com/OpenStrap/protocol) no establecen una lectura validada de oxígeno. Antes de habilitarla desde una banda concreta, hace falta que esta entregue una lectura derivada inequívoca o que se valide una señal óptica independiente contra un instrumento de referencia. Las lecturas del oxímetro también tienen [limitaciones de medición](https://www.fda.gov/medical-devices/products-and-medical-procedures/pulse-oximeters).
