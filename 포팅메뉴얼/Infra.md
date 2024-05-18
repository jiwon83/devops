# Infra

> 각 서비스에 대한 변수만 수정해주시면 동작합니다.

<!-------########## Back-end ##########--------->
# 1. Back-end.jenkinsfile

<!-- START: deploy-backend.Jenkinsfile  -->
<details>
<summary style="font-size:1.17em;">deploy-backend.jenkinsfile</summary>
<div markdown="1">
<br>

```groovy
pipeline {
    agent any 
    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'deploy/back', credentialsId: 'gitlab-jiwon-token', url: 'https://lab.ssafy.com/s10-final/S10P31A602.git'
            }
        }
        stage('Propertis Download') {
            steps {
                withCredentials( [file(credentialsId: 'backend-s3-yml', variable: 's3'),
                                file(credentialsId: 'backend-jwt-yml', variable: 'jwt'),
                                file(credentialsId: 'backend-logging-yml', variable: 'logging'),
                                file(credentialsId: 'backend-mongo-yml', variable: 'mongo'),
                                file(credentialsId: 'backend-mysql-yml', variable: 'mysql'),
                                file(credentialsId: 'backend-oauth-yml', variable: 'oauth'),
                                file(credentialsId: 'backend-redis-yml', variable: 'redis'),
                                file(credentialsId: 'backend-weather-yml', variable: 'weather')
                               
                                ] ){
                                    script {
                                        sh '''
                                            rm -rf backend/src/main/resources/security
                                            mkdir backend/src/main/resources/security
                                            cp $s3 backend/src/main/resources/security/application-s3.yml
                                            cp $jwt backend/src/main/resources/security/application-jwt.yml
                                            cp $logging backend/src/main/resources/security/application-logging.yml
                                            cp $mongo backend/src/main/resources/security/application-mongo.yml
                                            cp $mysql backend/src/main/resources/security/application-mysql.yml
                                            cp $oauth backend/src/main/resources/security/application-oauth.yml
                                            cp $redis backend/src/main/resources/security/application-redis.yml
                                            cp $weather backend/src/main/resources/security/application-weather.yml
                                            
                                        '''
                                    }
                                }
            }
        }
        stage('Build') {
            steps {
                dir('backend'){
                    sh './gradlew clean bootJar'
                }
            }
        }
        stage('Copy Deploy Script') {
            steps {
                withCredentials([file(credentialsId: 'backend-deploy-sh', variable: 'deploy')]){
                    script {
                        sh '''
                            cp $deploy backend/non-stop-deploy.sh
                            
                        '''
                    }
                }
            }
        }
        stage('Build Docker Image & Deploy') {
            steps {
                sshagent(credentials: ['43.203.229.26-ssh']) {
                    sh'''
                        ssh -o StrictHostKeyChecking=no ubuntu@43.203.229.26 '
                            cd /home/ubuntu/waffle/deploy/ci-cd/data/jenkins/data/workspace/deploy-backend/backend
                            sudo chmod 777 non-stop-deploy.sh
                            bash non-stop-deploy.sh
                        '
                    '''
                }
            }
        }    
        
    }
    post {
        success {
            script {
                withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
                    def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    def gitCommitMessage = sh(script: "git log -1 --pretty=format:'%s'", returnStdout: true).trim()
                    def gitAuthor = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
                    
                    
                    discordSend description: """
                    담당자 : ${gitAuthor}
                    커밋 메시지 : ${gitCommitMessage}
                    실행 시간 : ${currentBuild.duration / 1000}s
                    웹 사이트 : [What's Your Plan](https://wypl.site)
                    """,
                    link: env.BUILD_URL, result: currentBuild.currentResult, 
                    title: "🌐 [Prod] Backend : ${currentBuild.displayName} Success 🚀️", 
                    webhookURL: "$DISCORD"
                }
            }
        }
        failure {
            script {
                withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
                    def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    def gitCommitMessage = sh(script: "git log -1 --pretty=format:'%s'", returnStdout: true).trim()
                    def gitAuthor = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
                    
                    
                    discordSend description: """
                    담당자 : ${gitAuthor}
                    커밋 메시지 : ${gitCommitMessage}
                    실행 시간 : ${currentBuild.duration / 1000}s
                    """,
                    link: env.BUILD_URL, result: currentBuild.currentResult, 
                    title: "🌐 [Prod] Backend : ${currentBuild.displayName} Failure 😭", 
                    webhookURL: "$DISCORD",
                    notes: "@here"
                }
            }
        }
    }
}

```

