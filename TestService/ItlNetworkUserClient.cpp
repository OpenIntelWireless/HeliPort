//
//  ItlNetworkUserClient.cpp
//  TestService
//
//  Created by 钟先耀 on 2020/4/14.
//  Copyright © 2020 lhy. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

#include "ItlNetworkUserClient.hpp"

#define super IOUserClient
OSDefineMetaClassAndStructors( ItlNetworkUserClient, IOUserClient );

const IOExternalMethodDispatch ItlNetworkUserClient::sMethods[IOCTL_ID_MAX] {
    {sTest, 0, 0, 0, 0},
    {sBSSID, 0, 0, 0, 0}
};

bool ItlNetworkUserClient::initWithTask(task_t owningTask, void *securityID, UInt32 type, OSDictionary *properties)
{
    fTask = owningTask;
    return super::initWithTask(owningTask, securityID, type, properties);
}

bool ItlNetworkUserClient::start(IOService *provider)
{
    IOLog("start\n");
    if( !super::start( provider ))
        return false;
    fDriver = OSDynamicCast(TestService, provider);
    if (fDriver == NULL) {
        return false;
    }
    return true;
}

IOReturn ItlNetworkUserClient::clientClose()
{
    IOLog("clientClose\n");
    if( !isInactive())
        terminate();
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::clientDied()
{
    IOLog("clientDied\n");
    return super::clientDied();
}

void ItlNetworkUserClient::stop(IOService *provider)
{
    IOLog("stop\n");
    super::stop( provider );
}

IOReturn ItlNetworkUserClient::externalMethod(uint32_t selector, IOExternalMethodArguments * arguments, IOExternalMethodDispatch * dispatch, OSObject * target, void * reference)
{
    IOLog("externalMethod invoke. selector=%X\n", selector);
    IOReturn err;
    switch (selector) {
        default:
            err = super::externalMethod(selector, arguments, NULL, this, NULL);
            break;
    }
    return err;
}

IOReturn ItlNetworkUserClient::sTest(OSObject *target, void *reference, IOExternalMethodArguments *arguments)
{
    IOLog("%s 阿啊阿啊阿啊\n", __FUNCTION__);
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::sBSSID(OSObject *target, void *reference, IOExternalMethodArguments *arguments)
{
    IOLog("%s 噢噢噢噢噢\n", __FUNCTION__);
    return kIOReturnSuccess;
}
