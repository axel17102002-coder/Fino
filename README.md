# FinanzasApp 💰

App nativa de iOS para administrar finanzas personales, construida con **SwiftUI**, **SwiftData** y **Swift Charts**, con arquitectura **MVVM**.

## Requisitos

- **Xcode 16 o superior** (el proyecto usa carpetas sincronizadas, formato `objectVersion 77`)
- **iOS 18.0+** (iPhone o simulador)

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
├── Models/          Movimiento, Cuenta, Presupuesto, ObjetivoAhorro, enums de dominio
├── ViewModels/      Dashboard, Movimientos, Estadísticas, formulario de movimiento
├── Views/           Pantallas (Dashboard, Movimientos, Estadísticas, Configuración, Cuentas…)
├── Components/      SummaryCard, BalanceCard, DonutChart, TransactionRow, FilterSheet…
├── Services/        PersistenceService, CalculosService, InsightsService, Export/Import, DatosDemo
├── Extensions/      Color, Date, Double, View
└── Utilities/       Formatters, Haptics, Preferencias, ShareSheet
```

Toda la lógica de negocio vive en `Services/` y `ViewModels/`; las vistas solo presentan.

## Formato CSV

```
tipo,nombre,categoria,monto,fecha,notas,cuenta,cuotas
gasto,Supermercado Coto,supermercado,420000.0,2026-07-03T12:00:00Z,,Galicia Visa,1
```

El archivo exportado desde Configuración usa exactamente el formato que acepta la importación.
