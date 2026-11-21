# Tareas para Codex / agente de desarrollo

Proyecto Garmin Connect IQ escrito en Monkey C. Partir de esta versión 0.4, no de versiones anteriores.

## Prioridad 1: compilar de verdad

1. Instalar el Garmin Connect IQ SDK y las definiciones de producto de `fr165` y `fr165m`.
2. Ejecutar `monkeyc -f monkey.jungle -o HorizonteCimas-fr165.prg -y developer_key.der -d fr165` y corregir **todos** los errores y avisos significativos del compilador, sin eliminar funcionalidades.
3. Abrir en el simulador `fr165` y verificar el ciclo de vida de la app, GPS, sensores, entradas, almacenamiento y recepción JSON de Connect IQ.
4. Comprobar Overpass QL con una posición real, que `convert peak` genera los tags `name`, `ele`, `la`, `lo`, que ambas consultas aparecen en `elements` y que se respetan los límites y condiciones del servidor.
5. Medir consumo de memoria, tamaño máximo de respuesta BLE y consumo energético.

Además, en 0.4:

- Confirmar que `retryAction` devuelve símbolos comparables con `==` en el dispositivo y que `ds has :connectionAvailable` compila sin aviso.
- Verificar en el simulador la cadena de servidores alternativos (forzar HTTP 406 o 429) y la reducción de cupos (forzar -402).
- Comprobar que `markHidden` no dispara el watchdog con 100 cimas en `fr165`.
- Calibrar `SLOPE_TAN` con vistas reales: Guadarrama desde Cercedilla y Oberland bernés desde Grindelwald.

## Prioridad 2: mejoras funcionales

- Sustituir el filtro por cupos de Overpass por una estrategia que encuentre las cumbres más relevantes sin depender del orden arbitrario del servidor.
- Medir y minimizar la latencia de la interfaz y las superposiciones de etiquetas en 390×390 y tamaños menores.
- Evaluar si el tamaño máximo de caché debe ajustarse dinámicamente por dispositivo.
- Oclusión con modelo del terreno (por ejemplo, perfiles precalculados en el servidor) si la pista actual resulta insuficiente.
- Soporte táctil (tocar una etiqueta para seleccionarla) en `fr165`/`venu`.

## Criterios de aceptación

- Compilación sin errores para `fr165` y `fr165m`.
- No hay cierres inesperados al no tener GPS, Internet o brújula.
- Descargas correctas con el móvil emparejado; tras cerrar y abrir la app, los datos cercanos persisten.
- Cambio de dirección al girar el reloj y al usar controles manuales.
- Una caché antigua de otra zona no se muestra como actual.
- Informe reproducible de las pruebas de simulador/hardware.
