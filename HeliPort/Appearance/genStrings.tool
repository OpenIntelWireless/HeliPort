#!/bin/zsh

#
#  genStrings.tool
#  HeliPort
#
#  Created by Bat.bat on 2020/5/31.
#  Copyright © 2020 Bat.bat. All rights reserved.
#
#  This program and the accompanying materials are licensed and made available
#  under the terms and conditions of the The 3-Clause BSD License
#  which accompanies this distribution. The full text of the license may be found at
#  https://opensource.org/licenses/BSD-3-Clause
#

function abort() {
    echo "This tool cannot run in $1, aborting"
    exit 1
}

function checkEnv() {
    if [[ $OSTYPE != darwin* ]]; then
        abort "non macOS Systems"
    fi

    if [[ -z ${ZSH_VERSION+x} ]]; then
        abort "non zsh shells"
    fi
}

function main() {
    STRINGS="$(grep "NSLocalizedString(" *.swift)"
    STRINGS="$(echo "$STRINGS" | sed -e "s/.*NSLocalizedString(//g" | sed -e "s/, comment.*//g")"
    STRINGS="$(echo "$STRINGS" | xargs -I {} echo \"{}\" = \"{}\"\; &>/dev/null | sort | uniq)"
    echo "$STRINGS" > NEW.strings
    touch TMP.strings
    git merge-file zh-Hans.lproj/Localizable.strings TMP.strings NEW.strings
    osascript -e 'tell application (path to frontmost application as text) to display dialog "Open an external editor and resolve conflicts for the .strings files" buttons {"OK"} with icon caution' &>/dev/null
    echo 'DONE!'
}
checkEnv
cd $(dirname $0:A)
main
