#
# Homebrew Formula for curl + quiche
# Based on https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/curl.rb
#
# brew install -s <url of curl.rb>
#
# You can add --HEAD if you want to build curl from git master (recommended)
#
# For more information, see https://developers.cloudflare.com/http3/tutorials/curl-brew
#
class Curl < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server with HTTP/3 support using quiche"
  homepage "https://curl.se"
  url "https://curl.se/download/curl-7.83.1.tar.bz2"
  mirror "https://github.com/curl/curl/releases/download/curl-7_83_1/curl-7.83.1.tar.bz2"
  mirror "http://fresh-center.net/linux/www/curl-7.83.1.tar.bz2"
  mirror "http://fresh-center.net/linux/www/legacy/curl-7.83.1.tar.bz2"
  sha256 "f539a36fb44a8260ec5d977e4e0dbdd2eee29ed90fcedaa9bc3c9f78a113bff0"
  license "curl"

  livecheck do
    url "https://curl.se/download/"
    regex(/href=.*?curl[._-]v?(.*?)\.t/i)
  end

  bottle do
    sha256 cellar: :any,                 arm64_monterey: "de6b8150f5f89e6fa4341428c3d957de2dc4a127b0ce79ba74b118b5d44e2fd2"
    sha256 cellar: :any,                 arm64_big_sur:  "aca944aebbd9cf46016f68833d7039490e26c56ec6d2c672bca78b3b9b4d1ca0"
    sha256 cellar: :any,                 monterey:       "47943f6b96dd8d3ecc88a6975a94babc8ec93854e390c5713a8b25d7c915994f"
    sha256 cellar: :any,                 big_sur:        "0b9d8bcd39a0a634562dc62c791e65fa77f3cb264c7196713fab45e72ffac9d9"
    sha256 cellar: :any,                 catalina:       "23f58afae9b3715bfaf87a13b61d85e3f38e1beeee129f02002f76dc0d8c9360"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "647aee913233bc3299656f9c97554511740aa5e1fb80934ac73b977fb78b9875"
  end

  head do
    url "https://github.com/curl/curl.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  keg_only :provided_by_macos

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "rust" => :build
  depends_on "brotli"
  depends_on "libidn2"
  depends_on "libnghttp2"
  depends_on "libssh2"
  depends_on "openldap"
  depends_on "openssl@1.1"
  depends_on "rtmpdump"
  depends_on "zstd"

  uses_from_macos "krb5"
  uses_from_macos "zlib"

  resource "quiche" do
    url "https://github.com/cloudflare/quiche.git", branch: "master"
  end

  def install
    # Build with quiche:
    #   https://github.com/curl/curl/blob/master/docs/HTTP3.md#quiche-version
    quiche = buildpath/"quiche/quiche"
    resource("quiche").stage quiche.parent
    cd "quiche" do
      # Build static libs only
      inreplace "quiche/Cargo.toml", /^crate-type = .*/, "crate-type = [\"staticlib\"]"

      system "cargo", "build",
                      "--release",
                      "--package=quiche",
                      "--features=ffi,pkg-config-meta,qlog"
      (quiche/"deps/boringssl/src/lib").install Pathname.glob("target/release/build/*/out/build/lib{crypto,ssl}.a")
    end

    system "./buildconf" if build.head?

    args = %W[
      --disable-debug
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --with-ssl=#{quiche}/deps/boringssl/src
      --with-ca-fallback
      --with-secure-transport
      --with-default-ssl-backend=openssl
      --with-libidn2
      --with-librtmp
      --with-libssh2
      --without-libpsl
      --with-quiche=#{quiche.parent}/target/release
      --enable-alt-svc
    ]

    args << if OS.mac?
      "--with-gssapi"
    else
      "--with-gssapi=#{Formula["krb5"].opt_prefix}"
    end

    system "./configure", *args
    system "make", "install"
    system "make", "install", "-C", "scripts"
    libexec.install "scripts/mk-ca-bundle.pl"
  end

  test do
    # Fetch the curl tarball and see that the checksum matches.
    # This requires a network connection, but so does Homebrew in general.
    filename = (testpath/"test.tar.gz")
    system "#{bin}/curl", "-L", stable.url, "-o", filename
    filename.verify_checksum stable.checksum

    system libexec/"mk-ca-bundle.pl", "test.pem"
    assert_predicate testpath/"test.pem", :exist?
    assert_predicate testpath/"certdata.txt", :exist?
  end
end
