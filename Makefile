CHART_REPO := http://jenkins-x-chartmuseum:8080
NAME := jx-build-templates
OS := $(shell uname)

CHARTMUSEUM_CREDS_USR := $(shell cat /builder/home/basic-auth-user.json)
CHARTMUSEUM_CREDS_PSW := $(shell cat /builder/home/basic-auth-pass.json)

init: 
	helm init --client-only

setup: init
	helm repo add jenkinsxio https://storage.googleapis.com/chartmuseum.jenkins-x.io

build: clean setup
	helm dependency build jx-build-templates
	helm lint jx-build-templates
	./jx/scripts/test.sh

install: clean build
	helm upgrade ${NAME} jx-build-templates --install

upgrade: clean build
	helm upgrade ${NAME} jx-build-templates --install

delete:
	helm delete --purge ${NAME}

clean:
	rm -rf jx-build-templates/charts
	rm -rf jx-build-templates/${NAME}*.tgz
	rm -rf jx-build-templates/requirements.lock

release: clean build
ifeq ($(OS),Darwin)
	sed -i "" -e "s/version:.*/version: $(VERSION)/" jx-build-templates/Chart.yaml

else ifeq ($(OS),Linux)
	sed -i -e "s/version:.*/version: $(VERSION)/" jx-build-templates/Chart.yaml
else
	exit -1
endif
	helm package jx-build-templates
	curl --fail -u $(CHARTMUSEUM_CREDS_USR):$(CHARTMUSEUM_CREDS_PSW) --data-binary "@$(NAME)-$(VERSION).tgz" $(CHART_REPO)/api/charts
	rm -rf ${NAME}*.tgz
