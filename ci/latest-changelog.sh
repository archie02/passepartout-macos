#!/bin/sh
TARGET="CHANGELOG.md"
RELEASES=(`grep -n "^## " $TARGET | sed -E "s/^([0-9]+).*$/\1/g"`)
UNRELEASED=${RELEASES[0]}
LATEST=${RELEASES[1]}

if [ ! $LATEST ]; then
    LATEST=`cat $TARGET | wc -l`
    cat $TARGET | tail -n $((LATEST - UNRELEASED - 1))
    exit
fi
cat $TARGET | head -n $((LATEST - 1)) | tail -n $((LATEST - UNRELEASED - 2))
