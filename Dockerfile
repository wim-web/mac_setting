FROM php:8.1.7-fpm-alpine

# renovate: datasource=packagist depName=fzaninotto/faker
RUN yarn global add zenn-cli@1.9.2
