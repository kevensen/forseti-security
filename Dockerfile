# Copyright 2019 The Forseti Security Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

##### BEGIN BASE IMAGE #####
FROM python:3.6.9-slim-buster as base

ARG UID=1000
ARG GID=1000

ENV HOME=/home/forseti \
    WORK_DIR=/home/forseti/forseti-security \
    PATH=/home/forseti/.local/bin:$PATH

RUN groupadd -g $GID forseti && \
    useradd -d ${HOME} -u $UID -g forseti forseti && \
    mkdir -p ${HOME}/forseti-security && \
    chown -R forseti:forseti ${HOME}

WORKDIR ${WORK_DIR}

USER forseti
##### END BASE IMAGE #####

##### BEGIN PRE-BUILD IMAGE #####
FROM base AS pre-build

USER root
# Install Forseti Security dependencies.
# This should stay in sync with the deployment script used on the host machine in
#   deployment-templates/compute-engine/forseti-instance.py
RUN apt-get update  && \
    apt-get install -y build-essential \
                       libffi-dev \
                       libssl-dev \
                       libgmp-dev \
                       default-libmysqlclient-dev

USER forseti
##### END PRE-BUILD IMAGE #####

##### BEGIN BUILD IMAGE #####
FROM pre-build AS build

# Expose our source so we can install Forseti Security.
COPY --chown=forseti:forseti . ${WORK_DIR}

RUN pip install --no-cache-dir --upgrade -r requirements.txt --user

RUN pip install --no-cache-dir --upgrade google-cloud-profiler --user

# Install Forseti Security.
RUN python setup.py install --user

##### END BUILD IMAGE #####

##### BEGIN RUNTIME IMAGE #####
FROM base AS runtime

USER forseti

ENV PORT 50051

COPY --from=build --chown=forseti:forseti \
    /home/forseti/.local \
    /home/forseti/.local

COPY --from=build --chown=forseti:forseti \
    /home/forseti/forseti-security/.eggs \
    /home/forseti/forseti-security/.eggs

COPY --from=build --chown=forseti:forseti \
    /home/forseti/forseti-security/install/scripts/docker_entrypoint.sh \
    /home/forseti/.local/bin/

RUN chmod u+x /home/forseti/.local/bin/docker_entrypoint.sh

ENTRYPOINT ["docker_entrypoint.sh"]

##### BEGIN Forseti Server IMAGE #####
FROM runtime AS forseti-server

ENV SERVER_HOST 0.0.0.0
ENV SQL_DATABASE_NAME "forseti_security"
ENV SQL_USER root
ENV SERVICES "scanner model inventory explain notifier"
ENV CONFIG_FILE_PATH /forseti-security/forseti_conf_server.yaml
ENV LOG_LEVEL info

EXPOSE $PORT

ENTRYPOINT forseti_server \
           --endpoint $SERVER_HOST:$PORT \
           --forseti_db "mysql+pymysql://${SQL_USER}@/${SQL_DATABASE_NAME}?unix_socket=/cloudsql/${CLOUD_SQL_INSTANCE_NAME}" \
           --services $SERVICES \
           --config_file_path $CONFIG_FILE_PATH \
           --log_level=$LOG_LEVEL \
           --enable_console_log

##### END Forseti Server IMAGE #####
