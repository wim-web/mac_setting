## Python

```sh
asdf install python $PYTHON_VERSION
asdf global python $PYTHON_VERSION
```

## Ansible

```sh
python3 -m pip install --upgrade --user ansible==$ANSIBLE_VERSION
python3 -m pip show ansible
```

asdfと合わさってなんかよくわからん
`~/.asdf/shims/ansible`は合ってる
でも.tool-versionsのエラーはわからん

`rm -f ~/.asdf/shims/ansible*`して再インストールして`asdf reshim`するとなおった
