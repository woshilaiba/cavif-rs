set -exuo pipefail
VERSION=$1

echo "releasing $VERSION"

export MACOSX_DEPLOYMENT_TARGET=10.12
export CARGO_INCREMENTAL=0

rm -rf target/archive/win
mkdir -p target/archive/{mac,win,linux-generic}
rm -rf target/*.deb
rm -rf target/archive/linux-generic/cavif

(
  cargo +nightly build -Z build-std=std,panic_abort -Z build-std-features=panic_immediate_abort --bin cavif --target=x86_64-apple-darwin --release --features=cocoa_image --color=always 2>&1 | sed -e 's/^/maI: /';
  strip target/x86_64-apple-darwin/release/cavif
) &

(
  cargo +nightly build -Z build-std=std,panic_abort -Z build-std-features=panic_immediate_abort --bin cavif --target=aarch64-apple-darwin --release --features=cocoa_image --color=always 2>&1 | sed -e 's/^/ma1: /';
  strip target/aarch64-apple-darwin/release/cavif
) &

(
    ssh mops '"\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat" & cd C:\Users\admin\cavif & git fetch & git reset --hard origin/main & cargo update & cargo build --bin cavif --release' 2>&1 | sed -e 's/^/mops: /';
) &

(
  cargo +nightly build -Z build-std=std,panic_abort -Z build-std-features=panic_immediate_abort --bin cavif --target=x86_64-unknown-linux-musl --release --color=always 2>&1 | sed -e 's/^/msl: /';
  x86_64-elf-strip target/x86_64-unknown-linux-musl/release/cavif # this is homebrew cross tool
  cargo deb --no-build --no-strip --target=x86_64-unknown-linux-musl -o target/
) &

wait
cp target/x86_64-unknown-linux-musl/release/cavif target/archive/linux-generic/
scp mops:cavif/target/release/cavif.exe target/archive/win/;
test target/archive/win/cavif.exe
lipo -create target/x86_64-apple-darwin/release/cavif target/aarch64-apple-darwin/release/cavif  -output target/archive/mac/cavif
codesign -vs "Developer Id" target/archive/mac/cavif;
otool -L target/archive/mac/cavif
cp README.md LICENSE target/archive/
find target/archive -name .DS_Store -delete
( cd target/archive/; rm -f ../cavif-$VERSION.zip;
  zip -9r ../cavif-$VERSION.zip LICENSE README.md mac win linux-generic; )

open -R target/cavif-$VERSION.zip

open "https://github.com/kornelski/cavif/releases/new?tag=v$VERSION"
