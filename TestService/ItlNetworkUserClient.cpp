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
    void *data = isSet ? (void *)arguments->structureInput : (void *)arguments->structureOutput;
    if (!data) {
        return kIOReturnError;
    }
    return sMethods[selector](this, data, isSet);
}

IOReturn ItlNetworkUserClient::
sDRIVER_INFO(OSObject* target, void* data, bool isSet)
{
    ItlNetworkUserClient *that = OSDynamicCast(ItlNetworkUserClient, target);
    ioctl_driver_info *drv_info = (ioctl_driver_info *)data;
    drv_info->version = IOCTL_VERSION;
#ifdef API_TEST
    memcpy(drv_info->bsd_name, "en2", sizeof(drv_info->bsd_name));
    memcpy(drv_info->fw_version, "2002年的第一场雪", sizeof(drv_info->fw_version));
    memcpy(drv_info->driver_version, "1.0.0d", sizeof(drv_info->driver_version));
#endif
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
    ItlNetworkUserClient *that = OSDynamicCast(ItlNetworkUserClient, target);
#ifdef API_TEST
    that->isEnd = false;
#endif
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sSCAN_RESULT(OSObject* target, void* data, bool isSet)
{
    ItlNetworkUserClient *that = OSDynamicCast(ItlNetworkUserClient, target);
    struct ioctl_network_info *ni = (struct ioctl_network_info *)data;
#ifdef API_TEST
    if (that->isEnd) {
        return kIONoScanResult;
    }
    ni->bssid[0] = 0x12;
    ni->bssid[1] = 0x23;
    ni->bssid[2] = 0x33;
    ni->bssid[3] = 0x44;
    ni->bssid[4] = 0x55;
    ni->bssid[5] = 0x66;
    ni->channel = 149;
    ni->ni_rsncaps = 0;
    ni->ni_rsncipher = ITL80211_CIPHER_CCMP;
    ni->noise = -100;
    ni->rssi = -66;
    memcpy(ni->ssid, "这是一首简单的小情歌", sizeof(ni->ssid));
    that->isEnd = true;
#endif
    return kIOReturnSuccess;
}

IOReturn ItlNetworkUserClient::
sTX_POWER_LEVEL(OSObject* target, void* data, bool isSet)
{
    return kIOReturnSuccess;
}
