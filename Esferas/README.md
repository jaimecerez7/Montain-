# Esferas Pintadas 0.1 — esfera Garmin Connect IQ

Una esfera con tres estilos pictóricos, que se elige en **Garmin Connect → Dispositivo → Esferas → Esferas Pintadas → Ajustes → Estilo**.

| Estilo | Composición | Qué cuenta el dibujo |
|---|---|---|
| **Campos de color** | Bandas azul, óxido y crema de borde difuso | La línea de la banda óxido es el día: el punto avanza del amanecer al atardecer |
| **Orgánica** | Formas suaves en la periferia y centro burdeos liso | Las formas enmarcan los datos sin quedar detrás del texto |
| **Trazos** | Papel crema, pinceladas azules y una curva | Las **pinceladas son tus pasos** de los 7 días anteriores más hoy (el trazo claro), con altura relativa a tu objetivo. La **curva es la trayectoria real del sol** hoy y el punto naranja marca dónde está ahora |

## Datos

- **Hora y fecha:** respetan el formato de 12 o 24 h del reloj.
- **Tiempo:** el icono del estado, la temperatura y la probabilidad de lluvia vienen de Garmin Connect. Cuando no hay datos se muestra «--».
- **Amanecer y atardecer:** se **calculan en el reloj** con el algoritmo de la NOAA a partir de la última ubicación conocida, que sale del tiempo o de una actividad.
- **Pasos:** los de hoy, el objetivo y el historial de 7 días.
- **Luna:** el porcentaje de iluminación y el dibujo de la fase, también calculados en el reloj.

## Tipografía y composición

- **Jost**, una geométrica libre (licencia SIL OFL, en `tools/fonts/OFL.txt`), convertida a fuentes de mapa de bits para cinco resoluciones (260, 280, 390, 416 y 454 px) con `tools/make_fonts.py`.
- **Dígitos tabulares:** la hora no se desplaza al cambiar de minuto.
- **Tres niveles de jerarquía:**
  1. hora: Jost Light;
  2. fecha: versalitas espaciadas;
  3. datos: Jost Regular.
- Sin barras separadoras: los grupos se separan con aire y se centran como bloque.
- Iconos dibujados con el mismo grosor de trazo, sin depender de los glifos del reloj.

## Pantalla siempre encendida (AMOLED)

En reposo, los relojes AMOLED (FR165, FR265, FR965, Venu, Epix) muestran solo la hora y la fecha en gris sobre negro, con muy pocos píxeles encendidos. La posición se desplaza unos píxeles cada minuto para evitar marcas permanentes en la pantalla. Los relojes MIP (fēnix, FR255/955) mantienen la esfera completa.

## Pendiente de comprobar en el reloj

- **Memoria:** la fuente de la hora es grande, y los relojes antiguos (fēnix 6 Pro) tienen poca memoria para esferas.
- **Tiempo:** que el reloj reciba los datos del tiempo y la ubicación. Sin ubicación, el amanecer y el atardecer muestran «--:--» hasta tenerla.

Las capturas de `store/` las genera `store/generador/`, que replica el dibujo de `source/Themes.mc` con datos de ejemplo (Madrid, 21 de noviembre, 13:47).