</div>
</details>
<br>
<!-- END: deploy-backend.Jenkinsfile  -->

<!-- START: non-stop-deploy.sh  -->
<details>
<summary style="font-size:1.17em;">non-stop-deploy.sh</summary>
<div markdown="1">
<br>

```bash
#!/bin/sh

############ Variable ############
PROFILE="$1"
PORT="$2"
IMAGE_NAME="$3" # image name
TAG="latest"
VOLUME_PROFILE="$4" # volume directory name of profile
HOST_VOLUME_PATH="/home/ubuntu/$VOLUME_PROFILE/logs"
DOCKER_VOLUME_PATH="/logs"

########### Build Docker Image ##########
echo "Building Docker image..."
docker build -t "$IMAGE_NAME":"$TAG" .

########### Make Log Directory ##########
if [ ! -d "/home/ubuntu/$VOLUME_PATH/logs" ]; then
    echo "Making log directory..."
    mkdir -p /home/ubuntu/$VOLUME_PATH/logs
fi

########## Deploy ##########
CONTAINER_IDS=$(docker ps -aqf "name=$IMAGE_NAME") #$(docker ps -aq --filter ancestor=$IMAGE_NAME)
echo "Find CONTAINER_IDS ...  >>  $CONTAINER_IDS"

if [ -n "$CONTAINER_IDS" ]; then
    echo 'Stopping and removing Docker container...'
    docker stop $CONTAINER_IDS
    docker rm $CONTAINER_IDS
fi
echo "Deploy Spring Boot!!"
docker run -d --name $IMAGE_NAME -e PROFILE=$PROFILE -p $PORT:8080 -v $HOST_VOLUME_PATH:$DOCKER_VOLUME_PATH $IMAGE_NAME:$TAG
```

</div>
</details>
<br>
<!-- END: non-stop-deploy.sh  -->

<!-- START: dev-backend.jenkinsfile  -->
<details>
<summary style="font-size:1.17em;">dev-backend.jenkinsfile</summary>
<div markdown="1">
<br>

