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
