# Paquete del PO — runbook del operador

Cómo hacer CODESIGN con un Product Owner que trabaja fuera del repositorio, en un proyecto de Claude Desktop. Este fichero se basta solo: funciona antes de que esté instalado el skill `factory-po-intake` (el skill llega con `factory-sync.sh`, no con SETUP). Cuando el skill está presente, conduce estos mismos pasos.

## Este proyecto

Lo resuelve `SETUP --generate`. Actualiza este bloque a mano si la configuración cambia después (apartado 8).

- Proyecto: **{{PROJECT_NAME}}**
- Modo del paquete: **{{PO_PACKAGE_MODE}}** (`full` = design system y features · `features-only`)
- Las tarjetas del design system salen de: **{{DS_CARDS_SOURCE}}**
- Comando de reconstrucción: `{{DS_REBUILD_COMMAND}}`
- Workflow de CI: {{DS_CI_WORKFLOW_STATUS}}

Apartado de design system activo: **{{DS_ACTIVE_SECTION}}**

## El bucle

```
  Fábrica                PO (Claude Desktop)            Fábrica
 ┌─────────┐   zip →    ┌──────────────────┐   zip →   ┌──────────────────────┐
 │ genera  │            │ una feature, o   │           │ valida · ratifica ·  │
 │ paquete │            │ el design system │           │ sincroniza · catálogo│
 └─────────┘            └──────────────────┘           └──────────────────────┘
```

Nada de lo que devuelve el PO se aplica automáticamente, y nada se regenera: lo ratificado se incorpora tal como viene escrito.

## 1. Generar el paquete

Primero la exportación del roadmap. Pídesela al agente: *"exporta el roadmap para el paquete del PO"*. Lee el tablero con `/backlog --status` (el adaptador, nunca el tracker directamente) y escribe `roadmap.json` fuera del repositorio: una lista JSON de `{"id", "name", "summary"}` con cada feature del tablero que todavía no tiene carpeta `docs/spec/<ID>/`. Después:

```bash
python3 subproducts/po-package/build_po_package.py --roadmap ../roadmap.json
```

El generador lee el repositorio y escribe **fuera** de él: un árbol intermedio en la carpeta temporal del sistema (o `PO_PACKAGE_OUT`, o `--out`) y un zip en `~/Downloads` (o `--zip-dir`). Nunca llama al tracker. Sin `--roadmap` el paquete simplemente no lleva roadmap.

Antes de enviar, lee lo que ha impreso: el número de features, el número de tarjetas y cada `WARNING`. Un glosario vacío significa que no se pudo leer ningún journey: arréglalo primero, la regla del vocabulario cerrado no tiene de dónde agarrarse.

## 2. Montar el proyecto de Claude Desktop

El zip trae su propio `README.md` para el PO. En corto: proyecto nuevo → pegar **todo** `PROJECT-INSTRUCTIONS.md` en las instrucciones del proyecto → subir `00-core/`, `10-design-system/`, `30-templates/` al conocimiento → **no** subir `20-features/` (se adjunta por chat). Para trabajar el design system: un segundo proyecto con `PROJECT-INSTRUCTIONS-VISION.md`.

Prueba de humo: pregunta al proyecto qué features están especificadas y cuáles sólo en el roadmap. Si no las distingue, el conocimiento no se ha indexado.

## 3. Mientras el PO trabaja

Pide retornos pequeños y frecuentes. Dos o tres features se revisan en un día; un retorno grande tarda semanas y el producto se mueve por debajo. Un cambio de design system por retorno: un retorno de design system se adopta entero o se devuelve entero.

## 4. Validar el retorno

```bash
python3 subproducts/po-package/validate_po_return.py --selftest
python3 subproducts/po-package/validate_po_return.py --zip ~/Downloads/<retorno>.zip
```

Ejecuta `--selftest` primero, siempre: estas herramientas están fuera de la superficie gobernada y el autotest es su única red. El validador juzga **forma y coherencia, nunca mérito**. La forma del journey la juzga `scripts/check-journey-grammar.sh`, la misma puerta que CODESIGN aplica a lo que genera.