```groovy

pipeline {
    agent any
    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'develop/back', credentialsId: 'gitlab-jiwon-token', url: 'https://lab.ssafy.com/s10-final/S10P31A602.git'
            }
        }
        stage('Propertis Download') {
            steps {
                withCredentials( [file(credentialsId: 'backend-s3-yml', variable: 's3'),
                                file(credentialsId: 'backend-jwt-yml', variable: 'jwt'),
                                file(credentialsId: 'backend-logging-yml', variable: 'logging'),
                                file(credentialsId: 'backend-mongo-yml', variable: 'mongo'),
                                file(credentialsId: 'backend-mysql-yml', variable: 'mysql'),
                                file(credentialsId: 'backend-oauth-yml', variable: 'oauth'),
                                file(credentialsId: 'backend-redis-yml', variable: 'redis'),
                                file(credentialsId: 'backend-weather-yml', variable: 'weather')
                                ] ){
                                    script {
                                        sh '''
                                            rm -rf backend/src/main/resources/security
                                            mkdir backend/src/main/resources/security
                                            cp $s3 backend/src/main/resources/security/application-s3.yml
                                            cp $jwt backend/src/main/resources/security/application-jwt.yml
                                            cp $logging backend/src/main/resources/security/application-logging.yml
                                            cp $mongo backend/src/main/resources/security/application-mongo.yml
                                            cp $mysql backend/src/main/resources/security/application-mysql.yml
                                            cp $oauth backend/src/main/resources/security/application-oauth.yml
                                            cp $redis backend/src/main/resources/security/application-redis.yml
                                            cp $weather backend/src/main/resources/security/application-weather.yml
                                        '''
                                    }
                                }
            }
        }
        stage('Build') {
            steps {
                dir('backend'){
                    sh './gradlew clean bootJar'
                }
            }
        }
        stage('Build Docker Image & Deploy') {
            steps {
                sshagent(credentials: ['43.203.229.26-ssh']) {
                    sh'''
                        ssh -o StrictHostKeyChecking=no ubuntu@43.203.229.26 '
                            cd /home/ubuntu/waffle/deploy/ci-cd/data/jenkins/data/workspace/dev-backend-core/backend
                            sudo chmod +x build-image-and-deploy.sh
                            sh build-image-and-deploy.sh dev 8800 wypl-web-dev wypl
                        '
                    '''
                }
            }
        }    
        stage('Health Check') {
            steps {
                sh'''
                    URL="https://dev-api.wypl.site/actuator/health"
                    MAX_TRIES=10
                    tries=0
                    
                    while [ $tries -lt $MAX_TRIES ]; do
                        response=$(curl -s $URL)
                        if echo "$response" | grep -q "UP"; then
                            echo "Success: Server is UP!"
                            break
                        else
                            echo "Waiting Server..."
                            tries=$((tries+1))
                            if [ $tries -lt $MAX_TRIES ]; then
                                echo "Retrying in 10 seconds..."
                                sleep 3
                            else
                                echo "Failed: Server Is Down..."
                                exit 1
                            fi
                        fi
                    done
                '''
            }
        }
    }
    post {
        success {
            script {
                withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
                    def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    def gitCommitMessage = sh(script: "git log -1 --pretty=format:'%s'", returnStdout: true).trim()
                    def gitAuthor = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
                    
                    
                    discordSend description: """
                    담당자 : ${gitAuthor}
                    커밋 메시지 : ${gitCommitMessage}
                    실행 시간 : ${currentBuild.duration / 1000}s
                    웹 사이트 : [Dev - What's Your Plan](https://dev.wypl.site)
                    API 문서 : [Wypl Swagger Docs](https://dev-api.wypl.site/static/swagger-ui.html#/)
                    서버 상태 확인 : [Health Check](https://dev-api.wypl.site/actuator/health)
                    """,
                    link: env.BUILD_URL, result: currentBuild.currentResult, 
                    title: "🛠 [D️ev] Backend : ${currentBuild.displayName} Success 🚀️", 
                    webhookURL: "$DISCORD"
                }
            }
        }
        failure {
            script {
                withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
                    def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    def gitCommitMessage = sh(script: "git log -1 --pretty=format:'%s'", returnStdout: true).trim()
                    def gitAuthor = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
                    
                    
                    discordSend description: """
                    담당자 : ${gitAuthor}
                    커밋 메시지 : ${gitCommitMessage}
                    실행 시간 : ${currentBuild.duration / 1000}s
                    """,
                    link: env.BUILD_URL, result: currentBuild.currentResult, 
                    title: "🛠 [D️ev] Backend : ${currentBuild.displayName} Failure 😭", 
                    webhookURL: "$DISCORD"
                    // notes: "@here"
                }
            }
        }
    }
}

```

</div>
</details>
<br>
<!-- END: dev-backend.jenkinsfile -->

<!-- START: deploy.sh  -->
<details>
<summary style="font-size:1.17em;">deploy.sh</summary>
<div markdown="1">
<br>

