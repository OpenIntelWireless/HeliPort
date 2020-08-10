//
//  Api.h
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

#ifndef Api_h
#define Api_h

#include <IOKit/IOKitLib.h>
#include <IOKit/IOTypes.h>
#include "Common.h"
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>

#define MAX_NETWORK_LIST_LENGTH 50
#define MAX_SSID_LENGTH 32

typedef struct {
    char device_info_str[32];
    char driver_info_str[32];
} platform_info_t;

typedef struct {
    int count;
    struct ioctl_network_info networks[MAX_NETWORK_LIST_LENGTH];
} network_info_list_t;

typedef struct ioctl_sta_info station_info_t;

bool open_adapter(io_connect_t *connection_t);

void close_adapter(io_connect_t connection);

kern_return_t ioctl_get(int ctl, void *data, size_t data_len);

kern_return_t ioctl_set(int ctl, void *data, size_t data_len);

kern_return_t _ioctl(int ctl, bool is_get, void *data, size_t data_len);

kern_return_t _nake_ioctl(io_connect_t con, int *ctl, bool is_get, void *data, size_t data_len);

bool get_platform_info(platform_info_t *result);

bool get_power_state(bool *enabled);

bool get_80211_state(uint32_t *state);

bool get_network_list(network_info_list_t *list);

bool connect_network(const char *ssid, const char *pwd);

bool is_power_on(void);

kern_return_t get_station_info(station_info_t *info);

kern_return_t power_on(void);

kern_return_t power_off(void);

kern_return_t join_ssid(const char *ssid, const char *pwd);

kern_return_t associate_ssid(const char *ssid, const char *pwd);

kern_return_t dis_associate_ssid(const char *ssid);

void api_terminate(void);

#endif /* Api_h */
