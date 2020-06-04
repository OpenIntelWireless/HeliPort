//
//  main.cpp
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
    CFDictionaryRef     matchingDict = NULL;
    io_iterator_t       iter = 0;
    io_service_t        service = 0;
    kern_return_t       kr;

    matchingDict = IOServiceMatching("TestService");
    kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iter);
    if (kr != KERN_SUCCESS)
        return -1;
    while ((service = IOIteratorNext(iter)) != 0)
    {
        task_port_t     owningTask = mach_task_self();
        uint32_t        type = 0;
        io_connect_t    driverConnection;

        kr = IOServiceOpen(
                           service,
                           owningTask,
                           type,
                           &driverConnection);
        if (kr == KERN_SUCCESS)
        {
            ioctl_driver_info drv_info;
            size_t cnt = sizeof(ioctl_driver_info);
            kr = IOConnectCallStructMethod(driverConnection, IOCTL_80211_DRIVER_INFO, NULL, 0, &drv_info, &cnt);
            if (kr == kIOReturnSuccess) {
                printf("aaa\n");
            }
            printf("IOCTL_80211_TEST - %08x\n", kr);
            printf("ioctl_driver_info %s %s\n", drv_info.fw_version, drv_info.bsd_name);
            IOServiceClose(driverConnection);
        }

        IOObjectRelease(service);
    }
    IOObjectRelease(iter);

    std::cout << "Hello, World!\n";
    return 0;
}
