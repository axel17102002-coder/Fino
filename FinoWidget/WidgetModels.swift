//
//  WidgetModels.swift
//  Fino
//
//  Created by Axel Morano on 08/07/2026.
//

import Foundation

struct ResumenParaWidget: Codable {
    let mes: String
    let balance: Double
    let gastos: Double
    let ingresos: Double
    let cashback: Double
    let simboloMoneda: String
}
