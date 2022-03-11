#!/bin/bash
export PATH=$PATH:$PWD/../bin
docker-compose up -d ca_org2 ca_org3
sleep 2

IP="192.168.21.152"
for i in {2..3}; do
    CA="${IP}:705$(expr 1 + ${i})"

    mkdir orgs/org$i orgs/org$i/msp
    mkdir orgs/org$i/msp/{admincerts,cacerts,users}
    fabric-ca-client enroll -u http://admin:adminpw@$CA -H orgs/org$i/admin
    
    cp -r orgs/org$i/admin/msp/signcerts orgs/org$i/admin/msp/admincerts
    cp orgs/org$i/admin/msp/signcerts/cert.pem orgs/org$i/msp/admincerts
    cp orgs/ca/org$i/ca-cert.pem orgs/org$i/msp/cacerts

    fabric-ca-client register -u http://${CA} -H orgs/org$i/admin --id.name peer --id.type peer --id.secret peerpw
    fabric-ca-client enroll -u http://peer:peerpw@${CA} -H orgs/org$i/peer
    cp -r orgs/org$i/admin/msp/signcerts orgs/org$i/peer/msp/admincerts
done