all    :; DAPP_BUILD_OPTIMIZE=1 DAPP_BUILD_OPTIMIZE_RUNS=1 \
        	dapp --use solc:0.5.12 build
clean  :; dapp clean
test   :; ./test-dssspell.sh $(match)
deploy :; make && dapp create DssSpell
