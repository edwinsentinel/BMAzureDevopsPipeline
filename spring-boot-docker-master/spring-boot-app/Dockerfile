#creates a layer from an existing Spring Boot Docker image that exists locally or in any container registry. openjdk:11 will be the one to use.
FROM openjdk:11
# creates a specific space to persist some data in your container
VOLUME /tmp
#informs Docker that the container listens to the specified network ports at runtime
EXPOSE 8080
#defines a variable that can be passed to the application at runtime
ARG JAR_FILE=target/spring-boot-docker.jar
#copies new files, directories or remote file URLs from the source and adds them to the filesystem
ADD ${JAR_FILE} app.jar
#specifies the command that Docker will use to run our app
ENTRYPOINT ["java","-jar","/app.jar"]