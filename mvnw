#!/bin/sh
# Standard Maven Wrapper launch script

if [ -z "$JAVA_HOME" ] ; then
  JAVACMD=java
else
  JAVACMD="$JAVA_HOME/bin/java"
fi

# Find the project base directory
PRG="$0"
while [ -h "$PRG" ]; do
  ls=$(ls -ld "$PRG")
  link=$(expr "$ls" : '.*-> \(.*\)$')
  if expr "$link" : '/.*' > /dev/null; then
    PRG="$link"
  else
    PRG=$(dirname "$PRG")"/$link"
  fi
done
PRGDIR=$(dirname "$PRG")
MAVEN_PROJECTBASEDIR=$(cd "$PRGDIR" && pwd)

MAVEN_WRAPPER_JAR="$MAVEN_PROJECTBASEDIR/.mvn/wrapper/maven-wrapper.jar"
MAVEN_WRAPPER_PROPERTIES="$MAVEN_PROJECTBASEDIR/.mvn/wrapper/maven-wrapper.properties"

# Download the wrapper JAR if missing
if [ ! -f "$MAVEN_WRAPPER_JAR" ]; then
  if [ -f "$MAVEN_WRAPPER_PROPERTIES" ]; then
    WRAPPER_URL=$(grep 'wrapperUrl' "$MAVEN_WRAPPER_PROPERTIES" | cut -d'=' -f2)
  else
    WRAPPER_URL="https://repo.maven.apache.org/maven2/org/apache/maven/wrapper/maven-wrapper/3.3.2/maven-wrapper-3.3.2.jar"
  fi
  if command -v wget > /dev/null; then
    wget -q -O "$MAVEN_WRAPPER_JAR" "$WRAPPER_URL" || true
  elif command -v curl > /dev/null; then
    curl -fsL -o "$MAVEN_WRAPPER_JAR" "$WRAPPER_URL" || true
  fi
fi

exec "$JAVACMD" \
  -classpath "$MAVEN_WRAPPER_JAR" \
  "-Dmaven.multiModuleProjectDirectory=$MAVEN_PROJECTBASEDIR" \
  org.apache.maven.wrapper.MavenWrapperMain "$@"
