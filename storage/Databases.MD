# Databases

## Databases on EC2

- With EC2, you can run any database you want with ultimate control and flexibility.
- On the flipside you have to manage backups, redundancy patching, scaling etc
- This is a good option if you require a database, not supported by RDS such as IBM DB2 or are unable to move to an AWS managed database for whatever reason (process, feature support etc)

## RDS

- When not to use RDS:
  - lots of BLOBs (use S3)
  - automated scalability, name/value structure, unstructured data (use dynamoDB)
  - unsupported database or need full control (use EC2)
- Replication is synchronous between master and standby in another AZ
- Replication is async between master and read replica in another region
- In event of failure
  - If AZ fails then a standby in another AZ steps up with no loss
  - If region fails then you need to promote a read replica to standalone (single-AZ) then reconfigure it to be multi-AZ
    - Typically would do this manually as a big action!

## Aurora

- Built on top of RDS but is more advanced it is a fully managed RDS service for Postgresql and MySQL
- Multi-AZ by design
- AWS-managed auto scaling datastores
- Easier multi-region replicaton
- Read-replicas
  - One main replica and up to 15 read-replicas 
  - Data is held on data stores distributed accross these AZs
  - Data stores are independent of the instances you provision so can scale in and out independently depending on data 
  - Main instance handles all write traffic writing to all data copies and this replication is very fast
  - Once written it is available to read fast usually ~100ms
  - Read replicas can share read traffic: This means Aurora is fantastic for read heavy apps as the load can be spread
  - Aurora automatically promotes a read replcia if main instance fails and handles switch so no endpoint change to client
- Cluster endpoint - targets main instance - used for writes
- Reader endpoint - targets read replicas via an ELB - used for reads
- HA and DR
  - one primary and up to 5 secondary regions
  - data replicates async from primary to secondary regions with low latency
  - leverages storage level replication
  - secondary region can be promoted in case of an outage
- Aurora serverless 
  - great for highly variable workloads, standard better for predicatable workloads
  - Set min and max ACU and Aurora will scale based on load and min / max ACU
  - ACU = Aurora Capacity Units (2GiB, CPU and networking) - can set 0.5-128
- Use cases
  - Postgresql and MySQL
  - Great for HA and fault tollerance
  - Great for read heavy workloads 
  - Serverless good for spiky workloads
  - Low operational overheads