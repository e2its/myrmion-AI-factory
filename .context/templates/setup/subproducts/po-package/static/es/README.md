# ${project_name} — paquete del Product Owner

Paquete **${package_id}**. Te permite dar forma a la siguiente evolución del producto en un proyecto de Claude Desktop y devolver el resultado de manera que el lado de ingeniería pueda incorporarlo sin reescribirlo.

## Cómo se usa

1. Crea un proyecto en Claude Desktop.
2. Pega el contenido de **`PROJECT-INSTRUCTIONS.md`** en las instrucciones del proyecto. Cópialo del fichero `.md`, tal cual.
3. Sube al conocimiento del proyecto **`00-core/`**, **`10-design-system/`** y **`30-templates/`**.
4. **No** subas `20-features/`. Son los anexos pesados. Adjunta al chat sólo la carpeta de la feature sobre la que estés trabajando.
5. Comprueba que el proyecto lo ha entendido: pregúntale *"¿qué features están especificadas y cuáles están sólo en el roadmap?"*. Debe distinguir ${n_specified} de ${n_roadmap}. Si no puede, el conocimiento no se ha indexado; súbelo de nuevo.

Para trabajar sobre el **design system** en lugar de una feature, crea un segundo proyecto con **`PROJECT-INSTRUCTIONS-VISION.md`** (sólo viene cuando este paquete cubre el design system) y el mismo conocimiento.

## Qué hay dentro

| Carpeta | Subir al conocimiento | Qué es |
|---|---|---|
| `00-core/` | Sí | El producto en una página, el catálogo de features, el glosario, el mapa de rutas, el roadmap, las reglas del juego |
| `10-design-system/` | Sí | Guía de estilo, librería de componentes, tokens, la base de componentes y una tarjeta por componente |
| `20-features/` | **No** — se adjunta por chat | Los documentos vigentes de cada feature especificada |
| `30-templates/` | Sí | Los moldes de todo lo que devuelves |

## Los cuatro ficheros que más importan

- `00-core/domain-glossary.md` — el vocabulario cerrado. Mira aquí antes de nombrar nada.
- `00-core/rules-of-the-game.md` — qué puedes proponer y cuánto cuesta cada tipo de cambio.
- `10-design-system/components.md` — lo que ya existe para componer pantallas.
- `30-templates/ERQ-TEMPLATE.md` — cómo decir qué cambias y por qué.

## Qué se espera de vuelta

```
MANIFEST.yaml          <- índice de todo lo que traes
FEAT-XXX/
  ERQ.md               <- qué cambias y por qué
  user_journey.md      <- el recorrido y el contrato de negocio, completos
  spec.feature         <- los escenarios de comportamiento
  mock.html            <- la pantalla navegable, cuando la hay
VISION/                <- sólo en un retorno de design system
```

Envía retornos pequeños y a menudo: dos o tres features se revisan e incorporan en un día; doce tardan semanas, y para entonces el producto se ha movido por debajo.

Los documentos que devuelves se leen con las **mismas** comprobaciones automáticas que el lado de ingeniería aplica a los suyos. Un informe limpio significa que tu retorno se puede revisar. No significa que esté aceptado: después cada cambio se decide uno a uno, y recibes por escrito qué entró y qué no.
