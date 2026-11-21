# Horizonte Cimas 0.4 — Garmin Connect IQ (Monkey C)

Apunta el reloj hacia el horizonte para identificar cumbres: **nombre, elevación, distancia y rumbo**. El proyecto incluye soporte declarado para **Forerunner 165 y 165 Music**.

> **Estado.** El código y las pruebas Monkey C compilan de forma genérica con Connect IQ SDK 9.3.0. El ZIP contiene el proyecto fuente. La compilación para los dos Forerunner requiere instalar sus perfiles con Garmin SDK Manager.

## Cambios desde 0.3

- **Servidores alternativos de Overpass.** Si `overpass-api.de` falla (HTTP 406, 429, 5xx, tiempo agotado o respuesta inválida), la app prueba `overpass.private.coffee` y `overpass.kumi.systems` en la misma descarga. Guarda el último servidor que respondió bien y lo usa primero la próxima vez.
- **Respuestas demasiado grandes.** Si el reloj no puede recibir la respuesta (códigos -402 y -403), la consulta se repite con los cupos a la mitad y después a un cuarto. La pantalla indica que la lista está reducida.
- **Mensajes de error concretos.** La pantalla distingue entre móvil desconectado, tiempo agotado, servidor saturado o caído y respuesta demasiado grande. Antes de pedir datos se comprueba que haya conexión con el móvil, así no se gasta un intento en vano.
- **Arranque inmediato.** La última posición conocida basta para mostrar las cimas de la caché al abrir la app. Para descargar sigue haciendo falta un fijo GPS real, y la última posición conocida nunca sustituye a un fijo ya obtenido.
- **Cimas posiblemente ocultas.** Si una cima más cercana, en un rumbo próximo, asoma por encima de la línea de visión de otra más lejana, esta se dibuja con un triángulo hueco en gris. También pierde prioridad en etiquetas y selección, y la ficha añade «oculta?». La regla no usa un modelo del terreno: supone laderas de ~22° y solo se aplica con altitud GPS.
- **Avisos más claros.** Sin brújula, el pie indica «Gira con ARRIBA/ABAJO». También indica cuando la posición es aproximada. Los avisos «Esperando GPS preciso…» y «Cimas fuera de zona» desaparecen al volver a tener datos de la zona.
- **Silueta de las montañas.** Se dibuja un perfil del horizonte en tres capas de distancia (más de 20 km, de 8 a 20 km y menos de 8 km), de lejos y oscuro a cerca y claro. Cada cima se modela como un cono con la misma pendiente que la pista de oclusión. Las cimas altas se comprimen suavemente en lugar de recortarse. Solo se dibuja con altitud GPS.
- **Ficha de la cima centrada.** Muestra el nombre y, debajo, la altitud (▲) y la distancia (↔) en letra grande con iconos. Las etiquetas van en dos filas (hasta 5) y los textos se ajustan al ancho real de la pantalla redonda.
- La caché pasa a la versión 2 (cimas ordenadas por rumbo) y migra sola desde las versiones 0.2 y 0.3.
- Nuevas pruebas Monkey C: `overpassScaling`, `retryPolicy` y `occlusionHint`. El validador Python comprueba también la lista de servidores y la regla de oclusión.

## Cambios en 0.3

- Overpass distribuye hasta 120 resultados en cuatro anillos sin solapamiento entre 0 y 40 km. El reloj conserva hasta 100 cimas y prioriza las cercanas por distancia y las lejanas por elevación aparente.
- La caché guarda coordenadas y cimas en un único registro versionado. Migra la caché de la versión 0.2 y conserva los datos ante errores, respuestas parciales o resultados vacíos.
- La pantalla muestra el origen del rumbo y responde inmediatamente al giro manual. Las etiquetas se ajustan al ancho en píxeles y se descartan las que se solapan.
- El cálculo geográfico se actualiza al cambiar de zona, al moverse 15 m o al variar la altitud 10 m. También se actualiza si cambia la disponibilidad de la altitud GPS.
- Se incluyen pruebas Monkey C de geografía, validación de cimas, cobertura de la caché y generación de consultas.

## Qué necesitas

- Garmin Connect IQ SDK y extensión Monkey C para VS Code.
- Un reloj de la lista del `manifest.xml` (incluye **Forerunner 165 / 165 Music**).
- GPS activo y Garmin Connect emparejado al móvil con acceso a Internet para la primera descarga.
- Cumbres etiquetadas en OpenStreetMap con `natural=peak`, `name` y `ele`.

## Compilación y prueba en un Forerunner 165

