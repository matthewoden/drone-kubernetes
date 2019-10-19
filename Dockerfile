FROM arm32v6/alpine:3.10.2 
RUN apk --no-cache add curl ca-certificates bash
RUN curl -Lo /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/arm/kubectl
RUN chmod +x /usr/local/bin/kubectl
COPY update.sh /bin/
ENTRYPOINT ["/bin/bash"]
CMD ["/bin/update.sh"]
