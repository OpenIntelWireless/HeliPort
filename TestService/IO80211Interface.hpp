//
//  ItlNetworkInterface.hpp
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

#ifndef ItlNetworkInterface_hpp
#define ItlNetworkInterface_hpp

#include <FakeNetworkInterface.h>
#include <IOKit/network/IOEthernetInterface.h>
#include "IoctlId.h"

typedef int apple80211_postMessage_tlv_types;

#define IOCTL_GET 3224398281LL
#define IOCTL_SET 2150656456LL

#define IFNAMSIZ 16

struct apple80211req
{
    char        req_if_name[IFNAMSIZ];    // 16 bytes
    int            req_type;                // 4 bytes
    int            req_val;                // 4 bytes
    u_int32_t    req_len;                // 4 bytes
    void       *req_data;                // 4 bytes
};

class IO80211Interface : public IOEthernetInterface
{
    OSDeclareDefaultStructors( IO80211Interface )
    
public:
    virtual bool init( IONetworkController * controller ) APPLE_KEXT_OVERRIDE;
    
protected:
    
    virtual void free() APPLE_KEXT_OVERRIDE;
    
    virtual SInt32 performCommand(IONetworkController * controller,
                                  unsigned long         cmd,
                                  void *                arg0,
                                  void *                arg1) APPLE_KEXT_OVERRIDE;
    
    static int performGatedCommand(void *, void *, void *, void *, void *);
    
    UInt64 IO80211InterfaceUserSpaceToKernelApple80211Request(void *arg, apple80211req *req, unsigned long ctl);
    
    int apple80211_ioctl(IO80211Interface *netif, UInt64 method, apple80211req *a6);
    
    int apple80211_ioctl_set(IO80211Interface *netif, apple80211req *a6);
    
    int apple80211_ioctl_get(IO80211Interface *netif, apple80211req *a6);
};

#endif /* ItlNetworkInterface_hpp */
