#!/bin/bash --posix

pushd websocat

curl https://sh.rustup.rs -sSf > temp.sh
bash temp.sh -y
rm temp.sh

cargo build --release --features=ssl

popd
