//
//  Api.c
//  ClientKit
//
//  Created by 钟先耀 on 2020/4/7.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

#include "Api.h"
#include "mach/mach_port.h"
#include "pthread.h"
#include <stdio.h>

static pthread_mutex_t* api_mutex = NULL;

bool get_platform_info(platform_info_t *info) {
    memset(info, 0, sizeof(platform_info_t));

    struct ioctl_driver_info driver_info;
    if (ioctl_get(IOCTL_80211_DRIVER_INFO, &driver_info, sizeof(struct ioctl_driver_info)) != KERN_SUCCESS) {
        goto error;
    }

    // driver_version + " " + fw_version routinely exceeds the 32-byte
    // driver_info_str; strcat here smashed the caller's stack. The kernel's
    // strings also aren't guaranteed NUL-terminated, hence the %.*s bounds.
    snprintf(info->device_info_str, sizeof(info->device_info_str), "%.*s",
             (int)strnlen(driver_info.bsd_name, sizeof(driver_info.bsd_name)), driver_info.bsd_name);
    snprintf(info->driver_info_str, sizeof(info->driver_info_str), "%.*s %.*s",
             (int)strnlen(driver_info.driver_version, sizeof(driver_info.driver_version)),
             driver_info.driver_version,
             (int)strnlen(driver_info.fw_version, sizeof(driver_info.fw_version)),
             driver_info.fw_version);
    return true;

error:
    return false;
}

bool get_power_state(bool *enabled) {
    struct ioctl_power power;
    if (ioctl_get(IOCTL_80211_POWER, &power, sizeof(struct ioctl_power)) != KERN_SUCCESS) {
        goto error;
    }

    *enabled = power.enabled;

    return true;

error:
    return false;
}

bool get_80211_state(uint32_t *state) {
    struct ioctl_state state_struct;
    if (ioctl_get(IOCTL_80211_STATE, &state_struct, sizeof(struct ioctl_state)) != KERN_SUCCESS) {
        goto error;
    }

    *state = state_struct.state;

    return true;

error:
    return false;
}

bool get_network_ssid(char *ssid)
{
    struct ioctl_nw_id nwid;
    if (ioctl_get(IOCTL_80211_NW_ID, &nwid, sizeof(struct ioctl_nw_id)) != KERN_SUCCESS) {
        goto error;
    }
    
    memcpy(ssid, nwid.nwid, nwid.len);
    
    return true;
    
error:
    return false;
}

bool get_network_bssid(char *bssid)
{
    struct ioctl_nw_bssid nwbssid;
    if (ioctl_get(IOCTL_80211_NW_BSSID, &nwbssid, sizeof(struct ioctl_nw_bssid)) != KERN_SUCCESS) {
        goto error;
    }
    
    memcpy(bssid, nwbssid.bssid, ETHER_ADDR_LEN);
    
    return true;
    
error:
    return false;
}

bool get_network_list(network_info_list_t *list) {
    memset(list, 0, sizeof(network_info_list_t));

    struct ioctl_scan scan;
    struct ioctl_network_info network_info_ret;
    io_connect_t con;
    struct ioctl_sta_info sta_info;
    scan.version = IOCTL_VERSION;

    get_station_info(&sta_info);

    if (!open_adapter(&con)) {
        goto error;
    }
    int oid = IOCTL_80211_SCAN_RESULT;
    while (_nake_ioctl(con, &oid, true, &network_info_ret, sizeof(struct ioctl_network_info)) == kIOReturnSuccess) {
        if (list->count >= MAX_NETWORK_LIST_LENGTH) {
            break;
        }
        if (strlen((const char *)sta_info.ssid) > 0 && memcmp(sta_info.bssid, network_info_ret.bssid, ETHER_ADDR_LEN) == 0) {
            continue;
        }
        struct ioctl_network_info *info = &list->networks[list->count++];
        memcpy(info, &network_info_ret, sizeof(struct ioctl_network_info));
    }
    close_adapter(con);

    if (ioctl_set(IOCTL_80211_SCAN, &scan, sizeof(struct ioctl_scan)) != KERN_SUCCESS) {
        goto error;
    }
    return true;

error:
    return false;
}

bool connect_network(const char *ssid, const char *pwd) {
    if (associate_ssid(ssid, pwd) != KERN_SUCCESS) {
        goto error;
    }

    int timeout = 20;
    while (timeout-- > 0) {
        // Sleep first to wait for state to change
        sleep(1);
        uint32_t state;
        if (get_80211_state(&state) && state == ITL80211_S_RUN) {
            station_info_t sta_info;
            if (get_station_info(&sta_info) == KERN_SUCCESS) {
                return strncmp(ssid, (char*)sta_info.ssid, NWID_LEN) == 0;
            }
        }
    }

error:
    return false;
}

