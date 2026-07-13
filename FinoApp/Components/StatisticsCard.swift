import SwiftUI

/// Contenedor con estilo de tarjeta para cada gráfico de Estadísticas.
struct StatisticsCard<Contenido: View>: View {

    let titulo: String
    let subtitulo: String?
    let contenido: Contenido

    init(titulo: String, subtitulo: String? = nil, @ViewBuilder contenido: () -> Contenido) {
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.contenido = contenido()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.headline)
                if let subtitulo {
                    Text(subtitulo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            contenido
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .estiloTarjeta()
    }
}
