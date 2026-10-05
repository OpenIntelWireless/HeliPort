/*
 * EAPSupplicantBridge implementation. See EAPSupplicantBridge.h for the
 * public contract. This is a minimal, from-scratch RFC 4137 "lower layer" --
 * hostap's own src/eapol_supp/eapol_supp_sm.c does the same job for
 * wpa_supplicant proper, but pulls in far more than this project needs
 * (control interface, config file blobs, EAP-FAST PAC files, etc.), so it
 * was intentionally not vendored; this file plays that role instead.
 */
#include "EAPSupplicantBridge.h"

#include "utils/includes.h"
#include "utils/hostap_common.h"
#include "utils/wpabuf.h"
#include "eap_peer/eap_config.h"
#include "eap_peer/eap.h"
#include "crypto/tls.h"
#include "eap_peer/eap_methods.h"

struct eap_bridge {
    struct eap_sm *sm;
    struct eap_peer_config config;
    struct eap_config eap_conf;
    struct eapol_callbacks cb;

    /* RFC 4137 lower-layer state variables, owned here and exposed to the
     * EAP SM only through the eapol_callbacks get/set functions below. */
    bool eapSuccess;
    bool eapRestart;
    bool eapFail;
    bool eapResp;
    bool eapNoResp;
    bool eapReq;
    bool portEnabled;
    bool altAccept;
    bool altReject;
    unsigned int idleWhile;

    struct wpabuf *eapReqData;

    void *swift_ctx;
    eap_bridge_send_fn send_fn;
    eap_bridge_cert_fn cert_fn;
    eap_bridge_success_fn success_fn;
    eap_bridge_failure_fn failure_fn;

    int finished;
};

/* PEAP-only outer method list. Read-only, identical for every instance --
 * intentionally NOT per-bridge state. Rejecting anything but PEAP here is
 * deliberate: a misbehaving/hostile AP offering a weaker method (e.g. plain
 * EAP-MD5) must not be silently accepted. */
static struct eap_method_type allowed_methods[2];
static int allowed_methods_init_done;

static void ensure_allowed_methods(void)
{
    if (allowed_methods_init_done)
        return;
    allowed_methods[0].vendor = EAP_VENDOR_IETF;
    allowed_methods[0].method = EAP_TYPE_PEAP;
    allowed_methods[1].vendor = EAP_VENDOR_IETF;
    allowed_methods[1].method = EAP_TYPE_NONE; /* terminator */
    allowed_methods_init_done = 1;
}

/* ---- struct eapol_callbacks implementation ---- */

static struct eap_peer_config *cb_get_config(void *ctx)
{
    struct eap_bridge *b = ctx;
    return &b->config;
}

static bool cb_get_bool(void *ctx, enum eapol_bool_var variable)
{
    struct eap_bridge *b = ctx;
    switch (variable) {
    case EAPOL_eapSuccess: return b->eapSuccess;
    case EAPOL_eapRestart: return b->eapRestart;
    case EAPOL_eapFail: return b->eapFail;
    case EAPOL_eapResp: return b->eapResp;
    case EAPOL_eapNoResp: return b->eapNoResp;
    case EAPOL_eapReq: return b->eapReq;
    case EAPOL_portEnabled: return b->portEnabled;
    case EAPOL_altAccept: return b->altAccept;
    case EAPOL_altReject: return b->altReject;
    default: return false;
    }
}

static void cb_set_bool(void *ctx, enum eapol_bool_var variable, bool value)
{
    struct eap_bridge *b = ctx;
    switch (variable) {
    case EAPOL_eapSuccess: b->eapSuccess = value; break;
    case EAPOL_eapRestart: b->eapRestart = value; break;
    case EAPOL_eapFail: b->eapFail = value; break;
    case EAPOL_eapResp: b->eapResp = value; break;
    case EAPOL_eapNoResp: b->eapNoResp = value; break;
    case EAPOL_eapReq: b->eapReq = value; break;
    case EAPOL_portEnabled: b->portEnabled = value; break;
    case EAPOL_altAccept: b->altAccept = value; break;
    case EAPOL_altReject: b->altReject = value; break;
    default: break;
    }
}

static unsigned int cb_get_int(void *ctx, enum eapol_int_var variable)
{
    struct eap_bridge *b = ctx;
    if (variable == EAPOL_idleWhile)
        return b->idleWhile;
    return 0;
}

static void cb_set_int(void *ctx, enum eapol_int_var variable, unsigned int value)
{
    struct eap_bridge *b = ctx;
    if (variable == EAPOL_idleWhile)
        b->idleWhile = value;
}

static struct wpabuf *cb_get_eapReqData(void *ctx)
{
    struct eap_bridge *b = ctx;
    return b->eapReqData;
}

