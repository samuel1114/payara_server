FROM openjdk:8-jdk

#LABEL io.openshift.s2i.scripts-url="https://raw.githubusercontent.com/samuel1114/payara-server-s2i-41/master/s2i/bin"

RUN \
 apt-get update && \ 
 apt-get install -y unzip 

ENV ADMIN_USER admin

ENV PAYARA_PATH /opt/payara41

RUN \ 
 mkdir -p ${PAYARA_PATH}/deployments && \
 useradd -b /opt -m -s /bin/bash -d ${PAYARA_PATH} payara && echo payara:payara | chpasswd

# RUN uid=$(id -u payara)                                                                                                                                                                                                                                 

# specify Payara version to download
ENV PAYARA_PKG https://s3-eu-west-1.amazonaws.com/payara.fish/Payara+Downloads/Payara+4.1.2.181/payara-4.1.2.181.zip
ENV PAYARA_VERSION 181

ENV PKG_FILE_NAME payara-full-${PAYARA_VERSION}.zip

# Download Payara Server, install, then remove downloaded file
RUN \
 wget --quiet -O /opt/${PKG_FILE_NAME} ${PAYARA_PKG} && \
 unzip -qq /opt/${PKG_FILE_NAME} -d /opt && \
 chown -R payara:payara /opt && \
 rm /opt/${PKG_FILE_NAME}

USER payara
WORKDIR ${PAYARA_PATH}

# set credentials to admin/admin 

ENV ADMIN_PASSWORD admin

RUN echo 'AS_ADMIN_PASSWORD=\n\
AS_ADMIN_NEWPASSWORD='${ADMIN_PASSWORD}'\n\
EOF\n'\
>> /opt/tmpfile

RUN echo 'AS_ADMIN_PASSWORD='${ADMIN_PASSWORD}'\n\
EOF\n'\
>> /opt/pwdfile

 # domain1
RUN ${PAYARA_PATH}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/opt/tmpfile change-admin-password && \
 ${PAYARA_PATH}/bin/asadmin start-domain domain1 && \
 ${PAYARA_PATH}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/opt/pwdfile enable-secure-admin && \
 ${PAYARA_PATH}/bin/asadmin stop-domain domain1 && \
 rm -rf ${PAYARA_PATH}/glassfish/domains/domain1/osgi-cache

 # payaradomain
RUN \
 ${PAYARA_PATH}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/opt/tmpfile change-admin-password --domain_name=payaradomain && \
 ${PAYARA_PATH}/bin/asadmin start-domain payaradomain && \
 ${PAYARA_PATH}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/opt/pwdfile enable-secure-admin && \
 ${PAYARA_PATH}/bin/asadmin stop-domain payaradomain && \
 rm -rf ${PAYARA_PATH}/glassfish/domains/payaradomain/osgi-cache

# cleanup
RUN rm /opt/tmpfile

ENV PAYARA_DOMAIN domain1
ENV DEPLOY_DIR ${PAYARA_PATH}/deployments
ENV AUTODEPLOY_DIR ${PAYARA_PATH}/glassfish/domains/${PAYARA_DOMAIN}/autodeploy

# Default payara ports to expose
EXPOSE 4848 8009 8080 8181

ENV POSTBOOT_COMMANDS=${PAYARA_PATH}/post-boot-commands.asadmin

COPY generate_deploy_commands.sh ${PAYARA_PATH}/generate_deploy_commands.sh
COPY bin/startInForeground.sh ${PAYARA_PATH}/bin/startInForeground.sh

USER root
RUN \
 chown -R 1000070000 ${PAYARA_PATH} && \
 chgrp -R 0 ${PAYARA_PATH} && \
 chmod -R g=u ${PAYARA_PATH} && \
 chmod 777 ${PAYARA_PATH}/generate_deploy_commands.sh && \
 chmod 777 ${PAYARA_PATH}/bin/startInForeground.sh
ENV APP_ROOT=/opt/app-root
ENV PATH=${APP_ROOT}/bin:${PATH} HOME=${APP_ROOT}
COPY bin/ ${APP_ROOT}/bin/
RUN chown -R 1000070000 ${APP_ROOT} && \
    chmod -R u+x ${APP_ROOT}/bin && \
    chgrp -R 0 ${APP_ROOT} && \
    chmod -R g=u ${APP_ROOT} /etc/passwd
USER 1000070000

ENTRYPOINT ${PAYARA_PATH}/generate_deploy_commands.sh

USER 1000070000
