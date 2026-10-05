//
//  Bridge.h
//  HeliPort
//
//  Created by Bat.bat on 8/7/2024.
//  Copyright © 2024 OpenIntelWireless. All rights reserved.
//

#pragma once

// MARK: NSMenuItem Private API
#import <AppKit/AppKit.h>

@interface NSMenuItem ()
- (BOOL)_canBeHighlighted;
@end


// MARK: itlwm API
#include "../ClientKit/Api.h"

// MARK: Vendored hostap EAP-PEAP/MSCHAPv2 supplicant bridge
#include "EAPSupplicantBridge.h"
