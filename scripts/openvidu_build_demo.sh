#!/bin/bash -xe

echo "##################### EXECUTE: openvidu_build_demo #####################"

echo "Cloning openvidu server"
git clone https://github.com/openvidu/openvidu

echo "Removing unnecessary pieces"
rm -rf openvidu/{angular,static}

echo "Adjusting PATHs"
mkdir openvidu-server
cp -ra openvidu/openvidu-server/* openvidu-server

echo "Comment root path Basic Authorization in SecurityConfig.java"
sed -i 's/\.antMatchers(\"\/\").authenticated()/\/\/.antMatchers(\"\/\").authenticated()/g' ./openvidu-server/src/main/java/io/openvidu/server/security/SecurityConfig.java

echo "Copy plainjs-demo web files into static folder of openvidu-server project"
cp -a ../web/. ./openvidu-server/src/main/resources/static/

echo "Build and package maven project"
cd openvidu-server
mvn clean compile package -DskipTests=true
cd ..

echo "Copy .jar in docker build path"
cp openvidu-server/target/openvidu-server-*.jar ../openvidu-server.jar