| Veredicto | Qué hacer |
|---|---|
| GREEN | Se puede revisar. Pasa al apartado 5. Verde no es aceptado. |
| RED por forma | Devuelve el informe al PO, sin editar. |
| RED por un nombre inventado | Devuélvelo señalando el nombre del glosario. |
| GREEN con preguntas abiertas | Resuélvelas con el PO antes del apartado 5. |

Nunca arregles los documentos del PO para convertir un rojo en verde. Un título traducido significa que las instrucciones no calaron; parchearlo en silencio garantiza el mismo error en la siguiente ronda.

## 5. Ratificar, sincronizar, planificar el catálogo

1. **Lee la petición de evolución antes que los artefactos.** Contrasta cada `reuse_checked` con `00-core/domain-glossary.md`, `docs/ux/component-registry.json` y `config/codebase_inventory.json`.
2. **Una decisión por cambio** (RDR: al menos tres opciones, una recomendación, la elección del usuario registrada). Nunca clasifiques en lote.
3. **Escribe la zona de entrega**: copia cada objetivo ratificado a `docs/ux/po-return/VISION/` o `docs/ux/po-return/<ID>/`, y escribe `docs/ux/po-return/INTAKE.md` con el veredicto, los objetivos ratificados, los cambios rechazados y las decisiones.
4. **Sincroniza, un objetivo cada vez:**

   ```
   /codesign --sync VISION
   /codesign --sync <ID>
   ```

   `--sync` adopta lo ratificado tal como viene y añade sólo lo que es de la fábrica (cabecera, libro de iteraciones, clasificación del cambio, cascada). Nunca regenera y nunca edita contenido del PO: un hallazgo devuelve el objetivo como `NEEDS_INFO` y deja `docs/spec/<ID>/erq/<erq_id>.findings.md`: envía al PO sus puntos, sin editar. La petición de evolución y tus decisiones se guardan al lado, así sobreviven a la zona de entrega. Deja la zona de entrega sin commitear: `--sync` la commitea junto con la adopción. En este proyecto `/codesign --start` y `/codesign --refine` están cerrados y remiten aquí.
5. **Una feature nueva cuya tarea de CODESIGN no es elegible en el tablero** no se sincroniza por haber llegado. Aparca el material en una issue de refinamiento con `/backlog --create-issue`. Llegar no es planificar.
6. **Catálogo de componentes.** Tras sincronizar un design system, a cada componente de `docs/ux/component-registry.json` con estado `DESIGNED` y sin `backlog_ref` le falta trabajo de construcción. La primera vez: decide si se crea la feature fundacional de catálogo, y entonces `/backlog --plan-feature <ID> "Component Catalog"` y un `/backlog --create-issue "[<ID>] COMPONENT: <nombre>"` por componente (etiquetas `phase:implement`, `scope:frontend-only`, `kind:component-catalog`). Después: una issue de refinamiento por componente nuevo. Escribe `backlog_ref` y `PLANNED` de vuelta en el registro. Todo pasa por `/backlog`; nunca llames al tracker directamente.

## 6. Tarjetas del design system

El paquete lleva una tarjeta de previsualización por componente en `10-design-system/cards/`. De los tres apartados siguientes sólo uno aplica a este proyecto: el que se nombra en **Este proyecto**.

### 6A — tarjetas sólo desde la visión

No hay herramienta de reconstrucción configurada. Las tarjetas se cortan de `docs/ux/vision/component_library.html` y `style_guide.html`, una por cada ancla `data-component` / `data-token-group`. No hay nada más que ejecutar. El pie de cada tarjeta nombra la primitiva de código que materializa el componente, tomada del registro cruzado con el inventario de código.

### 6B — tarjetas reconstruidas desde el código, a mano (sin workflow de CI)

Una herramienta del proyecto renderiza los componentes reales en una carpeta de tarjetas dentro del repositorio. Ejecútala a través del generador cada vez que cambien los componentes, y siempre antes de generar un paquete:

