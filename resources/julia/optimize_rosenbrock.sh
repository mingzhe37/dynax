docker run \
    --user=root \
    --detach=false \
    -e DISPLAY=${DISPLAY} \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    --rm \
    -v `pwd`:/mnt/shared \
    -i \
    -t \
    yangyangfu/diffbuilding-jl /bin/bash -c "cd /mnt/shared && julia optimize_rosenbrock.jl"