static void cb_set_config_blob(void *ctx, struct wpa_config_blob *blob)
{
    /* No blob storage (PAC files etc.) needed for PEAP/MSCHAPv2 -- free
     * whatever the SM handed us so it isn't leaked. */
    (void)ctx;
    if (blob) {
        os_free(blob->name);
        os_free(blob->data);
        os_free(blob);
    }
}

static const struct wpa_config_blob *cb_get_config_blob(void *ctx, const char *name)
{
    (void)ctx;
    (void)name;
    return NULL;
}

static void cb_notify_pending(void *ctx) { (void)ctx; }

static void cb_eap_param_needed(void *ctx, enum wpa_ctrl_req_type field, const char *txt)
{
    /* Username/password are supplied up front; there is no interactive
     * control-interface re-prompt path in this project. */
    (void)ctx;
    (void)field;
    (void)txt;
}

static void cb_notify_cert(void *ctx, struct tls_cert_data *cert, const char *cert_hash)
{
    struct eap_bridge *b = ctx;
    /* Only the leaf (server) certificate matters for pinning -- depth 0 is
     * the server's own certificate; higher depths are intermediate/root CAs
     * in the chain it presented (see tls_process_certificate() in
     * tlsv1_client_read.c: idx 0 is parsed into conn->server_rsa_key, i.e.
     * treated as "the server's" certificate, confirming the indexing). */
    if (!cert || cert->depth != 0 || !b->cert_fn)
        return;
    b->cert_fn(b->swift_ctx, cert->depth,
              cert->subject ? cert->subject : "",
              cert_hash ? cert_hash : "");
}

static void cb_notify_status(void *ctx, const char *status, const char *parameter)
{
    (void)ctx;
    (void)status;
    (void)parameter;
}

static void cb_notify_eap_error(void *ctx, int error_code)
{
    (void)ctx;
    (void)error_code;
}

static void cb_set_anon_id(void *ctx, const u8 *id, size_t len)
{
    (void)ctx;
    (void)id;
    (void)len;
}

/* ---- EAPOL framing + driving the state machine ---- */

static void send_eapol_frame(struct eap_bridge *b, const u8 *eap_pkt, size_t eap_len)
{
    u8 *frame;

    if (eap_len > 0xFFFF)
        return; /* cannot happen for PEAP/MSCHAPv2 fragment sizes; defensive only */

    frame = os_malloc(4 + eap_len);
    if (!frame)
        return;

    frame[0] = 2; /* EAPOL protocol version 2 (IEEE 802.1X-2004) */
    frame[1] = 0; /* EAPOL-EAP */
    frame[2] = (u8)((eap_len >> 8) & 0xff);
    frame[3] = (u8)(eap_len & 0xff);
    if (eap_len)
        os_memcpy(frame + 4, eap_pkt, eap_len);

    wpa_printf(MSG_INFO, "EAPBridge: TX EAP code=%u id=%u type=%u len=%zu",
               eap_len > 0 ? eap_pkt[0] : 0, eap_len > 1 ? eap_pkt[1] : 0,
               eap_len > 4 ? eap_pkt[4] : 0, eap_len);

    b->send_fn(b->swift_ctx, frame, 4 + eap_len);
    os_free(frame);
}

static void run_step(struct eap_bridge *b)
{
    int res;

    if (b->finished)
        return;

    do {
        res = eap_peer_sm_step(b->sm);
    } while (res == 1);

    if (b->eapResp) {
        struct wpabuf *resp;
        b->eapResp = false;
        resp = eap_get_eapRespData(b->sm);
        if (resp) {
            send_eapol_frame(b, wpabuf_head_u8(resp), wpabuf_len(resp));
            wpabuf_free(resp);
        }
    }

    if (b->finished)
        return; /* a callback invoked during the step above already finished us */

    if (b->eapFail) {
        b->finished = 1;
        wpa_printf(MSG_ERROR, "EAPBridge: state machine reached FAILURE "
                   "(idleWhile=%u eapReq=%d altReject=%d) -> EAP_FAILURE",
                   b->idleWhile, b->eapReq, b->altReject);
        b->failure_fn(b->swift_ctx, EAP_BRIDGE_ERROR_EAP_FAILURE);
        return;
    }

    if (b->eapSuccess) {
        b->finished = 1;
        wpa_printf(MSG_INFO, "EAPBridge: state machine reached SUCCESS, key available=%d",
                   eap_key_available(b->sm));
        if (eap_key_available(b->sm)) {
            size_t key_len = 0;
            const u8 *key = eap_get_eapKeyData(b->sm, &key_len);
            /* Mirrors hostap's own src/eapol_supp/eapol_supp_sm.c
             * eapol_sm_get_key(): take the first 32 bytes of the MSK as the
             * PMK. Real callers (src/rsn_supp/wpa.c) do exactly this via
             * eapol_sm_get_key(sm->eapol, sm->pmk, PMK_LEN) with
             * PMK_LEN == 32 -- not derived independently here. */
            if (key && key_len >= 32) {
                b->success_fn(b->swift_ctx, key, 32);
            } else {
                b->failure_fn(b->swift_ctx, EAP_BRIDGE_ERROR_KEY_UNAVAILABLE);
            }
        } else {
            b->failure_fn(b->swift_ctx, EAP_BRIDGE_ERROR_KEY_UNAVAILABLE);
        }
        return;
    }
}

