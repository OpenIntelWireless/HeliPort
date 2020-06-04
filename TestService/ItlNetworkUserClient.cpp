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

const IOControlMethodAction ItlNetworkUserClient::sMethods[IOCTL_ID_MAX] {
    sDRIVER_INFO,
    sSTA_INFO,
    sPOWER,
    sSTATE,
    sNW_ID,
    sWPA_KEY,
    sASSOCIATE,
    sDISASSOCIATE,
    sJOIN,
    sSCAN,
    sSCAN_RESULT,
    sTX_POWER_LEVEL,
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
    bool isSet = selector & IOCTL_MASK;
    selector &= ~IOCTL_MASK;
    IOLog("externalMethod invoke. selector=0x%X isSet=%d\n", selector, isSet);
    if (selector < 0 || selector > IOCTL_ID_MAX) {
        return super::externalMethod(selector, arguments, NULL, this, NULL);
    }
    return sMethods[selector](this, isSet ? (void *)arguments->structureInput : (void *)arguments->structureOutput, isSet);
}

IOReturn ItlNetworkUserClient::
sDRIVER_INFO(OSObject* target, void* data, bool isSet)
{
    if (data == NULL) {
        return kIOReturnError;
    }
    ioctl_driver_info *drv_info = (ioctl_driver_info *)data;
    drv_info->version = IOCTL_VERSION;
    memcpy(drv_info->bsd_name, "en22", sizeof(drv_info->bsd_name));
    memcpy(drv_info->fw_version, "2002年的第一场雪", sizeof(drv_info->fw_version));
    memcpy(drv_info->driver_version, "1.0.0d", sizeof(drv_info->driver_version));
    IOLog("%s %s %s", __FUNCTION__, drv_info->bsd_name, drv_info->driver_version);
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sSTA_INFO(OSObject* target, void* data, bool isSet)
{
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sPOWER(OSObject* target, void* data, bool isSet)
{
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sSTATE(OSObject* target, void* data, bool isSet)
{
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sNW_ID(OSObject* target, void* data, bool isSet)
{
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sWPA_KEY(OSObject* target, void* data, bool isSet)
{
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sASSOCIATE(OSObject* target, void* data, bool isSet)
{
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sDISASSOCIATE(OSObject* target, void* data, bool isSet)
{
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sJOIN(OSObject* target, void* data, bool isSet)
{
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sSCAN(OSObject* target, void* data, bool isSet)
{
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sSCAN_RESULT(OSObject* target, void* data, bool isSet)
{
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sTX_POWER_LEVEL(OSObject* target, void* data, bool isSet)
{
    return kIOReturnSuccess;
}
