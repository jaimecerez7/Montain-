# Radar Vuelos 0.2 — Garmin Connect IQ (Monkey C)

Apunta el reloj hacia un avión y descubre qué vuelo es: **indicativo, aerolínea, tipo de avión, matrícula, altitud, distancia y cuántos grados sobre el horizonte** tienes que mirar.

## Cómo funciona

1. **Tu posición:** la da el GPS del reloj, y al abrir la app basta la última posición conocida.
2. **Los aviones:** cada 10 s el reloj pide a través del móvil los aviones que hay a menos de 25 millas náuticas (~46 km). Los datos vienen de [adsb.lol](https://adsb.lol), una red abierta de receptores ADS-B. Si falla dos veces seguidas, se usa [OpenSky Network](https://opensky-network.org) como reserva.
3. **Movimiento suave:** entre descargas, cada avión avanza en línea recta con su velocidad y su rumbo. La estimación se limita a 60 s, así que los aviones se mueven en tiempo real en la pantalla.
4. **Hacia dónde apuntas:** la brújula del reloj orienta el radar para que **arriba sea la dirección de tu brazo**. La cuña sombreada marca ±20°. El avión seleccionado es el más centrado en la cuña, con desempate a favor del más cercano.
5. **Elevación:** a partir de la altitud del avión, la distancia y la curvatura de la Tierra se calcula a cuántos grados sobre el horizonte está.

## Aviones sobre tu cabeza

Si un avión está a más de 60° sobre el horizonte, queda **seleccionado automáticamente**, apuntes donde apuntes. Muy cerca de la vertical, su dirección cambia demasiado rápido para depender de la cuña. La línea gris indica «Sobre tu cabeza», el ángulo pasa a «cénit» por encima de 85° y el reloj **vibra una vez** con cada avión que cruza por encima.

## Batería

- **GPS:** funciona en continuo solo hasta el primer fijo bueno. Después toma una lectura cada 2 minutos. Para aviones a decenas de km, unos cientos de metros de error no cambian nada, y el GPS continuo es lo que más gasta.
- **Descargas:** se hacen cada 10 s si hay aviones cerca y cada 30 s si no hay ninguno. Tras un error, cada 20 s.
- **Memoria:** se guardan como máximo 40 aviones. Si la respuesta es demasiado grande, el radio se reduce automáticamente.

Todo esto no se ha medido en un reloj real, porque no hay simulador. El consumo real queda por comprobar.

## Pantalla

- **Radar:** tú estás en el centro. La «N» marca el norte y el número indica el alcance del anillo exterior en km.
- **Aviones:** son flechas que apuntan hacia donde vuela cada uno. El color indica la altitud:
  - naranja: menos de 1 500 m (despegando o aterrizando);
  - azul: menos de 6 000 m;
  - blanco: crucero.
- **Línea gris:** el tipo y la matrícula del avión seleccionado, o el número de aviones y la antigüedad de los datos.
- **Ficha:** el indicativo y la aerolínea; debajo, la altitud (▲), la distancia (↔) y el ángulo sobre el horizonte.

## Controles

| Control | Acción |
|---|---|
| START / SELECT | Fijar el avión seleccionado o soltarlo. Fijado, indica «Gira N° a la derecha/izquierda» |
| ARRIBA / ABAJO | Alcance del radar: 10 / 25 / 50 km |
| Menú (mantener ARRIBA) | Alternar entre brújula y norte arriba |
| BACK | Salir |

Sin lectura de brújula, el radar pasa a **norte arriba** y la cuña apunta al norte.

## Límites

- **Sin ruta de origen a destino:** el servicio público de rutas de adsb.lol no respondía en las pruebas. La aerolínea se deduce del indicativo, por ejemplo IBE → Iberia.
- **Retraso:** los datos llegan con unos segundos de retraso más la conexión del móvil. Entre descargas, la posición es una estimación.
- **Cobertura:** solo aparecen los aviones que emiten ADS-B y están al alcance de algún receptor de la red. Los aviones militares y algunos privados pueden faltar.
- **Brújula:** como en Horizonte Cimas, conviene calibrarla y llevar el reloj horizontal.
- **Memoria:** se guardan como máximo los 40 aviones más cercanos. Si la respuesta es demasiado grande para el reloj, el radio baja a 15 y después a 8 millas náuticas.

## Privacidad

Para pedir los aviones, la app envía tu posición **redondeada a 0,01° (~1 km)** a adsb.lol, u OpenSky si se usa la reserva. No envía nada más.

## Datos

Datos de aviones © colaboradores de [adsb.lol](https://adsb.lol) (ODbL) y [OpenSky Network](https://opensky-network.org).

## Compilación

Se compila automáticamente en GitHub Actions junto a Horizonte Cimas (`.github/workflows/build-garmin.yml`). El resultado es el artefacto **RadarVuelos**: un `.iq` para la tienda y los `.prg` para fr165 y fr165m.

Las capturas de `store/` se generan con `node store/generador/shoot.js store`. Replican el dibujo de `RadarView.mc` con datos de ejemplo, no salen del simulador.
