# Periodic backup of mongoDB running inside a docker container

Mongo needs to be running inside a container named *mongo-container*. It also needs to have a docker volume mounted to `/var/db_data`

Copy `make_mongo_backup.sh` to somewhere to the user's home directory. **The user must have sudo permissions without password input!**

If the username running the container is for example *examos-runner*, copy the backup script to `/home/examos-runner/mongo_backup` and run run `crontab -e` and add the following line:

```
0 0 * * 0 /home/examos-runner/mongo_backup/make_mongo_backup.sh
```

Inside `make_mongo_backup.sh`, edit the mongodb listening port, `USERNAME` and `PASSWORD` to correspond your setup.