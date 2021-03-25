#!/bin/bash

(
    echo "mongodump --username $USERNAME --password $PASSWORD --port 5000 --out /var/db_data/"
    echo "exit"
    ) | sudo docker exec -ti -e USERNAME=superuser -e PASSWORD=password mongo-container bash
