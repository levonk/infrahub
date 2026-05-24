Need certificates generated for NTS service , but if your just supporting NTS clients, you can skip this

`Dockerfile
RUN apk add openssl
CMD openssl req -x509 -newkey rsa:2048 -nodes \
	-keyout /etc/chrony/server.key \
	-out /etc/chrony/server.crt \
	-days 1 -subj "/CN=ntp.local" && \
	chronyd -d`
