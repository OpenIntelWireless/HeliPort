//
//  EAPSupplicant.swift
//  HeliPort
//
//  Copyright © 2026 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import AppKit
import Foundation

/// Lifecycle of a single 802.1X/PEAP/MSCHAPv2 authentication attempt.
/// Mirrors hostap's eap_peer state machine (RFC 4137) at the granularity
/// HeliPort's UI/logging actually cares about, not its internal substates.
enum EAPSupplicantState {
    case idle
    case identityRequested
    case peapTLSHandshake
    case mschapv2Challenge
    case mschapv2Success
    case derivingPMK
    case done
    case failed(EAPSupplicantError)
}

enum EAPSupplicantError: Error {
    case transportUnavailable
    /// Username or password was empty — never sent anywhere.
    case missingCredentials(String)
    case timeout
    /// Server rejected the MSCHAPv2 response — bad username/password.
    case authenticationRejected
    case tlsHandshakeFailed(String)
    case malformedFrame
    /// The RADIUS server's certificate was declined by the user (first
    /// connection) or no longer matches the certificate trusted previously
    /// (repeat connection) — see the trust-on-first-use flow below.
    case certificateNotTrusted(String)
}

/// Moves complete Ethernet II EAPOL frames (EtherType 0x888E) between the
/// supplicant and itlwm.
protocol EAPFrameTransport: AnyObject {
    /// Called by EAPSupplicantManager to hand an outbound EAPOL/EAP frame
    /// down to itlwm for transmission to the AP/authenticator.
    func send(eapolFrame: Data) throws

    /// Set by EAPSupplicantManager; invoked by the transport whenever itlwm
    /// delivers an inbound EAPOL/EAP frame captured from the air.
    var onFrameReceived: ((Data) -> Void)? { get set }

    /// An EAP exchange is starting; deliver inbound frames promptly.
    func expectTraffic()
}

// MARK: - C callback trampolines
//
// eap_bridge_create() takes plain C function pointers, which can't capture
// context the way a Swift closure can. These are free functions (no
// captures) so Swift can convert them to C function pointers implicitly at
// the call site; `swift_ctx` is an unretained, unmanaged pointer to the
// EAPSupplicantManager instance that created the bridge, recovered inside
// each trampoline.

private func eapBridgeSendTrampoline(swiftCtx: UnsafeMutableRawPointer?,
                                     data: UnsafePointer<UInt8>?,
                                     len: Int) {
    guard let swiftCtx = swiftCtx else { return }
    let manager = Unmanaged<EAPSupplicantManager>.fromOpaque(swiftCtx).takeUnretainedValue()
    let bytes: [UInt8] = (data != nil && len > 0) ? Array(UnsafeBufferPointer(start: data, count: len)) : []
    manager.handleBridgeSend(eapolFrame: bytes)
}

private func eapBridgeCertTrampoline(swiftCtx: UnsafeMutableRawPointer?,
                                     depth: Int32,
                                     subject: UnsafePointer<CChar>?,
                                     sha256Hex: UnsafePointer<CChar>?) {
    guard let swiftCtx = swiftCtx else { return }
    let manager = Unmanaged<EAPSupplicantManager>.fromOpaque(swiftCtx).takeUnretainedValue()
    let subjectStr = subject.map { String(cString: $0) } ?? ""
    let hashStr = sha256Hex.map { String(cString: $0) } ?? ""
    manager.handleBridgeCert(depth: depth, subject: subjectStr, sha256Hex: hashStr)
}

private func eapBridgeSuccessTrampoline(swiftCtx: UnsafeMutableRawPointer?,
                                        pmk: UnsafePointer<UInt8>?,
                                        len: Int) {
    guard let swiftCtx = swiftCtx, let pmk = pmk else { return }
    let manager = Unmanaged<EAPSupplicantManager>.fromOpaque(swiftCtx).takeUnretainedValue()
    manager.handleBridgeSuccess(pmk: Array(UnsafeBufferPointer(start: pmk, count: len)))
}

private func eapBridgeFailureTrampoline(swiftCtx: UnsafeMutableRawPointer?,
                                        errorCode: Int32) {
    guard let swiftCtx = swiftCtx else { return }
    let manager = Unmanaged<EAPSupplicantManager>.fromOpaque(swiftCtx).takeUnretainedValue()
    manager.handleBridgeFailure(errorCode: errorCode)
}

