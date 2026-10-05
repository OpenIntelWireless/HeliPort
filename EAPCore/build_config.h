#ifndef EAPCORE_BUILD_CONFIG_H
#define EAPCORE_BUILD_CONFIG_H

/* Vendored hostap EAP-peer core (PEAP + MSCHAPv2 only). No OpenSSL/GnuTLS:
 * software-only "internal" crypto + hostap's own internal TLSv1 client. */

#define CONFIG_CRYPTO_INTERNAL
#define CONFIG_TLS_INTERNAL_CLIENT
#define CONFIG_INTERNAL_LIBTOMMATH
#define CONFIG_TLSV11
#define CONFIG_TLSV12
#define CONFIG_SHA256
#define CONFIG_SHA384
#define CONFIG_INTERNAL_SHA384
#define CONFIG_HMAC_SHA384_KDF

#define EAP_PEAP
#define EAP_MSCHAPv2
#define IEEE8021X_EAPOL

/* no eloop vendored — use os_get_random() directly, no background
 * entropy-pool mixing thread needed on a platform with a real CSPRNG */
#define CONFIG_NO_RANDOM_POOL

#endif
