import XCTest
@testable import ArmorCore

final class ReportsTests: XCTestCase {
    private func json(_ text: String) -> JSON { try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! JSON }

    func testTheSummaryIsReadWithItsCountsItsPatternsAndItsNote() {
        let summary = ReportsParser.summary(json("""
        {"date":"2026-03-05","language":"es","summary":{"totals":{"events":7,"alarms":5,"serious_alarms":2,"false_alarms":1}},
         "findings":[{"kind":"recurrent_false_alarm","subject":{"zone":"garden"},"count":4},{"kind":"hourly_repeat","subject":{"code":"intrusion","zone":"hall"},"count":3},{"kind":"intermittent_link","subject":{},"count":2}],
         "text":"Un día tranquilo.","ai_note":"Mira el sensor del jardín."}
        """))
        XCTAssertEqual([summary.events, summary.alarms, summary.serious, summary.falseAlarms], [7, 5, 2, 1])
        XCTAssertEqual(summary.text, "Un día tranquilo.")
        XCTAssertEqual(summary.aiNote, "Mira el sensor del jardín.")
        XCTAssertEqual(summary.findings.map { $0.subject }, ["garden", "intrusion / hall", "-"])
        XCTAssertEqual(summary.findings.map { $0.count }, [4, 3, 2])
    }

    func testASummaryWithoutANoteOrFindingsReadsAsEmptyAndNeverFails() {
        let summary = ReportsParser.summary(json(#"{"date":"2026-03-05","language":"en","text":"x"}"#))
        XCTAssertNil(summary.aiNote)
        XCTAssertTrue(summary.findings.isEmpty)
        XCTAssertEqual(summary.events, 0)
    }

    func testTheHeatMapKeepsTheGridAndThePositionsCounted() {
        let map = ReportsParser.heatmap(json(#"{"camera_id":"cam-front","cols":4,"rows":3,"accepted_positions":12,"contains_images":false}"#), png: Data([1, 2, 3]))
        XCTAssertEqual([map.cameraId, "\(map.cols)", "\(map.rows)", "\(map.positions)"], ["cam-front", "4", "3", "12"])
        XCTAssertNotNil(map.png)
    }

    func testADayIsARealDateFromTheYear2000() {
        for good in ["2026-03-05", "2024-02-29", "2000-01-01", "2026-12-31"] { XCTAssertTrue(ReportsParser.validDate(good), good) }
        for bad in ["2026-02-30", "2026-13-01", "1999-12-31", "2026-1-1", "yesterday", "", "2026-03-05T10", "2026-00-10", "2026-04-31", "2100-02-29", "2026-0a-10"] { XCTAssertFalse(ReportsParser.validDate(bad), bad) }
    }

    func testEveryRefusalOfTheServerHasWordsThatSayWhatToDo() {
        let cases: [(Int?, String, String)] = [
            (404, "daily_summary_disabled", "apagado"), (404, "heatmap_disabled", "apagado"), (422, "invalid_date", "Eso no es un día"), (503, "heatmap_not_configured", "no está configurado"),
            (503, "daily_summary_not_configured", "no está configurado"), (503, "report_busy", "otro informe"), (502, "heatmap_failed", "No se pudo"), (502, "", "No se pudo"), (429, "", "Demasiadas"),
            (403, "", "administrador o un operador"), (401, "", "administrador o un operador"), (404, "", "apagado"), (503, "", "no está configurado"), (404, "unknown_camera", "no conoce esa cámara"),
            (404, "heatmap_pipeline_off", "flujo de actividad"), (nil, "", "no ha respondido"),
        ]
        for (status, error, words) in cases { XCTAssertTrue(ReportRefusal.phrase(status: status, error: error).contains(words), "\(String(describing: status)) \(error)") }
        XCTAssertFalse(ReportRefusal.phrase(status: 418, error: "").isEmpty)
        XCTAssertEqual(Set(ReportRefusal.all).count, ReportRefusal.all.count)
    }

    func testAnErrorOfTheServerIsReadFromItsStatusAndItsWords() {
        let error = ArmorApiError(message: "x", status: 404, body: #"{"error":"daily_summary_disabled"}"#)
        XCTAssertEqual(ReportRefusal.phrase(for: error), ReportRefusal.phrase(status: 404, error: "daily_summary_disabled"))
        XCTAssertTrue(ReportRefusal.phrase(for: NSError(domain: "x", code: 1)).contains("no ha respondido"))
    }
}
