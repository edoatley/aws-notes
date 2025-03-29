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