```
docker build . -t ansible29
```

Run where ansible project is:

```
docker run -it -v $(pwd):/ansible -v <your_ssh_keys>:<your_ssh_keys> ansible29 /bin/bash
```