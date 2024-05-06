#!/bin/sh

# Variable
PROFILE="$1" # 원래는 prod
PORT="$2" # 배포에선 상관 없음.
NAME="$3" #wypl-web-prod 상관없음.
TAG="latest"

# Check Current Profile
CURRENT_PROFILE=$(curl -s --connect-timeout 5 http://dev-api.wypl.site/profile)
echo "profile > $CURRENT_PROFILE"
if [ $CURRENT_PROFILE == prod1 ]
then
    IDLE_PROFILE=prod2
    IDLE_PORT=58325
elif [ $CURRENT_PROFILE == prod2 ]
then
    IDLE_PROFILE=prod1
    IDLE_PORT=58324
else
    echo "> 일치하는 Profile이 없습니다. Profile: $CURRENT_PROFILE"
    echo "> prod1을 할당합니다."
    IDLE_PROFILE=prod1
    IDLE_PORT=58324
fi
echo "IDLE_PROFILE > $IDLE_PROFILE IDLE_PROT > $IDLE_PORT "


# Build Docker Image
echo "Building Docker image..."

# DATE_TAG=$(date +%y%m%d%H%M) # Date tag
IDLE_APPLICATION_NAME="$IDLE_PROFILE-$NAME"
ACTIVE_APPLICATION_NAME="$CURRENT_PROFILE-$NAME"

echo "IDLE_APPLICATION_NAME > $IDLE_APPLICATION_NAME"
echo "ACTIVE_APPLICATION_NAME > $ACTIVE_APPLICATION_NAME"

docker build -t "$IDLE_APPLICATION_NAME":"$TAG" . # 최신 버전으로 이미지 빌드

# IDLE Deploy & HEALTH CHECK
echo "> $IDLE_PROFILE 배포"
if [ $(docker ps -aq -f name=$IDLE_APPLICATION_NAME) ]; then
    echo 'Stopping and removing Docker container...'
    docker stop $IDLE_APPLICATION_NAME
    docker rm $IDLE_APPLICATION_NAME
fi
docker run -d --name $IDLE_APPLICATION_NAME -e PROFILE=$PROFILE -p $IDLE_PORT:8080 $IDLE_APPLICATION_NAME:$TAG


echo "> $IDLE_PROFILE 10초 후 Health check 시작"
echo "> curl -s http://api.wypl.site/actuator/health"
sleep 10

for retry_count in {1..10}
do
  APP_CONDITION=$(curl -s --connect-timeout 5 https://api.wypl.site/actuator/health) # -s : slient
  status=$(echo $response | jq -r '.status')

  if [ $status == "UP" ]
  then 
      echo "> Health check 성공: 서비스가 'UP' 상태입니다."
      break
  else
      echo "> Health check 실패: 서비스 상태는 '$status' 입니다."
  fi

  if [ $retry_count -eq 10 ]
  then
    echo "> Health check 실패. "
    echo "> Nginx에 연결하지 않고 배포를 종료합니다."
    exit 1
  fi

  echo "> Health check 연결 실패. 재시도..."
  sleep 10
done

# => 종료할 필요가 없지 않슴..? nginx 설정만 바꾸면 OK

