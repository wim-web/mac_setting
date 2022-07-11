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

### update

https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html

```sh
python3 -m pip install --upgrade --user ansible
asdf reshim
```

## finally

fishへの初期設定など

```sh
./finally
```
