```
docker build . -t openvidu/openvidu-ansible
```

Run where ansible project is:

```
docker run -it -v $(pwd):/ansible -v <your_ssh_keys>:<your_ssh_keys> openvidu/openvidu-ansible /bin/bash
```
