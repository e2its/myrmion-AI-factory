# Reglas del juego

## Lo que sí puedes hacer

- Proponer cambios sobre cualquier feature, especificada o del roadmap.
- Añadir un paso, un estado, un mensaje, un campo opcional, una regla de negocio.
- Proponer un concepto nuevo o un componente nuevo, diciendo qué buscaste antes.
- Recomendar un orden de prioridad.
- Dejar una pregunta abierta cuando no sepas.

## Lo que no puedes hacer

- Rediseñar una pantalla que funciona porque otra quedaría más bonita.
- Inventar un nombre para algo que el glosario ya nombra.
- Pedir un componente nuevo cuando uno de `../10-design-system/components.md` resuelve el caso.
- Escribir tipos técnicos, formatos, almacenamiento o nombres de protocolo.
- Decidir cuándo se construye algo, ni adelantar una feature del roadmap.
- Cambiar la navegación global como efecto colateral de una feature. La comparten todas; es un cambio de design system.
- Relajar una regla que el producto declara inquebrantable.

## Lo que cuesta de verdad cada tipo de cambio

| Cambio | Coste | Por qué |
|---|---|---|
| Texto, orden, estado vacío, mensaje de error | Muy bajo | Sólo toca la pantalla |
| Campo opcional nuevo en un concepto existente | Bajo | Se añade sin romper lo que funciona |
| Paso nuevo en un recorrido existente | Medio | Pantalla, escenarios y pruebas |
| Campo **obligatorio** nuevo | Alto | Alguien tiene que decidir qué pasa con lo que ya existe sin él |
| Concepto o acción nuevos | Alto | Contrato, almacenamiento, pruebas, todo el recorrido |
| Cambiar el significado de algo existente | Muy alto | Rompe lo construido y lo ya guardado |
| Navegación global | Muy alto | Afecta a todas las features a la vez |
| Cualquier cosa en una feature del roadmap | **Casi ninguno** | Todavía no hay nada construido |

## Cómo se decide lo que entra

1. Se comprueba la forma de tu retorno. Un retorno que falla vuelve a ti con el informe, sin editar.
2. Cada cambio se valora y se decide uno a uno. Nada se aplica automáticamente.
3. Lo aceptado se incorpora tal como lo escribiste. Lo que no, se te cuenta con el motivo.
4. Cuándo se construye se decide en el tablero del proyecto.
