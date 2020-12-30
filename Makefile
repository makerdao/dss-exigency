all    :; dapp --use solc:0.5.12 build
clean  :; dapp clean
test   :; ./test-dsspell.sh
deploy :; dapp create DssTests
