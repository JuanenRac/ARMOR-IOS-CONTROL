// ARMOR-IOS-CONTROL - the words of an alarm, by the code the server gives it (the same codes and phrases as the other clients).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum AlarmText {
    /// The phrase (Spanish source text, translated by `tr`) of an alarm code; an unknown code is shown as it comes.
    static let phrases: [String: String] = [
        "solar_cell_soh_abnormal": "Una celda de un módulo de batería está marcada como anormal por la propia batería",
        "solar_module_overcurrent": "Un módulo de batería lleva más corriente de la que dice admitir",
        "intrusion": "Intrusión detectada por los radares",
        "node_down": "Un nodo de campo no responde",
        "camera_motion": "Una cámara ha visto movimiento",
        "camera_down": "Una cámara no responde",
        "smoke": "Humo detectado",
        "co": "Monóxido de carbono detectado",
        "gas": "Gas detectado",
        "water_leak": "Inundación detectada",
        "panic": "Botón de pánico pulsado",
        "door_open": "Puerta abierta con el sistema armado",
        "window_open": "Ventana abierta con el sistema armado",
        "motion": "Movimiento con el sistema armado",
        "glass_break": "Rotura de cristal con el sistema armado",
        "vibration": "Vibración con el sistema armado",
        "tamper": "Un dispositivo ha sido manipulado",
        "low_battery": "Batería baja",
        "device_offline": "Un dispositivo ha dejado de responder",
        "triggered": "Un dispositivo se ha activado",
        "solar_fault": "Avería en un inversor solar",
        "solar_battery_low": "Batería solar baja",
        "solar_battery_alarm": "Una batería solar avisa de un problema",
        "solar_offline": "Un equipo solar ha dejado de responder",
        "solar_cells_unbalanced": "Las celdas de una batería están desequilibradas",
        "solar_battery_hot": "Una batería está demasiado caliente",
        "solar_battery_cold": "Una batería se está cargando con demasiado frío",
        "solar_battery_worn": "Una batería está muy desgastada",
        "solar_battery_overvoltage": "Una batería supera la tensión a la que actúa su propia protección",
        "solar_counter_rose": "Ha subido un contador de protección de un módulo de batería",
        "solar_inverter_hot": "Un inversor está demasiado caliente",
        "electrical_alarm": "Un contador de la red eléctrica avisa de una alarma",
        "electrical_voltage": "La tensión de red está fuera de rango",
        "electrical_grid_lost": "Se ha perdido el suministro de la red",
        "electrical_offline": "Un nodo eléctrico ha dejado de responder",
        "electrical_switch_fault": "Un conmutador de fuentes de la red eléctrica tiene una avería y queda abierto",
        "network_internet_down": "No hay internet y el router sigue respondiendo: es cosa del operador",
        "network_lan_down": "La red local está caída: el router no responde",
        "network_degraded": "Internet va lento o pierde paquetes",
        "network_new_device": "Un dispositivo que nunca se había visto se ha unido a la red",
        "network_arp_conflict": "Dos máquinas responden por una misma dirección de la red",
        "network_port_opened": "Un dispositivo de la red ha abierto un puerto",
        "network_offline": "Un nodo de red ha dejado de informar",
        "network_watched_online": "Un dispositivo que pediste vigilar ha vuelto a la red",
        "alarm_sounding": "¡La alarma está sonando!",
        "alarm_tamper": "Una zona de la alarma indica sabotaje (cable cortado o en cortocircuito)",
        "alarm_zone_trouble": "Una zona de la alarma no se puede leer: no está vigilando",
        "alarm_locked_out": "La central de alarma está bloqueada tras PIN erróneos",
        "alarm_offline": "Un nodo de alarma ha dejado de responder",
        "duress_disarm": "El sistema se desarmó con el PIN de coacción: puede que alguien esté siendo obligado",
    ]

    /// The sentence of an alarm code: from the table every client shares (in the language of the app) and, for a code that table lacks, from the phrases above; an unknown code is shown as it comes.
    public static func text(_ code: String, _ translator: Translator, table: [String: [String: String]] = AlarmCodes.shared) -> String {
        if let texts = table[code], let said = texts[translator.language] ?? texts["en"] { return said }
        guard let phrase = phrases[code] else { return code }
        return translator.tr(phrase)
    }

    public static func severityLabel(_ severity: String, _ translator: Translator) -> String {
        switch severity {
        case "critical": return translator.tr("CRÍTICA")
        case "high": return translator.tr("ALTA")
        default: return translator.tr("AVISO")
        }
    }
}
