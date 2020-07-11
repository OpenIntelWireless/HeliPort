//
//  main.cpp
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

#include <iostream>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/file.h>
#include <sys/sys_domain.h>
#include <sys/ioctl.h>
#include <sys/kern_event.h>
#include <sys/kern_control.h>

extern "C" {
#include "Api.h"
}

int main(int argc, const char * argv[]) {
    kern_return_t       kr;
    ioctl_driver_info drv_info;
    ioctl_scan scan;
    ioctl_network_info ni;
    size_t cnt = sizeof(ioctl_driver_info);
    
    kr = ioctl_get(IOCTL_80211_DRIVER_INFO, &drv_info, cnt);
    printf("ioctl_driver_info %s %s\n", drv_info.fw_version, drv_info.bsd_name);
    scan.version = IOCTL_VERSION;
    kr = ioctl_set(IOCTL_80211_SCAN, &scan, sizeof(ioctl_scan));
    kr = ioctl_get(IOCTL_80211_SCAN_RESULT, &ni, sizeof(ioctl_network_info));
    printf("%s\n", ni.ssid);
    std::cout << "Hello, World!\n";
    return 0;
}
