//
//  ItlNetworkUserClient.hpp
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

#ifndef ItlNetworkUserClient_hpp
#define ItlNetworkUserClient_hpp

#include <IOKit/IOLib.h>
#include <IOKit/IOUserClient.h>
#include <IOKit/IOBufferMemoryDescriptor.h>
#include "TestService.hpp"
#include "Common.h"

class ItlNetworkUserClient : public IOUserClient {
    
    OSDeclareDefaultStructors( ItlNetworkUserClient );
    
public:
    
    virtual bool start( IOService * provider ) override;
    virtual void stop( IOService * provider ) override;
    virtual bool initWithTask( task_t owningTask, void * securityID,
    UInt32 type,  OSDictionary * properties ) override;
    virtual IOReturn clientDied (void) override;
    virtual IOReturn clientClose( void ) override;
    virtual IOReturn externalMethod( uint32_t selector, IOExternalMethodArguments * arguments, IOExternalMethodDispatch * dispatch = 0, OSObject * target = 0, void * reference = 0 ) override;
    
private:
    static IOReturn sTest(OSObject* target, void* reference, IOExternalMethodArguments* arguments);
    static IOReturn sBSSID(OSObject* target, void* reference, IOExternalMethodArguments* arguments);
    static const IOExternalMethodDispatch sMethods[IOCTL_ID_MAX];
    
private:
    task_t fTask;
    TestService *fDriver;
};


#endif /* ItlNetworkUserClient_hpp */
