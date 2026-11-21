# Tareas para Codex / agente de desarrollo

Proyecto Garmin Connect IQ escrito en Monkey C. Partir de esta versión 0.2, no de la versión original.

## Prioridad 1: compilar de verdad

1. Instalar el Garmin Connect IQ SDK y las definiciones de producto de `fr165` y `fr165m`.
2. Ejecutar `monkeyc -f monkey.jungle -o HorizonteCimas-fr165.prg -y developer_key.der -d fr165` y corregir **todos** los errores y avisos significativos del compilador, sin eliminar funcionalidades.
3. Abrir en el simulador `fr165` y verificar el ciclo de vida de la app, GPS, sensores, entradas, almacenamiento y recepción JSON de Connect IQ.
4. Comprobar Overpass QL con una posición real, que `convert peak` genera los tags `name`, `ele`, `la`, `lo`, que ambas consultas aparecen en `elements` y que se respetan los límites y condiciones del servidor.
5. Medir consumo de memoria, tamaño máximo de respuesta BLE y consumo energético.

## Prioridad 2: mejoras funcionales

- Sustituir el filtro por cupos de Overpass por una estrategia que encuentre las cumbres más relevantes sin depender del orden arbitrario del servidor.
- Añadir persistencia versionada y migración de caché cuando cambie su formato.
- Mostrar si el rumbo es de brújula o manual; evitar confundirlo con el rumbo del desplazamiento GPS.
- Medir y minimizar la latencia de la interfaz y las superposiciones de etiquetas en 390×390 y tamaños menores.
- Evaluar si el tamaño máximo de caché debe ajustarse dinámicamente por dispositivo.
- Añadir pruebas Monkey C en `Toybox.Test` cuando el SDK esté disponible.

## Criterios de aceptación

- Compilación sin errores para `fr165` y `fr165m`.
- No hay cierres inesperados al no tener GPS, Internet o brújula.
- Descargas correctas con el móvil emparejado; tras cerrar y abrir la app, los datos cercanos persisten.
- Cambio de dirección al girar el reloj y al usar controles manuales.
- Una caché antigua de otra zona no se muestra como actual.
- Informe reproducible de las pruebas de simulador/hardware.
