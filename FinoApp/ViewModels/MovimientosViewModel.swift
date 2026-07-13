import Foundation
import Observation

enum OrdenMovimientos: String, CaseIterable, Identifiable {
    case fechaDescendente
    case fechaAscendente
    case montoDescendente
    case montoAscendente

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .fechaDescendente: "Más recientes"
        case .fechaAscendente: "Más antiguos"
        case .montoDescendente: "Mayor monto"
        case .montoAscendente: "Menor monto"
        }
    }
}

/// Estado de búsqueda, filtros y orden de la pantalla de Movimientos.
@Observable
final class MovimientosViewModel {

    var busqueda = ""
    var tipo: TipoMovimiento?
    var categoriaRaw: String?
    var mes: Date?
    var orden: OrdenMovimientos = .fechaDescendente

    var hayFiltrosActivos: Bool {
        tipo != nil || categoriaRaw != nil || mes != nil
    }

    var cantidadFiltrosActivos: Int {
        [tipo != nil, categoriaRaw != nil, mes != nil].filter { $0 }.count
    }

    func limpiarFiltros() {
        tipo = nil
        categoriaRaw = nil
        mes = nil
    }

    /// Aplica búsqueda, filtros y orden sobre la lista completa.
    func aplicar(a movimientos: [Movimiento]) -> [Movimiento] {
        var resultado = movimientos

        if let tipo {
            resultado = resultado.filter { $0.tipo == tipo }
        }
        if let categoriaRaw {
            resultado = resultado.filter { $0.categoriaRaw == categoriaRaw }
        }
        if let mes {
            resultado = resultado.filter { $0.fecha.mismoMes(que: mes) }
        }

        let texto = busqueda.trimmingCharacters(in: .whitespaces)
        if !texto.isEmpty {
            resultado = resultado.filter {
                $0.nombre.localizedCaseInsensitiveContains(texto)
                    || $0.nombreCategoria.localizedCaseInsensitiveContains(texto)
                    || $0.notas.localizedCaseInsensitiveContains(texto)
                    || ($0.cuenta?.nombre.localizedCaseInsensitiveContains(texto) ?? false)
            }
        }

        switch orden {
        case .fechaDescendente: resultado.sort { $0.fecha > $1.fecha }
        case .fechaAscendente: resultado.sort { $0.fecha < $1.fecha }
        case .montoDescendente: resultado.sort { $0.monto > $1.monto }
        case .montoAscendente: resultado.sort { $0.monto < $1.monto }
        }
        return resultado
    }

    /// Meses en los que hay movimientos, del más reciente al más antiguo.
    static func mesesDisponibles(en movimientos: [Movimiento]) -> [Date] {
        Set(movimientos.map { $0.fecha.inicioDeMes }).sorted(by: >)
    }

    /// Categorías seleccionables en el filtro según el tipo elegido.
    var categoriasParaFiltro: [any CategoriaInfo] {
        if let tipo {
            return tipo.categorias
        }
        return TipoMovimiento.allCases.flatMap { $0.categorias }
    }
}