static bool isSupportService(const char *name)
{
    if (strcmp(name, "TestService")
        && strcmp(name, "itlwmx") && strcmp(name, "itlwm")
        ) {
        return false;
    }
    return true;
}

bool open_adapter(io_connect_t *connection_t)
{
    kern_return_t kr;
    io_iterator_t iter;
    bool found = false;
    io_service_t service;
    mach_port_name_t port;
    uint32_t type = 0;
    char nn[20];
    if (IOMasterPort(0, &port)) {
        return false;
    }
    CFMutableDictionaryRef matchingDict = IOServiceMatching("IOEthernetController");
    kr = IOServiceGetMatchingServices(port, matchingDict, &iter);
    mach_port_deallocate(mach_task_self(), port);
    if (kr != KERN_SUCCESS)
        return false;
    while ((service = IOIteratorNext(iter)) && !found) {
        CFTypeRef type_ref = IORegistryEntryCreateCFProperty(service, CFSTR("IOClass"), kCFAllocatorDefault, 0);
        if (type_ref) {
            const char *name = CFStringGetCStringPtr(type_ref, 0);
            if (!name) {
                name = nn;
                CFStringGetCString(type_ref, nn, 20, 0);
            }
            if (isSupportService(name)) {
                if (IOServiceOpen(service, mach_task_self(), type, connection_t) == KERN_SUCCESS) {
                    found = true;
                }
            }
            // Fix leak issue if there is more than one Ethernet controller
            CFRelease(type_ref);
        }
        // Fix leak issue if there is more than one Ethernet controller
        IOObjectRelease(service);
    }
    IOObjectRelease(iter);

    if (found) {
        if (!api_mutex) {
            api_mutex = malloc(sizeof(pthread_mutex_t));
            pthread_mutex_init(api_mutex, NULL);
        }
        pthread_mutex_lock(api_mutex);
    }

    return found;
}

void close_adapter(io_connect_t connection)
{
    if (connection) {
        IOServiceClose(connection);
        pthread_mutex_unlock(api_mutex);
    }
}

kern_return_t _nake_ioctl(io_connect_t con, int *ctl, bool is_get, void *data, size_t data_len)
{
    if (!is_get) {
        *ctl |= IOCTL_MASK;
    }
    kern_return_t ret;
    if (is_get) {
        ret = IOConnectCallStructMethod(con, *ctl, NULL, 0, data, &data_len);
    } else {
        ret = IOConnectCallStructMethod(con, *ctl, data, data_len, NULL, 0);
    }
    return ret;
}

kern_return_t _ioctl(int ctl, bool is_get, void *data, size_t data_len)
{
    kern_return_t ret;
    io_connect_t con;
    if (!open_adapter(&con)) {
        return KERN_FAILURE;
    }
    ret = _nake_ioctl(con, &ctl, is_get, data, data_len);
    close_adapter(con);
    return ret;
}
    
kern_return_t ioctl_set(int ctl, void *data, size_t data_len) {
    return _ioctl(ctl, false, data, data_len);
}

kern_return_t ioctl_get(int ctl, void *data, size_t data_len) {
    return _ioctl(ctl, true, data, data_len);
}

bool is_power_on(void) {
    struct ioctl_power power;
    ioctl_get(IOCTL_80211_POWER, &power, sizeof(struct ioctl_power));
    return power.enabled;
}

kern_return_t power_on(void) {
    struct ioctl_power power;
    power.enabled = 1;
    power.version = IOCTL_VERSION;
    return ioctl_set(IOCTL_80211_POWER, &power, sizeof(struct ioctl_power));
}

kern_return_t power_off(void) {
    struct ioctl_power power;
    power.enabled = 0;
    power.version = IOCTL_VERSION;
    return ioctl_set(IOCTL_80211_POWER, &power, sizeof(struct ioctl_power));
}

kern_return_t get_station_info(station_info_t *info)
{
    return ioctl_get(IOCTL_80211_STA_INFO, info, sizeof(struct ioctl_sta_info));
}

kern_return_t join_ssid(const char *ssid, const char *pwd)
{
    struct ioctl_join join;
    join.version = IOCTL_VERSION;
    memcpy(join.nwid.nwid, ssid, 32);
    memcpy(join.wpa_key.key, pwd, sizeof(join.wpa_key.key));
    return ioctl_set(IOCTL_80211_JOIN, &join, sizeof(struct ioctl_join));
}

