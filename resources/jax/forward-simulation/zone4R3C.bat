docker run^
    --user=root^
    --detach=false^
    -v /tmp/.X11-unix:/tmp/.X11-unix^
    --rm^
    -v %CD%:/mnt/shared^
    -i^
    -t^
    yangyangfu/diffbuildings-jax-cuda /bin/bash -c "cd /mnt/shared && python zone4R3C.py"