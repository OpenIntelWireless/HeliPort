//
//  TestService.cpp
//  TestService
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

#include "TestService.hpp"
#include "Common.h"
#include <sys/kpi_mbuf.h>

#define super IOEthernetController
OSDefineMetaClassAndStructors(TestService, IOEthernetController)

bool TestService::init(OSDictionary *properties) {
    IOLog("Driver init()");
    return super::init(properties);
}

void TestService::free() {
    IOLog("Driver free()");
    super::free();
}

IOService* TestService::probe(IOService* provider, SInt32 *score) {
    IOLog("Driver probe");
    super::probe(provider, score);
    return this;
}

bool TestService::start(IOService *provider) {
    IOLog("Driver start");
    if (!super::start(provider)) {
        IOLog("Super start call failed!");
        releaseAll();
        return false;
    }
    const IONetworkMedium *primaryMedium;
    if (!createMediumTables(&primaryMedium) ||
        !setCurrentMedium(primaryMedium)) {
        releaseAll();
        return false;
    }
    if (!attachInterface((IONetworkInterface **)&fNetIf)) {
        IOLog("attachInterface failed!");
        releaseAll();
        return false;
    }
//    setupUserClient();
    registerService();
    return true;
}

void TestService::stop(IOService *provider) {
    IOLog("Driver stop");
    super::stop(provider);
    detachInterface(fNetIf);
    fNetIf->release();
}

bool TestService::createMediumTables(const IONetworkMedium **primary)
{
    IONetworkMedium    *medium;
    
    OSDictionary *mediumDict = OSDictionary::withCapacity(1);
    if (mediumDict == NULL) {
        IOLog("Cannot allocate OSDictionary\n");
        return false;
    }
    
    medium = IONetworkMedium::medium(kIOMediumEthernet1000BaseT | kIOMediumOptionFullDuplex | kIOMediumOptionFlowControl, 1000 * 1000000);
    IONetworkMedium::addMedium(mediumDict, medium);
    medium->release();
    if (primary) {
        *primary = medium;
    }
    
    bool result = publishMediumDictionary(mediumDict);
    if (!result) {
        IOLog("Cannot publish medium dictionary!\n");
    }
    
    mediumDict->release();
    return result;
}

bool TestService::setupUserClient()
{
    setProperty("IOUserClientClass", "ItlNetworkUserClient");
    return true;
}

void TestService::releaseAll()
{
    IOLog("%s\n", __FUNCTION__);
}

bool TestService::configureInterface(IONetworkInterface *netif) {
    IONetworkData *nd;
    
    IOLog("%s\n", __FUNCTION__);
    if (super::configureInterface(netif) == false) {
        IOLog("super failed\n");
        return false;
    }
    
    nd = netif->getNetworkData(kIONetworkStatsKey);
    if (!nd || !(fpNetStats = (IONetworkStats *)nd->getBuffer())) {
        IOLog("network statistics buffer unavailable?\n");
        return false;
    }
    
    return true;
}

//IONetworkInterface * TestService::createInterface()
//{
//    IO80211Interface * netif = new IO80211Interface;
//
//    if ( netif && ( netif->init( this ) == false ) )
//    {
//        netif->release();
//        netif = 0;
//    }
//    return netif;
//}

IOReturn TestService::disable(IONetworkInterface *netif)
{
    super::disable(netif);
    return kIOReturnSuccess;
}

IOReturn TestService::enable(IONetworkInterface *netif)
{
    super::enable(netif);
    return kIOReturnSuccess;
}

IOReturn TestService::getHardwareAddress(IOEthernetAddress *addrP) {
    addrP->bytes[0] = 0x12;
    addrP->bytes[1] = 0x22;
    addrP->bytes[2] = 0x32;
    addrP->bytes[3] = 0x42;
    addrP->bytes[4] = 0x52;
    addrP->bytes[5] = 0x62;
    return kIOReturnSuccess;
}

UInt32 TestService::outputPacket(mbuf_t m, void *param)
{
    IOLog("%s len=%d\n", __FUNCTION__, mbuf_pkthdr_len(m));
    freePacket(m);
    return kIOReturnOutputSuccess;
}

IOReturn TestService::setPromiscuousMode(IOEnetPromiscuousMode mode) {
    return kIOReturnSuccess;
}

IOReturn TestService::setMulticastMode(IOEnetMulticastMode mode) {
    return kIOReturnSuccess;
}

IOReturn TestService::setMulticastList(IOEthernetAddress* addr, UInt32 len) {
    return kIOReturnSuccess;
}
