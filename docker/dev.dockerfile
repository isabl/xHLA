FROM ubuntu:18.04

# [1] Get noninteractive frontend for Debian to avoid some problems:
#    debconf: unable to initialize frontend: Dialog
# [2] Always combine RUN apt-get update with apt-get install in the same RUN statement for cache busting
# https://docs.docker.com/engine/articles/dockerfile_best-practices/
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
	&& apt-get update -y \
	&& apt-get install -y \
		gcc \
		g++ \
		zlib1g-dev \
		libcurl4-openssl-dev \
		libssl-dev \
		r-base \
		wget \
		python3 \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

RUN wget https://bootstrap.pypa.io/pip/3.5/get-pip.py \
	&& python3 get-pip.py \
	&&  pip install awscli requests pytest boto3 logger

RUN wget https://github.com/samtools/samtools/releases/download/1.3/samtools-1.3.tar.bz2 \
	&& tar xjf samtools-1.3.tar.bz2 \
	&& cd samtools-1.3 \
	&& mv htslib-1.3 temp \
	&& wget https://github.com/humanlongevity/htslib/archive/jpiper/1.3-iam-support.zip \
	&& unzip 1.3-iam-support.zip \
	&& mv htslib-jpiper-1.3-iam-support htslib-1.3 \
	&& cd htslib-1.3 && autoconf && ./configure --enable-libcurl && make -j 8 all && cd .. \
	&& perl -pi -e 's/^(LIBS\s+=)/\1 -lcurl -lcrypto/' Makefile \
	&& make -j 8 \
	&& make install \
	&& cd .. \
	&& rm -rf samtools-1.3*

# for getting reads from 3rd party BAMs
RUN wget http://downloads.sourceforge.net/project/bio-bwa/bwa-0.7.15.tar.bz2 \
    --no-check-certificate \
	&& tar xjf bwa-0.7.15.tar.bz2 \
	&& cd bwa-0.7.15 \
	&& make -j 8 \
	&& mv bwa /usr/bin/ \
	&& cd .. \
	&& rm -rf bwa-*

# for getting reads from 3rd party BAMs
RUN wget https://github.com/lomereiter/sambamba/releases/download/v0.6.6/sambamba_v0.6.6_linux.tar.bz2 \
	&& tar xjf sambamba_v0.6.6_linux.tar.bz2 \
	&& mv sambamba_v0.6.6 /usr/bin/sambamba \
	&& rm sambamba_v0.6.6_linux.tar.bz2

RUN ln -s /usr/bin/python3 /usr/local/bin/python && which python
# for getting reads from 3rd party BAMs
RUN wget https://github.com/arq5x/bedtools2/releases/download/v2.26.0/bedtools-2.26.0.tar.gz \
	&& tar xzf bedtools-2.26.0.tar.gz \
	&& cd bedtools2/ \
	&& make -j 8 \
	&& make install \
	&& cd .. \
	&& rm -rf bedtools*

RUN echo "deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran40/" | tee -a /etc/apt/sources.list \
	&& apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 \
	&& apt-get update && apt-get install -y r-base libxml2-dev libfontconfig1-dev libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev
RUN echo 'install.packages("rlang", repos="http://cran.r-project.org", clean=TRUE);install.packages("devtools", repos="http://cran.r-project.org", clean=TRUE);q()' | R --no-save \
	&& echo 'devtools::install_version("data.table", "1.9.6", repos="http://cran.r-project.org", clean=TRUE);q()' | R --no-save \
	&& echo 'devtools::install_version("lpSolve", "5.6.13", repos="http://cran.r-project.org", clean=TRUE);q()' | R --no-save

RUN echo 'install.packages("BiocManager");BiocManager::install();BiocManager::install("IRanges")' | R --no-save

RUN wget https://github.com/bbuchfink/diamond/releases/download/v0.8.15/diamond-linux64.tar.gz \
	&& tar xzf diamond-linux64.tar.gz \
	&& mv diamond /usr/bin/ \
	&& rm diamond-linux64.tar.gz


RUN echo 'devtools::install_version("data.table", repos="http://cran.r-project.org", clean=TRUE);q()' | R --no-save

WORKDIR /opt
ENV PATH /opt/bin:$PATH
ADD data/ /opt/data/
ADD bin/ /opt/bin/

RUN cd /opt/data && diamond makedb --in hla.faa -d hla

ENTRYPOINT ["python", "/opt/bin/run.py"]
