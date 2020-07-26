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

static pthread_mutex_t* api_mutex = NULL;

bool get_platform_info(platform_info_t *info) {
    memset(info, 0, sizeof(platform_info_t));

    struct ioctl_driver_info driver_info;
    if (ioctl_get(IOCTL_80211_DRIVER_INFO, &driver_info, sizeof(struct ioctl_driver_info)) != KERN_SUCCESS) {
        goto error;
    }

    strcpy(info->device_info_str, driver_info.bsd_name);
    strcpy(info->driver_info_str, driver_info.driver_version);
    strcat(info->driver_info_str, " ");
    strcat(info->driver_info_str, driver_info.fw_version);
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
        if (memcmp(sta_info.bssid, network_info_ret.bssid, ETHER_ADDR_LEN) == 0) {
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
        uint32_t state;
        if (get_80211_state(&state) && state == ITL80211_S_RUN) {
            station_info_t sta_info;
            if (get_station_info(&sta_info) == KERN_SUCCESS) {
                return strcmp(ssid, (char*)sta_info.ssid) == 0;
            }
        }
        sleep(1);
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

bool is_power_on() {
    struct ioctl_power power;
    ioctl_get(IOCTL_80211_POWER, &power, sizeof(struct ioctl_power));
    return power.enabled;
}

kern_return_t power_on() {
    struct ioctl_power power;
    power.enabled = 1;
    power.version = IOCTL_VERSION;
    return ioctl_set(IOCTL_80211_POWER, &power, sizeof(struct ioctl_power));
}

kern_return_t power_off() {
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

kern_return_t dis_associate_ssid(const char *ssid)
{
    struct ioctl_disassociate dis;
    dis.version = IOCTL_VERSION;
    memcpy(dis.ssid, ssid, 32);
    return ioctl_set(IOCTL_80211_DISASSOCIATE, &dis, sizeof(struct ioctl_disassociate));
}

void api_terminate(void) {
    if (api_mutex) {
        /* acquire API lock to wait for the pending API call */
        pthread_mutex_lock(api_mutex);
        pthread_mutex_unlock(api_mutex);
        pthread_mutex_destroy(api_mutex);
    }
}
