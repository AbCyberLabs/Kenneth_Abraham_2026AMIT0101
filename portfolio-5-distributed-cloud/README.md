# Portfolio 5: Distributed and Cloud Database Exercise

Status of these files: NOT tested by the person who prepared them, because the
preparation environment had no Docker daemon. Run each step yourself, fix anything
that differs on your machine, and only keep screenshots of what really happened.

## What you need

Docker Desktop installed and running on your computer.

## Step 1: start three database servers

```
cd portfolio-5-distributed-cloud
docker compose up -d
docker ps
```

Screenshot `docker ps` showing mongo1, mongo2 and mongo3 running.

## Step 2: join them into one replica set

```
docker exec -it mongo1 mongosh --eval 'rs.initiate({_id:"kpayrs", members:[{_id:0, host:"mongo1:27017"},{_id:1, host:"mongo2:27017"},{_id:2, host:"mongo3:27017"}]})'
```

Wait about 15 seconds, then check:

```
docker exec -it mongo1 mongosh --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'
```

You should see one PRIMARY and two SECONDARY. Screenshot this.

## Step 3: show replication working

Write on the primary:

```
docker exec -it mongo1 mongosh --eval 'db.getSiblingDB("kpay").wallets.insertOne({_id:"C0100", fullName:"Replication Test", city:"Lagos"})'
```

Read from a secondary:

```
docker exec -it mongo2 mongosh --eval 'db.getMongo().setReadPref("secondary"); db.getSiblingDB("kpay").wallets.find({_id:"C0100"})'
```

The same document appears on mongo2. Screenshot it. That is replication.

## Step 4: show availability (failover)

Kill the primary, then ask who the new primary is.

```
docker stop mongo1
docker exec -it mongo2 mongosh --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'
```

After about 10 to 20 seconds mongo2 or mongo3 becomes PRIMARY. The system kept working
without mongo1. Screenshot before and after. Then bring it back:

```
docker start mongo1
```

mongo1 rejoins as a SECONDARY and catches up.

## Step 5: show the consistency choice

By default a write is acknowledged by the primary only. You can demand more:

```
docker exec -it mongo2 mongosh --eval 'db.getSiblingDB("kpay").wallets.insertOne({_id:"C0101", fullName:"Safe Write"}, {writeConcern:{w:"majority", wtimeout:5000}})'
```

`w: "majority"` waits until most servers have the data. It is slower but a failover
cannot lose that write. A balance transfer should use it. A page view counter would not.

## Step 6: discuss, in your own words (this is the discussion part of the marks)

Cover these ideas, using what you just saw:

1. **Replication.** Copies of the data on several servers. Benefits: availability and read scaling. Cost: copies can lag behind.
2. **Sharding.** Splitting the data across servers by a shard key, for when one server cannot hold or serve everything. For KPay a sensible shard key is the customer id, because most queries are about one customer. Explain why a key like `city` would be a poor choice (Lagos would be a hot spot).
3. **CAP theorem.** When the network splits, you must pick consistency or availability. Say which one a wallet should favour for balances (consistency) and which for a "recent activity" feed (availability is acceptable).
4. **Cloud deployment.** The same replica set could run on a managed cloud service such as MongoDB Atlas, which handles replication, backups and failover for you. Describe what you would gain (no server care, easy scaling) and what you would pay (cost, data residency questions for Nigerian financial data).

Sharding in Docker takes much more setup. Describing it clearly, with a diagram of
your own, is acceptable for the "or" in the brief (replication, sharding, availability,
consistency, or deployment evidence). The replica set above already covers replication,
availability and consistency with real evidence.

## Cleanup

```
docker compose down -v
```