```bash
python3 subproducts/po-package/build_po_package.py --mode ds-only --rebuild --check-drift --out ../ds-bundle
python3 subproducts/po-package/build_po_package.py --rebuild --roadmap ../roadmap.json
```

Por componente, una tarjeta renderizada desde el código gana a la de la visión, así el PO ve lo que la aplicación renderiza de verdad en cuanto el componente existe. Los componentes aún sin código conservan su tarjeta de la visión. Si el comando falta, falla o agota el tiempo, el generador avisa con ruido y usa las tarjetas de la visión: nunca bloquea. El comando se ejecuta sin shell, desde la raíz del repositorio.

### 6C — tarjetas reconstruidas en CI (workflow instalado)

Igual que 6B, y además `.github/workflows/design-system-rebuild.yml` ejecuta la reconstrucción y la comprobación de deriva en cada push a la rama principal y bajo demanda. Es informativo: nunca hace fallar el pipeline. Descarga el bundle de los artefactos de la ejecución, o lanza los comandos de 6B en local. Antes de generar un paquete, pasa igualmente `--rebuild` para que el paquete case con el código del día.

### Cómo leer el informe de deriva

| Hallazgo | Significado | Qué hacer |
|---|---|---|
| `code-card-unregistered` | El código renderiza un componente que el design system no conoce | Añádelo al design system, o quítalo del código |
| `implemented-without-code-card` | El registro dice construido y nada se renderiza | La herramienta no lo cubre, o el estado está mal |
| `candidate-implemented` | El registro dice diseñado o planificado, y el código ya lo renderiza | Reconcilia el registro a `IMPLEMENTED` (apartado 5.6) |

### Espejo en Claude Design (opcional)

`/design-sync` publica `10-design-system/` en un proyecto de design system de Claude Design. Es un espejo de solo ida, que arrancas tú. Nada aquí lo espera y ninguna puerta depende de él.

## 7. Cerrar el bucle

Regenera el paquete para que el PO trabaje sobre el estado nuevo, no sobre el que se le envió la vez anterior. Envíale una nota breve por escrito: qué entró, qué no y por qué, qué queda abierto. Sin ella el siguiente retorno repite los mismos errores.

## 8. Cambiar de caso más tarde

- **Activar la reconstrucción tras `defer`:** rellena `design_system.code_cards.dir` y `rebuild_command` en `subproducts/po-package/po-package.config.json`. Pasas a 6B.
- **Añadir el workflow de CI:** copia `.context/templates/setup/workflows/design-system-rebuild.github-actions.yml` a `.github/workflows/design-system-rebuild.yml`. Pasas a 6C.
- **Después actualiza el bloque "Este proyecto" de arriba**, y el de `RUNBOOK.md`. El generador compara ese bloque con la configuración y la presencia del workflow en cada ejecución y avisa cuando no coinciden.

## 9. Qué se rompe y cómo se nota

| Síntoma | Causa | Arreglo |
|---|---|---|
| El validador se niega a arrancar y nombra huecos de plantilla | La config nunca se materializó | Ejecuta `SETUP --generate`, o pasa `--config` |
| `journey-grammar-infra` | Falta `scripts/check-journey-grammar.sh` o no puede ejecutarse | Restáuralo con `factory-sync.sh`; sin él no se puede juzgar un retorno |
| Todos los mocks salen rojos por `external-deps` | El proyecto carga un host que las plantillas no cargan | Añádelo a `mock.allowed_external_hosts` en la config |
| El paquete lleva tarjetas de fichero entero | La visión no tiene anclas `data-component` | Añádelas con un retorno de design system |
| El glosario está vacío | No se pudo leer ningún journey | Pasa la puerta de journey sobre cada carpeta de feature |
| `/codesign --sync` dice que ejecutes antes el intake | Falta `docs/ux/po-return/INTAKE.md`, no está verde, o no lista el objetivo | Vuelve al apartado 5.3 |
