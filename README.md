
```
git clone https://github.com/Lafok/server-init.git
```
```
cd server-init
```
```
chmod +x setup-server.sh
```
## Insert values and keys in dev or prod env
```
nano .env.dev
```
```
nano .env.prod
```

### DEV 1
#### No DB no SSL
* update the system
* update the system
* create a user
* install Nginx
* configure the develop.harmonica.cloud website
* no database or HTTPS
```
sudo ./setup-server.sh --env dev
```

### DEV 2
#### with DB no SSL
* Everything as in 1
* Install PostgreSQL
* Open port 5432 for the database
```
sudo ./setup-server.sh --env dev --with-db
```

### DEV 3
#### with DB with SSL
* Everything as in 2
* Install Certbot
* Configure HTTPS for develop.harmonica.cloud
```
sudo ./setup-server.sh --env dev --with-db --with-ssl
```

### PROD 1
#### No DB no SSL
* for the domain prod.harmonica.cloud
* without database and HTTPS
```
sudo ./setup-server.sh --env prod
```

### PROD 2
#### with DB no SSL
```
sudo ./setup-server.sh --env prod --with-db
```

### PROD 3
#### with DB with SSL
```
sudo ./setup-server.sh --env prod --with-db --with-ssl
```

## Check
### Nginx
```
systemctl status nginx
```
```
nginx -t
```

### PostgreSQL
```
systemctl status postgresql
```
```
sudo -u postgres psql -c "\l"
```

### Application service
```
systemctl status harmonica.service
```
```
journalctl -u harmonica -n 50
```