/// Owns one authentication attempt at a time and is the only object allowed
/// to hand a derived PMK to itlwm. NetworkManager.connectEnterprise(_:) is
/// the sole caller; nothing else should reach into this class.
///
/// Certificate trust (Phase 7): every attempt without a stored pin for its
/// SSID runs a "probe" first -- hostap's own ca_cert="probe://" mechanism,
/// which always aborts the TLS handshake immediately after the leaf
/// certificate is seen and strictly before Phase 2/any credential exchange
/// (see EAPSupplicantBridge.h). This lets the user be shown the exact
/// certificate that would be trusted with zero risk, regardless of what
/// they decide. If they accept, a second, real attempt is started with
/// ca_cert="hash://server/sha256/<hex>", which hostap's vendored TLS code
/// enforces natively and synchronously -- so even a first-time connection's
/// real credential exchange only ever happens against a certificate that
/// was actually shown to and accepted by the user, not merely whatever the
/// probe happened to see. On every later connection to the same SSID, the
/// stored pin is used directly (no probe, no prompt) and a mismatch is
/// rejected by that same native hostap check before Phase 2 -- the case
/// that matters most, since it is what actually detects a network that
/// changed identity.
final class EAPSupplicantManager {
    static let shared = EAPSupplicantManager()

    private(set) var state: EAPSupplicantState = .idle
    private var transport: EAPFrameTransport?
    private var completion: ((Result<Void, EAPSupplicantError>) -> Void)?
    private var currentSSID: String?
    private var pendingAuth: NetworkAuth?

    private enum AttemptPhase {
        case probing
        case authenticating
    }
    private var attemptPhase: AttemptPhase = .authenticating
    private var pendingLeafCert: (subject: String, sha256Hex: String)?
    private var pinnedHexForCurrentAttempt: String?

    /// The live hostap eap_peer state machine + RFC 4137 lower-layer glue
    /// (EAPSupplicantBridge.c, vendored alongside EAPCore/). nil whenever no
    /// attempt is in flight.
    private var eapBridge: OpaquePointer?

    /// Every touch of eapBridge (start, inbound frames, the 1 s tick) is
    /// funnelled through this serial queue; the C engine is not thread-safe.
    private let eapQueue = DispatchQueue(label: "org.openintelwireless.HeliPort.eap")
    private var tickTimer: DispatchSourceTimer?
    private var attemptDeadline: DispatchTime?
    private var attemptStart: DispatchTime?
    private var framesIn = 0
    private var framesOut = 0

    /// The enterprise network we're currently authenticated to, kept after a
    /// successful attempt so that when the authenticator re-runs EAP on the
    /// existing association (periodic reauthentication, roaming, session
    /// timeout) we can answer it instead of dropping its requests.
    private var session: (ssid: String, auth: NetworkAuth)?
    private var attemptIsReauth = false

    /// Overall budget for one attempt, including a trust-prompt round trip.
    private static let attemptTimeoutSeconds = 90

    /// Darwin notification that makes HeliPort send an EAPOL-Start on the
    /// current enterprise session, asking the authenticator to re-run EAP.
    /// Test hook for the reauthentication path:
    ///   notifyutil -p org.openintelwireless.HeliPort.debug.reauth
    static let debugReauthNotification = "org.openintelwireless.HeliPort.debug.reauth"

