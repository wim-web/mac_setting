# Macの設定用Ansible

initializeとfinallyは1回のみ実行される想定

## initialize

Ansibleを動かすまでに必要なツールをインストール

```sh
INITIALIZE=true ./initialize
```

## Ansible

```sh
./ansible/local
```

## finally

fishへの初期設定など

```sh
./finally
```
