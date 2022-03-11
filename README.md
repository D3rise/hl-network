# Запуск сети

1. Изменить IP-адреса во всех конф. файлах и скриптах на те, которые будут использоваться в нашей сети:
   1. `192.168.21.154` соответствует первому компьютеру
   2. `192.168.21.152` соответствует второму компьютеру
2. Запустить `ca-start-1.sh` на первом компьютере
3. Синхронизировать папку `orgs` между обеими компьютерами (скопировать папку с первого компьютера на второй)
4. Запустить `ca-start-2.sh` на втором компьютере
5. Синхронизировать папку `orgs` между обеими компьютерами (скопировать папку со второго компьютера на первый)
6. Запустить `start-1.sh` на первом компьютере
7. Синхронизировать папку `orgs` между обеими компьютерами (скопировать папку с первого компьютера на второй)
8. Запустить `start-2.sh` на втором компьютере

## Инициализация сети

Для запуска сети на двух компьютерах, необходимо создать 4 разных файла:

1. `ca-start-1.sh` - для инициализации центров сертификации на первом компьютере
2. `ca-start-2.sh` - для инициализации центров сертификации на втором компьютере
3. `start-1.sh` - для запуска сети на первом компьютере
4. `start-2.sh` - для запуска сети на втором компьютере

### `ca-start-1.sh`

```sh
#!/bin/bash
export PATH=$PATH:$PWD/../bin
# Запускаем центры сертификации для ordering-организации и организации Users
docker-compose up -d ca_org0 ca_org1
sleep 2

IP="<внешний IP адрес первого компьютера>"

# Выпускаем и сохраняем сертификаты администраторов каждой организации на текущем компьютере
for i in {0..1}; do
    # Адрес центра сертификации текущей организации (организации с индексом $i)
    CA="${IP}:705$(expr 1 + ${i})"

    # Создаём MSP организации, понадобится для создания генезис-блока
    # и канала внутри сети
    mkdir orgs/org$i orgs/org$i/msp
    mkdir orgs/org$i/msp/{admincerts,cacerts,users}

    # выпускаем и сохраняем сертификат администратора текущей организации
    fabric-ca-client enroll -u http://admin:adminpw@$CA -H orgs/org$i/admin
    
    # копируем сертификат администратора в папку admincerts,
    # потому что этого от нас требует fabric
    cp -r orgs/org$i/admin/msp/signcerts orgs/org$i/admin/msp/admincerts

    # копируем сертификат администратора в MSP организации
    cp orgs/org$i/admin/msp/signcerts/cert.pem orgs/org$i/msp/admincerts
    
    # копируем корневой сертификат центра сертификации в MSP организации
    cp orgs/ca/org$i/ca-cert.pem orgs/org$i/msp/cacerts
done

# Теперь нам нужно зарегистрировать сертификат для orderer-ноды
# Адрес центра сертификации ordering-организации
CA="${IP}:7051"

# Регистрируеми и выпускаем сертификат orderer-ноды
fabric-ca-client register -u http://${CA} -H orgs/org0/admin --id.name orderer --id.type orderer --id.secret ordererpw
fabric-ca-client enroll -u http://orderer:ordererpw@${CA} -H orgs/org0/orderer
cp -r orgs/org0/admin/msp/signcerts orgs/org0/orderer/msp/admincerts

# Теперь мы регистрируем и выпускаем сертификаты всех остальных нод, принадлежащим остальным организациям
# Регистрацию orderer-ноды мы вынесли наверх, потому что процесс регистрации пиров и orderer-ноды отличаются командами
for i in {1..1}; do

    # Адрес центра сертификации текущей организации (организации с индексом $i)
    CA="${IP}:705$(expr 1 + ${i})"

    # Регистрируем и выпускаем сертификат пира
    fabric-ca-client register -u http://${CA} -H orgs/org$i/admin --id.name peer --id.type peer --id.secret peerpw
    fabric-ca-client enroll -u http://peer:peerpw@${CA} -H orgs/org$i/peer
    cp -r orgs/org$i/admin/msp/signcerts orgs/org$i/peer/msp/admincerts
done
```

### `ca-start-2.sh`