    private init() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), nil,
            { _, _, _, _, _ in EAPSupplicantManager.shared.requestReauthentication() },
            EAPSupplicantManager.debugReauthNotification as CFString, nil, .deliverImmediately)
    }

    /// Called at launch: if itlwm is still associated to a saved enterprise
    /// network (HeliPort was relaunched, or crashed, while connected),
    /// restore the session and open the EAPOL transport so authenticator-
    /// initiated reauthentication can still be answered.
    func attachIfOnEnterpriseNetwork(_ completion: ((Bool) -> Void)? = nil) {
        eapQueue.async {
            guard let session = self.sessionForCurrentNetwork() else {
                completion?(false)
                return
            }
            guard self.transport == nil else {
                completion?(true)
                return
            }
            guard KextEAPOLTransport.isSupported else {
                Log.error("EAPSupplicantManager: itlwm has no 802.1X support, cannot attach to \(session.ssid)")
                completion?(false)
                return
            }
            Log.debug("EAPSupplicantManager: attaching to existing \(session.ssid) association")
            self.configure(transport: KextEAPOLTransport())
            completion?(true)
        }
    }

    /// Sends an EAPOL-Start on the established session. The authenticator
    /// answers with a fresh EAP-Request/Identity, which startReauthentication
    /// then handles exactly like an authenticator-initiated reauth.
    func requestReauthentication() {
        attachIfOnEnterpriseNetwork { attached in
            guard attached else {
                Log.debug("EAPSupplicantManager: reauth requested but not on a saved enterprise network")
                return
            }
            self.sendEAPOLStartForReauth()
        }
    }

    private func sendEAPOLStartForReauth() {
        eapQueue.async {
            guard let session = self.sessionForCurrentNetwork() else {
                Log.debug("EAPSupplicantManager: reauth requested but there is no enterprise session")
                return
            }
            guard self.completion == nil, self.eapBridge == nil else {
                Log.debug("EAPSupplicantManager: reauth requested while an attempt is already running")
                return
            }
            var ssidBuf = [CChar](repeating: 0, count: Int(MAX_SSID_LENGTH) + 1)
            let driverSSID = get_network_ssid(&ssidBuf) ? String(cString: ssidBuf) : ""
            guard driverSSID == session.ssid,
                  let srcMAC = EAPSupplicantManager.currentInterfaceMAC(),
                  let dstMAC = EAPSupplicantManager.currentBSSID() else {
                Log.error("EAPSupplicantManager: reauth requested but not associated to \(session.ssid) " +
                          "(driver on '\(driverSSID)')")
                return
            }
            var frame = dstMAC + srcMAC + [0x88, 0x8E]
            frame += [2, 1, 0, 0] // EAPOL v2, EAPOL-Start, empty body
            let result = frame.withUnsafeBufferPointer { send_eapol_frame($0.baseAddress, UInt32($0.count)) }
            Log.debug("EAPSupplicantManager: sent EAPOL-Start to \(Self.macString(dstMAC)) to request " +
                      "reauthentication on \(session.ssid) (kr=0x\(String(UInt32(bitPattern: result), radix: 16)))")
        }
    }

    private func elapsed() -> String {
        guard let start = attemptStart else { return "-" }
        let millis = (DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        return "+\(millis)ms"
    }

    /// Injected once the IOUserClient-backed transport exists. Left nil
    /// until then so callers get an explicit .transportUnavailable failure
    /// rather than a silent no-op.
    /// Creates the kext-backed transport once; later calls reuse it.
    func useKextTransport() {
        eapQueue.sync {
            if self.transport == nil {
                self.configure(transport: KextEAPOLTransport())
            }
        }
    }

    func configure(transport: EAPFrameTransport) {
        Log.debug("EAPSupplicantManager: transport configured (\(type(of: transport)))")
        self.transport = transport
        self.transport?.onFrameReceived = { [weak self] frame in
            guard let self = self else { return }
            self.eapQueue.async { self.handleInboundFrame(frame) }
        }
    }

    func authenticate(ssid: String,
                      auth: NetworkAuth,
                      completion: @escaping (Result<Void, EAPSupplicantError>) -> Void) {
        eapQueue.async {
            self.attemptIsReauth = false
            self.beginAttempt(ssid: ssid, auth: auth, completion: completion)
        }
    }

    private func beginAttempt(ssid: String,
                              auth: NetworkAuth,
                              completion: @escaping (Result<Void, EAPSupplicantError>) -> Void) {
        if let stale = self.completion {
            Log.error("EAPSupplicantManager: new attempt for \(ssid) while one for " +
                      "\(currentSSID ?? "?") is still pending; abandoning the old one")
            self.completion = nil
            destroyBridge()
            stale(.failure(.timeout))
        }

        currentSSID = ssid
        self.completion = completion
        pendingAuth = auth
        pendingLeafCert = nil
        attemptStart = .now()
        attemptDeadline = .now() + .seconds(Self.attemptTimeoutSeconds)
        framesIn = 0
        framesOut = 0

        let pin = CertificatePinStore.shared.pin(forSSID: ssid)
        Log.debug("EAPSupplicantManager: authenticate ssid=\(ssid) " +
                  "usernameLength=\(auth.username.count) passwordLength=\(auth.password.count) " +
                  "pinnedCert=\(pin != nil) transport=\(transport != nil)")

        guard transport != nil else {
            Log.error("EAPSupplicantManager: no transport configured, cannot authenticate to \(ssid)")
            finish(.failure(.transportUnavailable))
            return
        }

        guard !auth.username.isEmpty else {
            Log.error("EAPSupplicantManager: username is empty for \(ssid); not starting EAP")
            finish(.failure(.missingCredentials("username is empty")))
            return
        }
        guard !auth.password.isEmpty else {
            Log.error("EAPSupplicantManager: password is empty for \(ssid); not starting EAP")
            finish(.failure(.missingCredentials("password is empty")))
            return
        }

        state = .identityRequested
        transport?.expectTraffic()
        startTickTimer()

        if let pin = pin {
            pinnedHexForCurrentAttempt = pin.sha256Hex
            startBridge(auth: auth, caCertConfig: "hash://server/sha256/\(pin.sha256Hex)", phase: .authenticating)
        } else {
            pinnedHexForCurrentAttempt = nil
            startBridge(auth: auth, caCertConfig: "probe://", phase: .probing)
        }
    }

    private func startTickTimer() {
        tickTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: eapQueue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in self?.tick() }
        tickTimer = timer
        timer.resume()
    }

    private func tick() {
        if let deadline = attemptDeadline, DispatchTime.now() >= deadline {
            Log.error("EAPSupplicantManager: attempt for \(currentSSID ?? "?") timed out after " +
                      "\(Self.attemptTimeoutSeconds)s (state=\(state), framesIn=\(framesIn), framesOut=\(framesOut))")
            destroyBridge()
            finish(.failure(.timeout))
            return
        }
        guard let bridge = eapBridge else { return }
        eap_bridge_tick(bridge)
    }

    private func startBridge(auth: NetworkAuth, caCertConfig: String, phase: AttemptPhase) {
        Log.debug("EAPSupplicantManager: \(elapsed()) starting EAP engine phase=\(phase) " +
                  "ssid=\(currentSSID ?? "?")")
        attemptPhase = phase
        pendingLeafCert = nil

        eap_bridge_set_verbose_logging(UserDefaults.standard.bool(forKey: "EAPVerboseLogging") ? 1 : 0)
        let usernameBytes = Array(auth.username.utf8)
        let passwordBytes = Array(auth.password.utf8)
        let swiftCtx = Unmanaged.passUnretained(self).toOpaque()

        let bridge: OpaquePointer? = caCertConfig.withCString { caCertCStr in
            usernameBytes.withUnsafeBufferPointer { userBuf in
                passwordBytes.withUnsafeBufferPointer { passBuf in
                    eap_bridge_create(userBuf.baseAddress, userBuf.count,
                                      passBuf.baseAddress, passBuf.count,
                                      caCertCStr,
                                      swiftCtx,
                                      eapBridgeSendTrampoline,
                                      eapBridgeCertTrampoline,
                                      eapBridgeSuccessTrampoline,
                                      eapBridgeFailureTrampoline)
                }
            }
        }

        guard let bridge = bridge else {
            Log.error("EAPSupplicantManager: eap_bridge_create failed for \(currentSSID ?? "?") (phase=\(phase))")
            finish(.failure(.tlsHandshakeFailed("failed to initialize EAP engine")))
            return
        }

        eapBridge = bridge
        state = .peapTLSHandshake
        eap_bridge_start(bridge)

        // A fresh engine after the certificate probe: the authenticator
        // already ran (and saw us abort) one EAP exchange on this
        // association, so it won't volunteer another Identity request.
        if framesIn > 0 {
            Log.debug("EAPSupplicantManager: \(elapsed()) restarting EAP on the existing association")
            eap_bridge_send_start(bridge)
        }
    }

    // MARK: - Association-watcher hooks (called from NetworkManager)

    /// Snapshot for NetworkManager's association watcher: whether an attempt
    /// is still in flight and how many EAPOL frames it has received.
    func progress() -> (active: Bool, framesIn: Int) {
        eapQueue.sync { (completion != nil, framesIn) }
    }

    /// The driver just (re)entered RUN on the target network. If the AP's
    /// own Identity request hasn't shown up, ask for one with EAPOL-Start.
    func associationEstablished(bssid: String) {
        eapQueue.async {
            guard let bridge = self.eapBridge, self.framesIn == 0 else { return }
            Log.debug("EAPSupplicantManager: \(self.elapsed()) associated to \(bssid) with no EAP " +
                      "traffic yet, sending EAPOL-Start")
            eap_bridge_send_start(bridge)
        }
    }

    /// Association never happened (or the AP never spoke EAP). Ends the
    /// attempt so the caller can release the network.
    func abortIfNoProgress(reason: String) {
        eapQueue.async {
            guard self.completion != nil, self.framesIn == 0 else { return }
            Log.error("EAPSupplicantManager: \(self.elapsed()) aborting attempt for " +
                      "\(self.currentSSID ?? "?"): \(reason)")
            self.finish(.failure(.timeout))
        }
    }

    /// Called once the vendored EAP engine derives a PMK from a completed
    /// PEAP/MSCHAPv2 handshake. Pushes it to itlwm via IOCTL_80211_WPA_KEY
    /// and only then resolves the pending completion.
    func deliverPMK(_ pmk: [UInt8]) {
        guard pmk.count == Int(PMK_LEN) else {
            Log.error("EAPSupplicantManager: derived PMK is \(pmk.count) bytes, expected \(PMK_LEN)")
            finish(.failure(.malformedFrame))
            return
        }
        pushResultToKernel(status: ITL_EAP_STATUS_SUCCESS, pmk: pmk)
        finish(.success(()))
    }

    /// Ends the remembered session: the user connected elsewhere or
    /// disconnected, so later EAP requests must not be answered with these
    /// credentials.
    func endSession(reason: String) {
        eapQueue.async {
            guard let session = self.session else { return }
            Log.debug("EAPSupplicantManager: ending session for \(session.ssid) (\(reason))")
            self.session = nil
        }
    }

    /// The in-memory session, or, when HeliPort was relaunched while itlwm
    /// stayed associated, one rebuilt from the saved credentials of the
    /// enterprise network the driver is currently on. Call on eapQueue.
    private func sessionForCurrentNetwork() -> (ssid: String, auth: NetworkAuth)? {
        if let session = session {
            return session
        }
        var ssidBuf = [CChar](repeating: 0, count: Int(MAX_SSID_LENGTH) + 1)
        guard get_network_ssid(&ssidBuf) else { return nil }
        let ssid = String(cString: ssidBuf)
        guard !ssid.isEmpty,
              let auth = CredentialsManager.instance.getAuthFromSsid(ssid),
              auth.security == ITL80211_SECURITY_WPA2_ENTERPRISE ||
                auth.security == ITL80211_SECURITY_WPA_ENTERPRISE_MIXED,
              !auth.username.isEmpty, !auth.password.isEmpty else {
            return nil
        }
        Log.debug("EAPSupplicantManager: restored session for \(ssid) from saved credentials")
        session = (ssid, auth)
        return session
    }

    /// The authenticator sent an EAP-Request while no attempt is running.
    /// Must be called on eapQueue; on return eapBridge is set if a
    /// reauthentication was started.
    private func startReauthentication(triggeredBy eapID: Int) {
        guard completion == nil, let session = sessionForCurrentNetwork() else { return }

        var ssidBuf = [CChar](repeating: 0, count: Int(MAX_SSID_LENGTH) + 1)
        let driverSSID = get_network_ssid(&ssidBuf) ? String(cString: ssidBuf) : ""
        guard driverSSID == session.ssid else {
            Log.debug("EAPSupplicantManager: EAP-Request id=\(eapID) while driver is on '\(driverSSID)', " +
                      "not '\(session.ssid)'; ignoring")
            return
        }
        // A reauthentication must never surface a trust prompt; it only
        // proceeds against the certificate the user already accepted.
        guard CertificatePinStore.shared.pin(forSSID: session.ssid) != nil else {
            Log.error("EAPSupplicantManager: reauthentication requested by \(session.ssid) but no pinned " +
                      "certificate; not answering")
            return
        }

        Log.debug("EAPSupplicantManager: \(session.ssid) requested reauthentication (EAP id=\(eapID)), " +
                  "answering with the saved session")
        let ssid = session.ssid
        attemptIsReauth = true
        beginAttempt(ssid: ssid, auth: session.auth) { result in
            switch result {
            case .success:
                Log.debug("EAPSupplicantManager: reauthentication to \(ssid) succeeded")
            case .failure(let error):
                Log.error("EAPSupplicantManager: reauthentication to \(ssid) failed: \(error); releasing network")
                NetworkManager.abandonEnterpriseNetwork(ssid, reason: "reauthentication failed")
            }
        }
    }

    private func handleInboundFrame(_ frame: Data) {
        let bytes = [UInt8](frame)
        let src = bytes.count >= 12 ? Self.macString(Array(bytes[6..<12])) : "?"
        let etherType = bytes.count >= 14 ? String(format: "0x%02X%02X", bytes[12], bytes[13]) : "?"
        let eapolType = bytes.count > 15 ? Int(bytes[15]) : -1
        let eapCode = bytes.count > 18 ? Int(bytes[18]) : -1
        let eapID = bytes.count > 19 ? Int(bytes[19]) : -1
        let eapType = bytes.count > 22 ? Int(bytes[22]) : -1
        Log.debug("EAPSupplicantManager: \(elapsed()) RX \(bytes.count)B from \(src) ethertype=\(etherType) " +
                  "eapolType=\(eapolType) eapCode=\(eapCode) id=\(eapID) eapType=\(eapType) " +
                  "engine=\(eapBridge != nil) state=\(state)")

        if eapBridge == nil, eapolType == 0, eapCode == 1 {
            startReauthentication(triggeredBy: eapID)
        }
        guard let bridge = eapBridge else {
            Log.debug("EAPSupplicantManager: no active EAP engine, dropping frame")
            return
        }
        // The transport delivers complete Ethernet II frames; the EAP bridge
        // wants the EAPOL payload starting at the version byte.
        guard frame.count > 14 else { return }
        framesIn += 1
        let eapolBytes = Array(frame.dropFirst(14))
        eapolBytes.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            eap_bridge_rx_eapol_frame(bridge, base, buf.count)
        }
    }

    /// eap_bridge_send_fn: the engine wants to transmit an EAPOL frame
    /// (already framed: version + type + length + EAP packet). Wraps it in
    /// an Ethernet header and hands it to the transport.
    fileprivate func handleBridgeSend(eapolFrame: [UInt8]) {
        guard let transport = transport else {
            Log.error("EAPSupplicantManager: engine wants to send but there is no transport")
            return
        }
        let srcMAC = EAPSupplicantManager.currentInterfaceMAC()
        let dstMAC = EAPSupplicantManager.currentBSSID()
        guard let srcMAC = srcMAC, let dstMAC = dstMAC else {
            Log.error("EAPSupplicantManager: cannot send EAPOL frame, own MAC=\(srcMAC.map(Self.macString) ?? "nil") " +
                      "AP BSSID=\(dstMAC.map(Self.macString) ?? "nil")")
            return
        }
        framesOut += 1
        Log.debug("EAPSupplicantManager: \(elapsed()) TX \(eapolFrame.count)B EAPOL " +
                  "type=\(eapolFrame.count > 1 ? Int(eapolFrame[1]) : -1) " +
                  "\(Self.macString(srcMAC)) -> \(Self.macString(dstMAC))")

        var frame = Data(capacity: 14 + eapolFrame.count)
        frame.append(contentsOf: dstMAC)
        frame.append(contentsOf: srcMAC)
        frame.append(contentsOf: [0x88, 0x8E]) // EtherType: EAPOL
        frame.append(contentsOf: eapolFrame)

        do {
            try transport.send(eapolFrame: frame)
        } catch {
            Log.error("EAPSupplicantManager: sending EAPOL frame failed: \(error)")
        }
    }

    /// eap_bridge_cert_fn: the leaf (server) certificate has been presented.
    /// Always stashed for whoever handles the attempt's eventual outcome
    /// (handleBridgeFailure, for both the probe and the pinned-mismatch
    /// cases). For an already-pinned attempt, a mismatch here is purely
    /// informational -- hostap's own native server_cert_only check is
    /// already independently enforcing the real rejection regardless of
    /// what this comparison decides, so a bug here cannot itself cause a
    /// mismatched certificate to be accepted.
    fileprivate func handleBridgeCert(depth: Int32, subject: String, sha256Hex: String) {
        Log.debug("EAPSupplicantManager: \(elapsed()) server certificate depth=\(depth) " +
                  "subject=\(subject) sha256=\(sha256Hex) phase=\(attemptPhase)")
        guard depth == 0 else { return }
        // Without a fingerprint there is nothing to compare; never treat that
        // as a mismatch.
        guard !sha256Hex.isEmpty else { return }
        pendingLeafCert = (subject: subject, sha256Hex: sha256Hex)

        guard attemptPhase == .authenticating,
              let expected = pinnedHexForCurrentAttempt,
              expected.caseInsensitiveCompare(sha256Hex) != .orderedSame else {
            return
        }

        let ssid = currentSSID ?? ""
        DispatchQueue.main.async {
            _ = CriticalAlert(
                message: NSLocalizedString("Certificate for network has changed", comment: ""),
                informativeText: NSLocalizedString(
                    "The certificate presented by \"\(ssid)\" no longer matches the one trusted previously. " +
                    "This may mean the certificate was legitimately renewed, or that this is a " +
                    "different network using the same name. The connection has been blocked.",
                    comment: ""),
                options: [NSLocalizedString("OK", comment: "")]
            ).show()
        }
    }

    /// eap_bridge_success_fn: handshake completed, `pmk` is exactly 32 bytes
    /// (the vendored bridge already validated this).
    fileprivate func handleBridgeSuccess(pmk: [UInt8]) {
        Log.debug("EAPSupplicantManager: \(elapsed()) EAP success, \(pmk.count)-byte PMK derived " +
                  "(framesIn=\(framesIn), framesOut=\(framesOut))")
        state = .mschapv2Success
        destroyBridge()
        deliverPMK(pmk)
    }

    /// eap_bridge_failure_fn. Branches on which phase this attempt was in:
    ///   - probing, cert seen: this IS the probe succeeding at its actual
    ///     job (learning the cert) -- show the trust prompt and, if
    ///     accepted, chain into a second, real attempt.
    ///   - probing, no cert seen: a genuine failure before ever reaching
    ///     the server (e.g. no response) -- report normally.
    ///   - authenticating: normal failure handling, except a detected
    ///     certificate mismatch is reported as .certificateNotTrusted
    ///     rather than a generic error.
    fileprivate func handleBridgeFailure(errorCode: Int32) {
        Log.debug("EAPSupplicantManager: \(elapsed()) engine reported failure code=\(errorCode) " +
                  "phase=\(attemptPhase) certSeen=\(pendingLeafCert != nil) " +
                  "framesIn=\(framesIn) framesOut=\(framesOut)")
        destroyBridge()

        if attemptPhase == .probing {
            guard let leafCert = pendingLeafCert else {
                Log.error("EAPSupplicantManager: probe failed before any server certificate was seen " +
                          "(framesIn=\(framesIn), framesOut=\(framesOut))")
                finish(.failure(mapBridgeError(errorCode)))
                return
            }
            handleProbeCompleted(leafCert: leafCert)
            return
        }

        if let leafCert = pendingLeafCert,
           let expected = pinnedHexForCurrentAttempt,
           expected.caseInsensitiveCompare(leafCert.sha256Hex) != .orderedSame {
            finish(.failure(.certificateNotTrusted(
                "certificate presented does not match the previously trusted certificate for this network")))
            return
        }

        finish(.failure(mapBridgeError(errorCode)))
    }

    /// Shows the trust-on-first-use prompt synchronously. Runs on eapQueue,
    /// never the main queue, and nothing on main waits on eapQueue, so
    /// DispatchQueue.main.sync here cannot deadlock.
    private func handleProbeCompleted(leafCert: (subject: String, sha256Hex: String)) {
        let ssid = currentSSID
        let auth = pendingAuth
        let fingerprint = Self.colonSeparated(hex: leafCert.sha256Hex)

        var trusted = false
        DispatchQueue.main.sync {
            let response = CriticalAlert(
                message: NSLocalizedString("New network certificate", comment: ""),
                informativeText: NSLocalizedString(
                    "The network \"\(ssid ?? "")\" has not been seen before. Only continue if you " +
                    "recognize and trust this network.\n\nSubject: \(leafCert.subject)\n" +
                    "SHA-256: \(fingerprint)",
                    comment: ""),
                options: [NSLocalizedString("Trust", comment: ""), NSLocalizedString("Cancel", comment: "")]
            ).show()
            trusted = response == .alertFirstButtonReturn
        }

        Log.debug("EAPSupplicantManager: user \(trusted ? "trusted" : "declined") certificate \(fingerprint)")
        guard trusted, let ssid = ssid, let auth = auth else {
            finish(.failure(.certificateNotTrusted("user declined to trust the certificate presented by this network")))
            return
        }

        CertificatePinStore.shared.setPin(
            CertificatePinStore.Pin(sha256Hex: leafCert.sha256Hex, subject: leafCert.subject),
            forSSID: ssid)

        // The prompt may have sat on screen for a while; give the real
        // attempt its own full budget.
        attemptDeadline = .now() + .seconds(Self.attemptTimeoutSeconds)
        pinnedHexForCurrentAttempt = leafCert.sha256Hex
        startBridge(auth: auth, caCertConfig: "hash://server/sha256/\(leafCert.sha256Hex)", phase: .authenticating)
    }

    private func mapBridgeError(_ errorCode: Int32) -> EAPSupplicantError {
        switch errorCode {
        case 2: // EAP_BRIDGE_ERROR_EAP_FAILURE
            return .authenticationRejected
        case 3: // EAP_BRIDGE_ERROR_KEY_UNAVAILABLE
            return .tlsHandshakeFailed("EAP reported success but no usable key material was available")
        case 4: // EAP_BRIDGE_ERROR_MALFORMED_FRAME
            return .malformedFrame
        default: // 1 == EAP_BRIDGE_ERROR_INIT_FAILED, or anything unrecognized
            return .tlsHandshakeFailed("EAP engine error (code \(errorCode))")
        }
    }

    private func destroyBridge() {
        guard let bridge = eapBridge else { return }
        eap_bridge_destroy(bridge)
        eapBridge = nil
    }

    private func finish(_ result: Result<Void, EAPSupplicantError>) {
        tickTimer?.cancel()
        tickTimer = nil
        attemptDeadline = nil
        destroyBridge()

        switch result {
        case .success:
            state = .done
            Log.debug("EAPSupplicantManager: \(elapsed()) \(attemptIsReauth ? "reauthentication" : "attempt") " +
                      "for \(currentSSID ?? "?") succeeded")
            if let ssid = currentSSID, let auth = pendingAuth {
                session = (ssid, auth)
            }
        case .failure(let error):
            state = .failed(error)
            Log.error("EAPSupplicantManager: \(elapsed()) \(attemptIsReauth ? "reauthentication" : "attempt") " +
                      "for \(currentSSID ?? "?") failed: \(error) (framesIn=\(framesIn), framesOut=\(framesOut))")
            pushResultToKernel(status: kernelStatus(for: error), pmk: nil)
            session = nil
        }
        attemptIsReauth = false
        currentSSID = nil
        pendingAuth = nil
        pendingLeafCert = nil
        pinnedHexForCurrentAttempt = nil
        let finish = completion
        completion = nil
        finish?(result)
    }

    private func kernelStatus(for error: EAPSupplicantError) -> itl80211_eap_status {
        switch error {
        case .timeout:
            return ITL_EAP_STATUS_TIMEOUT
        case .authenticationRejected, .certificateNotTrusted:
            return ITL_EAP_STATUS_FAILED
        case .transportUnavailable, .missingCredentials, .tlsHandshakeFailed, .malformedFrame:
            return ITL_EAP_STATUS_ERROR
        }
    }

    /// The only call site in HeliPort that pushes EAP status/PMK material
    /// down to the kext — goes through ClientKit's existing
    /// IOConnectCallStructMethod-based shim (set_eap_pmk in Api.c), the same
    /// path every other itlwm control operation already uses.
    private func pushResultToKernel(status: itl80211_eap_status, pmk: [UInt8]?) {
        guard let ssid = currentSSID else {
            Log.error("EAPSupplicantManager: cannot report status \(status.rawValue) to itlwm, no current SSID")
            return
        }

        let result: kern_return_t
        if status == ITL_EAP_STATUS_SUCCESS, let pmk = pmk {
            result = set_eap_pmk(ssid, status, pmk, UInt32(pmk.count))
        } else {
            result = set_eap_pmk(ssid, status, nil, 0)
        }

        if result != KERN_SUCCESS {
            Log.error("EAPSupplicantManager: set_eap_pmk(\(ssid), status=\(status.rawValue)) failed: " +
                      "0x\(String(UInt32(bitPattern: result), radix: 16))")
        } else {
            Log.debug("EAPSupplicantManager: set_eap_pmk(\(ssid), status=\(status.rawValue)) accepted by itlwm")
        }
    }

    private static func macString(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
    }

    private static func colonSeparated(hex: String) -> String {
        let chars = Array(hex)
        let pairs = stride(from: 0, to: chars.count - 1, by: 2).map { String(chars[$0...$0 + 1]) }
        return pairs.joined(separator: ":").uppercased()
    }

    // MARK: - MAC address helpers for constructing outbound Ethernet frames

    private static func currentInterfaceMAC() -> [UInt8]? {
        var platformInfo = platform_info_t()
        guard get_platform_info(&platformInfo) else { return nil }
        let bsd = String(cCharArray: platformInfo.device_info_str)
        guard let macStr = NetworkManager.getMACAddressFromBSD(bsd: bsd) else { return nil }
        return macBytes(fromColonString: macStr)
    }

    private static func currentBSSID() -> [UInt8]? {
        var bssidBuf = [Int8](repeating: 0, count: 6)
        guard get_network_bssid(&bssidBuf) else { return nil }
        return bssidBuf.map { UInt8(bitPattern: $0) }
    }

    private static func macBytes(fromColonString str: String) -> [UInt8]? {
        let parts = str.split(separator: ":")
        guard parts.count == 6 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(6)
        for part in parts {
            guard let byte = UInt8(part, radix: 16) else { return nil }
            bytes.append(byte)
        }
        return bytes
    }
}
