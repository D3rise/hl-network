#!/bin/bash
export PATH=$PATH:$PWD/../bin
docker-compose up -d ca_org0 ca_org1
sleep 2

IP="192.168.21.154"
for i in {0..1}; do
    CA="${IP}:705$(expr 1 + ${i})"

    mkdir orgs/org$i orgs/org$i/msp
    mkdir orgs/org$i/msp/{admincerts,cacerts,users}
    fabric-ca-client enroll -u http://admin:adminpw@$CA -H orgs/org$i/admin
    
    cp -r orgs/org$i/admin/msp/signcerts orgs/org$i/admin/msp/admincerts
    cp orgs/org$i/admin/msp/signcerts/cert.pem orgs/org$i/msp/admincerts
    cp orgs/ca/org$i/ca-cert.pem orgs/org$i/msp/cacerts
done

CA="${IP}:7051"
fabric-ca-client register -u http://${CA} -H orgs/org0/admin --id.name orderer --id.type orderer --id.secret ordererpw
fabric-ca-client enroll -u http://orderer:ordererpw@${CA} -H orgs/org0/orderer
cp -r orgs/org0/admin/msp/signcerts orgs/org0/orderer/msp/admincerts

for i in {1..1}; do
    CA="${IP}:705$(expr 1 + ${i})"
    fabric-ca-client register -u http://${CA} -H orgs/org$i/admin --id.name peer --id.type peer --id.secret peerpw
    fabric-ca-client enroll -u http://peer:peerpw@${CA} -H orgs/org$i/peer
    cp -r orgs/org$i/admin/msp/signcerts orgs/org$i/peer/msp/admincerts
done