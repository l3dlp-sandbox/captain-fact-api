#!/usr/bin/env bash
#---------------------------------------------------------------------------------------------------
# Start a docker release with dev params
# Usage ./test_docker_release.sh
#
# /!\ Obviously database must be started
#---------------------------------------------------------------------------------------------------

CF_REST_API_IMAGE=captain-fact-api:dev-test
CF_GRAPHQL_API_IMAGE=captain-fact-api-graphql:dev-test
CF_ATOM_FEED_IMAGE=captain-fact-atom-feed:dev-test
CF_OPENGRAPH_IMAGE=captain-fact-opengraph:dev-test

# If any command fails, exit
set -e

# Build
cd -- "$(dirname $0)"
docker build -t $CF_REST_API_IMAGE --build-arg APP=captain_fact ../..
docker build -t $CF_GRAPHQL_API_IMAGE --build-arg APP=cf_graphql ../..
docker build -t $CF_ATOM_FEED_IMAGE --build-arg APP=cf_atom_feed ../..
docker build -t $CF_OPENGRAPH_IMAGE --build-arg APP=cf_opengraph ../..

# Run server
echo "Let's test REST API on port 4000 =>"
docker run -it \
  -e "CF_HOST=localhost" \
  -e "CF_SECRET_KEY_BASE=8C6FsJwjV11d+1WPUIbkEH6gB/VavJrcXWoPLujgpclfxjkLkoNFSjVU9XfeNm6s" \
  -e "CF_S3_ACCESS_KEY_ID=test" \
  -e "CF_S3_SECRET_ACCESS_KEY=test" \
  -e "CF_S3_BUCKET=test" \
  -e "CF_DB_HOSTNAME=localhost" \
  -e "CF_DB_USERNAME=postgres" \
  -e "CF_DB_PASSWORD=postgres" \
  -e "CF_DB_NAME=captain_fact_dev" \
  -e "CF_FACEBOOK_APP_ID=506726596325615" \
  -e "CF_FACEBOOK_APP_SECRET=4b320056746b8e57144c889f3baf0424" \
  -e "CF_FRONTEND_URL=http://localhost:3333" \
  -e "CF_CHROME_EXTENSION_ID=chrome-extension://lpdmcoikcclagelhlmibniibjilfifac" \
  -v "$(pwd)/../priv/secrets:/run/secrets:ro" \
  --network host \
  --rm ${CF_REST_API_IMAGE} console

echo "Let's test GraphQL API on port 4002 =>"
docker run -it \
  -e "CF_HOST=localhost" \
  -e "CF_S3_ACCESS_KEY_ID=test" \
  -e "CF_S3_SECRET_ACCESS_KEY=test" \
  -e "CF_S3_BUCKET=test" \
  -e "CF_SECRET_KEY_BASE=8C6FsJwjV11d+1WPUIbkEH6gB/VavJrcXWoPLujgpclfxjkLkoNFSjVU9XfeNm6s" \
  -e "CF_DB_HOSTNAME=localhost" \
  -e "CF_DB_USERNAME=postgres" \
  -e "CF_DB_PASSWORD=postgres" \
  -e "CF_DB_NAME=captain_fact_dev" \
  -e "CF_BASIC_AUTH_PASSWORD=password" \
  -v "$(pwd)/../priv/secrets:/run/secrets:ro" \
  --network host \
  --rm ${CF_GRAPHQL_API_IMAGE} console

echo "Let's test ATOM feed on port 4004 =>"
docker run -it \
  -e "CF_HOST=localhost" \
  -e "CF_S3_ACCESS_KEY_ID=test" \
  -e "CF_S3_SECRET_ACCESS_KEY=test" \
  -e "CF_S3_BUCKET=test" \
  -e "CF_DB_HOSTNAME=localhost" \
  -e "CF_DB_USERNAME=postgres" \
  -e "CF_DB_PASSWORD=postgres" \
  -e "CF_DB_NAME=captain_fact_dev" \
  -v "$(pwd)/../priv/secrets:/run/secrets:ro" \
  --network host \
  --rm ${CF_ATOM_FEED_IMAGE} console

# Cleanup
docker rmi -f ${CF_REST_API_IMAGE}
