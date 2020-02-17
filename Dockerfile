FROM quay.io/jlopsti/ocp-tomcat:1

COPY uol/ecommerce/ /opt/apache-tomcat-7.0.88/webapps/ROOT/

RUN touch /opt/apache-tomcat-7.0.88/logs/catalina.out && \
    chmod 777 /opt/apache-tomcat-7.0.88/logs /opt/apache-tomcat-7.0.88/work && \
    chmod 666 /opt/apache-tomcat-7.0.88/logs/catalina.out /opt/apache-tomcat-7.0.88/conf/* && \
    chown -R 1001:1001 /opt/apache-tomcat-7.0.88

EXPOSE 8080

RUN useradd -u 1001 tomcatuser
USER tomcatuser

CMD /opt/apache-tomcat-7.0.88/bin/startup.sh & tail -F /opt/apache-tomcat-7.0.88/logs/catalina.out
