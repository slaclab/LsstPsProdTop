# LsstPsProdTop

# Before you clone the GIT repository

1) Create a github account:
> https://github.com/

2) On the Linux machine that you will clone the github from, generate a SSH key (if not already done)
> https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/

3) Add a new SSH key to your GitHub account
> https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/

4) Setup for large filesystems on github (one-time operation)
> $ git lfs install

# Clone the GIT repository
```
$ git clone --recursive git@github.com:slaclab/LsstPsProdTop
```

# How to build the firmware

1) Setup Xilinx licensing
> In C-Shell: 
```
source LsstPsProdTop/firmware/setup_env_slac.csh
```

> In Bash:
```
source LsstPsProdTop/firmware/setup_env_slac.sh
```

2) Go to the target directory and make the firmware:
```
$ cd LsstPsProdTop/firmware/targets/LsstPsProdTop/
$ make
```

4) Optional: Review the results in GUI mode
```
$ make gui
```

# How to launch the Python GUI Software

1) Go to the pyrogue software directory:
```
$ cd LsstPsProdTop/software/rogue/
```

2) Setup Script:
> In C-Shell: 
```
$ source setup_template.csh
```

> In Bash:
```
$ source setup_template.sh
```

3) Run the pyrogue gui script:
```
$ python3 scripts/devGui.py --ip \<IP\>
```

>> \<DEV\> is the IP of the FPGA (example: 192.168.1.20)


# How to reprogram the FPGA's PROM via python

1) Go to the pyrogue software directory:
```
$ cd LsstPsProdTop/software/rogue/
```

2) Setup Script:
> In C-Shell: 
```
$ source setup_template.csh
```

> In Bash:
```
$ source setup_template.sh
```

3) Run the pyrogue gui script:
```
$ python3 scripts/programFpgaProm.py --ip \<IP\> --mcs \<MCS\>
```

>> \<IP\> is the IP of the FPGA (example: 192.168.1.20)

>> \<MCS\> is the path to the .MCS file
