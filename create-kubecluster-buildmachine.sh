#!//bin/bash

# cleanup previous builds
if [ -d ~/gopath/src/github.com/Azure/acs-engine/_output/ ]
then
  rm -rf  ~/gopath/src/github.com/Azure/acs-engine/_output/
fi

export PATH=$PATH:/home/chris/bin
#az login
#azure account show
#echo "Enter sub id"
#read subscription
subscription=56e05a15-abff-44df-9297-b6b6c5fcaa8e
sub=$(az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$subscription")
echo $sub
#echo "Resource groupname"
#read rgroupname
rgroupname=$1
agentcount=$2
tmpkey=`echo $(cat ~/.ssh/id_rsa.pub)`
sshKey=$(echo "$tmpkey" | sed 's/\//\\\//g')
clientid=$(echo $sub | jq '.appId')
clientsecret=$(echo $sub | jq '.password')
id=$(uuid)

storageName=$(echo $id | sed 's/-//g' | cut -c 1-10)


export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/gopath
go get github.com/Azure/acs-engine 2>/dev/null
go get all
cd $GOPATH/src/github.com/Azure/acs-engine
go build


cp -f ~/gopath/src/github.com/Azure/acs-engine/examples/kubernetes.json /opt/acs-kube-template.json
cd /opt
sed -in "s/keyData\": \"\"/keyData\": \"$sshKey\"/g" acs-kube-template.json
sed -in "s/servicePrincipalClientID\": \"\"/servicePrincipalClientID\": $clientid/g" acs-kube-template.json
sed -in "s/servicePrincipalClientSecret\": \"\"/servicePrincipalClientSecret\": $clientsecret/g" acs-kube-template.json
sed -in "s/dnsPrefix\": \"\"/dnsPrefix\": \"a${id}z\"/g" acs-kube-template.json


cd ~/gopath/src/github.com/Azure/acs-engine
./acs-engine /opt/acs-kube-template.json
cp -f _output/Kubernetes*/azuredeploy* /opt
cd /opt

azure group create \
    --name=$rgroupname \
    --location="east us"

sed -in '/agentpool1Count/!b;n;c\"value\": '$agentcount'' /opt/azuredeploy.parameters.json
sed -in  's/^.*\"storageAccountBaseName.*/\"storageAccountBaseName\":\"'kube$storageName'\",/' azuredeploy.json

azure group deployment create \
    --name=$id \
    --resource-group="$rgroupname" \
    --template-file="azuredeploy.json" \
    --parameters-file="azuredeploy.parameters.json"

rm -f /opt/azuredeploy.*
rm -f /opt/acs-kube-template.json*

if [ ! -d ~/.kube ]
then
  mkdir ~/.kube 
fi
echo "NOW copy the kube master config to your machine...and you are good to go"
echo "scp azureuser@a${id}z.eastus.cloudapp.azure.com:~/.kube/config ~/.kube/config"
#cd ~/microsoft/acs-kubernetes/kube-deploy
