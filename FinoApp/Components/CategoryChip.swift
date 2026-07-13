import SwiftUI

/// Chip de categoría con ícono y color propios; resalta cuando está seleccionada.
struct CategoryChip: View {

    let categoria: any CategoriaInfo
    var seleccionada: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: categoria.icono)
                .font(.caption)
            Text(categoria.nombre)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(seleccionada ? categoria.color : Color.primary)
        .background(Capsule().fill(seleccionada ? categoria.color.opacity(0.18) : Color.rellenoTerciario))
        .overlay(Capsule().strokeBorder(seleccionada ? categoria.color : .clear, lineWidth: 1.5))
        .contentShape(Capsule())
        .animation(.snappy(duration: 0.2), value: seleccionada)
        .accessibilityAddTraits(seleccionada ? .isSelected : [])
    }
}

#Preview {
    HStack {
        CategoryChip(categoria: CategoriaGasto.comida, seleccionada: true)
        CategoryChip(categoria: CategoriaGasto.transporte)
    }
    .padding()
}
