# OCRXLAB Infrastructure

> Le nouveau arbutus aura le nom de code 'orcxlab';
> Ici l'idee est de créer un cluster docker swarm nommé 'ocrxlab' constituer de
> de 4 instances (3 masters parmi lesquels nous aurions 2 pivots et 1 worker)

> - ocrxlab-pivot1
> - ocrxlab-pivot2
> - ocrxlab-server1
> - ocrxlab-server2


## Cluster Swarm


### Réorganisation du cluster

1. Supprimer les workers
1. Ajouter les masters
1. Ajouter les workere


```sh
## Master
docker node ls

docker node update --availability drain worker-old-03

docker node rm worker-old-03
docker node rm --force worker-old-03

## worker
docker swarm leave
docker swarm leave --force
```
