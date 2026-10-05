//
//  KextEAPOLTransport.swift
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

import Foundation

enum KextEAPOLTransportError: Error {
    case sendFailed(kern_return_t)
}

/// Moves EAPOL frames between the supplicant and itlwm through the
/// RX_EAPOL / TX_EAPOL user-client calls. itlwm queues incoming frames, so
/// they are polled: quickly while an EAP exchange is expected, slowly
/// otherwise, which is enough to catch an authenticator-initiated
/// reauthentication (APs retransmit EAP requests for several seconds).
final class KextEAPOLTransport: EAPFrameTransport {
    var onFrameReceived: ((Data) -> Void)?

    private static let fastInterval: DispatchTimeInterval = .milliseconds(10)
    private static let slowInterval: DispatchTimeInterval = .milliseconds(250)
    private static let fastWindow: DispatchTimeInterval = .seconds(30)

    private let queue = DispatchQueue(label: "org.openintelwireless.HeliPort.eapol")
    private let timer: DispatchSourceTimer
    private var fastUntil = DispatchTime.now()
    private var polling = KextEAPOLTransport.slowInterval
    private var buffer = [UInt8](repeating: 0, count: Int(EAPOL_MAX_FRAME))

    /// False when the installed itlwm predates 802.1X support.
    static var isSupported: Bool {
        var frame = [UInt8](repeating: 0, count: Int(EAPOL_MAX_FRAME))
        var len: UInt32 = 0
        return receive_eapol_frame(&frame, UInt32(frame.count), &len) == KERN_SUCCESS
    }

    init() {
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: polling)
        timer.setEventHandler { [weak self] in self?.poll() }
        timer.resume()
    }

    deinit {
        timer.cancel()
    }

    func expectTraffic() {
        queue.async {
            self.fastUntil = .now() + Self.fastWindow
            self.setInterval(Self.fastInterval)
        }
    }

    func send(eapolFrame: Data) throws {
        let result = eapolFrame.withUnsafeBytes { raw -> kern_return_t in
            send_eapol_frame(raw.bindMemory(to: UInt8.self).baseAddress, UInt32(raw.count))
        }
        guard result == KERN_SUCCESS else {
            throw KextEAPOLTransportError.sendFailed(result)
        }
        expectTraffic()
    }

    private func poll() {
        // Bounded so a misbehaving peer can't keep this queue busy forever.
        for _ in 0..<32 {
            var len: UInt32 = 0
            guard receive_eapol_frame(&buffer, UInt32(buffer.count), &len) == KERN_SUCCESS, len > 0 else {
                break
            }
            fastUntil = .now() + Self.fastWindow
            onFrameReceived?(Data(buffer[0..<Int(len)]))
        }
        setInterval(DispatchTime.now() < fastUntil ? Self.fastInterval : Self.slowInterval)
    }

    private func setInterval(_ interval: DispatchTimeInterval) {
        guard interval != polling else { return }
        polling = interval
        timer.schedule(deadline: .now() + interval, repeating: interval)
    }
}
