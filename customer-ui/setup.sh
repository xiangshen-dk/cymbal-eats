#!/usr/bin/env bash

# Copyright 2022 Google LLC
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

source ../config-env.sh

export BASE_DIR=$PWD

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

export NVM_DIR="/usr/local/nvm"
source $NVM_DIR/nvm.sh;

nvm install 12.22.1
npm install
npm install -g @quasar/cli
npm install -g envsub
npm install pubsub-js

if [[ -z "${ORDER_SERVICE_URL}" ]]; then
  ORDER_SERVICE_URL=$(gcloud run services describe $ORDER_SERVICE_NAME \
    --region=$REGION \
    --format=json | jq \
    --raw-output ".status.url")
  export ORDER_SERVICE_URL
else
  echo "Using pre-defined ORDER_SERVICE_URL=$ORDER_SERVICE_URL"
fi

if [[ -z "${INVENTORY_SERVICE_URL}" ]]; then
  INVENTORY_SERVICE_URL=$(gcloud run services describe $INVENTORY_SERVICE_NAME \
    --region=$REGION \
    --format=json | jq \
    --raw-output ".status.url")
  export INVENTORY_SERVICE_URL
else
  echo "Using pre-defined INVENTORY_SERVICE_URL=$INVENTORY_SERVICE_URL"
fi

if [[ -z "${MENU_SERVICE_URL}" ]]; then
  MENU_SERVICE_URL=$(gcloud run services describe $MENU_SERVICE_NAME \
    --region=$REGION \
    --format=json | jq \
    --raw-output ".status.url")
  export MENU_SERVICE_URL
else
  echo "Using pre-defined MENU_SERVICE_URL=$MENU_SERVICE_URL"
fi

envsub .env.tmpl .env

rm -rf cloud-run/public

quasar clean
quasar build

mkdir -p cloud-run/public
cp -r dist/spa/* cloud-run/public
cd cloud-run

gcloud run deploy $CUSTOMER_SERVICE_NAME \
  --source . \
  --platform managed \
  --region $REGION \
  --project=$PROJECT_ID \
  --allow-unauthenticated \
  --set-env-vars=VUE_APP_PROJECT_ID=$PROJECT_ID,VUE_APP_MENU_SERVICE_URL=$MENU_SERVICE_URL,VUE_APP_INVENTORY_SERVICE_URL=$INVENTORY_SERVICE_URL,VUE_APP_ORDER_SERVICE_URL=$ORDER_SERVICE_URL \
  --quiet
