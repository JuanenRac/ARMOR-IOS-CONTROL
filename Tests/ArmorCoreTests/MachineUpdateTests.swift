import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

/// Updating the programs of the machine from the phone: what the server answers is read as it is, the calls are the ones the server has, the name typed again is what the server asks for,
/// and every word has a text in the eight languages. The same checks as the Android app.
final class MachineUpdateTests: XCTestCase {
    private let t = plain()
    private let plan = "0123456789abcdef01234567"

    private func object(_ text: String) -> JSON { (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? JSON ?? [:] }

    func testTheSwitchAndTheProgramsAreReadAndAProgramOutsideTheContractIsLeftOut() {
        let on = MachineUpdateParser.state(object(#"{"enabled":true,"available":true,"require_signed":true,"projects":["ARMOR-SERVER","ARMOR-STUDIO","not a project","../etc"],"reason":""}"#))
        XCTAssertTrue(on.enabled)
        XCTAssertTrue(on.requireSigned)
        XCTAssertEqual(on.projects, ["ARMOR-SERVER", "ARMOR-STUDIO"])
        let off = MachineUpdateParser.state(object(#"{"enabled":false,"reason":"switched_off"}"#))
        XCTAssertFalse(off.enabled)
        XCTAssertEqual(off.reason, "switched_off")
        XCTAssertTrue(off.projects.isEmpty)
        // the safe reading: what the server does not say is off, and the signature is required
        let empty = MachineUpdateParser.state([:])
        XCTAssertFalse(empty.enabled)
        XCTAssertTrue(empty.requireSigned)
    }

    func testThePreviewCarriesThePlanOnlyWhenItIsAValidOneAndAnUpdateIsAvailable() {
        let outdated = MachineUpdateParser.preview(object(#"{"project":"ARMOR-SERVER","installed":true,"local_version":"0.8.1.0","github_version":"0.8.2.0","state":"outdated","update_available":true,"plan_id":"\#(plan)","expires_in_s":300}"#))
        XCTAssertTrue(outdated.updateAvailable)
        XCTAssertEqual(outdated.planId, plan)
        XCTAssertEqual(outdated.expiresInS, 300)
        let current = MachineUpdateParser.preview(object(#"{"project":"ARMOR-SERVER","local_version":"0.8.2.0","github_version":"0.8.2.0","update_available":false}"#))
        XCTAssertFalse(current.updateAvailable)
        XCTAssertEqual(current.planId, "")
        // a plan that is not 24 hex digits is dropped: the phone never sends what the server would not hand out
        XCTAssertEqual(MachineUpdateParser.preview(object(#"{"project":"ARMOR-SERVER","update_available":true,"plan_id":"../../x"}"#)).planId, "")
        XCTAssertEqual(MachineUpdateParser.preview(object(#"{"project":"ARMOR-SERVER","update_available":true,"plan_id":null}"#)).planId, "")
    }

    func testTheNameTypedAgainMustBeExactlyTheProgramsAndTheCodeEmptyOrSixDigits() {
        XCTAssertTrue(MachineUpdateParser.confirmationOk(project: "ARMOR-SERVER", typed: "ARMOR-SERVER"))
        XCTAssertFalse(MachineUpdateParser.confirmationOk(project: "ARMOR-SERVER", typed: "armor-server"))
        XCTAssertFalse(MachineUpdateParser.confirmationOk(project: "ARMOR-SERVER", typed: "ARMOR-SERVER "))
        XCTAssertFalse(MachineUpdateParser.confirmationOk(project: "ARMOR-SERVER", typed: ""))
        XCTAssertFalse(MachineUpdateParser.confirmationOk(project: "server", typed: "server"))
        XCTAssertTrue(MachineUpdateParser.codeOk(""))
        XCTAssertTrue(MachineUpdateParser.codeOk("012345"))
        for bad in ["12345", "1234567", "12345a"] { XCTAssertFalse(MachineUpdateParser.codeOk(bad), bad) }
        XCTAssertTrue(MachineUpdateParser.isPlan(plan))
        XCTAssertFalse(MachineUpdateParser.isPlan("ABCDEF0123456789abcdef01"))
    }

    func testThePlanCountsDownAndNeverGoesBelowZero() {
        XCTAssertEqual(MachineUpdateParser.secondsLeft(expiresInS: 300, elapsedMs: 0), 300)
        XCTAssertEqual(MachineUpdateParser.secondsLeft(expiresInS: 300, elapsedMs: 10_400), 290)
        XCTAssertEqual(MachineUpdateParser.secondsLeft(expiresInS: 300, elapsedMs: 400_000), 0)
        XCTAssertEqual(MachineUpdateParser.secondsLeft(expiresInS: 300, elapsedMs: -5_000), 300)
    }

    func testTheJobIsReadWithItsStepsAndTheLogIsMergedWithoutRepeatingLines() {
        let job = MachineUpdateParser.job(object(#"{"id":"j1","state":"running","percent":140,"steps":[{"id":"server.download","state":"done","percent":100},{"id":"server.install","state":"running","percent":30},{"state":"x"}],"error":"","log":["a","b"],"log_total":2}"#))
        XCTAssertTrue(job.running)
        XCTAssertEqual(job.percent, 100)
        XCTAssertEqual(job.steps.map { $0.id }, ["server.download", "server.install"])
        XCTAssertEqual(job.logTotal, 2)
        XCTAssertEqual(MachineUpdateParser.mergeLog(["a", "b"], since: 2, fresh: ["c"]), ["a", "b", "c"])
        XCTAssertEqual(MachineUpdateParser.mergeLog(["a", "b"], since: 1, fresh: ["x", "y"]), ["a", "x", "y"])
        XCTAssertEqual(MachineUpdateParser.mergeLog(["a", "b"], since: 2, fresh: []), ["a", "b"])
        let failed = MachineUpdateParser.job(object(#"{"id":"j1","state":"failed","error":"the signature is not valid"}"#))
        XCTAssertTrue(failed.failed)
        XCTAssertFalse(failed.running)
        XCTAssertEqual(MachineUpdateParser.stepPart("server.download"), "download")
        XCTAssertEqual(MachineUpdateParser.stepPart("check"), "check")
    }

    func testTheCallsAreTheOnesTheServerHasAndSendOnlyWhatItTakes() async throws {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let api: ArmorApi = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
        let origin = "http://192.168.0.180:8080"

        StubProtocol.routes["GET /api/v1/admin/machine-update"] = (200, #"{"enabled":true,"available":true,"require_signed":true,"projects":["ARMOR-SERVER"],"reason":""}"#)
        let state = try await api.machineUpdateState(origin)
        XCTAssertEqual(state.projects, ["ARMOR-SERVER"])

        StubProtocol.routes["POST /api/v1/admin/machine-update/preview"] = (200, #"{"project":"ARMOR-SERVER","local_version":"0.8.1.0","github_version":"0.8.2.0","update_available":true,"plan_id":"\#(plan)","expires_in_s":300}"#)
        let preview = try await api.machineUpdatePreview(origin, project: "ARMOR-SERVER")
        XCTAssertEqual(preview.planId, plan)
        let previewBody = object(try XCTUnwrap(StubProtocol.bodies.last))
        XCTAssertEqual(Set(previewBody.keys), ["project"])

        StubProtocol.routes["POST /api/v1/admin/machine-update/apply"] = (202, #"{"id":"job-1"}"#)
        let id = try await api.machineUpdateApply(origin, project: "ARMOR-SERVER", planId: plan, confirm: "ARMOR-SERVER", code: "123456")
        XCTAssertEqual(id, "job-1")
        let applied = object(try XCTUnwrap(StubProtocol.bodies.last))
        XCTAssertEqual(Set(applied.keys), ["project", "plan_id", "confirm", "totp"])
        XCTAssertEqual(applied["confirm"] as? String, "ARMOR-SERVER")
        // without a code none is sent, and an empty one is not a code
        _ = try await api.machineUpdateApply(origin, project: "ARMOR-SERVER", planId: plan, confirm: "ARMOR-SERVER", code: nil)
        XCTAssertEqual(Set(object(try XCTUnwrap(StubProtocol.bodies.last)).keys), ["project", "plan_id", "confirm"])
        _ = try await api.machineUpdateApply(origin, project: "ARMOR-SERVER", planId: plan, confirm: "ARMOR-SERVER", code: "")
        XCTAssertNil(object(try XCTUnwrap(StubProtocol.bodies.last))["totp"])

        StubProtocol.routes["GET /api/v1/admin/machine-update/jobs/job-1"] = (200, #"{"id":"job-1","state":"done","percent":100,"steps":[],"log":["ok"],"log_total":1}"#)
        let job = try await api.machineUpdateJob(origin, id: "job-1", since: 0)
        XCTAssertEqual(job.state, "done")
        XCTAssertEqual(StubProtocol.seen.last?.url?.query, "since=0")
        _ = try await api.machineUpdateJob(origin, id: "job-1", since: -4)
        XCTAssertEqual(StubProtocol.seen.last?.url?.query, "since=0")
    }

    func testAProofOfIdentityThatIsOldIsAskedForAgainAndEveryRefusalHasItsWords() async throws {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let api: ArmorApi = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
        let origin = "http://192.168.0.180:8080"
        StubProtocol.routes["POST /api/v1/admin/machine-update/apply"] = (403, #"{"error":"this needs the password or the code again","code":"elevation_required"}"#)
        do { _ = try await api.machineUpdateApply(origin, project: "ARMOR-SERVER", planId: plan, confirm: "ARMOR-SERVER", code: nil); XCTFail("expected a refusal") }
        catch let error as ArmorApiError { XCTAssertTrue(error.isElevationRequired) }

        let expected: [(Int, String, String)] = [
            (403, "machine_update_disabled", "La actualización desde el móvil está apagada en el servidor o en el ayudante de mantenimiento."),
            (404, "no_plan", "El plan ya no existe o ya se usó. Comprueba las versiones otra vez."),
            (410, "plan_expired", "El plan ha caducado. Comprueba las versiones otra vez."),
            (409, "busy", "Ya hay otro trabajo en marcha en el equipo."),
            (422, "confirmation_mismatch", "El nombre escrito no coincide con el del programa."),
            (422, "bad_code", "El código de un solo uso tiene seis cifras."),
            (422, "bad_plan", "El plan no es válido. Comprueba las versiones otra vez."),
            (422, "unknown_project", "Ese programa no está en la lista de los que se pueden actualizar."),
            (429, "too_soon", "Se actualizó otro programa hace un momento. Espera unos minutos."),
            (503, "maintenance_unavailable", "El ayudante de mantenimiento no está instalado o no contesta."),
        ]
        for (status, error, words) in expected {
            StubProtocol.routes["POST /api/v1/admin/machine-update/apply"] = (status, "{\"error\":\"\(error)\"}")
            do { _ = try await api.machineUpdateApply(origin, project: "ARMOR-SERVER", planId: plan, confirm: "ARMOR-SERVER", code: nil); XCTFail("expected a refusal") }
            catch let refused as ArmorApiError {
                XCTAssertEqual(refused.status, status)
                XCTAssertEqual(refused.detail, error)
                XCTAssertEqual(MachineUpdateText.errorText(refused, t), words)
            }
        }
        XCTAssertEqual(MachineUpdateText.errorText(NSError(domain: "x", code: 1), t), "No se pudo completar.")
    }

    func testEveryWordOfTheScreenHasATextInEveryLanguage() throws {
        var needed: [String] = []
        for reason in ["switched_off", "not_configured", "agent_switched_off", "not_answering", "refused", "anything_else"] { needed.append(MachineUpdateText.reason(reason, t)) }
        for status in [403, 404, 410, 409, 422, 429, 503, 500] {
            for detail in ["machine_update_disabled", "confirmation_mismatch", "bad_code", "bad_plan", ""] { needed.append(MachineUpdateText.refusal(status: status, detail: detail, t)) }
        }
        for part in ["download", "verify", "install", "stage", "restart", "check"] { needed.append(MachineUpdateText.stepName("server." + part, t)) }
        XCTAssertGreaterThan(Set(needed).count, 20)
        for code in ["en", "de", "fr", "it", "ja", "zh", "pt"] {
            let table = try XCTUnwrap(Translator.bundled(code), code)
            let missing = Set(needed).filter { (table[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
            XCTAssertEqual(missing.sorted(), [], "\(code) lacks texts")
        }
    }
}
