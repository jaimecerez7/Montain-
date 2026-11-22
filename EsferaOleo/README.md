# Óleo — esfera Garmin Connect IQ

Esfera independiente con el diseño **Óleo**: el fondo es la pintura al óleo naranja aportada por el usuario (`Esferas/tools/art/oleo.png`). En el reloj aparece como **Óleo** en la lista de esferas, sin menús para elegir obra.

- **Hora como cartela**, arriba a la izquierda: las horas en Jost negrita y los minutos finos, con la fecha en óxido.
- **Datos en el crema de abajo a la derecha**, alineados con la curva de la pantalla:
  - tiempo y probabilidad de lluvia;
  - pasos;
  - próximo amanecer o atardecer;
  - luna en su fase;
  - batería en cinco puntos.
- **Sol y luna** se calculan en el reloj. La ubicación sale de la actividad en curso o de la última posición GPS del reloj (permiso *Positioning*). Si no hay ninguna, se usa una aproximada (el centro de España).
- **Siempre encendida (AMOLED):** solo la hora y la fecha en gris, desplazándose unos píxeles cada minuto.

Comparte el código de dibujo con `Esferas/` (`Astro.mc`, `Draw.mc`, `FaceData.mc` y `Themes.mc` son copias).
