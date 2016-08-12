#!/bin/bash
#
# Copyright (C) 2016 OmniROM Project
#
# Modified for personal usage. A script combo between Omni, DU, and
# other remnants that I picked up along the way.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
echo -e "Enter the AOSP ref to merge"
read ref

echo " "

# Colors
COLOR_RED='\033[0;31m'
COLOR_BLANK='\033[0m'

# Google source url
REPO=https://android.googlesource.com/platform/

# This is the array of upstream repos we track
upstream=()

# This is the array of repos to blacklist and not merge
blacklist=('manifest' 'prebuilt' 'packages/apps/DeskClock' 'packages/apps/Bluetooth' 'system/bt')

function is_in_blacklist() {
  for j in ${blacklist[@]}
  do
    if [ "$j" == "$1" ]; then
      return 0;
    fi
  done
  return 1;
}

function get_repos() {
  if [ -f aosp-forked-list ]; then
    rm -f aosp-forked-list
  fi
  touch aosp-forked-list
  declare -a repos=( $(repo list | cut -d: -f1) )
  curl --output /tmp/rebase.tmp $REPO --silent # Download the html source of the Android source page
  # Since their projects are listed, we can grep for them
  for i in ${repos[@]}
  do
    if grep -q "$i" /tmp/rebase.tmp; then # If Google has it and
      if grep -q "$i" ./.repo/manifest.xml; then # If we have it in our manifest and
        if grep "$i" ./.repo/manifest.xml | grep -q "remote="; then # If we track our own copy of it
          if ! is_in_blacklist $i; then # If it's not in our blacklist
            upstream+=("$i") # Then we need to update it
            echo $i >> aosp-forked-list
          else
            echo "================================================"
            echo " "
            echo "$i is in blacklist"
            echo " "
          fi
        fi
      fi
    fi
  done
  rm /tmp/rebase.tmp
}

function delete_upstream() {
  for i in ${upstream[@]}
  do
    rm -rf $i
  done
}

function force_sync() {
  echo "Repo Syncing........."
  sleep 10
  repo sync --force-sync >> /dev/null
  if [ $? -eq 0 ]; then
    echo "Repo Sync success"
  else
    echo "Repo Sync failure"
    exit 1
  fi
}

function print_result() {
  if [ ${#failed[@]} -eq 0 ]; then
    echo ""
    echo "========== "$ref" is merged sucessfully =========="
    echo "========= Compile and test before pushing to github ========="
    echo ""
  else
    echo -e $COLOR_RED
    echo -e "These repos have merge errors: \n"
    for i in ${failed[@]}
    do
      echo -e "$i"
    done
    echo -e $COLOR_BLANK
  fi
}

# Need to generate a list of repos
get_repos

echo "================================================"
echo "          Force Syncing all your repos          "
echo "         and deleting all upstream repos        "
echo " This is done so we make sure you're up to date "
echo "================================================"
echo " "

delete_upstream
force_sync

while read path;
  do

  project=`echo android_${path} | sed -e 's/\//\_/g'`

  echo ""
  echo "====================================================================="
  echo " PROJECT: ${project} -> [ ${path}/ ]"
  echo ""

  cd $path;

  git merge --abort;

  repo sync -d .

  if git branch | grep "android-6.0-merge" > /dev/null; then
    git branch -D android-6.0-merge > /dev/null
  fi

  repo start android-6.0-merge .

  if ! git remote | grep "aosp" > /dev/null; then
    git remote add aosp https://android.googlesource.com/platform/$path > /dev/null
  fi

  git fetch --tags aosp

  git merge $ref;
  if [ $? -ne 0 ]; then # If merge failed
    failed+=($path/) # Add to the list of failed repos
  fi

  cd - > /dev/null

done < aosp-forked-list

# Print any repos that failed, so we can fix merge issues
print_result