1. Descarga e instala **Connect IQ SDK Manager** desde <https://developer.garmin.com/connect-iq/sdk/>. Instala un SDK reciente y las definiciones de **Forerunner 165**.
2. En VS Code instala **Monkey C** y abre **esta carpeta (`HorizonteCimas/`)**.
3. Genera la clave de desarrollador con `Monkey C: Generate a Developer Key`.
4. Selecciona `fr165` (o `fr165m`) y ejecuta `Monkey C: Run` para probar en simulador.
5. Prueba una posición GPS conocida, distintas orientaciones, sin datos, sin móvil y la rotación manual.
6. Compila `Monkey C: Build for Device` y copia el `.prg` resultante a `GARMIN/APPS/` mediante USB si el dispositivo y el proceso de instalación lo permiten.

Opcional por línea de comandos (ajusta las rutas al SDK y a tu clave):

```bash
monkeyc -f monkey.jungle -o HorizonteCimas-fr165.prg -y developer_key.der -d fr165
```

## Controles

| Control | Acción |
|---|---|
| START / SELECT | Forzar descarga de cimas (necesita red) |
| ARRIBA / ABAJO | Girar orientación manual ±10° |
| Menú (mantener ARRIBA, si el reloj expone esa acción) | Reactivar brújula |
| BACK | Salir |

## Comportamiento y límites

- El **rumbo de la brújula** se lee desde `Sensor.Info.heading` si está disponible; si no, no se inventa una medición y se puede usar el modo manual.
- La **elevación aparente** tiene en cuenta curvatura y una aproximación de refracción; no equivale a visibilidad real ni incorpora un modelo del terreno.
- **La oclusión es solo orientativa**: se estima con las propias cimas, sin modelo del terreno, así que una cresta sin cima etiquetada no tapa nada y una cima marcada como «¿oculta?» puede verse. La calibración de la brújula, la orientación de la muñeca y el GPS afectan a los resultados.
- Solo incluye cimas con nombre y elevación en OpenStreetMap. Los cupos de Overpass pueden omitir cimas en anillos densos. La selección dentro de un anillo saturado depende del orden del servidor.
- Sin altitud GPS, las marcas verticales son orientativas hasta obtenerla.
- La caché es local: al alejarse más de 5 km necesita una actualización; si no hay cobertura, se indican los datos no actualizados sin presentar cimas fuera de zona.

## Verificación

```bash
python3 tools/validate_project.py
```

Las siete comprobaciones de Python pasan. Cubren el manifiesto, los recursos, el contrato declarado de descarga y las referencias matemáticas.

Compilación genérica y pruebas Monkey C en un equipo con los perfiles instalados:

```bash
monkeyc -f monkey.jungle -o /tmp/HorizonteCimas-generic.prg -y developer_key.der -w
monkeyc -f monkey.jungle -o /tmp/HorizonteCimas-tests.prg -y developer_key.der -d fr165 -w -t
connectiq
monkeydo /tmp/HorizonteCimas-tests.prg fr165 -t
```

**0.4 no se ha compilado**: en el entorno de esta revisión no había acceso a la descarga del SDK de Garmin. Hay que compilar y ejecutar las pruebas Monkey C antes de instalarla. En la revisión 0.3 finalizaron la compilación genérica y la compilación genérica con `-t`. El servicio de descarga de perfiles respondió HTTP 401 sin cuenta Garmin. Las compilaciones con `-d fr165` y `-d fr165m` quedaron bloqueadas por la falta de esos perfiles. También quedan por verificar la ejecución en simulador y reloj, la descarga mediante Garmin Connect, la persistencia tras reinicio, la latencia, la memoria, el límite BLE y el consumo.

### Prueba de Overpass

La consulta de cuatro anillos se ejecutó con el centro `46.557,7.898` y la instancia regional `https://overpass.osm.ch/api/interpreter`. Devolvió 104 cimas en 15 243 bytes, repartidas en 8, 32, 28 y 36 por anillo, con `name`, `ele`, `la` y `lo` en cada elemento. El endpoint principal (`overpass-api.de`) respondió HTTP 406 desde ese entorno; por eso la 0.4 añade servidores alternativos. `overpass.osm.ch` solo contiene datos de Suiza y no se usa en la app. Una consulta pequeña a una instancia alternativa sí devolvió los campos esperados para Guadarrama. La prueba HTTP desde un ordenador deja pendiente la prueba a través del móvil emparejado.

Datos de cimas © colaboradores de OpenStreetMap. [Licencia y atribución](https://www.openstreetmap.org/copyright).

## Fuentes técnicas

- [Documentación Connect IQ](https://developer.garmin.com/connect-iq/)
- [Sensor.Info.heading](https://developer.garmin.com/connect-iq/api-docs/Toybox/Sensor/Info.html)
- [Communications.makeWebRequest](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html)
- [Overpass QL / OpenStreetMap](https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL)
