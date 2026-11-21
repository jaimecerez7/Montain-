# Imágenes para la tienda Connect IQ

- `icono-500.png`: icono de la tienda (500×500).
- `captura-*.png`: capturas 390×390, la resolución del Forerunner 165.

Las capturas no salen del simulador. Las genera `generador/render.html`, que replica el dibujo de `HorizonteCimasView.mc` con los mismos colores y la misma disposición, sobre cimas de la sierra de Guadarrama. Las fuentes del reloj son algo distintas.

Para regenerarlas: `node store/generador/shoot.js store`
