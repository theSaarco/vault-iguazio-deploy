#! /bin/bash

kubectl create namespace vault 2>&1 | grep -v "AlreadyExists"
helm repo add hashicorp https://helm.releases.hashicorp.com

USERNAME=$(kubectl -n default-tenant get secrets mlrun-v3io-fuse -o jsonpath='{.data.username}' | base64 -d)
ACCESS_KEY=$(kubectl -n default-tenant get secrets mlrun-v3io-fuse -o jsonpath='{.data.accessKey}' | base64 -d)
kubectl -n vault create secret generic vault-v3io-fuse --type='v3io/fuse' --from-literal=username=$USERNAME --from-literal=accessKey=$ACCESS_KEY 2>&1 | grep -v "AlreadyExists"

SYSTEM_URL=$(kubectl -n default-tenant get ingress mlrun-api -o yaml | grep "host:" | cut -d"." -f2-)
helm install vault hashicorp/vault -n vault -f overrides.yaml --set server.ingress.hosts[0].host="vault.$SYSTEM_URL"

ready=0
while [ $ready -eq 0 ]
do
  echo "Waiting for pod to be ready, sleeping 5 seconds..."
  sleep 5
  ready=$(kubectl -n vault get pods --selector='app.kubernetes.io/name=vault' | grep "1/1" | wc -l)
done

# To make sure initialization is really done.
sleep 1

kubectl exec -n vault vault-0 -- /bin/vault operator init -n 1 -t 1 >vault_keys 2>&1

if grep -Fq "Vault is already initialized" vault_keys
then
	echo "Vault already initialized - not going to overwrite k8s secret"
	rm -rf vault_keys
	exit
fi

ROOT_TOKEN=$(awk -F ":" '/Initial Root Token/ {print $2}' vault_keys)
UNSEAL_KEY=$(awk -F ":" '/Unseal Key 1/ {print $NF}' vault_keys)

kubectl -n vault delete secret vault-init 2>&1 | grep -v "NotFound"
kubectl -n vault create secret generic vault-init --from-literal=root_token="$ROOT_TOKEN" --from-literal=unseal_key="$UNSEAL_KEY"

rm -rf vault_keys
