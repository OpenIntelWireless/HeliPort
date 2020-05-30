//
//  ItlNetworkInterface.cpp
//  TestService
//
//  Created by 钟先耀 on 2020/5/25.
//  Copyright © 2020 lhy. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

#include "IO80211Interface.hpp"
#include <sys/errno.h>

#define super IOEthernetInterface
OSDefineMetaClassAndStructors( IO80211Interface, IOEthernetInterface )

bool IO80211Interface::init(IONetworkController *controller)
{
    IOLog("%s\n", __FUNCTION__);
    if ( super::init(controller) == false )
        return false;
    setInterfaceSubType(3);
    return true;
}

void IO80211Interface::free()
{
    IOLog("%s\n", __FUNCTION__);
    super::free();
}

SInt32 IO80211Interface::performCommand( IONetworkController * ctr,
                                           unsigned long         cmd,
                                           void *                arg0,
                                           void *                arg1 )
{
    IOLog("%s cmd=%lu\n", __FUNCTION__, cmd);
    SInt32  ret;
    
    if ( ctr == 0 ) return EINVAL;
    
    switch ( cmd )
    {
        case 2149607880LL:
        case 2150132168LL:
        case 3223873993LL:
            ret = (int) ctr->executeCommand(
                             this,            /* client */
                             (IONetworkController::Action)
                                &IO80211Interface::performGatedCommand,
                             this,            /* target */
                             ctr,             /* param0 */
                             (void *) cmd,    /* param1 */
                             arg0,            /* param2 */
                             arg1 );          /* param3 */
            return ret;
            break;

        default:
            if (cmd <= 3223349704LL) {
                ret = (int) ctr->executeCommand(
                this,            /* client */
                (IONetworkController::Action)
                   &IO80211Interface::performGatedCommand,
                this,            /* target */
                ctr,             /* param0 */
                (void *) cmd,    /* param1 */
                arg0,            /* param2 */
                arg1 );          /* param3 */
                return ret;
            }
            break;
    }

    return super::performCommand(ctr, cmd, arg0, arg1);
}

UInt64 IO80211Interface::IO80211InterfaceUserSpaceToKernelApple80211Request(void *arg, apple80211req *req, unsigned long ctl)
{
    UInt64 result;
    UInt32 v5;
    uint8_t *a1 = (uint8_t *)arg;
    uint8_t *req_ptr = (uint8_t*)req;
    if ( ctl != 3223873993LL && ctl != 2150132168LL ) {
        *(uint64_t*)(req_ptr + 8) = *((uint64_t*)((uint8_t*)a1 + 8));
        *(uint64_t*)req_ptr = *(uint64_t*)a1;
        *(uint32_t*)(req_ptr + 0x10) = *((uint32_t*)((uint8_t*)a1 + 0x10));
        *(uint32_t*)(req_ptr + 0x14) = *((uint32_t*)((uint8_t*)a1 + 0x14));
        *(uint32_t*)(req_ptr + 0x18) = *((uint32_t*)((uint8_t*)a1 + 0x18));
        result = (uint64_t)(*((uint32_t*)((uint8_t*)a1 + 0x1C)));
        v5 = 4;
    } else {
        *(uint64_t*)(req_ptr + 8) = *((uint64_t*)((uint8_t*)a1 + 8));
        *(uint64_t*)req_ptr = *(uint64_t*)a1;
        *(uint32_t*)(req_ptr + 0x10) = *((uint32_t*)((uint8_t*)a1 + 0x10));
        *(uint32_t*)(req_ptr + 0x14) = *((uint32_t*)((uint8_t*)a1 + 0x14));
        *(uint32_t*)(req_ptr + 0x18) = *((uint32_t*)((uint8_t*)a1 + 0x18));
        result = *((uint64_t*)((uint8_t*)a1 + 0x20));
        v5 = 8;
    }
    *(uint64_t*)(req_ptr + 0x20) = result;
    *(uint32_t*)(req_ptr + 0x28) = (uint32_t)v5;
    return result;
}

int IO80211Interface::performGatedCommand(void * target,
                                             void * arg1_ctr,
                                             void * arg2_cmd,
                                             void * arg3_0,
                                             void * arg4_1)
{
    IOLog("%s\n", __FUNCTION__);
    apple80211req req;
    UInt64 method;
    IO80211Interface *that = (IO80211Interface *)target;
    if (!arg1_ctr) {
        return 22LL;
    }
    UInt64 ctl = *(UInt64 *)arg1_ctr;
    bzero(&req, sizeof(apple80211req));
    that->IO80211InterfaceUserSpaceToKernelApple80211Request(arg3_0, &req, ctl);
    if ((ctl | 0x80000) == 2150132168LL) {
        method = IOCTL_SET;
    } else {
        method = IOCTL_GET;
    }
    return that->apple80211_ioctl(that, method, &req);
}

int IO80211Interface::apple80211_ioctl(IO80211Interface *netif, UInt64 method, apple80211req *a6)
{
    IOLog("%s\n", __FUNCTION__);
    if (method == IOCTL_GET) {
        return apple80211_ioctl_get(netif, a6);
    } else {
        return apple80211_ioctl_set(netif, a6);
    }
}

int IO80211Interface::apple80211_ioctl_get(IO80211Interface *netif, apple80211req *a6)
{
    uint32_t index = a6->req_type - 1;
    IOLog("%s %d\n", __FUNCTION__, index);
    if (index > 0x160) {
        return 102;
    }
    return kIOReturnSuccess;
}

int IO80211Interface::apple80211_ioctl_set(IO80211Interface *netif, apple80211req *a6)
{
    uint32_t index = a6->req_type - 1;
    IOLog("%s %d\n", __FUNCTION__, index);
    if (index > 0x160) {
        return 102;
    }
    return kIOReturnSuccess;
}
