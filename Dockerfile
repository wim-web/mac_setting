FROM php:8.1.7-fpm-alpine
FROM golang:1.17.6-windowsservercore-1809

# renovate: datasource=composer depName=fzaninotto/faker
RUN yarn global add zenn-cli@1.0.0
