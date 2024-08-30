FROM cvriend/pgs:latest
WORKDIR /

# Need fslinstaller.py
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    bc \
    dc \
    tree \
    parallel \
    zip && \
    rm -rf /var/lib/apt/lists/*

RUN wget https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/releases/fslinstaller.py && python fslinstaller.py -d /usr/local/fsl/ -V 6.0.7.13

RUN echo '\n # FSL Setup \nFSLDIR=/usr/local/fsl \nPATH=${FSLDIR}/share/fsl/bin:${PATH} \nexport FSLDIR PATH \n. ${FSLDIR}/etc/fslconf/fsl.sh' >> /root/.bashrc

COPY analysis_script.sh .

RUN mkdir /data
RUN mkdir /code

RUN chmod +x analysis_script.sh

ENTRYPOINT ["/analysis_script.sh"]
