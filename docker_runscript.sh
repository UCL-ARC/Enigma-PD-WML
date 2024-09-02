date > docker_log.txt
docker run -v "$(pwd)":/home -v "$(pwd)"/code:/code -v "$(pwd)"/data:/data enigma-pd-wml  >> docker_log.txt 2>&1
date >> docker_log.txt
