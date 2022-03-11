#!/bin/bash
export PATH=$PATH:$PWD/../bin
docker-compose up -d peer-org2 peer-org3 cli-org2 cli-org3
sleep 1

configtxgen -profile WSR -channelID wsr -outputAnchorPeersUpdate orgs/common/org2anchors.tx -asOrg Shops
configtxgen -profile WSR -channelID wsr -outputAnchorPeersUpdate orgs/common/org3anchors.tx -asOrg Bank

for i in {2..3}; do
    docker exec -ti cli-org$i peer channel join -b wsr.block -o 192.168.21.154:7050
    docker exec -ti cli-org$i peer channel update -c wsr -f org${i}anchors.tx -o 192.168.21.154:7050
done