```sh
#!/bin/bash
export PATH=$PATH:$PWD/../bin

# Поднимаем центры сертификации организаций Shops и Bank
docker-compose up -d ca_org2 ca_org3

# Ждём завершения их инициализации
sleep 2

IP="<внешний IP адрес второго компьютера>"

# Создаём MSP организаций, выпускаем сертификаты администраторов,
# регистрируем сертификаты пиров каждой организации
for i in {2..3}; do
    # Адрес центра сертификации текущей организации (организации с индексом $i)
    CA="${IP}:705$(expr 1 + ${i})"

    # Создаём структуру MSP для текущекй организации
    mkdir orgs/org$i orgs/org$i/msp
    mkdir orgs/org$i/msp/{admincerts,cacerts,users}

    # Выпускаем и сохраняем сертификат
    # администратора текущей организации
    fabric-ca-client enroll -u http://admin:adminpw@$CA -H orgs/org$i/admin
    
    # Указываем в MSP администратора сертификаты всех
    # администраторов организации (в нашем случае только его самого)
    cp -r orgs/org$i/admin/msp/signcerts orgs/org$i/admin/msp/admincerts

    # Копируем сертификат администратора и
    # корневой сертификат центра сертификации в MSP организации 
    cp orgs/org$i/admin/msp/signcerts/cert.pem orgs/org$i/msp/admincerts
    cp orgs/ca/org$i/ca-cert.pem orgs/org$i/msp/cacerts

    # Регистрируем сертификат пира текущей организации, 
    # после чего выпускаем его и сохраняем
    fabric-ca-client register -u http://${CA} -H orgs/org$i/admin --id.name peer --id.type peer --id.secret peerpw
    fabric-ca-client enroll -u http://peer:peerpw@${CA} -H orgs/org$i/peer
    cp -r orgs/org$i/admin/msp/signcerts orgs/org$i/peer/msp/admincerts
done
```

### `start-1.sh`

```sh
#!/bin/bash
export PATH=$PATH:$PWD/../bin

# Генерируем генезис-блок сети (он понадобится для поднятия orderer-ноды)
configtxgen -profile WSRGenesis -channelID syschannel -outputBlock orgs/org0/orderer/genesis.block

# Генерируем файл транзакции создания канала, с
# его помощью мы позже создадим канал в сети
configtxgen -profile WSR -channelID wsr -outputCreateChannelTx orgs/common/wsr.tx

# На первом компьютере есть две организации: Orderer и Users,
# но непосредственное участие в ней принимает только Users,
# а Orderer выступает в качестве независимой организации
# формирующей порядок блоков в сети

# Генерируем файл транзакции обновления списка anchor-пиров организации.
# Это необходимо для того, чтобы другие участники сети знали,
# по какому адресу можно обращаться к пирам нашей организации
configtxgen -profile WSR -channelID wsr -outputAnchorPeersUpdate orgs/common/org1anchors.tx -asOrg Users

# Поднимаем orderer, пир организации Users, а также командную строку для этого пира
docker-compose up -d orderer peer-org1 cli-org1
sleep 1

# Создаём канал в сети (взамен получаем файл блока канала wsr.block, который позже
# используем для присоединения к каналу всех организаций)
docker exec -ti cli-org1 peer channel create -o 192.168.21.154:7050 -c wsr -f wsr.tx

# Проходимся по всем организациям на текущем компьютере
for i in {1..1}; do
    # Используя блок создания канала wsr.block, присоединяемся к каналу
    docker exec -ti cli-org$i peer channel join -b wsr.block -o 192.168.21.154:7050

    # Используя файл транзакции обновления списка Anchor-пиров, обновляем их в блокчейне
    docker exec -ti cli-org$i peer channel update -c wsr -f org${i}anchors.tx -o 192.168.21.154:7050
done
```

### `start-2.sh`

```sh
#!/bin/bash
export PATH=$PATH:$PWD/../bin
# Поднимаем пиры организаций Shops и Bank, а также командных интерфейсов к ним
docker-compose up -d peer-org2 peer-org3 cli-org2 cli-org3
sleep 1

# Создаём файлы транзакций обновления Anchor-пиров для того чтобы позже обновить их в блокчейне
# Это необходимо для того, чтобы другие участники сети знали,
# по какому адресу можно обращаться к пирам нашей организации
configtxgen -profile WSR -channelID wsr -outputAnchorPeersUpdate orgs/common/org2anchors.tx -asOrg Shops
configtxgen -profile WSR -channelID wsr -outputAnchorPeersUpdate orgs/common/org3anchors.tx -asOrg Bank

# Проходимся по организациям в нашем канале
for i in {2..3}; do
    # Присоединяемся к нашему каналу, используя файл блока создания канала
    docker exec -ti cli-org$i peer channel join -b wsr.block -o 192.168.21.154:7050

    # Обновляем список anchor-пиров в сети, используя ранее созданные файлы транзакций
    docker exec -ti cli-org$i peer channel update -c wsr -f org${i}anchors.tx -o 192.168.21.154:7050
done
```