/* ---- public API ---- */

eap_bridge_t *eap_bridge_create(const uint8_t *username, size_t username_len,
                                const uint8_t *password, size_t password_len,
                                const char *ca_cert_config,
                                void *swift_ctx,
                                eap_bridge_send_fn send_fn,
                                eap_bridge_cert_fn cert_fn,
                                eap_bridge_success_fn success_fn,
                                eap_bridge_failure_fn failure_fn)
{
    static int methods_registered;
    struct eap_bridge *b;

    if (!send_fn || !cert_fn || !success_fn || !failure_fn)
        return NULL;

    wpa_printf(MSG_INFO, "EAPBridge: create identity_len=%zu password_len=%zu ca_cert=%s",
               username_len, password_len,
               ca_cert_config ? (os_strncmp(ca_cert_config, "probe://", 8) == 0 ? "probe://" : "hash://<pinned>") : "(none)");

    if (!methods_registered) {
        if (eap_peer_peap_register() != 0 || eap_peer_mschapv2_register() != 0) {
            wpa_printf(MSG_ERROR, "EAPBridge: failed to register PEAP/MSCHAPv2 methods");
            return NULL;
        }
        methods_registered = 1;
    }
    ensure_allowed_methods();

    b = os_zalloc(sizeof(*b));
    if (!b)
        return NULL;

    b->swift_ctx = swift_ctx;
    b->send_fn = send_fn;
    b->cert_fn = cert_fn;
    b->success_fn = success_fn;
    b->failure_fn = failure_fn;
    b->portEnabled = true; /* 802.11 association already completed by the
                            * time authenticate() runs -- see
                            * itlwm::associateSSIDEnterprise() ordering */

    b->config.identity = os_malloc(username_len ? username_len : 1);
    b->config.password = os_malloc(password_len ? password_len : 1);
    if (!b->config.identity || !b->config.password) {
        eap_bridge_destroy(b);
        return NULL;
    }
    if (username_len)
        os_memcpy(b->config.identity, username, username_len);
    b->config.identity_len = username_len;
    if (password_len)
        os_memcpy(b->config.password, password, password_len);
    b->config.password_len = password_len;

    /* Outer: PEAP (allowed_methods). Inner (Phase 2, inside the TLS
     * tunnel): MSCHAPv2 -- selected via this config string, which
     * eap_peap.c parses itself; there is no separate struct field for it
     * (confirmed by reading eap_config.h and eap_peap.c's own config
     * parsing before writing this). */
    b->config.phase2 = os_strdup("auth=MSCHAPV2");
    if (!b->config.phase2) {
        eap_bridge_destroy(b);
        return NULL;
    }

    /* PEAPv0 is what Windows/macOS use and what RADIUS servers (NPS, ISE,
     * FreeRADIUS) interoperate with reliably; PEAPv1 derives keys with
     * different labels. Without this hostap picks v1 whenever the server
     * advertises it. */
    b->config.phase1 = os_strdup("peapver=0");
    if (!b->config.phase1) {
        eap_bridge_destroy(b);
        return NULL;
    }

    /* wpa_supplicant's DEFAULT_FRAGMENT_SIZE. Left at 0, hostap splits every
     * TLS message into zero-byte fragments and the handshake never
     * progresses. */
    b->config.fragment_size = 1398;

    b->config.eap_methods = allowed_methods;

    /* Phase 7: trust-on-first-use pinning. ca_cert_config is either
     * "probe://" (learn the cert, always abort before Phase 2 -- see
     * header) or "hash://server/sha256/<hex>" (pin-and-enforce, checked
     * natively and synchronously by the vendored TLS code). NULL is still
     * accepted at this layer for completeness but must never be used by a
     * real caller -- EAPSupplicantManager always passes one of the two
     * secure forms. */
    if (ca_cert_config) {
        b->config.cert.ca_cert = os_strdup(ca_cert_config);
        if (!b->config.cert.ca_cert) {
            eap_bridge_destroy(b);
            return NULL;
        }
    } else {
        b->config.cert.ca_cert = NULL;
    }

    b->cb.get_config = cb_get_config;
    b->cb.get_bool = cb_get_bool;
    b->cb.set_bool = cb_set_bool;
    b->cb.get_int = cb_get_int;
    b->cb.set_int = cb_set_int;
    b->cb.get_eapReqData = cb_get_eapReqData;
    b->cb.set_config_blob = cb_set_config_blob;
    b->cb.get_config_blob = cb_get_config_blob;
    b->cb.notify_pending = cb_notify_pending;
    b->cb.eap_param_needed = cb_eap_param_needed;
    b->cb.notify_cert = cb_notify_cert;
    b->cb.notify_status = cb_notify_status;
    b->cb.notify_eap_error = cb_notify_eap_error;
    b->cb.set_anon_id = cb_set_anon_id;

    /* Have the TLS client hash the server certificate for notify_cert in
     * pinned (hash://) mode too, not only when probing, so a changed
     * certificate can be reported as such. */
    b->eap_conf.cert_in_cb = 1;

    b->sm = eap_peer_sm_init(b, &b->cb, b, &b->eap_conf);
    if (!b->sm) {
        wpa_printf(MSG_ERROR, "EAPBridge: eap_peer_sm_init failed");
        eap_bridge_destroy(b);
        return NULL;
    }
    /* wpa_supplicant enables all EAP interop workarounds by default
     * (DEFAULT_EAP_WORKAROUND). */
    eap_set_workaround(b->sm, 1);

    return b;
}

