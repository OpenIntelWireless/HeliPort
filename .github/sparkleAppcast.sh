#!/bin/zsh

#
#  sparkleAppcast.sh
#  HeliPort
#
#  Created by Bat.bat on 2020/6/11.
#  Copyright © 2020 lhy. All rights reserved.
#

#
#  This program and the accompanying materials are licensed and made available
#  under the terms and conditions of the The 3-Clause BSD License
#  which accompanies this distribution. The full text of the license may be found at
#  https://opensource.org/licenses/BSD-3-Clause
#

cd $GITHUB_WORKSPACE

PUBDATE="$(date +"%a, %d %b %Y %T %z")"

APPCAST=(
    '<?xml version="1.0" standalone="yes"?>'
    '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">'
    '    <channel>'
    '        <title>HeliPort</title>'
    '        <item>'
    "            <title>${NEWVER}</title>"
    "            <pubDate>${PUBDATE}</pubDate>"
    '            <description><![CDATA['
    "                <link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/Primer/14.4.0/primer.min.css\"><meta charset=\"UTF-8\"> $(curl -L --silent https://github.com/zxystd/HeliPort/releases/latest | sed -n '/<div class=\"markdown-body\">/,/<\/div>/p' | tr -d '\n')"
    '            ]]>'
    '            </description>'
    "            <sparkle:minimumSystemVersion>10.12</sparkle:minimumSystemVersion>"
    "            <enclosure url=\"https://github.com/zxystd/HeliPort/releases/latest/download/HeliPort.zip\" sparkle:version=\"${NEWVER}\" sparkle:shortVersionString=\"${NEWVER}\" type=\"application/octet-stream\" $(./sparkle/bin/sign_update -s ${SPARKLE_KEY} ./Artifacts/HeliPort.zip)/>"
    '        </item>'
    '    </channel>'
    '</rss>'
)

sleep 10

for appcast in "${APPCAST[@]}"; do
    echo "${appcast}" >> ./Artifacts/appcast.xml
done
