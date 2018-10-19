#!/usr/bin/env bash

if [ "${1}" == "init" ]; then
    chmod +x $HOME/bin/travis_ci_operator.sh
    curl -L https://raw.githubusercontent.com/OriHoch/travis-ci-operator/master/read_yaml.py > $HOME/bin/read_yaml.py
    chmod +x $HOME/bin/read_yaml.py
    curl -L https://raw.githubusercontent.com/OriHoch/travis-ci-operator/master/update_yaml.py > $HOME/bin/update_yaml.py
    chmod +x $HOME/bin/update_yaml.py
    if [ -e .travis.banner ]; then cat .travis.banner; else curl -L https://raw.githubusercontent.com/OriHoch/travis-ci-operator/master/.travis.banner; fi
    ! $(eval echo `read_yaml.py .travis-ci-operator.yaml selfDeployKeyDecryptCmd`) \
        && echo Failed to get self deploy key && exit 1
    echo Successfully initialized travis-ci-operator
    exit 0

elif [ "${1}" == "docker-login" ]; then
    ! docker login -u "${DOCKER_USER}" -p "${DOCKER_PASSWORD}" && echo failed to login to Docker && exit 1
    echo Logged in to Docker
    exit 0

elif [ "${1}" == "github-update" ]; then
    DEPLOY_KEY_NAME="${2}"
    GIT_BRANCH="${3}"
    UPDATE_SCRIPT="${4}"
    COMMIT_MSG="${5}"
    if [ "${DEPLOY_KEY_NAME}" == "self" ]; then
        GITHUB_REPO_SLUG="${TRAVIS_REPO_SLUG}"
    else
        GITHUB_REPO_SLUG="${6}"
    fi
    [ -z "${DEPLOY_KEY_NAME}" ] || [ -z "${GIT_BRANCH}" ] || [ -z "${UPDATE_SCRIPT}" ] || [ -z "${COMMIT_MSG}" ] \
        && echo missing required arguments && exit 1
    [ "${DEPLOY_KEY_NAME}" == "self" ] && [ "${COMMIT_MSG}" == "${TRAVIS_COMMIT_MESSAGE}" ] && [ "${GIT_BRANCH}" == "${TRAVIS_BRANCH}" ] \
        && echo skipping update of self with same commit msg and branch && exit 0
    [ -z "${GITHUB_REPO_SLUG}" ] && echo missing GITHUB_REPO_SLUG && exit 1
    if [ "${DEPLOY_KEY_NAME}" != "self" ]; then
        ! $(eval echo `read_yaml.py .travis-ci-operator.yaml ${DEPLOY_KEY_NAME}DeployKeyDecryptCmd`) \
            && echo Failed to get deploy key && exit 1
    fi
    GITHUB_DEPLOY_KEY_FILE=".travis_ci_operator_${DEPLOY_KEY_NAME}_github_deploy_key.id_rsa"
    if [ -e "${GITHUB_DEPLOY_KEY_FILE}" ]; then
        cp -f "${GITHUB_DEPLOY_KEY_FILE}" ~/.ssh/id_rsa && chmod 400 ~/.ssh/id_rsa
        [ "$?" != "0" ] && echo echo failed to setup deploy key for pushing to GitHub && exit 1
    else
        echo WARNING: deploy key file not found
    fi
    GIT_REPO="git@github.com:${GITHUB_REPO_SLUG}.git"
    TEMPDIR=`mktemp -d`
    echo Cloning git repo ${GIT_REPO} branch ${GIT_BRANCH}
    ! git clone --branch ${GIT_BRANCH} ${GIT_REPO} ${TEMPDIR} && echo failed to clone repo && exit 1
    pushd $TEMPDIR
    eval "${UPDATE_SCRIPT}"
    echo Committing and pushing to GitHub repo ${GIT_REPO} branch ${GIT_BRANCH}
    git commit -m "${COMMIT_MSG}" && ! git push ${GIT_REPO} ${GIT_BRANCH} \
        && echo failed to push change to GitHub && exit 1
    popd
    rm -rf $TEMPDIR
    echo GitHub update completed successfully
    exit 0

elif [ "${1}" == "github-yaml-update" ]; then
    DEPLOY_KEY_NAME="${2}"
    GIT_BRANCH="${3}"
    YAML_FILE="${4}"
    UPDATE_VALUES="${5}"
    COMMIT_MSG="${6}"
    if [ "${DEPLOY_KEY_NAME}" == "self" ]; then
        GITHUB_REPO_SLUG="${TRAVIS_REPO_SLUG}"
    else
        GITHUB_REPO_SLUG="${7}"
    fi
    [ -z "${DEPLOY_KEY_NAME}" ] || [ -z "${GIT_BRANCH}" ] || [ -z "${YAML_FILE}" ] || [ -z "${UPDATE_VALUES}" ] || [ -z "${COMMIT_MSG}" ] \
        && echo missing required arguments && exit 1
    [ "${DEPLOY_KEY_NAME}" == "self" ] && [ "${COMMIT_MSG}" == "${TRAVIS_COMMIT_MESSAGE}" ] && [ "${GIT_BRANCH}" == "${TRAVIS_BRANCH}" ] \
        && echo skipping update of self with same commit msg and branch && exit 0
    [ -z "${GITHUB_REPO_SLUG}" ] && echo missing GITHUB_REPO_SLUG && exit 1
    if [ "${DEPLOY_KEY_NAME}" != "self" ]; then
        ! $(eval echo `read_yaml.py .travis-ci-operator.yaml ${DEPLOY_KEY_NAME}DeployKeyDecryptCmd`) \
            && echo Failed to get deploy key && exit 1
    fi
    GITHUB_DEPLOY_KEY_FILE=".travis_ci_operator_${DEPLOY_KEY_NAME}_github_deploy_key.id_rsa"
    if [ -e "${GITHUB_DEPLOY_KEY_FILE}" ]; then
        cp -f "${GITHUB_DEPLOY_KEY_FILE}" ~/.ssh/id_rsa && chmod 400 ~/.ssh/id_rsa
        [ "$?" != "0" ] && echo failed to setup deploy key for pushing to GitHub && exit 1
    else
        echo WARNING: deploy key file not found
    fi
    GIT_REPO="git@github.com:${GITHUB_REPO_SLUG}.git"
    TEMPDIR=`mktemp -d`
    echo Cloning git repo ${GIT_REPO} branch ${GIT_BRANCH}
    ! git clone --branch ${GIT_BRANCH} ${GIT_REPO} ${TEMPDIR} && echo failed to clone repo && exit 1
    pushd $TEMPDIR
    ! update_yaml.py "${UPDATE_VALUES}" "${YAML_FILE}" \
        && echo failed to update yaml file && exit 1
    echo Committing and pushing to GitHub repo ${GIT_REPO} branch ${GIT_BRANCH}
    git add "${YAML_FILE}"
    git commit -m "${COMMIT_MSG}" && ! git push ${GIT_REPO} ${GIT_BRANCH} \
        && echo failed to push change to GitHub && exit 1
    popd
    rm -rf $TEMPDIR
    echo GitHub yaml update completed successfully
    exit 0

else
    echo unknown command
    exit 1

fi
