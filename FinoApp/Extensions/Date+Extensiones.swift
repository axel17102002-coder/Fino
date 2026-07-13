import Foundation

extension Date {

    /// Primer instante del mes de esta fecha.
    var inicioDeMes: Date {
        let componentes = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: componentes) ?? self
    }

    func mismoMes(que otra: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: otra, toGranularity: .month)
    }

    func agregandoMeses(_ meses: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: meses, to: self) ?? self
    }

    func agregandoDias(_ dias: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: dias, to: self) ?? self
    }

    private func formateada(_ formato: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = formato
        return formatter.string(from: self)
    }

    /// `Julio`
    var nombreMes: String {
        formateada("MMMM").capitalized
    }

    /// `Julio 2026`
    var mesYAnio: String {
        formateada("MMMM yyyy").capitalized
    }

    /// `Jul`
    var mesCorto: String {
        formateada("MMM").capitalized
    }

    /// `4 jul`
    var diaYMes: String {
        formateada("d MMM")
    }

    /// `4 jul 2026`
    var fechaCorta: String {
        formateada("d MMM yyyy")
    }

    /// Nombre del día de la semana, ej: `viernes`.
    var nombreDiaSemana: String {
        formateada("EEEE")
    }
}
