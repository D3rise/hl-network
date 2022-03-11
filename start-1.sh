#!/bin/bash
export PATH=$PATH:$PWD/../bin

configtxgen -profile WSRGenesis -channelID syschannel -outputBlock orgs/org0/orderer/genesis.block
configtxgen -profile WSR -channelID wsr -outputCreateChannelTx orgs/common/wsr.tx

configtxgen -profile WSR -channelID wsr -outputAnchorPeersUpdate orgs/common/org1anchors.tx -asOrg Users

docker-compose up -d orderer peer-org1 cli-org1
sleep 1
docker exec -ti cli-org1 peer channel create -o 192.168.21.154:7050 -c wsr -f wsr.tx

for i in {1..1}; do
    docker exec -ti cli-org$i peer channel join -b wsr.block -o 192.168.21.154:7050
    docker exec -ti cli-org$i peer channel update -c wsr -f org${i}anchors.tx -o 192.168.21.154:7050
done