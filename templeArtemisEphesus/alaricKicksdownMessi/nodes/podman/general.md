title: list all containers
creationDate: 2026-09-04 04:42
body: `docker container ls --all`
--
title: start/stop existing container
creationDate: 2026-09-04 04:43
body: `docker container start|stop <container name>`
--
title: override entrypoint
creationDate: 2026-09-04 05:14
body: `docker run -it --entrypoint <command> <container name>`
--
title: remove image
creationDate: 2026-09-04 05:19
body: `docker rmi <image name>`
--
title: remove all dangling images
creationDate: 2026-09-04 05:21
body: `docker image prune`
--
title: remove all images not currently associated with a container
creationDate: 2026-09-04 05:21
body: `docker image prune -a`