```bash
#!/bin/sh

############ Variable ############
PROFILE="$1"
PORT="$2"
IMAGE_NAME="$3" # image name
TAG="latest"
VOLUME_PROFILE="$4" # volume directory name of profile
HOST_VOLUME_PATH="/home/ubuntu/$VOLUME_PROFILE/logs"
DOCKER_VOLUME_PATH="/logs"

########### Build Docker Image ##########
echo "Building Docker image..."
docker build -t "$IMAGE_NAME":"$TAG" .

########### Make Log Directory ##########
if [ ! -d "/home/ubuntu/$VOLUME_PATH/logs" ]; then
    echo "Making log directory..."
    mkdir -p /home/ubuntu/$VOLUME_PATH/logs
fi

########## Deploy ##########
CONTAINER_IDS=$(docker ps -aqf "name=$IMAGE_NAME") #$(docker ps -aq --filter ancestor=$IMAGE_NAME)
echo "Find CONTAINER_IDS ...  >>  $CONTAINER_IDS"

if [ -n "$CONTAINER_IDS" ]; then
    echo 'Stopping and removing Docker container...'
    docker stop $CONTAINER_IDS
    docker rm $CONTAINER_IDS
fi
echo "Deploy Spring Boot!!"
docker run -d --name $IMAGE_NAME -e PROFILE=$PROFILE -p $PORT:8080 -v $HOST_VOLUME_PATH:$DOCKER_VOLUME_PATH $IMAGE_NAME:$TAG
```

</div>
</details>
<br>
<!-- END: deploy.sh  -->


<!-------########## Front-end ##########--------->

# 2. Front-end.Jenkinsfile

<details>
<summary style="font-size:1.17em;">deploy-frontend.jenkinsfile</summary>
<div markdown="1">
<br>

```groovy

pipeline {
    agent any

    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'deploy/front', credentialsId: 'gitlab-jiwon-token', url: 'https://lab.ssafy.com/s10-final/S10P31A602.git'
            }
        }
        stage('Propertis Download') {
            steps {
                withCredentials( [file(credentialsId: 'frontend-env-prod', variable: 'env')] ){
                    script {
                        sh 'cp $env frontend/.env.prod'
                    }
                }
            }
        }
        stage('Install Dependencies'){
            steps {
                dir('frontend') {
                    nodejs(nodeJSInstallationName: 'NodeJS 22.0.0') {
                        sh 'npm install && npm run build:prod'
                    }
                }
            }
        }
        stage('Remove Frontend Files') {
            steps {
                sshagent(credentials: ['43.203.229.26-ssh']) {
                    sh'''
                        ssh ubuntu@43.203.229.26 `
                            cd /home/ubuntu/waffle/deploy/frontend
                            rm -rf *
                        `
                    '''
                }
            }
        }
        stage('Copy To Deploy Server') {
            steps {
                sshagent(credentials: ['43.203.229.26-ssh']) {
                    sh'''
                        scp -r "frontend/dist" ubuntu@43.203.229.26:/home/ubuntu/waffle/deploy/frontend
                    '''
                }
            }
        }
        stage('Nginx Reload') {
            steps {
                sshagent(credentials: ['43.203.229.26-ssh']) {
                    sh'''
                        ssh -o StrictHostKeyChecking=no ubuntu@43.203.229.26 '
                            sudo systemctl reload nginx
                        '
                    '''
                }
            }
        }
    }
    post {
        success {
            script {
                withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
                    def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    def gitCommitMessage = sh(script: "git log -1 --pretty=format:'%s'", returnStdout: true).trim()
                    def gitAuthor = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
                    
                    
                    discordSend description: """
                    담당자 : ${gitAuthor}
                    커밋 메시지 : ${gitCommitMessage}
                    실행 시간 : ${currentBuild.duration / 1000}s
                    웹 사이트 : [What's Your Plan](https://wypl.site)
                    """,
                    link: env.BUILD_URL, result: currentBuild.currentResult, 
                    title: "🌐 [Prod] Frontend : ${currentBuild.displayName} Success 🚀️", 
                    webhookURL: "$DISCORD"
                }
            }
        }
        failure {
            script {
                withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
                    def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    def gitCommitMessage = sh(script: "git log -1 --pretty=format:'%s'", returnStdout: true).trim()
                    def gitAuthor = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
                    
                    
                    discordSend description: """
                    담당자 : ${gitAuthor}
                    커밋 메시지 : ${gitCommitMessage}
                    실행 시간 : ${currentBuild.duration / 1000}s
                    """,
                    link: env.BUILD_URL, result: currentBuild.currentResult, 
                    title: "🌐 [Prod] Frontend : ${currentBuild.displayName} Failure 😭", 
                    webhookURL: "$DISCORD",
                    notes: "@here"
                }
            }
        }
    }
}


```

