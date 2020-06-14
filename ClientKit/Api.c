//
//  Api.c
//  ClientKit
//
//  Created by 钟先耀 on 2020/4/7.
//  Copyright © 2020 lhy. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

#include "Api.h"
#include "mach/mach_port.h"


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

bool get_network_list(network_info_list_t *list) {
    memset(list, 0, sizeof(network_info_list_t));

    struct ioctl_scan scan;
    struct ioctl_network_info network_info_ret;
    io_connect_t con;
    scan.version = IOCTL_VERSION;
    if (ioctl_set(IOCTL_80211_SCAN, &scan, sizeof(struct ioctl_scan)) != KERN_SUCCESS) {
        goto error;
    }
    sleep(5);
    if (!open_adapter(&con)) {
        goto error;
    }
    int oid = IOCTL_80211_SCAN_RESULT;
    while (_nake_ioctl(con, &oid, true, &network_info_ret, sizeof(struct ioctl_network_info)) == kIOReturnSuccess) {
        if (list->count >= MAX_NETWORK_LIST_LENGTH) {
            break;
        }
        network_info_t *info = &list->networks[list->count++];
        strncpy(info->SSID, (char*) network_info_ret.ssid, 32);
        info->RSSI = network_info_ret.rssi;
        info->auth.security = network_info_ret.ni_rsncipher;
    }
    close_adapter(con);
    return true;

error:
    return false;
}

bool connect_network(network_info_t *info) {
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
    while ((service = IOIteratorNext(iter))) {
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
                    IOObjectRelease(service);
                    CFRelease(type_ref);
                    break;
                }
            }
        }
    }
    IOObjectRelease(iter);
    return found;
}

void close_adapter(io_connect_t connection)
{
    if (connection) {
        IOServiceClose(connection);
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