void eap_bridge_set_verbose_logging(int verbose)
{
    /* MSG_DEBUG includes MSCHAPv2 challenge/response hexdumps, which are
     * enough to attack the password offline; keep it strictly opt-in. */
    wpa_debug_level = verbose ? MSG_DEBUG : MSG_INFO;
}

void eap_bridge_start(eap_bridge_t *b)
{
    if (!b || b->finished)
        return;

    /* hostap's INITIALIZE action (which arms idleWhile = ClientTimeout) only
     * runs via the global eapRestart && portEnabled transition. Without it
     * the SM falls straight through to IDLE with idleWhile == 0 and
     * immediately declares FAILURE. wpa_supplicant's eapol_supp sets this
     * the same way when authentication begins. */
    b->eapRestart = true;
    wpa_printf(MSG_INFO, "EAPBridge: start (eapRestart), waiting for EAP-Request from the authenticator");
    run_step(b);
}

void eap_bridge_send_start(eap_bridge_t *b)
{
    static const u8 eapol_start[4] = {2, 1, 0, 0}; /* version=2, type=EAPOL-Start, len=0 */

    if (!b || b->finished)
        return;

    wpa_printf(MSG_INFO, "EAPBridge: sending EAPOL-Start");
    b->send_fn(b->swift_ctx, eapol_start, sizeof(eapol_start));
}

void eap_bridge_tick(eap_bridge_t *b)
{
    if (!b || b->finished)
        return;
    if (b->idleWhile > 0) {
        b->idleWhile--;
        if (b->idleWhile == 0)
            wpa_printf(MSG_INFO, "EAPBridge: idleWhile expired, stepping state machine");
    }
    run_step(b);
}

void eap_bridge_rx_eapol_frame(eap_bridge_t *b, const uint8_t *data, size_t len)
{
    u8 type;
    size_t body_len;

    if (!b || b->finished || !data)
        return;

    if (len < 4)
        return; /* shorter than an EAPOL header; drop silently, not fatal */

    type = data[1];
    body_len = ((size_t)data[2] << 8) | (size_t)data[3];

    wpa_printf(MSG_INFO, "EAPBridge: RX EAPOL version=%u type=%u body_len=%zu frame_len=%zu"
               " EAP code=%u id=%u type=%u",
               data[0], type, body_len, len,
               len > 4 ? data[4] : 0, len > 5 ? data[5] : 0, len > 8 ? data[8] : 0);

    if (body_len > len - 4) {
        wpa_printf(MSG_ERROR, "EAPBridge: malformed EAPOL frame, body_len %zu > %zu",
                   body_len, len - 4);
        b->finished = 1;
        b->failure_fn(b->swift_ctx, EAP_BRIDGE_ERROR_MALFORMED_FRAME);
        return;
    }

    if (type != 0 /* EAPOL-EAP */)
        return; /* EAPOL-Key/Logoff/etc: not this layer's concern */

    if (b->eapReqData) {
        wpabuf_free(b->eapReqData);
        b->eapReqData = NULL;
    }
    b->eapReqData = wpabuf_alloc_copy(data + 4, body_len);
    if (!b->eapReqData)
        return;

    b->eapReq = true;
    run_step(b);
}

void eap_bridge_destroy(eap_bridge_t *b)
{
    if (!b)
        return;
    if (b->sm)
        eap_peer_sm_deinit(b->sm);
    if (b->eapReqData)
        wpabuf_free(b->eapReqData);
    os_free(b->config.identity);
    os_free(b->config.password);
    os_free(b->config.phase1);
    os_free(b->config.phase2);
    os_free(b->config.cert.ca_cert);
    os_free(b);
}
