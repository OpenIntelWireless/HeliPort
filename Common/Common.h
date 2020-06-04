//
//  Common.h
//  ClientKit
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

#ifndef Common_h
#define Common_h

#include "IoctlId.h"

#define API_TEST

#define IOCTL_MASK 0x800000
#define IOCTL_VERSION 1
#define NWID_LEN 32
#define WPA_KEY_LEN 128

struct ioctl_driver_info {
    unsigned int version;
    char fw_version[32];    //firmware version string
    char driver_version[32];    //driver version string
    char bsd_name[32];  //interface bsd name, eg. en1
};

enum itl_phy_mode {
    ITL80211_MODE_11A,
    ITL80211_MODE_11B,
    ITL80211_MODE_11G,
    ITL80211_MODE_11N,
    ITL80211_MODE_11AC,
    ITL80211_MODE_11AX
};

struct ioctl_sta_info {
    unsigned int version;
    enum itl_phy_mode op_mode;
    int max_mcs;
    int cur_mcs;
};

struct ioctl_power {
    unsigned int version;
    unsigned int enabled;    //1 == on, 0 == off
    unsigned int maxsleep;   //max sleep in ms
};

enum itl_80211_state {
    ITL80211_S_INIT    = 0,    /* default state */
    ITL80211_S_SCAN    = 1,    /* scanning */
    ITL80211_S_AUTH    = 2,    /* try to authenticate */
    ITL80211_S_ASSOC    = 3,    /* try to assoc */
    ITL80211_S_RUN        = 4    /* associated */
};

struct ioctl_state {
    unsigned int version;
    int state; //itl_80211_state
};

struct ioctl_nw_id {
    unsigned int version;
    unsigned int len;
    char nwid[NWID_LEN];
};

struct ioctl_wpa_key {
    unsigned int version;
    unsigned int len;
    char key[WPA_KEY_LEN];
};

struct ioctl_associate {
    unsigned int version;
    struct ioctl_nw_id nwid;
    struct ioctl_wpa_key wpa_key;
};

struct ioctl_disassociate {
    unsigned int version;
};

struct ioctl_join {
    unsigned int version;
};

struct ioctl_scan {
    unsigned int version;
};

struct ioctl_scan_result {
    unsigned int version;
};

struct ioctl_tx_power {
    unsigned int version;
};

#endif /* Common_h */
