FROM makerdao/dapphub-tools

WORKDIR /home/maker/dss-exigency
COPY .git .git
COPY archive archive
COPY lib lib
COPY src src
COPY Makefile Makefile
COPY addresses.json addresses.json
COPY test-dssspell.sh test-dssspell.sh

RUN sudo chown -R maker:maker /home/maker/dss-exigency

CMD /bin/bash -c "nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_0_5_12"
CMD /bin/bash -c "export PATH=/home/maker/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin && ./test-dssspell.sh"


