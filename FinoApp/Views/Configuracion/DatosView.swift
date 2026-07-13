import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Pantalla de datos (dentro de Configuración): backup completo,
/// exportación/importación CSV, datos de ejemplo y borrado total.
struct DatosView: View {

    @AppStorage(Preferencias.claveRecordatorioBackup) private var recordatorioBackup = false

    @Environment(\.modelContext) private var contexto
    @Query private var movimientos: [Movimiento]
    @Query private var cuentas: [Cuenta]
    @Query private var presupuestos: [Presupuesto]
    @Query private var objetivos: [ObjetivoAhorro]

    @State private var confirmandoBorrado = false
    @State private var importando = false
    @State private var cantidadImportada: Int?
    @State private var archivoExportado: ArchivoExportado?
    @State private var confirmandoRestauracion = false
    @State private var importandoBackup = false
    @State private var movimientosRestaurados: Int?
    @State private var falloRestauracion = false

    var body: some View {
        Form {
            seccionBackup
            seccionCSV
            seccionPeligro
        }
        .scrollContentBackground(.hidden)
        // Deja pasar el último renglón por encima de la barra inferior.
        .contentMargins(.bottom, 84, for: .scrollContent)
        .background(Color.fondoPantalla)
        .navigationTitle("Datos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Secciones

    private var seccionBackup: some View {
        Section {
            Button {
                crearBackup()
            } label: {
                Label("Guardar backup completo", systemImage: "icloud.and.arrow.up")
            }
            .disabled(movimientos.isEmpty && cuentas.isEmpty && presupuestos.isEmpty && objetivos.isEmpty)

            Button {
                confirmandoRestauracion = true
            } label: {
                Label("Restaurar backup", systemImage: "icloud.and.arrow.down")
            }

            Toggle(isOn: $recordatorioBackup) {
                Label("Recordarme cada 15 días", systemImage: "bell.badge")
            }
            .onChange(of: recordatorioBackup) { _, activado in
                if activado {
                    Task {
                        await NotificacionesService.pedirPermiso()
                        NotificacionesService.programarRecordatorioBackup()
                    }
                } else {
                    NotificacionesService.cancelarRecordatorioBackup()
                }
            }
        } header: {
            textoSobreFondo("Backup")
        } footer: {
            textoSobreFondo("El backup incluye todo: cuentas, movimientos, presupuestos, objetivos y categorías. Al guardarlo, elegí \"Guardar en Archivos\" → iCloud Drive para tenerlo a salvo en la nube.", esFooter: true)
        }
        .confirmationDialog(
            "¿Restaurar un backup?",
            isPresented: $confirmandoRestauracion,
            titleVisibility: .visible
        ) {
            Button("Elegir archivo", role: .destructive) { importandoBackup = true }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Los datos actuales se van a reemplazar por completo con los del backup.")
        }
        .fileImporter(
            isPresented: $importandoBackup,
            allowedContentTypes: [.json]
        ) { resultado in
            if case .success(let url) = resultado {
                if let cantidad = BackupService.restaurar(desde: url, en: contexto) {
                    movimientosRestaurados = cantidad
                    Haptics.exito()
                } else {
                    falloRestauracion = true
                    Haptics.error()
                }
            }
        }
        .alert(
            "Backup restaurado",
            isPresented: Binding(
                get: { movimientosRestaurados != nil },
                set: { if !$0 { movimientosRestaurados = nil } }
            )
        ) {
            Button("OK") { movimientosRestaurados = nil }
        } message: {
            Text("Se restauraron \(movimientosRestaurados ?? 0) movimientos con sus cuentas, presupuestos, objetivos y categorías.")
        }
        .alert("No se pudo restaurar", isPresented: $falloRestauracion) {
            Button("OK") {}
        } message: {
            Text("El archivo no parece ser un backup válido de Fino.")
        }
    }

    private var seccionCSV: some View {
        Section {
            Button {
                exportarCSV()
            } label: {
                Label("Exportar movimientos (CSV)", systemImage: "square.and.arrow.up")
            }
            .disabled(movimientos.isEmpty)

            Button {
                importando = true
            } label: {
                Label("Importar movimientos (CSV)", systemImage: "square.and.arrow.down")
            }
        } header: {
            textoSobreFondo("Planilla (CSV)")
        } footer: {
            textoSobreFondo("El CSV exportado tiene el mismo formato que acepta la importación.", esFooter: true)
        }
        .fileImporter(
            isPresented: $importando,
            allowedContentTypes: [.commaSeparatedText, .plainText]
        ) { resultado in
            if case .success(let url) = resultado {
                cantidadImportada = ExportImportService.importarCSV(
                    desde: url, en: contexto, cuentas: cuentas
                )
                Haptics.exito()
            }
        }
        .alert(
            "Importación completa",
            isPresented: Binding(
                get: { cantidadImportada != nil },
                set: { if !$0 { cantidadImportada = nil } }
            )
        ) {
            Button("OK") { cantidadImportada = nil }
        } message: {
            Text("Se importaron \(cantidadImportada ?? 0) movimientos.")
        }
        .sheet(item: $archivoExportado) { archivo in
            ShareSheet(url: archivo.url)
                .presentationDetents([.medium, .large])
        }
    }

    private var seccionPeligro: some View {
        Section {
            Button {
                DatosDemo.insertar(en: contexto)
                Haptics.exito()
            } label: {
                Label("Cargar datos de ejemplo", systemImage: "wand.and.stars")
            }

            Button(role: .destructive) {
                confirmandoBorrado = true
            } label: {
                Label("Eliminar toda la base de datos", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        } header: {
            textoSobreFondo("Zona de riesgo")
        }
        .confirmationDialog(
            "¿Eliminar toda la base de datos?",
            isPresented: $confirmandoBorrado,
            titleVisibility: .visible
        ) {
            Button("Eliminar todo", role: .destructive) {
                PersistenceService.shared.borrarTodo()
                Haptics.advertencia()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se van a borrar todos los movimientos, cuentas, presupuestos y objetivos. Esta acción no se puede deshacer.")
        }
    }

    // MARK: - Helpers

    /// Encabezados y pies de sección legibles sobre el fondo verde.
    private func textoSobreFondo(_ texto: LocalizedStringKey, esFooter: Bool = false) -> some View {
        Text(texto)
            .foregroundStyle(.white.opacity(esFooter ? 0.7 : 0.85))
    }

    // MARK: - Acciones

    private func exportarCSV() {
        guard let url = try? ExportImportService.archivoCSV(de: movimientos) else {
            Haptics.error()
            return
        }
        archivoExportado = ArchivoExportado(url: url)
    }

    private func crearBackup() {
        guard let url = try? BackupService.crearArchivo(
            cuentas: cuentas,
            movimientos: movimientos,
            presupuestos: presupuestos,
            objetivos: objetivos
        ) else {
            Haptics.error()
            return
        }
        archivoExportado = ArchivoExportado(url: url)
    }
}

#Preview {
    DatosView()
        .modelContainer(for: [Movimiento.self, Cuenta.self], inMemory: true)
}
