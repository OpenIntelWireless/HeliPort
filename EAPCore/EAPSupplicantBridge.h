/*
 * EAPSupplicantBridge - minimal RFC 4137 "lower layer" driving hostaps
 * vendored eap_peer state machine (PEAP outer / MSCHAPv2 inner) from Swift.
 *
 * This replaces what hostaps own (NOT vendored) src/eapol_supp/eapol_supp_sm.c
 * would normally do: own the EAPOL boolean/int state variables the EAP SM
 * reads/writes via callbacks, own the EAP-Request buffer, and drive
 * eap_peer_sm_step() to completion after each external event (an inbound
 * frame, or the initial kickoff).
 *
 * Threading: this bridge is NOT thread-safe internally and expects to be
 * driven from a single serial queue (EAPSupplicantManager already serializes
 * calls onto its own queue at the Swift layer).
 */
#ifndef EAP_SUPPLICANT_BRIDGE_H
#define EAP_SUPPLICANT_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

typedef struct eap_bridge eap_bridge_t;

/* Called with a complete EAPOL frame (starting at the EAPOL version byte -
 * version(1) + type(1) + body_length(2, big-endian) + body) that must be
 * wrapped in an Ethernet header (dst = AP BSSID, src = our own MAC,
 * ethertype 0x888E) and transmitted by the caller. The bridge owns "data"
 * only for the duration of this call. */
typedef void (*eap_bridge_send_fn)(void *swift_ctx, const uint8_t *data, size_t len);

/* Called whenever the peer (server) certificate is presented during the TLS
 * handshake -- depth 0 only (the leaf/server certificate; intermediate/CA
 * certificates at higher depth are not forwarded, callers only need the
 * leaf for pinning). subject and sha256_hex are valid only for the duration
 * of this call; copy them if needed afterward. sha256_hex is lowercase hex,
 * no separators, exactly 64 characters. May be called zero or more times
 * per attempt depending on how many round trips the TLS handshake needs;
 * in practice exactly once per attempt that gets far enough to see a
 * certificate at all. */
typedef void (*eap_bridge_cert_fn)(void *swift_ctx, int depth, const char *subject,
                                   const char *sha256_hex);

/* Called exactly once, with a 32-byte PMK, when the handshake completes
 * successfully. */
typedef void (*eap_bridge_success_fn)(void *swift_ctx, const uint8_t *pmk, size_t pmk_len);

/* Called exactly once if the handshake fails or is aborted. error_code is an
 * eap_bridge_error value. */
typedef void (*eap_bridge_failure_fn)(void *swift_ctx, int error_code);

enum eap_bridge_error {
    EAP_BRIDGE_ERROR_INIT_FAILED = 1,
    EAP_BRIDGE_ERROR_EAP_FAILURE = 2,
    EAP_BRIDGE_ERROR_KEY_UNAVAILABLE = 3,
    EAP_BRIDGE_ERROR_MALFORMED_FRAME = 4,
};

/* Creates a bridge configured for EAP-PEAP (outer) / MSCHAPv2 (inner) with
 * the given credentials. Does not send anything yet - call eap_bridge_start().
 *
 * ca_cert_config selects how (whether) the server certificate is checked --
 * passed straight through to struct eap_peer_cert_config.ca_cert, whose
 * format is documented in eap_config.h:
 *   - NULL: no verification at all (insecure -- do not use for a real
 *     attempt; every real caller must pass one of the two options below).
 *   - "probe://": always fails immediately after the leaf certificate is
 *     seen (cert_fn fires, then the handshake aborts before Phase 2/any
 *     credential exchange -- this is hostap's own built-in mechanism for
 *     "let me see the server's cert without ever risking real credentials",
 *     used here to implement trust-on-first-use safely).
 *   - "hash://server/sha256/<64 lowercase hex chars>": only succeeds if the
 *     presented leaf certificate's SHA-256 matches exactly; enforced
 *     natively and synchronously by the vendored TLS code during Certificate
 *     message parsing, strictly before Phase 2 begins.
 *
 * Returns NULL on allocation/init failure. */
eap_bridge_t *eap_bridge_create(const uint8_t *username, size_t username_len,
                                const uint8_t *password, size_t password_len,
                                const char *ca_cert_config,
                                void *swift_ctx,
                                eap_bridge_send_fn send_fn,
                                eap_bridge_cert_fn cert_fn,
                                eap_bridge_success_fn success_fn,
                                eap_bridge_failure_fn failure_fn);

/* Initializes the EAP state machine (eapRestart) so it waits for the
 * authenticator's EAP-Request/Identity. Sends nothing on its own. */
void eap_bridge_start(eap_bridge_t *b);

/* 0: hostap logs at MSG_INFO (default). Nonzero: MSG_DEBUG, which includes
 * credential-derived hexdumps; diagnostics only. */
void eap_bridge_set_verbose_logging(int verbose);

/* Sends an EAPOL-Start, asking the authenticator to (re)issue its
 * EAP-Request/Identity. Safe to call repeatedly. */
void eap_bridge_send_start(eap_bridge_t *b);

/* Feeds one complete inbound EAPOL frame (Ethernet header already stripped
 * by the caller, starting at the EAPOL version byte) into the state machine
 * and steps it to completion. May invoke send_fn/cert_fn/success_fn/
 * failure_fn synchronously before returning. */
void eap_bridge_rx_eapol_frame(eap_bridge_t *b, const uint8_t *data, size_t len);

/* RFC 4137 lower-layer one-second clock: decrements idleWhile and steps the
 * state machine, so a silent authenticator eventually fails the attempt.
 * Call once per second while an attempt is in flight. */
void eap_bridge_tick(eap_bridge_t *b);

/* Releases all resources. Safe to call at any point; does not itself invoke
 * failure_fn. */
void eap_bridge_destroy(eap_bridge_t *b);

#endif /* EAP_SUPPLICANT_BRIDGE_H */