kern_return_t associate_ssid(const char *ssid, const char *pwd)
{
    struct ioctl_associate ass;
    memcpy(ass.nwid.nwid, ssid, 32);
    memcpy(ass.wpa_key.key, pwd, sizeof(ass.wpa_key.key));
    ass.version = IOCTL_VERSION;
    return ioctl_set(IOCTL_80211_ASSOCIATE, &ass, sizeof(struct ioctl_associate));
}

kern_return_t associate_ssid_enterprise(const char *ssid)
{
    struct ioctl_associate_enterprise req;
    memset(&req, 0, sizeof(req));
    req.version = IOCTL_VERSION;

    size_t ssid_len = strnlen(ssid, NWID_LEN);
    memcpy(req.nwid.nwid, ssid, ssid_len);
    req.nwid.len = (unsigned int)ssid_len;

    return ioctl_set(IOCTL_80211_ASSOCIATE_ENTERPRISE, &req, sizeof(req));
}

kern_return_t dis_associate_ssid(const char *ssid)
{
    struct ioctl_disassociate dis;
    dis.version = IOCTL_VERSION;
    memcpy(dis.ssid, ssid, 32);
    return ioctl_set(IOCTL_80211_DISASSOCIATE, &dis, sizeof(struct ioctl_disassociate));
}

kern_return_t set_eap_pmk(const char *ssid, enum itl80211_eap_status status,
                           const unsigned char *pmk, unsigned int pmk_len)
{
    struct ioctl_eap_pmk req;
    memset(&req, 0, sizeof(req));
    req.version = IOCTL_VERSION;

    // strnlen, not strlen: never trust ssid to be a properly NUL-terminated
    // string shorter than NWID_LEN just because the caller says so.
    size_t ssid_len = strnlen(ssid, NWID_LEN);
    memcpy(req.ssid, ssid, ssid_len);
    req.ssid_len = (unsigned int)ssid_len;
    req.status = status;

    if (status == ITL_EAP_STATUS_SUCCESS) {
        if (pmk == NULL || pmk_len != PMK_LEN) {
            return KERN_INVALID_ARGUMENT;
        }
        memcpy(req.pmk, pmk, PMK_LEN);
        req.pmk_len = PMK_LEN;
    }

    kern_return_t kr = ioctl_set(IOCTL_80211_WPA_KEY, &req, sizeof(req));

    // Don't let a derived PMK linger in this stack frame any longer than
    // the syscall that consumes it needs it for. memset_s, unlike memset,
    // can't be optimized away as a dead store.
    memset_s(&req, sizeof(req), 0, sizeof(req));

    return kr;
}

kern_return_t send_eapol_frame(const unsigned char *frame, unsigned int len)
{
    if (frame == NULL || len < 18 || len > EAPOL_MAX_FRAME) {
        return KERN_INVALID_ARGUMENT;
    }
    struct ioctl_eapol_tx *req = calloc(1, sizeof(*req));
    if (req == NULL) {
        return KERN_RESOURCE_SHORTAGE;
    }
    req->version = IOCTL_VERSION;
    req->len = len;
    memcpy(req->frame, frame, len);
    kern_return_t kr = ioctl_set(IOCTL_80211_TX_EAPOL, req, sizeof(*req));
    free(req);
    return kr;
}

kern_return_t receive_eapol_frame(unsigned char *frame, unsigned int capacity, unsigned int *len)
{
    if (frame == NULL || len == NULL) {
        return KERN_INVALID_ARGUMENT;
    }
    *len = 0;
    struct ioctl_eapol_rx *rx = calloc(1, sizeof(*rx));
    if (rx == NULL) {
        return KERN_RESOURCE_SHORTAGE;
    }
    kern_return_t kr = ioctl_get(IOCTL_80211_RX_EAPOL, rx, sizeof(*rx));
    if (kr == KERN_SUCCESS && rx->len > 0) {
        if (rx->len > capacity || rx->len > EAPOL_MAX_FRAME) {
            kr = KERN_INVALID_ARGUMENT;
        } else {
            memcpy(frame, rx->frame, rx->len);
            *len = rx->len;
        }
    }
    free(rx);
    return kr;
}

void api_terminate(void) {
    if (api_mutex) {
        /* acquire API lock to wait for the pending API call */
        pthread_mutex_lock(api_mutex);
        pthread_mutex_unlock(api_mutex);
        pthread_mutex_destroy(api_mutex);
    }
}