После того как мы создали эти файлы и сохранили их на обеих компьютерах, нам необходимо создать конфигурационный файл сети: `configtx.yaml`.

### `configtx.yaml`

*Мы копируем всё содержимое `configtx.yaml` из `fabric-samples/test-network/configtx/configtx.yaml`, но меняем его под себя:*

1. Меняем названия организаций:
   1. `Org1` на `Users`
   2. `Org2` на `Shops`
   3. `Org3` на `Bank`

2. В конфигурацию каждой организации добавляем следующие поля:

    ```yaml
    AnchorPeers:
        - Host: <внешний IP адрес компьютера, на котором работает пир организации>
          Port: <порт пира этой организации>
    ```

3. Вместо обычных `Policies` в конфигурации мы указываем следующие (пример на организации Users с ID `UsersMSP`):

   ```yaml
    Policies:
        # Чтение и запись в блокчейн: могут все участники организации
        Readers:
            Type: Signature
            Rule: "OR('UsersMSP.member')"
        Writers:
            Type: Signature
            Rule: "OR('UsersMSP.member')"
        # Администраторами выступают только администраторы организации
        Admins:
            Type: Signature
            Rule: "OR('UsersMSP.admin')"
        # Проверять валидность транзакций могут все участники организации
        Endorsement:
            Type: Signature
            Rule: "OR('UsersMSP.member')"
    ```

4. В ссылке (пункте) `OrdererDefaults`, меняем поле `OrdererType` с `etcdraft` на `solo`

5. В `Profiles` по-умолчанию есть лишь один профиль с конфигурацией как Orderer'a, так и организаций, но нам нужна конфигурация с использованием системного канала (`syschannel`), поэтому мы переписываем профили на вот это:

    ```yaml
    Profiles:
        # Профиль генезис-блока (системного канала, используется только orderer-нодой)
        WSRGenesis:
            <<: *ChannelDefaults
            Orderer:
                <<: *OrdererDefaults

            # Организации, отвечающие за формирование порядка блоков
            Organizations:
                - *Orderer
            Capabilities: *OrdererCapabilities
            
            # Консорциумы, отвечающие за принятие решений
            # в нашем случае есть только один такой, в котором присутствуют все организации
            Consortiums:
                Cons:
                    Organizations:
                        - *Users
                        - *Shops
                        - *Bank
        # Профиль нашего канала, в нём присутсвуют все организации нашей сети
        WSR:
            <<: *ChannelDefaults
            Application:
            <<: *ApplicationDefaults
            Organizations:
                - *Users
                - *Shops
                - *Bank
            Capabilities: *ApplicationCapabilities
            Consortium: Cons
    ```

После написания скриптов и создания конфигурации генезис-блока, нам необходимо написать `docker-compose.yml`, в котором будут прописаны конфигурации каждого контейнера принимающего участие в формировании сети

### `docker-compose.yml`

*Мы формируем `docker-compose.yml` из содержимого файлов `fabric-samples/test-network/compose/compose-test-net.yaml` и `fabric-samples/test-network/compose/compose-ca.yaml`.*  
Из первого файла мы берём конфигурацию центра сертификации, а из второго - конфигурации orderer-пира и пиров остальных организаций.

1. В конфигурации каждого контейнера мы убираем поле `ports`
2. В конфигурации каждого контейнера добавляем поле `network_mode: "host"`, чтобы контейнер мог обращаться к компьютерам в локальной сети
3. Для контейнеров ЦС (центров сертификации) мы должны использовать следующую конфигурацию:

```yaml
  ca_org0:
    image: hyperledger/fabric-ca:latest
    labels:
      service: hyperledger-fabric
    environment:
      - FABRIC_CA_HOME=/hl # рабочая папка, прописываем в volumes
      - FABRIC_CA_SERVER_CA_NAME=ca-org2 # имя ЦС
      - FABRIC_CA_SERVER_PORT=7053 # порт ЦС, должен быть уникальным
      - FABRIC_CA_SERVER_ADDRESS=192.168.21.152 # ВАЖНО: внешний адрес ЦС
      - FABRIC_CA_SERVER_LISTENADDRESS=192.168.21.152 # ВАЖНО: внешний адрес ЦС, который будет прослушиваться
      - FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:17056 # ВАЖНО: адрес для сервиса операций, должен быть уникальным
    command: sh -c 'fabric-ca-server start -b admin:adminpw -d'
    # ВАЖНО: тома (папки) которые будут внедряться внутрь контейнера
    volumes:
      - ./orgs/ca/org0:/hl
    container_name: ca_org0
    network_mode: "host"
```

