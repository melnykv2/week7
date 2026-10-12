## How to run

```bash
# 1. Turn on Swarm mode (single-node cluster)
docker swarm init

# 2. Deploy the stack
cd task_3_swarm
docker stack deploy -c docker-compose.yaml hc

# 3. Wait until all replicas are running
docker stack services hc
```

## Demonstration

### 1. Swarm cluster

```
$ docker swarm init
Swarm initialized: current node (maa8w5iwu0ksfsaz21wjoz3h7) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token <token> 192.168.65.3:2377

$ docker node ls
ID                            HOSTNAME         STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
maa8w5iwu0ksfsaz21wjoz3h7 *   docker-desktop   Ready     Active         Leader           29.8.0
```

### 2. Deploy

```
$ docker stack deploy -c docker-compose.yaml hc
Creating network hc_backend
Creating service hc_db
Creating service hc_web

$ docker stack services hc
ID             NAME      MODE         REPLICAS   IMAGE              PORTS
v2ojmbr0rtqm   hc_db     replicated   1/1        postgres:17
fjqsrj857eyf   hc_web    replicated   2/2        healthchecks:dev   *:8000->8000/tcp
```

### 3. The overlay networks

```
$ docker network ls --filter driver=overlay
NETWORK ID     NAME         DRIVER    SCOPE
b8wgsy7ar9t2   hc_backend   overlay   swarm
gdhbpfm4fer2   ingress      overlay   swarm

$ docker network inspect hc_backend --format '{{.Driver}} {{.Scope}} {{range .IPAM.Config}}{{.Subnet}}{{end}}'
overlay swarm 10.0.1.0/24
```

### 4. Service discovery and the virtual IP

The network is `attachable`, so a temporary container can join it and query
Docker's DNS:

```
$ docker run --rm --network hc_backend alpine nslookup web
Server:         127.0.0.11
Name:   web
Address: 10.0.1.5

$ docker run --rm --network hc_backend alpine nslookup tasks.web
Server:         127.0.0.11
Name:   tasks.web
Address: 10.0.1.10
Name:   tasks.web
Address: 10.0.1.8
```

- `web` → **one** address, `10.0.1.5`: the service's **virtual IP**. Clients
  (like the app connecting to `db`) use this address, and Swarm balances
  connections across the replicas behind it.
- `tasks.web` → **one address per replica**: the real container IPs.

### 5. Connectivity over the overlay

```
$ docker run --rm --network hc_backend alpine wget -qS -O /dev/null http://web:8000/accounts/login/
  HTTP/1.1 200 OK
```

The request goes by service name, through the VIP, over the overlay network.
The app reaches Postgres the same way: `DB_HOST: db`.

### 6. Load balancing through the routing mesh

```
$ for i in $(seq 1 10); do curl -s -o /dev/null http://localhost:8000/accounts/login/; done
$ docker service logs hc_web 2>&1 | grep curl
hc_web.1.yp3ffvdrmh75@docker-desktop | 10.0.0.2 - - [12/Oct/2026:08:28:56 +0000] "GET /accounts/login/ HTTP/1.1" 200 6712 "-" "curl/8.7.1"
hc_web.1.yp3ffvdrmh75@docker-desktop | 10.0.0.2 - - [12/Oct/2026:08:28:56 +0000] "GET /accounts/login/ HTTP/1.1" 200 6712 "-" "curl/8.7.1"
hc_web.1.yp3ffvdrmh75@docker-desktop | 10.0.0.2 - - [12/Oct/2026:08:28:56 +0000] "GET /accounts/login/ HTTP/1.1" 200 6712 "-" "curl/8.7.1"
hc_web.1.yp3ffvdrmh75@docker-desktop | 10.0.0.2 - - [12/Oct/2026:08:28:56 +0000] "GET /accounts/login/ HTTP/1.1" 200 6712 "-" "curl/8.7.1"
hc_web.1.yp3ffvdrmh75@docker-desktop | 10.0.0.2 - - [12/Oct/2026:08:28:56 +0000] "GET /accounts/login/ HTTP/1.1" 200 6712 "-" "curl/8.7.1"
hc_web.2.kcjgq8uzjkek@docker-desktop | 10.0.0.2 - - [12/Oct/2026:08:28:56 +0000] "GET /accounts/login/ HTTP/1.1" 200 6712 "-" "curl/8.7.1"
hc_web.2.kcjgq8uzjkek@docker-desktop | 10.0.0.2 - - [12/Oct/2026:08:28:56 +0000] "GET /accounts/login/ HTTP/1.1" 200 6712 "-" "curl/8.7.1"
hc_web.2.kcjgq8uzjkek@docker-desktop | 10.0.0.2 - - [12/Oct/2026:08:28:56 +0000] "GET /accounts/login/ HTTP/1.1" 200 6712 "-" "curl/8.7.1"
hc_web.2.kcjgq8uzjkek@docker-desktop | 10.0.0.2 - - [12/Oct/2026:08:28:56 +0000] "GET /accounts/login/ HTTP/1.1" 200 6712 "-" "curl/8.7.1"
hc_web.2.kcjgq8uzjkek@docker-desktop | 10.0.0.2 - - [12/Oct/2026:08:28:56 +0000] "GET /accounts/login/ HTTP/1.1" 200 6712 "-" "curl/8.7.1"
```

- The 10 requests were split **5 / 5** between the two replicas (`hc_web.1`
  and `hc_web.2`).
- Every request comes from `10.0.0.2`, an address on the **`ingress`** network
  (`10.0.0.0/24`), not from the Mac. That's the routing mesh: published port
  8000 is handled by the `ingress` overlay, which forwards each request to one
  of the replicas.

## Bridge vs host vs overlay

| | Bridge (task 2) | Host (task 3) | Overlay (task 3 swarm) |
|---|---|---|---|
| Spans | one host | one host | many hosts (Swarm cluster) |
| Requires | nothing | nothing | Swarm mode |
| Container IP | private, per host | the host's | private, cluster-wide |
| Service discovery | by name | none | by name + VIP load balancing |
| Publishing ports | `ports:` per host | not needed | routing mesh on every node |
| Isolation | yes | no | yes |
| Use case | single-host apps | performance, host-level tools | multi-host clusters, scaling, high availability |

## Cleanup

```bash
docker stack rm hc                # remove services and the hc_backend network
docker swarm leave --force        # turn Swarm mode off
docker volume rm hc_db-data       # optional: delete the database data
```
