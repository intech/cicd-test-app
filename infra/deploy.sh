#!/bin/bash
#REGISTRY="put here registry"
#if needed docker login (to remember)
function change_master {
  attempts=0
  max_attempts=5

  while [[ $attempts -lt $max_attempts ]]; do
    status=$(curl -s "$1" | jq -r '.status')
    
    if [[ $status == "ok" ]]; then
      echo "stopped master - $master"
      sudo docker-compose stop $master   #need to add checking if ready to stop??
      curl -X PUT localhost:$(get_port $non_master)/master   #need to add check if ok?
      break
    fi
    
    attempts=$((attempts + 1))
    sleep 5
  done
}
function get_port {
  if [[ $1 == "printer1" ]]; then
    echo "3000"
  elif [[ $1 == "printer2" ]]; then
    echo "3001"
  fi
}
function try_updating {
    master=$1
    non_master=$2
    echo "master is: $master"
    # out=$(sudo docker pull $REGISTRY)
    out="asdfsfgd"
    # out="up to date"
    if [[ $out != *"up to date"* ]]; then   
        echo $out
        echo "image has been changed, start redeploy"
        sudo docker-compose start $non_master
        change_master "http://localhost:$(get_port $non_master)/ready"

    else
        echo "no update for the image"
    fi
}


date
echo "new script start"

response1=$(curl -s localhost:3000/ready | jq -r '.master')
response2=$(curl -s localhost:3001/ready | jq -r '.master')

if [[ $response1 == "false" && $response2 == "false" ]]; then    #works only if docker-compose is up, need to start docker-compose if nothing is executed? carefull with tags..
    echo "$(try_updating printer2 printer1)"
else
if [[ $response1 == "true" ]]; then
    echo "$(try_updating printer1 printer2)"
fi
if [[ $response2 = "true" ]]; then
    echo "$(try_updating printer2 printer1)"
fi
fi    
