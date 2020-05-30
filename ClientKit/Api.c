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

static io_service_t service;
static io_connect_t driver_connection;

bool connect_driver(void) {
    printf("connecting driver\n");

    service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("ItlNetworkUserClient"));
    if (service == IO_OBJECT_NULL) {
        printf("could not find any service matching\n");
        return false;
    }

    if (IOServiceOpen(service, mach_task_self(), 0, &driver_connection) != KERN_SUCCESS) {
        printf("could not open service\n");
        return false;
    }

    return true;
}

bool get_platform_info(platform_info_t *info) {
    memset(info, 0, sizeof(platform_info_t));
    // test
    strcpy(info->device_info_str, "intel");
    strcpy(info->driver_info_str, "itwlm v1.0");
    return true;
}

bool get_network_list(network_info_list_t *list) {
    memset(list, 0, sizeof(network_info_list_t));
    // test
    list->count = 2;
    strcpy(list->networks[0].SSID, "test0");
    list->networks[0].is_connected = true;
    list->networks[0].is_encrypted = true;

    strcpy(list->networks[1].SSID, "test2");
    list->networks[1].is_connected = false;
    list->networks[1].is_encrypted = true;
    return true;
}

void disconnect_driver(void) {
    IOServiceClose(driver_connection);
    IOObjectRelease(service);
}
