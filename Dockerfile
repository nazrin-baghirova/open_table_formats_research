FROM python:3.11-buster

# Environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV SPARK_VERSION=3.5.4
ENV HADOOP_VERSION=3
ENV SPARK_HOME=/home/spark
ENV PATH=$SPARK_HOME/bin:$PATH
ENV JAVA_VERSION=11
ENV ICEBERG_VERSION = 1.6.0
ENV SPARK_MAJOR_VERSION=3.5

# Install necessary packages and dependencies
RUN apt-get update && apt-get install -y \
    "openjdk-${JAVA_VERSION}-jre-headless" \
    curl \
    wget \
    vim \
    sudo \
    whois \
    ca-certificates-java \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


RUN SPARK_DOWNLOAD_URL="https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala2.13.tgz" \
    && wget --verbose -O apache-spark.tgz "${SPARK_DOWNLOAD_URL}" \
    && mkdir -p /home/spark \
    && tar -xf apache-spark.tgz -C /home/spark --strip-components=1 \
    && rm apache-spark.tgz


    # Set up a non-root user
ARG USERNAME=sparkuser
ARG USER_UID=1000
ARG USER_GID=1000

# Create the docker group first (if not already existing)
RUN groupadd --gid 999 docker || true  

# Create the sparkuser and add it to the docker group
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && usermod -aG docker $USERNAME  # Add the sparkuser to the docker group

# Set ownership for Spark d
RUN chown -R $USER_UID:$USER_GID ${SPARK_HOME}

# Create directories for logs and event logs
RUN mkdir -p ${SPARK_HOME}/logs \
    && mkdir -p ${SPARK_HOME}/event_logs \
    && chown -R $USER_UID:$USER_GID ${SPARK_HOME}/event_logs \
    && chown -R $USER_UID:$USER_GID ${SPARK_HOME}/logs



# Set up Spark configuration for logging and history server
RUN echo "spark.eventLog.enabled true" >> $SPARK_HOME/conf/spark-defaults.conf \
    && echo "spark.eventLog.dir file://${SPARK_HOME}/event_logs" >> $SPARK_HOME/conf/spark-defaults.conf \
    && echo "spark.history.fs.logDirectory file://${SPARK_HOME}/event_logs" >> $SPARK_HOME/conf/spark-defaults.conf
COPY core-site.xml $SPARK_HOME/conf/core-site.xml

# Install Python packages for Jupyter and PySpark
RUN pip install --no-cache-dir jupyter findspark pandas docker


RUN mkdir -p /home/spark/jars

RUN curl -o $SPARK_HOME/jars/hudi-spark3.5-bundle_2.13-0.15.0.jar https://repo1.maven.org/maven2/org/apache/hudi/hudi-spark3.5-bundle_2.13/0.15.0/hudi-spark3.5-bundle_2.13-0.15.0.jar && \
    curl -o $SPARK_HOME/jars/spark-avro_2.13-3.5.2.jar https://repo1.maven.org/maven2/org/apache/spark/spark-avro_2.13/3.5.2/spark-avro_2.13-3.5.2.jar && \
    curl -o $SPARK_HOME/jars/hadoop-aws-3.3.1.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.1/hadoop-aws-3.3.1.jar && \
    curl -o $SPARK_HOME/jars/aws-java-sdk-bundle-1.11.1026.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.11.1026/aws-java-sdk-bundle-1.11.1026.jar && \
    curl -o $SPARK_HOME/jars/delta-spark_2.13-3.3.0.jar https://repo1.maven.org/maven2/io/delta/delta-spark_2.13/3.3.0/delta-spark_2.13-3.3.0.jar && \
    curl -o $SPARK_HOME/jars/delta-spark_2.12-3.3.0.jar https://repo1.maven.org/maven2/io/delta/delta-spark_2.12/3.3.0/delta-spark_2.12-3.3.0.jar && \
    curl -o $SPARK_HOME/jars/delta-storage-3.3.0.jar https://repo1.maven.org/maven2/io/delta/delta-storage/3.3.0/delta-storage-3.3.0.jar && \
    curl -o $SPARK_HOME/jars/iceberg-spark-runtime-3.5_2.12-1.6.0.jar https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.6.0/iceberg-spark-runtime-3.5_2.12-1.6.0.jar && \
    curl -o $SPARK_HOME/jars/iceberg-spark-runtime-3.5_2.13-1.6.0.jar https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.13/1.6.0/iceberg-spark-runtime-3.5_2.13-1.6.0.jar


# Add the entrypoint script
COPY entrypoint.sh /home/spark/entrypoint.sh
RUN chmod +x /home/spark/entrypoint.sh

# Switch to non-root user
USER $USERNAME

# Set workdir and create application directories
RUN mkdir -p /home/$USERNAME/app

WORKDIR /home/$USERNAME/app

# Expose necessary ports for Jupyter and Spark UI
EXPOSE 4040 4041 18080 8888

ENTRYPOINT ["/home/spark/entrypoint.sh"]