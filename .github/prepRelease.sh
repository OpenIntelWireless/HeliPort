#!/bin/zsh

#
#  prepRelease.sh
#  HeliPort
#
#  Created by Bat.bat on 2020/6/10.
#  Copyright © 2020 lhy. All rights reserved.
#

#
#  This program and the accompanying materials are licensed and made available
#  under the terms and conditions of the The 3-Clause BSD License
#  which accompanies this distribution. The full text of the license may be found at
#  https://opensource.org/licenses/BSD-3-Clause
#

cd $GITHUB_WORKSPACE

eval $(grep -m 1 "MARKETING_VERSION" HeliPort.xcodeproj/project.pbxproj | tr -d ';' | tr -d '\t' | tr -d " ")

echo "::set-env name=NEWVER::$MARKETING_VERSION"

# Unless this project becomes insane, there's no chance that the version number will be larger than 9.9.9
# Don't bump version for tag since we're using keywords for releases (Drafts can't be overridden in GH Actions)
#if [[ ${MARKETING_VERSION##*.} == 9 ]]; then
#    if [[ ${MARKETING_VERSION:2:1} == 9 ]]; then
#        NEWVER="$((${MARKETING_VERSION:0:1}+1)).0.0"
#    else
#        NEWVER="${MARKETING_VERSION:0:1}.$((${MARKETING_VERSION:2:1}+1)).0"
#    fi
#else
#    NEWVER="${MARKETING_VERSION%.*}.$((${MARKETING_VERSION##*.}+1))"
#fi

#cd build/Build/Products/Release
cd build/Build/Products/Debug
ditto -c -k --sequesterRsrc --keepParent *.app HeliPort.zip
cd -
mkdir Artifacts
cp -R build/Build/Products/Debug/*.zip Artifacts

git log -"20" --format="- %H %s" | grep -v 'gitignore\|Repo\|Docs\|Merge\|yml\|CI\|Commit\|commit\|attributes' | sed '/^$/d' >> ReleaseNotes.md
#git log -"$(git rev-list --count $(git rev-list --tags | head -n 1)..HEAD)" --format="- %H %s" | grep -v 'gitignore\|Repo\|Docs\|Merge\|yml\|CI\|Commit\|commit\|attributes' | sed  '/^$/d' >> ReleaseNotes.md

mkdir sparkle
cd sparkle
rawURL="https://github.com/sparkle-project/Sparkle/releases/latest"
URL="https://github.com$(one=${"$(curl -L --silent "${rawURL}" | grep '/download/' | grep -m 1 'xz' )"#*href=\"} && two=${one%\"\ rel*} && echo $two)"
curl -#LO "${URL}"
tar xvf *.xz >/dev/null 2>&1
cd ..
