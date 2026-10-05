# EAPCore

A subset of [hostap](https://w1.fi/hostap.git) (wpa_supplicant): the EAP peer
state machine, the PEAP and MSCHAPv2 methods, and hostap's internal TLS client and
crypto, so HeliPort doesn't depend on OpenSSL.

Local changes:

- `EAPSupplicantBridge.c/.h` (new): the lower layer (RFC 4137) that HeliPort's
  Swift supplicant drives.
- `build_config.h` (new): the feature set used here.
- `utils/wpa_debug.c`: messages are also sent to `os_log` (subsystem
  `com.OpenIntelWireless.HeliPort`, category `hostap`), since stdout is
  discarded for an app launched by launchd.
- `utils/common.h` is renamed `hostap_common.h` so it doesn't clash with
  ClientKit's `Common.h` on a case-insensitive file system.

## License

hostap is distributed under the terms of the BSD license:

> wpa_supplicant and hostapd
> Copyright (c) 2002-2019, Jouni Malinen <j@w1.fi> and contributors
> All Rights Reserved.
>
> Redistribution and use in source and binary forms, with or without
> modification, are permitted provided that the following conditions are
> met:
>
> 1. Redistributions of source code must retain the above copyright
>    notice, this list of conditions and the following disclaimer.
>
> 2. Redistributions in binary form must reproduce the above copyright
>    notice, this list of conditions and the following disclaimer in the
>    documentation and/or other materials provided with the distribution.
>
> 3. Neither the name(s) of the above-listed copyright holder(s) nor the
>    names of its contributors may be used to endorse or promote products
>    derived from this software without specific prior written permission.
>
> THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
> "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
> LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
> A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
> OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
> SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
> LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
> DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
> THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
> (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
> OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
