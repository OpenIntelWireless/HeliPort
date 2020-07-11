//
//  TestService.hpp
//  TestService
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

#include <IOKit/IOLib.h>
#include <IOKit/IOLocks.h>
#include <IOKit/IOService.h>
#include <IOKit/network/IOEthernetController.h>
#include <IOKit/network/IOOutputQueue.h>
#include <IOKit/IOCommandGate.h>
#include "IO80211Interface.hpp"

class TestService : public IOEthernetController {
    OSDeclareDefaultStructors(TestService)
    
public:
    bool init(OSDictionary *properties) override;
    void free() override;
    IOService* probe(IOService* provider, SInt32* score) override;
    bool start(IOService *provider) override;
    void stop(IOService *provider) override;
    IOReturn getHardwareAddress(IOEthernetAddress* addrP) override;
    IOReturn enable(IONetworkInterface *netif) override;
    IOReturn disable(IONetworkInterface *netif) override;
    UInt32 outputPacket(mbuf_t, void * param) override;
    IOReturn setPromiscuousMode(IOEnetPromiscuousMode mode) override;
    IOReturn setMulticastMode(IOEnetMulticastMode mode) override;
    IOReturn setMulticastList(IOEthernetAddress* addr, UInt32 len) override;
    bool configureInterface(IONetworkInterface *netif) override;
//    virtual IONetworkInterface * createInterface() override;
    
    bool setupUserClient();
    bool createMediumTables(const IONetworkMedium **primary);
    
    void releaseAll();
    
protected:
    IOEthernetInterface *fNetIf;
    IONetworkStats *fpNetStats;
};
