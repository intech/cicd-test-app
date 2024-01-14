#!/bin/bash
#REGISTRY="put here registry"
#if needed docker login (to remember)


function get_port {
  if [[ $1 == "printer1" ]]; then
    echo "3000"
  elif [[ $1 == "printer2" ]]; then
    echo "3001"
  fi
}

function check_status {
  start=$(date +%s)

  while true; do
    response=$(curl -s "http://localhost:$1/ready" | jq -r '.master')

    if [[ $response == "false" ]]; then
      current=$(date +%s)
      duration=$((current - start))

      if [[ $duration -gt 5 ]]; then
        logger "new master is not ready, fallback to backup tag"
        break
      fi
    else
      echo "New master is ready, need some magic for backup tag"
      break
    fi

    sleep 1
  done
}

function change_master {
  attempts=0
  max_attempts=5

  while [[ $attempts -lt $max_attempts ]]; do
    status=$(curl -s "$1" | jq -r '.status')
    
    if [[ $status == "ok" ]]; then
      logger "crontask script: stopped master - $master"
      if [[ $(curl -s "http://localhost:$(get_port $master)/ready" | jq -r '.readyToStop') == "true" ]]; then
        sudo docker-compose stop $master  #need to add checking if ready to stop??
        curl -X PUT localhost:$(get_port $non_master)/master   #need to add check if ok?
        check_status $(get_port $non_master)
      else
        logger "crontask script: master is not ready for stop"
      fi
      break
    fi
    
    attempts=$((attempts + 1))3ц
    sleep 5
  done
}




function try_updating {
  master=$1
  non_master=$2
  if [[ $(curl -s "http://localhost:$(get_port $master)/ready" | jq -r '.readyToStop') == "true" ]]; then
    logger "crontask script: master is: $master"
    sudo docker-compose start $non_master
    change_master "http://localhost:$(get_port $non_master)/ready"
  else
    logger "crontask script: master is not ready for stop"
  fi  
}


logger "crontask script: new script start"

# out=$(sudo docker pull $REGISTRY)
out="asdfsfgd"
# out="up to date"
if [[ $out != *"up to date"* ]]; then
  logger "crontask script: $out"
  logger "crontask script: image has been changed, start redeploy"
  response1=$(curl -s --fail localhost:3000/ready | jq -r '.master')
  response2=$(curl -s --fail localhost:3001/ready | jq -r '.master')
  if [[ $response1 == "" && $response2 == "" ]]; then    #init no port answers anything -> no docker-compose is up
    logger "no service is up, starting both"
    sudo docker-compose up -d
  else
    if [[ $response1 == "false" && $response2 == "false" ]]; then
      try_updating printer2 printer1
    else
      if [[ $response1 == "true" ]]; then
        try_updating printer1 printer2
      fi
      if [[ $response2 = "true" ]]; then
          try_updating printer2 printer1
      fi
    fi
  fi
else
    logger "crontask script: no update for the image"
fi