</div>
</details>
<br>

<details>
<summary style="font-size:1.17em;">dev-frontend.jenkinsfile</summary>
<div markdown="1">
<br>

```groovy
pipeline {
    agent any

    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'develop/front', credentialsId: 'gitlab-jiwon-token', url: 'https://lab.ssafy.com/s10-final/S10P31A602.git'
            }
        }
        stage('Propertis Download') {
            steps {
                withCredentials( [file(credentialsId: 'frontend-env-dev', variable: 'env')] ){
                    script {
                        sh 'cp $env frontend/.env.dev'
                    }
                }
            }
        }
        stage('Install Dependencies'){
            steps {
                dir('frontend') {
                    nodejs(nodeJSInstallationName: 'NodeJS 22.0.0') {
                        sh 'npm install && npm run build:dev'
                    }
                }
            }
        }
        stage('Rmove Frontend Files') {
            steps {
                sshagent(credentials: ['43.203.229.26-ssh']) {
                    sh'''
                        ssh ubuntu@43.203.229.26 `
                            cd /home/ubuntu/waffle/dev/frontend
                            rm -rf *
                        `
                    '''
                }
            }
        }
        stage('Copy To Deploy Server') {
            steps {
                sshagent(credentials: ['43.203.229.26-ssh']) {
                    sh'''
                        scp -r "frontend/dist" ubuntu@43.203.229.26:/home/ubuntu/waffle/dev/frontend
                    '''
                }
            }
        }
        stage('Nginx Reload') {
            steps {
                sshagent(credentials: ['43.203.229.26-ssh']) {
                    sh'''
                        ssh -o StrictHostKeyChecking=no ubuntu@43.203.229.26 '
                            sudo systemctl reload nginx
                        '
                    '''
                }
            }
        }
    }
    post {
        success {
            script {
                withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
                    def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    def gitCommitMessage = sh(script: "git log -1 --pretty=format:'%s'", returnStdout: true).trim()
                    def gitAuthor = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
                    
                    
                    discordSend description: """
                    담당자 : ${gitAuthor}
                    커밋 메시지 : ${gitCommitMessage}
                    실행 시간 : ${currentBuild.duration / 1000}s
                    웹 사이트 : [Dev - What's Your Plan](https://dev.wypl.site)
                    """,
                    link: env.BUILD_URL, result: currentBuild.currentResult, 
                    title: "🛠 [D️ev] Frontend : ${currentBuild.displayName} Success 🚀️", 
                    webhookURL: "$DISCORD"
                }
            }
        }
        failure {
            script {
                withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
                    def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    def gitCommitMessage = sh(script: "git log -1 --pretty=format:'%s'", returnStdout: true).trim()
                    def gitAuthor = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
                    
                    
                    discordSend description: """
                    담당자 : ${gitAuthor}
                    커밋 메시지 : ${gitCommitMessage}
                    실행 시간 : ${currentBuild.duration / 1000}s
                    """,
                    link: env.BUILD_URL, result: currentBuild.currentResult, 
                    title: "🛠 [D️ev] Frontend : ${currentBuild.displayName} Failure 😭", 
                    webhookURL: "$DISCORD",
                    notes: "@here"
                }
            }
        }
    }
}

```
</div>
</details>

<br>

<!-------########## Nginx ##########--------->

# 3. Nginx

<details>
<summary style="font-size:1.17em;">default</summary>
<div markdown="1">
<br>

