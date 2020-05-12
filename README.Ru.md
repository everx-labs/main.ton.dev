# README

Это руководство содержит инструкции о том, как построить и настроить узел валидатора в цепочке блоков TON. Приведенные ниже инструкции и сценарии были проверены в Ubuntu 18.04.
# Начало

## Системные Требования
| Конфигурация | CPU (cores) | RAM (GiB) | Storage (GiB) | Network (Gbit/s)|
|---|:---|:---|:---|:---|
| Минимальная |8|16|1000|1|
| Рекомендуемая |16|32|1000|1| 
## Пререквизиты
### 1. Устанавливаем необходимые значения в переменные среды
Поправьте (если требуется) `main.ton.dev/scripts/env.sh`
    
    $ cd main.ton.dev/scripts/
    $ . ./env.sh 
### 2. Собираем ноду
Собираем ноду:

    $ ./build.sh
### 3. Процесс установки ноды
Инициализация ноды:

    $ ./setup.sh
### 4. Подготавливаем Multisignature Wallet
**Заметка**: Все обращения к утилите TONOS-CLI должны выполняться из папки `scripts`.

Multisignature wallet (или просто кошелек) используется валидатором для отправки election requests to the Elector smart contract.

Пусть `N` будет общим кол-вом кошельков custodians и `K` количество минимальных подтверждений, необходимых для выполнения транзакции кошелька.

1. Прочтите [TONOS-CLI документацию](https://docs.ton.dev/86757ecb2/v/0/p/94921e-running-tonos-cli-with-tails-os-and-working-with-multisignature-wallet) (*Deploying Multisignature Wallet to TON blockchain*) и сгенерируйте мнемоническую фразу и публичные ключи для `N - 1` custodians.
2. Генерируем адрес кошелька и `Nth` custodian ключ:
```
    $ ./msig_genaddr.sh
```
Этот скрипт создает 2 файла: `$(hostname -s).addr` и `msig.keys.json` в папке `~/ton-keys/`. 
Используем публичный ключ и `msig.keys.json` как `Nth` custodian публичный ключ когда будем осуществлять деплой кошелька.

## Запуск ноды валидатора
Выполняем этот шаг когда сеть запущена.
Запускаем ноду:

    $ ./run.sh
  
Дожидаемся когда нода произведет синхронизацию с мастерчейном. В зависимости от пропускной способности сети этот шаг может занять значительное время (до нескольких часов).

Вы можете использовать следующий скрипт для проверки синхронизации ноды:

    $ ./check_node_sync_status.sh

Пример вывода скрипта:
```
connecting to [127.0.0.1:3030]
local key: FB0A67F8992DB0EF51860D45E89951275A4D6EB6A381BBF99023292982F97247
remote key: 2AD4363BE4BCCEFEF667CB919B199C4710278B8E2B0D972E18D1E5A17B62A99D
conn ready
unixtime            1588443685
masterchainblock            (-1,8000000000000000,989):85316E413BD4FFBE76AF7BCDC2A75C27B2BA3AE45381D0CE7B5684949447DF07:6D975F062203F2A2F913FC528387036F47B27AB156B76E4127C186E32A6ED9C3
masterchainblocktime            1588443683
gcmasterchainblock            (-1,8000000000000000,0):3D009F42614CBA3537A41596BFD6E598756C83332668990C914D67A3B137D37D:40D1F2B2588A6A00D8AB05C8C1E944E42B172B5C111867B70DBC41009EE10C55
keymasterchainblock            (-1,8000000000000000,669):712CBAF305CB9AF1CD3745FDDB8E184796D8A21E7C559A42EB6B68D8B2F2FF89:3B03B9075B20BD1E6111492C41756F337FF649C6C89B9F87D446FAC47DCFD2BB
knownkeymasterchainblock            (-1,8000000000000000,669):712CBAF305CB9AF1CD3745FDDB8E184796D8A21E7C559A42EB6B68D8B2F2FF89:3B03B9075B20BD1E6111492C41756F337FF649C6C89B9F87D446FAC47DCFD2BB
rotatemasterchainblock            (-1,8000000000000000,918):4DD1DF6361F4B406DCC948B99E0D1ADD6988AC8F824F2E1B263CFED2AD46742E:12A8599C16C5EF1B09713F7EC91E2F765E97545F046FE6871DCD0C82E0377036
stateserializermasterchainseqno            984
shardclientmasterchainseqno            988
INFO: TIME_DIFF = -2
```
Если параметр `TIME_DIFF` равен нескольким секундам, процесс синхронинзации завершен.

### 1. Инициализация multisignature wallet

**Заметка**: Все обращения к утилите TONOS-CLI должны выполняться из папки `scripts`.


Gather all custodians' public keys and deploy wallet using [TONOS-CLI](https://docs.ton.dev/86757ecb2/v/0/p/94921e-running-tonos-cli-with-tails-os-and-working-with-multisignature-wallet) (lookup Deploying Multisignature Wallet to TON blockchain in the document above). Use `K` value as `reqConfirms` deploy parameter.
Make sure that the wallet was deployed at the address saved in `$(hostname -s).addr` file.


### 2.Запуск скрипта валидатора

Specify `<STAKE>` argument in tokens. This amount of tokens will be sent by wallet to Elector smart contract in every validation cycle.

Запускаем скрипт валидатора:

    $ watch -n 60 ./validator_msig.sh <STAKE> >> ./validator.log 2>&1

### Принцип работы скрипта валидатора

Скрипт запускается каждую минуту.

1. Makes an initial check for masterchain.
2. Checks startup time.
3. Gets address of elector contract and reads `election_id` from elector contract.
4. If `election_id` == 0 (that means no validator elections at the moment):
    1. script requests size of validator stake that can be returned from elector. (by running Elector's `compute_returned_stake` get-method). Returned value will not be 0 if validator won previous elections and was a validator;
    2. if this value != 0, script submits new transaction from wallet to Elector contract with 1 token and `recover-stake` payload;
    3. if request to wallet succeeds, script extracts `transactionId` and prints it in terminal and then exits. Other wallet custodians should confirm transaction using this Id. 
5. If `election_id` != 0 (that means it's time to participate in elections):
    1. checks if `stop-election` file exists then exits;
    2. checks if file `active-election-id` exists, then reads `active_election_id` from it and compares it to `election_id`. If they are equal then exits (it means that validator has already sent its stake to Elector in current elections);
    3. calls `validator-engine-console` to generate new validator key and adnl address;
    4. reads config param 15 to get elections timeouts;
    5. runs `validator-elect-req.fif` fift script to generate unsigned validator election request;
    6. calls `validator-engine-console` to sign election request with newly generated validator keypair;
    7. submits new transaction from wallet to Elector contract with `$stake` amount of tokens and `process_new_stake` payload;
    8. if request to wallet succeeds, script extracts `transactionId` and prints it in terminal;
    9. wallet custodians should confirm transaction using this Id. When wallet accumulates the required number of confirmations, it sends validator election request to Elector.



