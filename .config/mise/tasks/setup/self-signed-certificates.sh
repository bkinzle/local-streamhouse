#!/usr/bin/env bash

#MISE description="Sets up self-signed certificates for local development"

if [ -d ${MISE_PROJECT_ROOT}/.ssl ];
then
  echo "Local certificates already exist, skipping"
else
  mkdir -p ${MISE_PROJECT_ROOT}/.ssl
  openssl genrsa -out ${MISE_PROJECT_ROOT}/.ssl/root-ca-key.pem 2048
  openssl req -x509 -new -nodes -key ${MISE_PROJECT_ROOT}/.ssl/root-ca-key.pem -days 3650 -sha256 -out ${MISE_PROJECT_ROOT}/.ssl/root-ca.pem -subj "/CN=kube-ca" -addext "keyUsage=critical,keyCertSign,cRLSign"
  echo "Root certificate created"

  mkdir -p $(brew --prefix)/etc/ca-certificates/${DNSMASQ_DOMAIN}
  cp ${MISE_PROJECT_ROOT}/.ssl/root-ca.pem $(brew --prefix)/etc/ca-certificates/${DNSMASQ_DOMAIN}/local-o11y-stack-ca.crt
  echo "Enter your mac's password and verify trusting to add this to keychain..."
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $(brew --prefix)/etc/ca-certificates/${DNSMASQ_DOMAIN}/local-o11y-stack-ca.crt

  echo "Creating a Java Keystore with the CA Certificate imported..."
  cd ${MISE_PROJECT_ROOT}/.ssl
  keytool -importcert -trustcacerts -file root-ca.pem -alias kubeCA -keystore truststore.jks -storepass changeit -noprompt
fi