4. Для контейнера orderer-пира мы должны использовать следующую конфигурацию:

```yaml
  orderer:
    container_name: orderer
    image: hyperledger/fabric-orderer:2.4.3
    labels:
      service: hyperledger-fabric
    environment:
      - ORDERER_GENERAL_LISTENADDRESS=192.168.21.154 # ВАЖНО: адрес, который будет прослушиваться orderer-пиром, обязательно должен быть равен внешнему IP-адресу машины, на которой будет запущен контейнер
      - ORDERER_GENERAL_LISTENPORT=7050 # ВАЖНО: прослушиваемый порт
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP # ID организации, которой принадлежит orderer-пир
      - ORDERER_GENERAL_LOCALMSPDIR=/hl/msp # папка с MSP этого пира
      - ORDERER_GENERAL_BOOTSTRAPMETHOD=file # метод инициализации orderer (мы создаём системный канал, поэтому используем файл генезис-блока)
      - ORDERER_GENERAL_BOOTSTRAPFILE=/hl/genesis.block # путь к файлу генезис-блока
    working_dir: /hl
    command: orderer
    volumes:
        - ./orgs/org0/orderer:/hl
    network_mode: "host"
```

5. Для контейнера пиров мы должны использовать следующую конфигурацию:

```yaml
  peer-org1:
    container_name: peer-org1
    image: hyperledger/fabric-peer:2.4.3
    labels:
      service: hyperledger-fabric
    environment:
      # Generic peer variables
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - FABRIC_LOGGING_SPEC=INFO
      # Peer specific variables
      - CORE_PEER_ID=peer-org1
      - CORE_PEER_ADDRESS=192.168.21.154:9051
      # ВАЖНО: прослушиваемый адрес пира, должен быть уникален
      - CORE_PEER_LISTENADDRESS=192.168.21.154:9051
      # ВАЖНО: адрес для контрактов, должен быть уникален
      - CORE_PEER_CHAINCODEADDRESS=192.168.21.154:9072
      # ВАЖНО: прослушиваемый адрес для контрактов, должен совпадать с CORE_PEER_CHAINCODEADDRESS
      - CORE_PEER_CHAINCODELISTENADDRESS=192.168.21.154:9072
      # ВАЖНО: внешний endpoint для других организаций (через него они будут находить наш пир)
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=192.168.21.154:9051
      - CORE_PEER_GOSSIP_BOOTSTRAP=192.168.21.154:9051
      # ВАЖНО: прослушиваемый адрес для операций, должен быть уникален
      - CORE_OPERATIONS_LISTENADDRESS=192.168.21.154:9444
      # ID организации, которой принадлежит наш пир
      - CORE_PEER_LOCALMSPID=UsersMSP
      - CORE_PEER_MSPCONFIGPATH=/hl/peer/msp
    volumes:
        - /var/run:/host/var/run
        - ./orgs/org1:/hl
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
    network_mode: "host"
```

6. Для контейнеров CLI мы должны использовать следующую конфигурацию:

```yaml
  cli-org1:
    container_name: cli-org1
    image: hyperledger/fabric-tools:2.4.3
    labels:
      service: hyperledger-fabric

    # Обязательно оставляем tty и ввод открытым, чтобы мы
    # могли заходить в CLI и вписывать туда команды
    tty: true
    stdin_open: true
    environment:
      # Путь к сокету докера, обязателен и необходим для взаитодействия CLI с другими контейнерами
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      # Путь к MSP, от имени которого будет обращаться к
      # сети нашей организации
      - CORE_PEER_MSPCONFIGPATH=/hl/admin/msp
      # ВАЖНО: адрес пира, к которому будет обращаться CLI
      - CORE_PEER_ADDRESS=192.168.21.154:9051
      # ID организации, которой принадлежит наш MSP
      - CORE_PEER_LOCALMSPID=UsersMSP
    working_dir: /common
    command: /bin/bash
    volumes:
        - /var/run:/host/var/run
        - ./orgs/org1:/hl
        - ./orgs/common:/common
    network_mode: "host"
```
