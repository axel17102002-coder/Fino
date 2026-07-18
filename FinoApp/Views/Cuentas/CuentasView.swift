import SwiftUI
import SwiftData

/// Listado de cuentas y tarjetas de crédito con sus saldos y consumos.
struct CuentasView: View {

    @Query(sort: [SortDescriptor(\Cuenta.orden), SortDescriptor(\Cuenta.nombre)]) private var cuentas: [Cuenta]
    @Environment(\.modelContext) private var contexto

    @State private var mostrandoAlta = false
    @State private var cuentaEnEdicion: Cuenta?
    @State private var cuentaSeleccionada: Cuenta?
    @State private var modoEdicion: EditMode = .inactive

    private var tarjetas: [Cuenta] { cuentas.filter(\.esTarjetaCredito) }
    private var otrasCuentas: [Cuenta] { cuentas.filter { !$0.esTarjetaCredito } }

    var body: some View {
        Group {
            if cuentas.isEmpty {
                EmptyState(
                    icono: "creditcard",
                    titulo: String(localized: "Sin cuentas"),
                    mensaje: String(localized: "Creá tus cuentas, billeteras y tarjetas para saber dónde está tu plata."),
                    tituloAccion: String(localized: "Agregar cuenta")
                ) {
                    mostrandoAlta = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                lista
            }
        }
        .background(Color.fondoPantalla)
        .navigationTitle("Cuentas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !cuentas.isEmpty {
                    Button(modoEdicion == .active ? "Listo" : "Ordenar") {
                        withAnimation {
                            modoEdicion = modoEdicion == .active ? .inactive : .active
                        }
                    }
                }
                Button {
                    mostrandoAlta = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Agregar cuenta")
            }
        }
        .environment(\.editMode, $modoEdicion)
        .sheet(isPresented: $mostrandoAlta) {
            AddCuentaSheet()
        }
        .sheet(item: $cuentaEnEdicion) { cuenta in
            AddCuentaSheet(cuenta: cuenta)
        }
        .navigationDestination(item: $cuentaSeleccionada) { cuenta in
            CuentaDetalleView(cuenta: cuenta)
        }
    }

    private var lista: some View {
        List {
            if !tarjetas.isEmpty {
                Section("Tarjetas de crédito") {
                    ForEach(tarjetas) { tarjeta in
                        TarjetaCreditoCard(cuenta: tarjeta, expandida: true)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle())
                            .onTapGesture { cuentaSeleccionada = tarjeta }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    eliminar(tarjeta)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                                Button {
                                    cuentaEnEdicion = tarjeta
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                    .onMove { origen, destino in
                        mover(origen, a: destino, dentroDe: tarjetas)
                    }
                }
            }

            if !otrasCuentas.isEmpty {
                Section("Cuentas y billeteras") {
                    ForEach(otrasCuentas) { cuenta in
                        filaCuenta(cuenta)
                            .contentShape(Rectangle())
                            .onTapGesture { cuentaSeleccionada = cuenta }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    eliminar(cuenta)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                                Button {
                                    cuentaEnEdicion = cuenta
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                    .onMove { origen, destino in
                        mover(origen, a: destino, dentroDe: otrasCuentas)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    /// Reordena dentro de una de las dos secciones y persiste la posición.
    /// Tarjetas y cuentas guardan órdenes independientes porque nunca se
    /// muestran mezcladas.
    private func mover(_ origen: IndexSet, a destino: Int, dentroDe lista: [Cuenta]) {
        var reordenada = lista
        reordenada.move(fromOffsets: origen, toOffset: destino)
        for (indice, cuenta) in reordenada.enumerated() {
            cuenta.orden = indice
        }
        try? contexto.save()
        Haptics.exito()
    }

    private func filaCuenta(_ cuenta: Cuenta) -> some View {
        HStack(spacing: 12) {
            Image(systemName: cuenta.icono)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(cuenta.color)
                .frame(width: 40, height: 40)
                .background(Circle().fill(cuenta.color.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(cuenta.nombre)
                    .font(.subheadline.weight(.semibold))
                Text(cuenta.tipo.nombre)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(CalculosService.saldo(de: cuenta).enMoneda)
                .font(.callout.bold())
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func eliminar(_ cuenta: Cuenta) {
        contexto.delete(cuenta)
        try? contexto.save()
        Haptics.advertencia()
    }
}

#Preview {
    NavigationStack {
        CuentasView()
    }
    .modelContainer(for: [Cuenta.self, Movimiento.self], inMemory: true)
}
