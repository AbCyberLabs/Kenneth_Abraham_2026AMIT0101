# Portfolio 5: Distributed and cloud database exercise

This part builds a three server MongoDB replica set in Docker for the KPay Wallet case study. It tests replication, failover, write concern, and what happens when most of the servers are gone. Sharding and the cloud are discussed in the analysis but not built.

## Files in this folder

| File | What it is |
|---|---|
| docker-compose.yml | Starts three MongoDB 7 servers: mongo1, mongo2 and mongo3 |
| README.md | This file |
| screenshots | Eight pictures from my own run, p5_01 to p5_08 |

## What you need

Docker Desktop. I ran everything on 12 October 2026 on Windows 11 with Docker Desktop 4.94.0 (WSL 2), Docker 29.8.2 and Windows PowerShell 5.1. The commands below are the ones I ran in PowerShell. In PowerShell the JavaScript goes inside double quotes and uses single quotes within it. In another shell the quotes may need changing.

## Step 1: start three database servers

```
cd portfolio-5-distributed-cloud
docker compose up -d
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

mongo1, mongo2 and mongo3 were all running (image mongo:7) on host ports 27017, 27018 and 27019. Screenshot: p5_01.

## Step 2: join them into one replica set

```
docker exec mongo1 mongosh --eval "rs.initiate({_id:'kpayrs', members:[{_id:0, host:'mongo1:27017'},{_id:1, host:'mongo2:27017'},{_id:2, host:'mongo3:27017'}]})"
```

Wait about 15 seconds, then check the status:

```
docker exec mongo1 mongosh --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))"
```

One server is PRIMARY and two are SECONDARY. Which one becomes the primary can change from run to run. In my run it was mongo3, so the commands below stop and write to mongo3. If another server is PRIMARY in yours, use that one instead. Screenshot: p5_02.

## Step 3: show replication

Write a wallet on the primary (mongo3 in my run):

```
docker exec mongo3 mongosh --quiet --eval "db.getSiblingDB('kpay').wallets.insertOne({_id:'C0100', fullName:'Replication Test', city:'Lagos'})"
```

Read it from a secondary (mongo2):

```
docker exec mongo2 mongosh --quiet --eval "db.getMongo().setReadPref('secondary'); db.getSiblingDB('kpay').wallets.find({_id:'C0100'})"
```

The write was acknowledged, and the same document came back from mongo2. Screenshot: p5_03.

## Step 4: show failover

Stop the primary, then ask mongo1 for the status:

```
docker stop mongo3
docker exec mongo1 mongosh --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))"
```

mongo1 was PRIMARY, mongo2 was SECONDARY and mongo3 showed as (not reachable/healthy).

Then write a wallet while mongo3 is still down. This uses the replica set address, so the driver finds the new primary by itself:

```
docker exec mongo1 mongosh --quiet "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/?replicaSet=kpayrs" --eval "db.getSiblingDB('kpay').wallets.insertOne({_id:'C0102', fullName:'Written During Failover', city:'Abuja'})"
```

The write was acknowledged. Screenshot: p5_04.

Start mongo3 again, check the status, and read the wallet that was written while it was down:

```
docker start mongo3
docker exec mongo1 mongosh --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))"
docker exec mongo3 mongosh --quiet --eval "db.getMongo().setReadPref('secondary'); db.getSiblingDB('kpay').wallets.find({_id:'C0102'})"
```

mongo3 came back as a SECONDARY, mongo1 stayed PRIMARY, and mongo3 returned C0102. Screenshot: p5_05.

I did not measure how long the failover took. docker stop is a clean shutdown, and my first status check after it already showed mongo1 as PRIMARY.

## Step 5: show the consistency choice (write concern)

A write concern says how many servers must have a write before MongoDB acknowledges it. In MongoDB 7 the default for a replica set like this one is already majority, so this command writes it out to make the choice visible. It waits until most of the servers (2 of 3) have the data:

```
docker exec mongo1 mongosh --quiet "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/?replicaSet=kpayrs" --eval "db.getSiblingDB('kpay').wallets.insertOne({_id:'C0101', fullName:'Safe Write'}, {writeConcern:{w:'majority', wtimeout:5000}})"
```

The write was acknowledged with all three servers running. Screenshot: p5_06.

## Step 6: what happens with no majority

Stop two of the three servers, check the status, and try to write to the one that is left:

```
docker stop mongo2 mongo3
docker exec mongo1 mongosh --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))"
docker exec mongo1 mongosh --quiet --eval "db.getSiblingDB('kpay').wallets.insertOne({_id:'C0103', fullName:'Should Be Refused'})"
```

mongo1 became SECONDARY, mongo2 and mongo3 showed as (not reachable/healthy), and the insert was refused with `MongoServerError: not primary`. This insert goes straight to mongo1, which is why the error comes back at once. Screenshot: p5_07.

Start the two servers again and check the status:

```
docker start mongo2 mongo3
docker exec mongo1 mongosh --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))"
```

mongo1 became PRIMARY again, and mongo2 and mongo3 were SECONDARY. Screenshot: p5_08.

## Results from my own run

| Picture | Step | Result |
|---|---|---|
| p5_01 | docker ps | mongo1, mongo2 and mongo3 running, image mongo:7, ports 27017, 27018 and 27019 |
| p5_02 | Replica set status | mongo1 SECONDARY, mongo2 SECONDARY, mongo3 PRIMARY |
| p5_03 | Replication | C0100 written on mongo3 (acknowledged). Read from mongo2 as a secondary: the same document |
| p5_04 | docker stop mongo3 | mongo1 PRIMARY, mongo2 SECONDARY, mongo3 (not reachable/healthy). C0102 written through the replica set address: acknowledged |
| p5_05 | docker start mongo3 | mongo1 PRIMARY, mongo2 SECONDARY, mongo3 SECONDARY. mongo3 returned C0102, which was written while it was down |
| p5_06 | Majority write | C0101 written with w majority and wtimeout 5000: acknowledged |
| p5_07 | No majority | mongo2 and mongo3 stopped. mongo1 became SECONDARY. Insert of C0103 refused: MongoServerError: not primary |
| p5_08 | Recovered | After docker start mongo2 mongo3: mongo1 PRIMARY, mongo2 SECONDARY, mongo3 SECONDARY |

## Screenshots

All files are in the screenshots folder.

| File | What it shows |
|---|---|
| p5_01_docker_ps.png | The three servers running |
| p5_02_replica_set_status.png | mongo3 PRIMARY, mongo1 and mongo2 SECONDARY |
| p5_03_replication.png | A write on mongo3 read back from mongo2 |
| p5_04_failover.png | mongo3 stopped, mongo1 now PRIMARY, a write accepted |
| p5_05_mongo3_back.png | mongo3 back as SECONDARY, with the write it missed |
| p5_06_write_concern.png | A write with w majority, acknowledged |
| p5_07_no_majority.png | One server left, writes refused: not primary |
| p5_08_recovered.png | All three servers back, mongo1 PRIMARY |

## Analysis

### 1. What did replication do?

A replica set keeps the same data on several servers. I started three MongoDB servers (mongo1, mongo2 and mongo3) and joined them into one set called kpayrs. In my run mongo3 won the election and became the primary, and the other two became secondaries. All writes go to the primary, and it sends each change on to the secondaries. I wrote a test wallet (C0100) on mongo3 and read it back from mongo2 with the read preference set to secondary, and the same document came back. That copy was made by the replica set, not by me.

### 2. What happened when I stopped the primary?

I stopped the primary with docker stop mongo3. At my first status check afterwards, mongo1 was the new PRIMARY, mongo2 was still SECONDARY and mongo3 showed as not reachable. So the set chose a new primary by itself and carried on with two of its three servers. While mongo3 was down I wrote a new wallet (C0102) and it was acknowledged. When I started mongo3 again it came back as a SECONDARY and already held C0102.

I did not time the failover. docker stop is a clean shutdown, so it can be quicker than a real crash. The MongoDB documentation says servers wait 10 seconds by default before starting an election, but I have not measured that.

### 3. What does write concern majority protect?

With w: majority, MongoDB only acknowledges a write once most of the servers (2 of 3) have it. Any server that becomes primary afterwards will have that write too, so a failover cannot lose it. In MongoDB 7 this is already the default for a replica set like mine, so I wrote it out to make the choice visible. My test write (C0101) was acknowledged with all three servers running. The cost is that the write waits for a second server. I did not test a failure in the middle of a write, so how it protects the data comes from the documentation and not from my own result.

### 4. What happened with no majority, and what does it say about consistency and availability?

I stopped mongo2 and mongo3 so that only mongo1 was left. The status check showed mongo1 as SECONDARY, and an insert sent to it was refused with MongoServerError: not primary. A server that can see only itself cannot tell whether the others are down or just cut off from it. If it kept accepting writes, two servers could end up holding different changes. So it stopped taking writes.

The CAP theorem says that when a network splits, a system has to give up either consistency or availability. Here MongoDB gave up availability, because writes stopped, to keep the data consistent. For KPay balances I think that is the right choice, because a wallet that is briefly unavailable is better than one that shows two different balances. For something like a recent activity feed, being available matters more and slightly old data is acceptable. Stopping two containers is not the same as a real network split, but the effect on mongo1 is the same, because it cannot reach a majority. When I started mongo2 and mongo3 again, mongo1 became PRIMARY and the other two became secondaries.

### 5. Sharding: why customer id and not city?

Replication copies the same data to every server, so it does not help when there is too much data for one server. Sharding splits the data across servers using a shard key. I did not build sharding, so this part is my reasoning only. Customer id is a good shard key because most queries are about one customer (open a wallet, send money, view a statement), so each query can go to one shard. City would be a poor key. Most customers would probably be in a few big cities such as Lagos, so one shard would take most of the traffic. Ids like C0001 and C0002 count upwards, so a plain range on them would send every new customer to the last shard. A hashed key on the customer id would spread them out.

### 6. Managed cloud: what would I gain and what would I lose?

The same replica set could run on a managed service such as MongoDB Atlas. I would gain less server work, because the provider looks after the servers, replication, backups and failover, and it is easy to add capacity as the number of customers grows. I would give up some control and pay every month. I would also have to check where the data is stored. KPay holds Nigerian financial data, so I would need to find out which rules apply before choosing a region. I did not deploy to a cloud service in this portfolio, so this is discussion only.

### 7. Limits of this setup

All three servers ran as Docker containers on one laptop, so this setup survives one server stopping but not the laptop failing. It is not a backup either, because a wallet deleted by mistake would be deleted on all three copies. It also has no password (no authentication), and docker ps shows the ports open on 0.0.0.0, which means all network interfaces of my laptop. That is fine for a classroom demo on my own machine but not for real money. I tested stopping servers and not a real network split, I did not measure the failover time, and I did not test sharding or a cloud deployment.

## Clean up and restart

```
docker compose stop
docker compose start
docker compose down -v
```

docker compose stop stops the servers and keeps the data. docker compose start starts them again. docker compose down -v removes the servers and deletes all their data, so only use it when you are completely finished. After a restart the replica set is still set up, because the data lives in Docker volumes. After a reboot of the computer, docker compose up -d starts the three servers again.

## If you run these tests again after Portfolio 4

Portfolio 4 creates a unique index on the email field of kpay.wallets. The test wallets in this README have no email, so MongoDB will refuse the second one with an E11000 duplicate key error (the email is empty for both). Either give each test wallet an email, or drop the index first:

```
docker exec mongo1 mongosh --quiet "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/?replicaSet=kpayrs" --eval "db.getSiblingDB('kpay').wallets.dropIndex('email_1')"
```
