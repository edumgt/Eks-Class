# Spring Boot Docker 빌드 명령

## Step-01: Docker 빌드
```t
# 디렉터리 변경
cd 03-notifications-service
mvn clean
mvn install

# 예시
docker build --build-arg JAR_FILE=target/*.jar -t myorg/myapp .

# 1.0.0
#1. pom.xml 버전을 1.0.0으로 업데이트
#2. mvn clean, install
docker build --build-arg JAR_FILE=target/*.jar -t stacksimplify/kube-notifications-microservice:1.0.0 .
docker push stacksimplify/kube-notifications-microservice:1.0.0

# 2.0.0 
#1. Notification Controller Java를 V2로 업데이트
#2. pom.xml 버전을 2.0.0으로 업데이트
#3. mvn clean, install
docker build --build-arg JAR_FILE=target/*.jar -t stacksimplify/
kube-notifications-microservice:2.0.0 .
docker push stacksimplify/kube-notifications-microservice:2.0.0

# 3.0.0-AWS-XRay 
#1. Notification Controller Java를 V3로 업데이트
#2. pom.xml 버전을 3.0.0-AWS-XRay로 업데이트
#3. mvn clean, install
docker build --build-arg JAR_FILE=target/*.jar -t stacksimplify/
kube-notifications-microservice:3.0.0-AWS-XRay  .
docker push stacksimplify/kube-notifications-microservice:3.0.0-AWS-XRay 

```
