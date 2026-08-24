import SwiftUI

/// Encabezado de la card principal del Dashboard: el balance del mes con
/// sus métricas clave. La lista de últimos movimientos y el análisis por
/// categoría son bloques aparte, y el Dashboard los ordena debajo.
struct BalanceCard: View {

    let balance: Double
    let ingresos: Double
    let gastos: Double
    let cashback: Double

    /// Valor que se muestra: arranca en cero y sube hasta el balance real.
    @State private var balanceMostrado: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private func animarBalance(hasta valor: Double) {
        guard !reducirMovimiento else {
            balanceMostrado = valor
            return
        }
        withAnimation(.easeOut(duration: 0.7)) { balanceMostrado = valor }
    }

    /// Balance a la izquierda y métricas en una columna a la derecha.
    ///
    /// Sin `ViewThatFits` a propósito: el ancho ideal del balance en 46pt
    /// es mayor que cualquier pantalla, así que esta fila "no entraba"
    /// nunca y se elegía siempre la alternativa apilada. Lo que resuelve
    /// los anchos chicos es el `minimumScaleFactor` del número.
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            bloqueBalance
                .frame(maxWidth: .infinity, alignment: .leading)

            bloqueMetricas
                .frame(width: 138, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var bloqueBalance: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Resumen de \(Date.now.nombreMes)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Image(systemName: "sparkles")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.indigo)
            }

            // Cuenta desde cero al abrir y vuelve a contar al cambiar.
            ContadorMoneda(valor: balanceMostrado)
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .onAppear { animarBalance(hasta: balance) }
                .onChange(of: balance) { _, nuevo in animarBalance(hasta: nuevo) }

            chipBalance
        }
    }

    private var chipBalance: some View {
        let positivo = balance >= 0
        let color: Color = positivo ? .green : .red
        return HStack(spacing: 5) {
            Image(systemName: positivo ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
            Text(positivo ? "Balance positivo" : "Balance negativo")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color.legible())
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.legible().opacity(0.16)))
    }

    private var bloqueMetricas: some View {
        VStack(alignment: .leading, spacing: 12) {
            indicador(String(localized: "Gastos"), valor: gastos, icono: "arrow.up.right", color: .red)
            indicador(String(localized: "Ingresos"), valor: ingresos, icono: "arrow.down.left", color: .green)
            indicador(String(localized: "Cashback"), valor: cashback, icono: "creditcard.fill", color: .orange)
        }
    }

    private func indicador(_ titulo: String, valor: Double, icono: String, color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icono)
                .font(.caption.weight(.bold))
                .foregroundStyle(color.legible())
                .frame(width: 28, height: 28)
                .background(Circle().fill(color.legible().opacity(0.18)))

            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(valor.enMoneda)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

}

/// Monto que sube contando.
///
/// `contentTransition(.numericText())` no servía acá: entre "$ 0" y el
/// balance final solo emparejaba el último dígito, que subía desde abajo
/// mientras el resto aparecía de golpe. Al ser `Animatable`, SwiftUI
/// interpola el valor y redibuja el cuerpo en cada cuadro, así que se
/// mueven todos los dígitos a la vez.
private struct ContadorMoneda: View, Animatable {

    var valor: Double

    var animatableData: Double {
        get { valor }
        set { valor = newValue }
    }

    var body: some View {
        Text(valor.enMoneda)
    }
}

#Preview {
    BalanceCard(
        balance: 647_800,
        ingresos: 2_500_000,
        gastos: 1_900_000,
        cashback: 47_800
    )
    .padding()
}
