# FinanzasApp 💰

App nativa de iOS para administrar finanzas personales, construida con **SwiftUI**, **SwiftData** y **Swift Charts**, con arquitectura **MVVM**.

## Requisitos

- **Xcode 16 o superior** (el proyecto usa carpetas sincronizadas, formato `objectVersion 77`)
- **iOS 18.0+** (iPhone o simulador)
- **watchOS 11.0+** para la app del reloj. El scheme `Fino` incrusta la app
  de Apple Watch, así que la plataforma watchOS tiene que estar instalada
  o el build falla antes de empezar: `xcodebuild -downloadPlatform watchOS`

## Cómo compilar

1. Abrir `FinanzasApp.xcodeproj` en Xcode.
2. Seleccionar un simulador de iPhone (o tu dispositivo).
3. `Cmd + R`.

Desde la terminal:

```bash
xcodebuild -project FinanzasApp.xcodeproj -scheme FinanzasApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

> En el primer arranque la app carga **datos de ejemplo** (movimientos, cuentas, tarjetas, presupuestos y objetivos) para que todas las pantallas se vean completas. Se pueden borrar desde **Configuración → Eliminar toda la base de datos**.

## Funcionalidades

- **Dashboard**: donut chart interactivo (Swift Charts) con gastos / ingresos / cashback, tarjetas resumen, balance, carrusel de tarjetas de crédito, presupuestos, objetivos y últimos movimientos.
- **Movimientos**: búsqueda, filtros por mes/categoría/tipo, orden por fecha o monto, edición, duplicado y eliminación por swipe.
- **Cuentas**: efectivo, cuentas bancarias, billeteras virtuales y **tarjetas de crédito** con límite, día de cierre y vencimiento, consumo y disponible.
- **Cuotas**: compras en cuotas con seguimiento automático (cuota actual, restantes, monto pendiente).
- **Presupuestos** mensuales por categoría con semáforo verde/naranja/rojo.
- **Objetivos de ahorro** con barra de progreso.
- **Estadísticas**: gastos por categoría, evolución mensual, ingresos vs gastos, cashback acumulado, top categorías, balance histórico e **insights** automáticos.
- **Configuración**: tema claro/oscuro/automático, moneda (ARS/USD/EUR), exportar/importar CSV, borrar base de datos.

## Estructura

```
FinanzasApp/
├── FinoApp/           App de iPhone
│   ├── Models/        Movimiento, Cuenta, Presupuesto, ObjetivoAhorro, enums de dominio
│   ├── ViewModels/    Dashboard, Movimientos, Estadísticas, formulario de movimiento
│   ├── Views/         Pantallas (Dashboard, Movimientos, Estadísticas, Configuración, Cuentas…)
│   ├── Components/    SummaryCard, BalanceCard, DonutChart, TransactionRow, FilterSheet…
│   ├── Services/      PersistenceService, CalculosService, InsightsService, Export/Import, DatosDemo
│   ├── Extensions/    Color, Date, Double, View
│   └── Utilities/     Formatters, Haptics, Preferencias, ShareSheet
├── FinoWidget/        Widgets de pantalla de inicio y bloqueo
├── FinoWatch/         App de Apple Watch
└── FinoCompartido/    Contrato iPhone ↔ reloj (lo compilan los dos targets)
```

Toda la lógica de negocio vive en `Services/` y `ViewModels/`; las vistas solo presentan.

## Apple Watch

Versión recortada de la app, con tres pantallas y nada más:

- **Resumen**: balance del mes y la dona de gastos por categoría. Tocando
  un renglón se resalta esa porción.
- **Nuevo gasto**: monto (corona digital o tecleado) y categoría. Sin
  cuenta, sin cuotas y sin notas: el movimiento llega al iPhone sin cuenta
  asignada y se termina de completar ahí.
- **Últimos**: los últimos movimientos, solo lectura.

Cuentas, tarjetas de crédito, cuotas, presupuestos, objetivos,
estadísticas y escaneo de tickets se quedan en el iPhone.

### Cómo se sincroniza

Por **WatchConnectivity**, no por App Group: el App Group
(`group.com.axelmorano.FinoApp`) comparte datos entre la app y el widget
en el mismo teléfono, y el reloj es otro dispositivo.

- **iPhone → reloj**: `SincronizacionWatchService` publica un
  `SnapshotWatch` completo con `updateApplicationContext`. El sistema
  guarda uno solo, así que cada envío pisa al anterior y el reloj siempre
  lee lo último. Va colgado de `WidgetDataService.publicar`, así que todo
  lo que ya refresca el widget refresca también la muñeca.
- **reloj → iPhone**: los gastos viajan de a uno con `transferUserInfo`,
  que encola y entrega aunque la app esté cerrada (iOS la despierta en
  segundo plano). Cada gasto lleva su `id` para que un reintento del
  sistema no duplique el movimiento.

El reloj guarda el último snapshot en `UserDefaults`, así abre con datos
aunque el iPhone esté lejos, y suma el gasto recién cargado en local
mientras espera la confirmación.

La forma de los mensajes vive en `FinoCompartido/PayloadWatch.swift`, que
compilan los dos targets: si una punta queda vieja el JSON deja de
decodificar y el reloj se queda mudo sin avisar.

## Formato CSV

```
tipo,nombre,categoria,monto,fecha,notas,cuenta,cuotas
gasto,Supermercado Coto,supermercado,420000.0,2026-07-03T12:00:00Z,,Galicia Visa,1
```

El archivo exportado desde Configuración usa exactamente el formato que acepta la importación.
