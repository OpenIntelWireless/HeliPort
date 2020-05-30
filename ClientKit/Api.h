//
//  Api.h
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

#ifndef Api_h
#define Api_h

#include <IOKit/IOKitLib.h>
#include "Common.h"
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>

#define MAX_NETWORK_LIST_LENGTH 50

typedef struct {
    char device_info_str[32];
    char driver_info_str[32];
} platform_info_t;

typedef struct {
    char SSID[32];
    bool is_connected;
    bool is_encrypted;
    int RSSI;
    char password[63];
} network_info_t;

typedef struct {
    int count;
    network_info_t networks[MAX_NETWORK_LIST_LENGTH];
} network_info_list_t;

bool connect_driver(void);

void disconnect_driver(void);

bool get_platform_info(platform_info_t *result);

bool get_network_list(network_info_list_t *list);

#endif /* Api_h */
