import SwiftUI
import SwiftData

/// Detalle de una cuenta o tarjeta: resumen y todos los movimientos hechos con ella.
struct CuentaDetalleView: View {

    @Bindable var cuenta: Cuenta
    @Environment(\.modelContext) private var contexto

    @State private var mostrandoEdicion = false
    @State private var mostrandoAlta = false
    @State private var movimientoEnEdicion: Movimiento?

    private var consumos: [Movimiento] { cuenta.movimientosOrdenados }

    /// Los gastos de la tarjeta partidos por resumen. Vacío para cuentas
    /// que no son tarjeta o que no tienen día de cierre configurado, y
    /// ahí la lista queda plana como antes.
    private var resumenes: [ResumenDeTarjeta] {
        CalculosService.resumenesDeTarjeta(cuenta)
    }

    var body: some View {
        List {
            Section {
                Group {
                    if cuenta.esTarjetaCredito {
                        TarjetaCreditoCard(cuenta: cuenta, expandida: true)
                    } else {
                        CuentaResumenCard(cuenta: cuenta, expandida: true)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if !resumenes.isEmpty {
                ForEach(resumenes) { resumen in
                    Section {
                        ForEach(resumen.renglones) { renglon in
                            filaDeResumen(renglon)
                        }
                    } header: {
                        encabezado(de: resumen)
                    }
                }
            } else {
            Section {
                if consumos.isEmpty {
                    sinConsumos
                } else {
                    ForEach(consumos) { movimiento in
                        TransactionRow(movimiento: movimiento)
                            .contentShape(Rectangle())
                            .onTapGesture { movimientoEnEdicion = movimiento }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    eliminar(movimiento)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                                Button {
                                    movimientoEnEdicion = movimiento
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            } header: {
                if !consumos.isEmpty {
                    Text(cuenta.esTarjetaCredito
                        ? "\(consumos.count) consumos"
                        : "\(consumos.count) movimientos")
                }
            }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.fondoPantalla)
        .navigationTitle(cuenta.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    mostrandoAlta = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(cuenta.esTarjetaCredito ? "Agregar consumo" : "Agregar movimiento")

                Button {
                    mostrandoEdicion = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel(cuenta.esTarjetaCredito ? "Editar tarjeta" : "Editar cuenta")
            }
        }
        .sheet(isPresented: $mostrandoEdicion) {
            AddCuentaSheet(cuenta: cuenta)
        }
        .sheet(isPresented: $mostrandoAlta) {
            AddTransactionSheet(cuentaPreseleccionada: cuenta)
        }
        .sheet(item: $movimientoEnEdicion) { movimiento in
            AddTransactionSheet(movimiento: movimiento)
        }
    }

    /// Mes del resumen, cuándo cierra y cuánto suma.
    private func encabezado(de resumen: ResumenDeTarjeta) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(resumen.titulo)
                    .font(.subheadline.weight(.semibold))
                Text(resumen.enCurso
                    ? String(localized: "Cierra el \(resumen.cierre.diaYMes)")
                    : String(localized: "Cerró el \(resumen.cierre.diaYMes)"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(resumen.total.enMoneda)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .textCase(nil)
    }

    /// Un renglón del resumen. En las compras financiadas muestra qué
    /// cuota es y por cuánto, en vez del total de la compra: es lo que la
    /// tarjeta cobra en este resumen.
    private func filaDeResumen(_ renglon: ResumenDeTarjeta.Renglon) -> some View {
        HStack(spacing: 12) {
            Image(systemName: renglon.movimiento.iconoCategoria)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(renglon.movimiento.categoria?.color ?? .gray)
                .frame(width: 36, height: 36)
                .background(Circle().fill((renglon.movimiento.categoria?.color ?? .gray).opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(renglon.movimiento.nombre)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(detalle(de: renglon))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(renglon.monto.enMoneda)
                .font(.callout.bold())
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { movimientoEnEdicion = renglon.movimiento }
    }

    private func detalle(de renglon: ResumenDeTarjeta.Renglon) -> String {
        var partes = [renglon.movimiento.fecha.diaYMes]
        if let cuota = renglon.cuota {
            partes.append(String(localized: "Cuota \(cuota)/\(renglon.movimiento.cuotas)"))
        }
        return partes.joined(separator: " · ")
    }

    private var sinConsumos: some View {
        VStack(spacing: 8) {
            Image(systemName: cuenta.esTarjetaCredito ? "creditcard" : cuenta.icono)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(cuenta.esTarjetaCredito ? "Sin consumos" : "Sin movimientos")
                .font(.subheadline.weight(.semibold))
            Text(cuenta.esTarjetaCredito
                ? "Todavía no registraste compras con esta tarjeta."
                : "Todavía no registraste movimientos con esta cuenta.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func eliminar(_ movimiento: Movimiento) {
        DeudasService.eliminarVinculadas(a: movimiento.id, en: contexto)
        contexto.delete(movimiento)
        try? contexto.save()
        Haptics.advertencia()
    }
}

#Preview {
    NavigationStack {
        CuentaDetalleView(cuenta: Cuenta(nombre: "Galicia Visa", tipo: .tarjetaCredito))
    }
    .modelContainer(for: [Cuenta.self, Movimiento.self], inMemory: true)
}
