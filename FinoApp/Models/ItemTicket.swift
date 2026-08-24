import Foundation

/// Un renglón del ticket: el producto y lo que costó.
///
/// Es un `Codable` y no un `@Model` a propósito: el detalle no se
/// consulta ni se filtra por separado, siempre se lee junto al
/// movimiento, así que guardarlo como valor evita sumarle una entidad y
/// una relación al esquema.
struct ItemTicket: Codable, Hashable {

    var nombre: String
    var monto: Double
    /// El renglón es consumo tuyo solo, no del grupo. En un gasto
    /// compartido, estos van enteros a tu parte y el resto se divide.
    var soloMio: Bool

    init(nombre: String, monto: Double, soloMio: Bool = false) {
        self.nombre = nombre
        self.monto = monto
        self.soloMio = soloMio
    }

    /// Decodificación a mano por `soloMio`: los detalles guardados antes
    /// de que existiera la marca no traen la clave, y el `Codable`
    /// sintetizado falla cuando falta una en vez de usar el valor por
    /// defecto.
    init(from decoder: any Decoder) throws {
        let contenedor = try decoder.container(keyedBy: CodingKeys.self)
        nombre = try contenedor.decode(String.self, forKey: .nombre)
        monto = try contenedor.decode(Double.self, forKey: .monto)
        soloMio = try contenedor.decodeIfPresent(Bool.self, forKey: .soloMio) ?? false
    }
}

extension Array where Element == ItemTicket {

    var total: Double {
        reduce(0) { $0 + $1.monto }
    }

    /// Los productos, sin los renglones de descuento.
    var productos: [ItemTicket] {
        filter { $0.monto > 0 }
    }

    /// Reparte el ticket entre vos y las demás personas usando la marca
    /// de cada renglón.
    ///
    /// Los renglones marcados como tuyos van enteros a tu parte; el resto
    /// se divide entre todos. Los importes se escalan para que el reparto
    /// sume exactamente lo que se pagó: así los descuentos del ticket
    /// —que son renglones negativos— quedan repartidos en la misma
    /// proporción, sin tener que decidir a quién le tocó cada promoción.
    ///
    /// Devuelve `nil` si no hay con quién dividir o si no hay renglones.
    func reparto(entrePersonas personas: Int, totalPagado: Double) -> (tuya: Double, deCadaUno: Double)? {
        guard personas > 0, totalPagado > 0 else { return nil }
        let productos = self.productos
        guard !productos.isEmpty else { return nil }

        let compartido = productos.filter { !$0.soloMio }.total
        let mios = productos.filter(\.soloMio).total
        let base = compartido + mios
        guard base > 0 else { return nil }

        let escala = totalPagado / base
        let deCadaUno = (compartido / Double(personas + 1)) * escala
        return (tuya: totalPagado - deCadaUno * Double(personas), deCadaUno: deCadaUno)
    }
}
