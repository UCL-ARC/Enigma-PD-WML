date > docker_log.txt
docker run -v "$(pwd)":/home -v "$(pwd)"/code:/code -v "$(pwd)"/data:/data fsl_test  >> docker_log.txt 2>&1
date >> docker_log.txt