```text
#####
# Default server configuration
#####

server {
        listen 80 default_server;
        listen [::]:80 default_server;

        root /var/www/html;

        server_name wypl.site;

        location / {
                return 301 https://wypl.site$request_uri;
        }
}

# SSL 추가
server {
        listen 443 ssl;
        server_name wypl.site;

        ssl_certificate /etc/letsencrypt/live/wypl.site/fullchain.pem;  # SSL 인증서 파일
        ssl_certificate_key /etc/letsencrypt/live/wypl.site/privkey.pem;  # SSL 키 파일

        location / {
                root /home/ubuntu/waffle/deploy/frontend/dist;
                index index.html index.htm;
                try_files $uri $uri/ /index.html;
        }
}
```

</div>
</details>

## 3.2 Frontend

<details>
<summary style="font-size:1.17em;">web-dev.conf</summary>
<div markdown="1">
<br>

<!-- ### 3.2.1 deploy -->
```text
#####
# Dev Web Server configuration
#####

server {
        listen 80;
        listen [::]:80;

        root /var/www/html;

        server_name dev.wypl.site;

        location / {
                return 301 https://dev.wypl.site$request_uri;
        }
}

# SSL 추가
server {
        listen 443 ssl;
        server_name dev.wypl.site;

        location / {
                root /home/ubuntu/waffle/dev/frontend/dist;
                index index.html index.htm;
                try_files $uri $uri/ /index.html;
        }
}

```

</div>
</details>
<br>

## 3.3 Backend

<details>
<summary style="font-size:1.17em;">spring-deploy.conf</summary>
<div markdown="1">
<br>

```text
server {

        listen 80;
        listen [::]:80;

        server_name api.wypl.site;

        location / {
                return 301 https://api.wypl.site$request_uri;

        }
}

server {

        listen 443 ssl;
        server_name api.wypl.site;

        include /etc/nginx/sites-available/deploy-service-url.inc;


        location / {
                proxy_pass $deploy_service_url;
        }

        location /notification {
                proxy_set_header Connection '';
                proxy_set_header Content-Type 'text/envet-stream';
                proxy_buffering off;
                proxy_pass $deploy_service_url;
        }
}

```
</div>
</details>
<br>

<details>
<summary style="font-size:1.17em;">spring-dev.conf</summary>
<div markdown="1">
<br>

```text
server {

        listen 80;
        listen [::]:80;

        server_name dev-api.wypl.site;

        location / {
                return 301 https://dev-api.wypl.site$request_uri;
        }
}

server {

        listen 443 ssl;
        server_name dev-api.wypl.site;

        location / {
                proxy_pass http://43.203.229.26:8800;
        }

        location /notification {
                proxy_set_header Connection '';
                proxy_set_header Content-Type 'text/envet-stream';
                proxy_buffering off;
                proxy_pass http://43.203.229.26:8800;
        }
}

```

</div>
</details>
<br>

<details>
<summary style="font-size:1.17em;">Jenkins.conf</summary>
<div markdown="1">
<br>

```text
server {

        listen 80;
        listen [::]:80;
        root /var/www/html;

        server_name jenkins.wypl.site;

        location / {
                return 301 https://jenkins.wypl.site$request_uri;
        }
}

server {

        listen 443 ssl;

        server_name jenkins.wypl.site;

        location / {
                proxy_pass http://43.203.229.26:8100;
        }
}

```
</div>
</details>
<br>

<details>
<summary style="font-size:1.17em;">grafana.conf</summary>
<div markdown="1">
<br>

```text
#####
# Dev Grafana Configuration
#####

server {
        listen 80;
        listen [::]:80;

        root /var/www/html;

        server_name grafana.wypl.site;

        location / {
                return 301 https://grafana.wypl.site$request_uri;
        }
}

# SSL 추가
server {
        listen 443 ssl;
        server_name grafana.wypl.site;

        location / {
                proxy_pass http://43.203.229.26:8501;
        }
}

```

</div>
</details>
<br>

