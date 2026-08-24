import SwiftUI

/// Gastos y cashback repartidos por medio de pago, en un carrusel de dos
/// páginas dentro de una misma tarjeta.
///
/// Van juntos porque son la misma pregunta mirada de los dos lados: con
/// qué pagás y qué te devuelve cada tarjeta. Verlos uno al lado del otro
/// es lo que deja ver si la que más usás es también la que más rinde.
struct MediosDePagoCard: View {

    let gastos: [TotalPorMedioDePago]
    let cashback: [TotalPorMedioDePago]

    @State private var pagina: Int? = 0

    /// Los gastos solo tienen sentido con al menos dos medios: con uno la
    /// barra siempre da 100% y no dice nada. El cashback aparece aunque
    /// sea de una sola tarjeta, que ahí lo que interesa es el monto.
    private var paginas: [Pagina] {
        var todas: [Pagina] = []
        if gastos.count >= 2 {
            todas.append(Pagina(
                id: 0,
                titulo: String(localized: "Gastos por medio de pago"),
                destacado: String(localized: "El que más usás"),
                items: gastos,
                esCashback: false
            ))
        }
        if !cashback.isEmpty {
            todas.append(Pagina(
                id: 1,
                titulo: String(localized: "Cashback por tarjeta"),
                destacado: String(localized: "La que más te devuelve"),
                items: cashback,
                esCashback: true
            ))
        }
        return todas
    }

    private struct Pagina: Identifiable {
        let id: Int
        let titulo: String
        let destacado: String
        let items: [TotalPorMedioDePago]
        let esCashback: Bool

        /// El total va en el subtítulo: sin él los porcentajes de cada
        /// fila no tienen contra qué compararse, y así entra sin pedirle
        /// a `StatisticsCard` un hueco que las demás métricas no usan.
        var subtitulo: String {
            guard let primero = items.first else { return items.total.enMoneda }
            return "\(destacado): \(primero.nombre) · \(items.total.enMoneda)"
        }
    }

    /// La página que se está viendo, para que el encabezado de la tarjeta
    /// la acompañe mientras el contenido se desliza.
    private var actual: Pagina? {
        paginas.first { $0.id == pagina } ?? paginas.first
    }

    var body: some View {
        if let actual {
            StatisticsCard(titulo: actual.titulo, subtitulo: actual.subtitulo) {
                VStack(spacing: 14) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 20) {
                            ForEach(paginas) { pagina in
                                filas(de: pagina)
                                    .containerRelativeFrame(.horizontal)
                                    .id(pagina.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $pagina)

                    if paginas.count > 1 {
                        puntos
                    }
                }
                .animation(.snappy(duration: 0.2), value: pagina)
            }
        }
    }

    private func filas(de pagina: Pagina) -> some View {
        VStack(spacing: 16) {
            ForEach(pagina.items) { item in
                fila(item, en: pagina)
            }
        }
    }

    private func fila(_ item: TotalPorMedioDePago, en pagina: Pagina) -> some View {
        let proporcion = pagina.items.proporcion(de: item)
        // El verde de marca, el mismo del botón + y de la pestaña activa,
        // en vez del verde del sistema: es plata que vuelve y conviene
        // que se lea como Fino.
        let acento = pagina.esCashback ? Color.verdeBarra : item.color

        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: item.icono)
                    .font(.caption)
                    .foregroundStyle(item.color)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(item.color.opacity(0.2)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.nombre)
                        .font(.subheadline)
                        .lineLimit(1)
                    // El conteo al lado del porcentaje porque "el que más
                    // usás" puede ser el de más plata o el de más veces,
                    // y no siempre son el mismo.
                    Text("\(item.cantidad) movimientos · \(Int((proporcion * 100).rounded()))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(item.total.enMoneda)
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(pagina.esCashback ? Color.verdeBarra : .primary)
            }

            barra(proporcion: proporcion, color: acento)
        }
    }

    private func barra(proporcion: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.rellenoTerciario)
                Capsule()
                    .fill(color)
                    .frame(width: max(geo.size.width * proporcion, 3))
            }
        }
        .frame(height: 5)
    }

    private var puntos: some View {
        HStack(spacing: 7) {
            ForEach(paginas) { p in
                Capsule()
                    .fill(Color.primary.opacity(pagina == p.id ? 0.6 : 0.2))
                    .frame(width: pagina == p.id ? 18 : 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.25), value: pagina)
    }
}
