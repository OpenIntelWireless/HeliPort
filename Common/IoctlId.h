//
//  IoctlId.h
//  HeliPort
//
//  Created by 钟先耀 on 2020/4/8.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

#ifndef IoctlId_h
#define IoctlId_h

enum IOCTL_IDS {
    IOCTL_80211_DRIVER_INFO,
    IOCTL_80211_STA_INFO,
    IOCTL_80211_POWER,
    IOCTL_80211_STATE,
    IOCTL_80211_NW_ID,
    IOCTL_80211_WPA_KEY,
    IOCTL_80211_ASSOCIATE,
    IOCTL_80211_DISASSOCIATE,
    IOCTL_80211_JOIN,
    IOCTL_80211_SCAN,
    IOCTL_80211_SCAN_RESULT,
    IOCTL_80211_TX_POWER_LEVEL,
    
    IOCTL_ID_MAX
};

#endif /* IoctlId_h */
