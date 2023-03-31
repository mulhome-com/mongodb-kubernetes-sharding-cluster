#!/bin/bash

#Creating the config server
kubectl apply -f mongo-cfg.yaml

echo "Waiting config server ..."
kubectl get pods | grep mongo-cfg | grep ContainerCreating

while [ $? -eq 0 ]
do
	sleep 1
	echo -e "\n\nWaiting the following containers..."
	kubectl get pods | grep mongo-cfg | grep ContainerCreating
done

loop=0
master=""
members=""

info=`kubectl -n mulhome-mongo get pod | grep mongo-cfg | awk '{print$1}'` 
for name in ${info}  
do 
	if [[ $loop -eq 0 ]]; then
		master=${name} 
	fi
	members="${members}{_id: ${loop}, host: \"${name}.mongo-cfg-svc:27018\"},"

	let loop=$loop+1
done

CMD='rs.initiate({ _id : "cfg", configsvr: true, members: ['${members::-1}']})'
kubectl exec -it $master -- bash -c "mongo --port 27018 --eval '$CMD'"


#Creating the shard node
kubectl apply -f mongo-rs.yaml

echo "Waiting shard server ..."
kubectl get pods | grep mongo-rs0 | grep ContainerCreating

while [ $? -eq 0 ]
do
	sleep 1
	echo -e "\n\nWaiting the following containers..."
	kubectl get pods | grep mongo-rs0 | grep ContainerCreating
done

loop=0
master=""
members=""
replics=""

info=`kubectl -n mulhome-mongo get pod | grep mongo-rs0 | awk '{print$1}'` 
for name in ${info}  
do 
	if [[ $loop -eq 0 ]]; then
		master=${name} 
		replics="${name}.mongo-rs0-svc:27019"
	fi
	members="${members}{_id: ${loop}, host: \"${name}.mongo-rs0-svc:27019\"},"

	let loop=$loop+1
done

CMD='rs.initiate({ _id : "cfg", configsvr: true, members: ['${members::-1}']})'
kubectl exec -it $master -- bash -c "mongo --port 27019 --eval '$CMD'"


#Creating the mongos server
kubectl apply -f mongos-deployment.yaml

echo "Waiting mongos server ..."
kubectl get pods | grep mongos | grep ContainerCreating

while [ $? -eq 0 ]
do
	sleep 1
	echo -e "\n\nWaiting the following containers..."
	kubectl get pods | grep mongos | grep ContainerCreating
done

mongos=`kubectl get pods | grep mongos | awk '{print$1}'`

kubectl exec -it ${mongos} -- bash -c "mongo --eval 'rs0/${replics}'"

