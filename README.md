# docker-image-builder

scripts to automatically build and push image automatically with multiple version

> [!NOTE]
> this script requires you to have a docker hub account, and will need you to login via `docker login` 

> [!IMPORTANT]
> you probably want to makesure first! that there is no error in your docker build. As any error would stop the script from running and you will probably need to start the build from the begining. since the script wont know if it's the base or the prod that failed! and thus this script would probably start from the base