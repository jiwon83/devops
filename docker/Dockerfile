# Dockerfile
FROM amazoncorretto:17-alpine

LABEL MAINTAINER="Jiwon Han <gkswldnj0803@gmail.com>"

# 환경변수로부터 JAR 파일 경로를 받습니다.
ARG JAR_FILE

# JAR 파일을 컨테이너 내부로 복사
COPY ${JAR_FILE} wypl.jar

# 애플리케이션 실행 명령
ENTRYPOINT ["java", "-jar", "wypl.jar"]

# 컨테이너 포트 지정
EXPOSE 8800